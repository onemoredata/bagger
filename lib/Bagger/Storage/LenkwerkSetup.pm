=head1 NAME

   Bagger::Storage::LenkwerkSetup -- Tooling Config Management for Bagger

=cut

package Bagger::Storage::LenkwerkSetup;

use strict;
use warnings;
use URI::Escape;
use Carp 'croak';
use Capture::Tiny 'capture';
our $VERSION = '0.0.1';

=head1 SYNOPSIS

   This module contains basic getters and setters for common config info.

   To get the dbhost:

   Bagger::Storage::AppSetup->dbhost

   To set the dbhost:

   Bagger::Storage::AppSetup->set_dbhost('127.0.0.1');

=head1 DESCRIPTION

   This module provides the tooling configuration management for the rest of
   the Bagger tooling.  This allows us to manage having configuration
   considerations separate from the mechanism of their retrieval.

   For example configuration formats could be substituted, etc. or info
   supplied on the command line, and the tooling routines don't have to know
   how the information was received.

   For each config parameter, a pair of functions is used.  The getter has no
   prefix or other annotations, while the setter has set_ prefixed.  This is
   because the configuration here is intended to be set only in limited places
   in the application and so it is important to keep this sort of read/write
   segregation here.

   If setters are called without a defined argument, they do nothing.  There
   is no provision to unset a config variable.

   All configuration parameters should be in ASCII or UTF-8 (which is an ASCII
   superset.

=head1 Config Accessors

=head2 dbhost -- Hostname or IP address of lenkwerk database host

=over

=item dbhost -- gets the database host

=item set_dbhost($host) -- sets the database host

=back

=cut

my $dbhost;

sub dbhost { $dbhost }

sub set_dbhost {
    my ($self, $host) = @_;
    $dbhost = $host if defined $host;
}

=head2 dbport -- Port number for lenkwerk database -- defaults to 5432

=over

=item dbport  -- gets the database port

=item set_dbport($port) -- sets the database port.

=back

=cut

my $dbport = 5432; # default

sub dbport { $dbport };

sub set_dbport {
    my ($self, $port) = @_;
    croak 'Port must be an integer' if $port =~ /\D/;
    croak "Postgres cannot use privileged port $port" if $port < 1024;
    croak "Port $port out of range, must be between 1024 and 65535" 
                                                              if $port > 65535;
    $dbport = $port if defined $port;
}

=head2 lenkwerkdb

   database name for the lenkwerk database.  Defaults to lenkwerk.

=over

=item lenkwerkdb -- gets db name for lenkwerk connection

=item set_lenkwerkdb($dbname) -- sets database name for lenkwerk connection

=back

=cut

my $lenkwerkdb = "lenkwerk";

sub lenkwerkdb { $lenkwerkdb }

sub set_lenkwerkdb {
    my ($self, $dbname) = @_;
    $lenkwerkdb = $dbname if defined $dbname;
}

=head2 dbuser

   Username for database connection to Lenkwerk db.  Initially this is
   undefined, and will default (via libpq) to the OS user the script runs as.

=over

=item dbuser -- get dbuser

=item set_dbuser($username) -- sets dbuser

=back

=cut

my $dbuser;

sub dbuser { $dbuser }

sub set_dbuser {
    my ($self, $uname) = @_;
    $dbuser = $uname if defined $uname;
}

=head2 dbpass

   Password for database connection to Lenkwerk db

   Note if this is only run from a couple of locations, the password could be
   set in the .pgpass file instead.  PGPASSWORD can also be used to pass in the
   password.  See libpq documentation for details.

=over

=item dbpass -- get db password

=item set_dbpass($password) -- set db password

=back

=cut

my $dbpass;

sub dbpass { $dbpass }

sub set_dbpass {
    my ($self, $passwd) = @_;
    $dbpass = $passwd if defined $passwd;
}

=head2 dbi_str

 Gets the dbi connectin string for the database connection based on current settings.

=cut

sub _dbi_str_keyval {
    my ($value, $key) = @_;
    return () unless $value;
    return ("$key=$value");
}

sub dbi_str { "DBI:Pg:" . 
             join(';', _dbi_str_keyval($lenkwerkdb, 'database'),
                       _dbi_str_keyval($dbhost, 'host'),
                       _dbi_str_keyval($dbport, 'port'),
	 )
}

=head2 dsn_uri

   Returns a well-formed URI from config input.  All items are properly
   escaped.

=cut

sub dsn_uri {
    my $dsn = 'postgresql://';
    $dsn .= join ':', (uri_escape_utf8($dbuser // ''),
                       uri_escape_utf8($dbpass // ''));
    $dsn .= '@';
    $dsn .= join ':', (uri_escape_utf8($dbhost // ''),
                       uri_escape_utf8($dbport // ''));
    $dsn .= '/';
    $dsn .= uri_escape_utf8($lenkwerkdb);
    return $dsn;
}


# use for programs that don't support dsn's
sub _cli_args {
    return (
        ($dbuser ? ('-U', "$dbuser") : ()),
        ($dbhost ? ('-h', "$dbhost") : ()),
        ($dbport ? ('-p', $dbport) : ()),
        '--no-password',
    );
}

=head1 DATABASE SETUP ROUTINES

=head2 createdb

  This function creates a database and returns 1 if successful and 0 if not.

  It thrown an exception if the database name has not been specified.

=cut

sub createdb {
    croak 'No database set' unless $lenkwerkdb;
    local $! ; # mask last system error

    # If we are told to use a password, then we will
    # mask the environment variable in this routine.
    #
    # This is safer than alternatives.

    local $ENV{PGPASSWORD} = $dbpass if defined $dbpass;
    my ($stdout, $stderr, $failure) = capture {
        return system('createdb', _cli_args, $lenkwerkdb);
    };
    warn 'Database creation failed' if $failure;
    for my $line (split /^/m, $stderr){
        warn $line if $stderr;
    } 
    return not $failure;
}


=head2 load

  Loads the database with the extensions for the various schemas required.

  Returns 1 if successful, 0 if not.

  Throws an exception if the database name is not specified.

=cut

my %exts = (
     bagger_lw_storage => '0.0.1',
);
sub load {
    croak 'No database set' unless $lenkwerkdb;
    my $success = 1;
    for my $ext (keys %exts) {
        local $! = undef; # mask last system error
        my ($stdout, $stderr, $failure) = capture { 
            return system('psql', dsn_uri, '-c', 
                "create extension ${ext} version '$exts{$ext}'");
        };
        for my $line (split /^/m, $stderr){
            warn $line if $stderr;
        } 
	warn "Error loading extension $ext" if $failure;
        return 0 if $failure;
    }
    return 1;
}

1;

# vim:ts=4:sw=4:expandtab
