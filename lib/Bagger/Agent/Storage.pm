=head1 NAME

   Bagger::Agent::Storage -- Storage Agent for Bagger

=cut

package Bagger::Agent::Storage;

=head1 SYNOPSIS

   Bagger::Agent::Storage->run

   # or alternative;y (usually used in testing)

   Bagger::Agent::Storage->start
   Bagger::Agent::Storage->loop

   # to stop

   Bagger::Agent::Storage->stop

   # also can write config:

   Bagger::Agent::Storage->write_config

=cut

use 5.020;
use strict;
use warnings;
use AnyEvent;
use Coro;
use AnyEvent::Loop;
use Net::Etcd;
use Getopt::Long;
use Config::IniFiles;
use Sys::Hostname;
use Bagger::Storage::Config;
use Bagger::Storage::Instance;
use Bagger::Agent::Storage::Schaufel;

=head1 DESCRIPTION

This module provides the routines for the agents which run on the storage nodes
which are responsible for listening ot events and processing them.

Bagger uses a distributed configuration store, such as Etcd or Zookeeper for
node configuration, but the point of truth is the lenkwerk PostgreSQL database.
These configuration stores are effectively points of notification and
publication of changes, and the Lenkwerk agent listens to these events and
publishes them to the event store.

The storage agents connect to the Lenkwerk databases in order to retrive the
initial configuration store information and then disconnect.  They may
reconnect if they need to register state, such a node going down.  Nodes going
down, however, are registered on a best effort basis.  Therefore schaufel
instances and their associated agents must handle the case where the node is
down but the system still believes it is up.

Bagger operates under the general assumption that critical structural changes
to the data semantics stored will take place at a point in the future at an
hour boundary.  These changes do not necessarily require a restart of Schaufel
instances.  Servermap changes do require a restart of schaufel instances but
they do not require a new schema just because the servermap changes.

In future versions the agent may publish statistics to the key/value store or
via other ways.  This is not implemented at present however.

If a Schaufel has crashed erroneously, the correct way to restart it is to
restart the agent.  If the node is listed as having a read-only or offline
status, then changing this in Lenkwerk should cause the agent to start
schaufel.

=head1 CONFIGURATION PARAMETERS USED

=head2 Commandline usage

=over

=item -h --host hostname or ip address for Lenkwerk (default: unix socket)

=item -p --port port to connect for Lenkwerk (default: 5432)

=item -U --user username to connect to Lenkwerk (default: same as system username)

=item -d --database database name to connect to (default: lenkwerk)

=item -c --config path/to/config/file (default: no config file)

=item -H --instancehost  Hostname or ip address for the storage node

=item -B --baggerdbuser  Username to connect as Schaufel to Bagger

=item -g --genconfig  Config file to write.

Note that in this case, the agent writes the config and exits without doing
anything else.  This allows you to create a new config file from a template
overwriting whatever you like.

=back

=head2 Configuration file usage

The config file is an inifile with two sections: lenkwerk and instance.

Both contain host, port, and user, and the lenkwerk section can specify a
database as well.

If no user is specified either on commandline or in the file for the connection
to the storage note, the instance's username field is used for the connection.

As with other sections, no provision is made for specifying passwords.  Please
try to use other methods of access where possible, such as certificate
authentication, but when absolutely needed, you can set the PGPASSWORD
environment variable.

An example of a full config file is:

  [lenkwerk]
  host=lenkwerk.mydomain
  port=5432
  username=bagger
  database=lenkwerk

  [instance]
  host=storage-1.mydomain
  port=5432
  username=schaufel

=head2 Lenkwerk Config

=over

=item kvstore_type

The KVStore type (usually 'etcd')

=item kvstore_config

Connection incormation passed to the KVStore driver

=item kafka_topic

A text description of the kafka topic to be consumed

=item kafka_broker

The IP or hostname of the Kafka broker

=item kafka_consumer_group

The ID of the consumer group used

=item schaufel_threads

Integer number of threads to run with Schaufel

=item schaufel_cmd

The command used to launch schaufel, defaults to /usr/bin/schaufel

=item schaufel_log

The place to log schaufel output.  Defaults to /var/log/schaufel/bagger.log

=back

=head1 PROGRAM CONTROL FUNCTIONS

The program control functions provide handles on running the actual agent.

The primary way this is usually run is with the C<run()> package method.  For
testing, C<start()> can be called folloed by C<loop()>.  When it is time to
stop the loop, you can call stop.

=head2 run

The C<run()> function starts the agent and then enters the loop() function.

