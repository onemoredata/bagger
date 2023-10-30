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
my ($hostname, $instanceport, $connect_role, $instance, $retention, $servermap,
    $kvstore, $genconfig);

sub _add_opts {
    return (
        'instancehost|H=s' => \$hostname,
        'instanceport|P=i' => \$instanceport,
        'baggerdbuser|B=s' => \$connect_role,
        'genconfig|g=s'      => \$genconfig,
    );
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

    my $kvstore_type = Bagger::Storage::Config->get('kvstore_type');
    my $kvstore_config = Bagger::Storage::Config->get('kvstore_config');
    $kvstore = Bagger::Agent::KVStore->new($kvstore_type, $kvstore_config);

    # enforce_retention to set up next callback
    enforce_retention();
    # set up watches on kvstore
    $kvstore->watch(\&_process_kvmsg);
    return;
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

Stops the event loop and exits

=cut

sub stop {
    $stop = 1;
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
    # Write data to local instance
    # need to write row, thinking of just passing the json to populate_record.
}

=head2 postgres_instance

Checks to see whether our instance is affected and if so, starts or stops
schaufel.

=cut

sub postgres_instance{
    my ($key, $value) = @_;
    write_data($key, $value);
    # Need to see if it is us or one of our copies
    # Handle state appropriately
}

=head2 update_servermap

Writes the data to the storage node, writes a new Schaufel config, and
restarts Schaufel.

=cut

sub update_servermap{
    my ($key, $value) = @_;
    write_data($key, $value);
    write_schaufel_config();
    restart_schaufel();
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

=head2 write_schaufel_config

Writes the schaufel config based on the servermap

=cut

sub write_schaufel_config{}

=head2 restart_schaufel

Restarts Schaufel

=cut

sub restart_schaufel{}

=head2 enforce_retention

This handles the retention strategy by processing the partition list and
dropping expired tables.

=cut

sub enforce_retention{
    AnyEvent->timer(after => 3600, cb => \&enforce_retention);
}

1;
