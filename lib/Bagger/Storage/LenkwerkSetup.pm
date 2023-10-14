=head1 NAME

   Bagger::Storage::LenkwerkSetup -- Tooling Config Management for Bagger

=cut

package Bagger::Storage::LenkwerkSetup;

use strict;
use warnings;
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

   Username for database connection to Lenkwerk db

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
   set in the .pgpass file instead.

=over

=item dbpass -- get db password

=item set_dbpass($password) -- set db password

=cut

my $dbpass;

sub dbpass { $dbpass }

sub set_dbpass {
    my ($self, $passwd) = @_;
    $dbpass = $passwd if defined $passwd;
}

1;