=cut

# Just a dispatch table
my %prefix_proc = (
    PostgresInstance => \&postgres_instance,
    Index            => \&write_data,
    Dimension        => \&write_data,
    Config           => \&write_data,
    Servermap        => \&update_servermap,
);

sub run {
    start();
    loop();
}

# callback for messages from the key/value store:

sub _process_kvmsg {
    my ($key, $value) = @_;
    for my $k (%prefix_proc) {
        goto $prefix_proc{$k} if $key =~ m#^/$k#;
    }
}

=head2 start

This routine starts the agent.  This includes setting up the waters on etcd and
appropriate callbacks for various types of events.  These are then processed one
at a time as they are received.

=cut

# Using module-local variables for the singular state of the running instance.
# These represent all the constant data needed for handling events.  They should
# ONLY be set by start().
#
# Most of these are config variables which can be reset on restart.
#
my ($hostname, $instanceport, $connect_role, $instance, $retention, $servermap,
    $kvstore, $genconfig, $kafka_topic, $kafka_broker, $kafka_consumer_group,
    $schaufel_threads, @copies, $schaufel, $schaufel_cmd, $schaufel_log);

sub _add_opts {
    return (
        'instancehost|H=s' => \$hostname,
        'instanceport|P=i' => \$instanceport,
        'baggerdbuser|B=s' => \$connect_role,
        'genconfig|g=s'      => \$genconfig,
    );
}

# internal function _my_smap_key()
#
# Returns the key of the primary instance we are responsible for (i.e. the one
# running Schaufel

sub _my_smap_key { join('_', $instance->host, $instance->port) };

# Internal function _cond_start_schaufel
#
# Checks to see if Schaufel is running.
# If not, and it is able to run, we start it

sub _cond_start_schaufel {
    return if $schaufel; # already running
    start_schaufel() if _all_copies_can_write();
}

sub start {
    # get config
    # Bagger::CLI already sets up our db info
    #
    # Step 1:  Find our instance
    write_config() if $genconfig;

    if (!$hostname) {
        # fallback:  inifile, then Sys::Hostname::hostname
        $hostname = (defined $Bagger::CLI::ini{instance}{host}) ?
             $Bagger::CLI::ini{instance}{host} : hostname;
    }
    if(!$instanceport) {
        # fallback: inifile, then if there is only one port rgistered
        # on host
        $instanceport = (defined $Bagger::CLI::ini{instance}{port} ?
             $Bagger::CLI::ini{instance}{port} : undef);
    }

    # At this point we can assume we have a hostname.  We can NOT assume we
    # have a port.

    if ($instanceport) {
        $instance = Bagger::Storage::Instance->get_by_info($hostname, $instanceport);
    } else {
        my @instancelist = rep {$_->host eq $hostname} Bagger::Storage::Instance->list;
        if (scalar @instancelist > 1) {
            die "Was not assigned a port and there are multiple instances for $hostname";
        }
        ($instance) = @instancelist;
    }
    die "No instance for hostname $hostname" unless $instance;

    $servermap = Bagger::Storage::Servermap->most_recent;
    die 'No servermap set yet' unless $servermap;

    # Step 2, servermap preparation
    #
    # we need to get instances for all copies we currently use
    #
    # This is needed to write new Schaufel configs as well as to determine
    # states needed for starting or stopping schaufel.

    for my $item (@{$servermap->servermap->{_my_smap_key}->copies}){
        push @copies, $instance->get_by_info($item->{host}, $item->{port});
    }

    my $kvstore_type = Bagger::Storage::Config->get('kvstore_type');
    my $kvstore_config = Bagger::Storage::Config->get('kvstore_config');
    $kvstore = Bagger::Agent::KVStore->new($kvstore_type, $kvstore_config);

    # Step 3: Schaufel config
    $kafka_topic = Bagger::Storage::Config->get('kafka_topic')->value_string;
    $kafka_broker = Bagger::Storage::Config->get('kafka_broker')->value_string;
    $kafka_consumer_group = Bagger::Storage::Config->get(
        'kafka_consumer_group'
    )->value_string;
    $schaufel_threads = Bagger::Storage::Config->get(
        'schaufel_threads'
    )->value_string;
    $schaufel_cmd = Bagger::Storage::Config->get('schaufel_cmd')->value_string
        || '/usr/bin/schaufel'; # default
    $schaufel_log = Bagger::Storage::Config->get('schaufel_log')->value_string
        || '/var/log/schaufel/bagger.log'; # default


    # Disconnect from Lenkwerk
    my $dbh = $instance->_dbh->disconnect;
    $dbh->disconnect;

    AnyEvent->signal(signal => 'TERM', cb => sub { stop() });
    AnyEvent->signal(signal => 'INT', cb => sub { rude_quit() });

    # We need to set up a dummy sigchild handler here so that when we do watch
    # for the end of a child process, we can properly get it.  So we will set
    # up a handler for our own exit.  This avoids a race condition where the
    # the signal is not handled if Schaufel quickly exits.
    #
    # See AnyEvent main docs for more information
    AnyEvent->child(pid => $$, cb => sub {});

    # enforce_retention to set up next callback
    enforce_retention();
    # set up watches on kvstore
    $kvstore->watch(\&_process_kvmsg);
    _cond_start_schaufel
    return;
}

