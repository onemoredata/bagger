=head1 NAME

    Bagger::CLI -- Command-Line Common Routines for Bagger Programs

=cut

package Bagger::CLI;

=head1 SYNOPSIS

    use Bagger::CLI;
    run_program('Bagger::Agent::LW');

=cut

## no critic qw(Modules::ProhibitAutomaticExportation)
use Getopt::Long;
use Config::IniFiles;
use Bagger::Storage::LenkwerkSetup;
use strict;
use warnings;
use Exporter 'import';
our @EXPORT = qw(run_program config_file);

=head1 DESCRIPTION

The C<Bagger::CLI> module provides the basic abstractions for running the
command-line tooling around Bagger.  Note that these modules (or the CLI) can
be integrated into infrastructure-as-code frameworks fairly easily.

Additionally this module is used for the "agent" programs which handle
management events and ensure that these are properly propagated across the
control infrastructure.

The overall philosophy here is that command line and config files are here to
bootstrap the overall configuration, the rest of which is handled in the
C<Lenkwerk> database.  Therefore one has to provide either enough information
to get started or accept default values.

=head1 COMMAND-LINE OPTIONS

The CLI framework allows for one to specify a PostgreSQL server to connect to
for further configuration values which can then be operated by the program perl
module.

=over

=item -h --host hostname or ip address to connect to (default: unix socket)

=item -p --port port to connect to (default: 5432)

=item -U --user username to connect as (default: same as system username)

=item -d --database database name to connect to (default: lenkwerk)

=item -c --config path/to/config/file (default: no config file)

=back

The command line has no provision for accepting passwords.  These should be
specified in the C<.pgpass> file as described in the PostgreSQL documnetation.

It is also worth noting that certificate, Kerberos, and peer authentication
all work without passwords.  For details on these, please see the PostgreSQL
documentation.

If you really must specify a password on the commandline, export the
C<PGPASSWORD> environmental variable instead.

If you have a specific program, you can use the C<config_file()> function
to load that without exposing the commandline.

=head1 CONFIG FILE

The config file is very simple.  It is an inifile with a single C<Lenkwerk>
section and fields for C<host>, C<port>, C<username>, and C<database>.

A sample config file is:

  [lenkwerk]
  host=lenkwerk.mydomain
  port=5432
  username=bagger
  database=lenkwerk

The same defaults hold true as for the commandline options above.

=head1 FUNCTIONS

This module offers only a few functions which are aimed at making it easy
to integrate commandline tools into Bagger.

=head2 run_program($class, [ $noargs ])

This function takes one or two arguments.  The first, class, is required and
specifies the program to run.  The second specifies that command-line arguments
should be ignored.  This might be used if a configuration file had been
specified in the code of the program.

The commandline arguments (unless C<$noargs> is set to a true value) are then
parsed and the configuration file, if specified is run.  These are then set for
Lenkwerk database connections.  Then the program class is loaded and the C<run>
function called.

=cut

## no critic qw(Variables::ProhibitPackageVars)
our %ini;
## use critic

sub run_program {
    my ($class, $noargs) = @_;
    ## no critic qw(BuiltinFunctions::ProhibitStringyEval)
    eval "require $class" or die $@;
    $class->import if $class->can('import');
    my @add_opts;
    @add_opts = $class->_add_opts() if $class->can('_add_opts');
    my ($host, $port, $username, $dbname, $configfile);
    unless ($noargs) {
        GetOptions (
            "host|h=s"     => \$host, 
            "port|p=i"     => \$port,
            "username|U=s" => \$username,
            "database|d=s" => \$dbname,
            "config|c=s"   => \$configfile,
            @add_opts,
        );
    }
    if ($configfile) {
        no autovivification;
        tie %ini, 'Config::IniFiles', ( -file => $configfile );
        $host     = $ini{lenkwerk}{host}     if exists $ini{lenkwerk}{host};
        $port     = $ini{lenkwerk}{port}     if exists $ini{lenkwerk}{port};
        $username = $ini{lenkwerk}{username} if exists $ini{lenkwerk}{username};
        $dbname   = $ini{lenkwerk}{database} if exists $ini{lenkwerk}{database};
    }
    Bagger::Storage::LenkwerkSetup->set_dbhost($host) if $host;
    Bagger::Storage::LenkwerkSetup->set_dbport($port) if $port;
    Bagger::Storage::LenkwerkSetup->set_lenkwerkdb($dbname) if $dbname;
    Bagger::Storage::LenkwerkSetup->set_dbuser($username) if $username;
    $class->run;
}

=head2 config_file($configfile)

Processes the config file and passes the values on to LenkwerkSetup.

=cut

sub config_file {
    my $configfile = shift;
    my ($host, $port, $username, $dbname);
    if ($configfile) {
        no autovivification;
        tie %ini, 'Config::IniFiles', ( -file => $configfile );
        $host     = $ini{lenkwerk}{host}     if exists $ini{lenkwerk}{host};
        $port     = $ini{lenkwerk}{port}     if exists $ini{lenkwerk}{port};
        $username = $ini{lenkwerk}{username} if exists $ini{lenkwerk}{username};
        $dbname   = $ini{lenkwerk}{database} if exists $ini{lenkwerk}{database};
    }
    Bagger::Storage::LenkwerkSetup->set_dbhost($host) if $host;
    Bagger::Storage::LenkwerkSetup->set_dbport($port) if $port;
    Bagger::Storage::LenkwerkSetup->set_lenkwerkdb($dbname) if $dbname;
    Bagger::Storage::LenkwerkSetup->set_dbuser($username) if $username;
}

=head1 WRITING BAGGER PROGRAMS

There are a number of things which the Bagger CLI supports which require

=head2 Extending Configuration

There are two important methods for extending configuration supported by
C<Bagger::CLI>.  The first is that additional directives can be placed in the
inifile whose result has a global scope.  If an inifile has been used, the
handler is at C<%Bagger::CLI::ini>.  Additional configuration variables can be
accessed using C<Config::IniFile>'s tied hash API.

The second method, usually used in tandem is to specify an C<_add_opts> in the
main application class of your program.  This MUST return a list with an
even-numbered list of elements.  These get passed along to the C<GetOptions>
call.  Since you would usually pass along references to "my"-scoped variables
in your module, these would get written there.

=cut

1;