# internal function _restart()
#
# Clears shared state and starts again.

sub _restart {
    undef $_ for ($kafka_topic, $kafka_broker, $kafka_consumer_group,
                  $schaufel_threads, $instance, $retention, $kvstore);
    undef @copies;
    start();
}

=head2 loop

Enters the main application loop.

=cut

# AnyEvent::Loop::run just advances one_event at a time in an endless loop.
# So here we just set a global state variable and stop when it is set.
my $stop = 0;
sub loop {
    AnyEvent::Loop::one_event while (not $stop);
}

=head2 stop

Stops the event loop and exits.  This is done at the end of te current event
queue.

This works by setting a stop variable and sending an event to process.

=cut

sub stop {
    $stop = 1;
    my $sentinel = AnyEvent->condvar;
    $sentinel->cb(sub {} );
    $sentinel->send; # send noop to be processed
    stop_schaufel();
}

=head2 rude_quit

This simply exits the loop making no attempt to finish processing.

=cut

sub rude_quit {
    stop_shaufel();
    exit(0);
}


=head1 EVENT PROCESSING

Event decisions are based on prefixes on etcd keys.  The following prefixes
require the following actions:

=over

=item /PostresInstance

May require starting or stopping Schaufel if the instance in quesiton is used
by our schaufel.

=item /Index

Write new data to the storage node

=item /Dimension

Write new data to the storage node

=item /Servermap

Write new data to the storage node and restart Schaufel

=item /Config

Write new data to the storage node.

=back

=head1 EVENT HANDLER FUNCTIONS

=head2 write_data

Used to write the data from Etcd to the storage node.

=cut

sub write_data {
    my ($key, $value) = $_;
    Bagger::Agent::Storage::Message->new(
        instance => $instance, key => $key, value => $value
    )->save;
}

=head2 postgres_instance

Checks to see whether our instance is affected and if so, starts or stops
schaufel.

=cut

# Internal function _is_my_key($key)
#
# Must be a /PostgresInstance/ key.
#
# Checks to see if it corresponds to $instance

sub _is_my_key { $_[0] eq _my_smap_key }

# Internal function _is_copy_instance
#
# Returns true if the key corresponds to any of our copies.   Otherwise returns
# false.

# Internal function _instance_key takes an Instance object and returns a
# corresponding key

sub _instance_key { join('/', '/PostgresInstance', $_->host, $_->port) }

sub _is_copy_instance {
    my ($key) = @_;
    return scalar grep { $key eq _instance_key($_) } @copies;
}


# Internal function _all_copies_can_write($key)
#
# Identifies the item in @copies where the key refers, checks the status
# of instance values..  This is done at the end of te current event
# queue.
#
# Returns true if all copies can write.  Returns false if any copy cannot.
#
# This can be called without $key in which case no instances will be updated

sub _all_copies_can_write {
    my ($key) = @_;
    $key //= ''; # default is not to match anything.
    my $can_copy = 1;
    for my $c (@copies) {
        if ($key eq _instance_key($c)){
            $c = Bagger::Storage::Instance->get_instance_by_info($c->host, $c->port);
            $c->_dbh->disconnect;
        }
        $can_copy = $can_copy and $c->can_copy;
    }
    return $can_copy;
}


sub postgres_instance{
    my ($key, $value) = @_;
    write_data($key, $value);
    if (_is_my_instance($key) or _is_copy_instance($key)){
        if (_all_copies_can_write($key) and $schaufel) {
            # we may want to log here in the future
        } elsif (!_all_copies_can_write($key) and $schaufel) {
            stop_schaufel();
        } elsif (_all_copies_can_write($key) and !$schaufel) {
            start_schaufel();
        } elsif (!_all_copies_can_write($key) and !$schaufel) {
            # may want to log here
        }
    }
}

=head2 update_servermap

Writes the data to the storage node stops schaufel and restarts schaufel with the
new hostconfig.  Then re-initiates our own data structures on a phased basis over
about 10 seconds..

=cut

sub update_servermap{
    my ($key, $value) = @_;
    write_data($key, $value);
    restart_schaufel();

    # We don't wnat all agents to restart at once and therefore overwhelm
    # the Lenkwerk database in the case of large clusters.  So we will
    # phase this and assume that the database queries for 10% of the cluster
    # take less than 1 second.
    #
    # Note that Schaufel is already running on the new config so this is not a
    # time-critical operation anymore.
    #
    # Additionally we actually want to pause event processing during this time
    # since we will just get caught up once we restart.

    sleep rand();
    _restart();
}

=head1 AGENT FUNCTION CHANGES

=head2 write_config

Writes our own bootstrapping configuration file and exit.

The file to write is specified by the -g or --genconfig flag.  This means you
can specify -c for a config file to read and -g for a file to write,
overwriting options in the commandline.  This can be useful for bootstrapping
a configuration for the storage node.

=cut

# We use the tied hash API here so hash assignments are write operations.
# Note that autovification does not work on tied hashes so to create a new
# section we have to explicitly initiate it as a new hashref before we can
# assign values to the section.

sub write_conifig{
    tie my %inifile, 'Config::IniFiles', ( -file => $genconfig );
    $inifile{lenkwerk} = {}; # new section, no autovivification
    $inifile{lenkserk}{host}     = Bagger::Storage::LenkwerkSetup->dbhost;
    $inifile{lenkserk}{port}     = Bagger::Storage::LenkwerkSetup->dbport;
    $inifile{lenkserk}{username} = Bagger::Storage::LenkwerkSetup->dbuser;
    $inifile{instance} = {}; # new section, no autovivification
    $inifile{instance}{host}     = $hostname;
    $inifile{instance}{port}     = $instanceport;
    exit(0);
}

=head2 restart_schaufel

Restarts Schaufel

Returns 1 on successful restart, 0 on failure.

This module will B<not> restart Schaufel if it exits with a status other
than 0.

=cut

sub restart_schaufel{
    my $success = stop_schaufel();
    if ($success){
        $success = $success && start_schaufel();
    } else {
        warn "Schaufel exited with a non-zero status.  Not restarting.";
    }
   warn "Unable to restart Schaufel.  It is probably in a stopped state."
        unless $success;
   return $success;
}

=head2 start_shchaufel

Starts Schaufel.  An error will be thrown if Schaufel is already started

=cut

sub start_schaufel {
    $schaufel = Bagger::Agent::Storage::Schaufel->new(
        log => $schaufel_log, broker => $kafka_broker, hosts => [@copies],
        cmd => $schaufel_cmd, topic  => $kafka_topic,
        threads => $schaufel_threads, group => $kafka_consumer_group
    );
    $schaufel->start;

    # Set up sigchild handler
    my $sigchild = sub {
        my ($pid, $status) = @_;
        if ($status != 0) {
            warn "Schaufel stopped with exit code of $status. Stopping agent.";
            warn "Please check Schaufel and Postgres logs, fix the problem, and restart";
            stop();
        }
        # There may be causes where we want to automatically restart schaufel
        # or the agent on a 0 status, but not sure what they are so we need
        # to wait for now.  Chances are this will mostly happen during restart
        # events when we are already restarting Schaufel.
        #
        # However, if we expect to have Schaufel auto-exit in the future, then
        # we need to add an additional listener in that case to restart when
        # that happens.
    };
    my $w = AnyEvent->child(pid => $schaufel->pid, cb => $sigchild);
}

=head2 stop_schaufel

Stops Schaufel.  An error will be thrown if Schaufel is already stopped.

Returns true if schaufel stops with an exit code of 0, returns false if
an exit code is above 1.

=cut

sub stop_schaufel{
    my $sig = shift // 'TERM';
    $schaufel->stop($sig);
}

=head2 enforce_retention

This handles the retention strategy by processing the partition list and
dropping expired tables.

=cut
sub enforce_retention{
    state $timer;
    $timer = AnyEvent->timer(
        after => 3600, interval => 3600, cb => \&enforce_retention
    ) unless $timer;
    # Running this directly but could be eventually moved to a pgobject
    # class
    $instance->cnx->do('select storage.enforce_retention()');
}

1;
