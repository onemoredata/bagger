=head1 NAME

   Bagger::Agent::Drivers::KVStore::Etcd -- Etcd support for Bagger

=cut

package Bagger::Agent::Drivers::KVStore::Etcd;
use 5.020; # need for hash slices

=head1 SYNOPSIS

This module provides the functions for C<Bagger::Agent::KVStore>.

The exports are automatic and intended to implement those interfaces.

=cut

use strict;
use warnings;
use Exporter 'import';
use MIME::Base64;
use Net::Etcd;
use Moose;
use Bagger::Type::JSON;
with 'Bagger::Agent::Drivers::KVStore'; # enforces api

=head1 DESCRIPTION

This module provides the functions for etcd interaction via the key/value store
agent interaction module.  This driver is capable of doing reads, writes, and
watches.

This provides a full Moose object.

=head1 ATTRIBUTES

All attributes are optional.

=head2 host Str

This is the hostname for the etcd connection.

=cut

has host => (is => 'ro', isa => 'Str', default => 'localhost');

=head2 port Int

Port for connection

=cut

has port => (is => 'ro', isa => 'Int', default => 2379);

=head2 ssl Bool default false

whether to use SSL or not.

=cut

has ssl => (is => 'ro', isa => 'Bool', default => 0);

=head2 user Str

Username for authentication.  Does not authenticate if not set.

=cut

has user => (is => 'ro', isa => 'Str');

=head2 password Str

Password for authentication.

=cut

has password => (is => 'ro', isa => 'Str');

=head2 cnx Net::Etcd

This is the active connection to the etcd database.

=cut

# $self->_slice returns a hashref with the properties requested.
# This relies on the fact that Moose objects are blessed hashrefs.

sub _slice2 {
    my $self = shift;
    my @vars = @_;
    my @list;
    for my $var(@vars){
        push @list, $var, $self->{$var};
    }
    return { @list };
}

sub _slice {
    my $self = shift;
    my @vars = @_;
    return { %{$self}{@vars} };
}

sub _etcd_connect {
    my $self = shift;
    my $cnx = Net::Etcd->new($self->_slice('host', 'port', 'ssl'));
    die 'Could not create new etcd connection' unless $cnx;
    $cnx->auth($self->_slice('user', 'password'))->authenticate if $self->user;
    return $cnx;
}


has cnx => (is => 'ro', isa => 'Net::Etcd', builder => '_etcd_connect', lazy => 1);

=head1 CONSTRUCTOR

=head2 kvconnect

This method should receive a hashref which can then be used to both instantiate
the object and connect.  If it connects properly, it will return an object.  If
it fails to connect, an exception is thrown.

=cut

sub kvconnect {
    my ($class, $arghash) = @_;
    my $self = $class->new($arghash);
}    

=head1 METHODS

=head2 kvread($key)

Reads a value from a key and returns a JSON document payload.

=cut

sub kvread {
    my ($self, $key) = @_;
    my $value =  $self->cnx->range({key => $key })->{response}->{content};
    $value = Bagger::Type::JSON->from_db($value)->{kvs}->[0]->{value};
    return decode_base64($value);
}

=head2 kvwrite($key, value)

Takes a key and a json object and writes it to the etcd store.

=cut

sub kvwrite {
    my ($self, $key, $value)  = @_;
    return $self->cnx->put( { key => $key, value => $value } )->is_success;
}

=head2 kvwatch($subroutine)

Watches all Bagger-related keys and executes $subroutine

=cut

# This will take some work in the storage agent to ensure it works properly
# and is portable

sub _portability_wrapper {
    my $sub = shift;
    &$sub() if ref $sub;
}

sub kvwatch {
    my ($self, $subroutine ) = @_;
    return $self->watch({key => '/Dim', range_end => "\0" }, 
        sub { _portability_wrapper($subroutine) });
}

__PACKAGE__->meta->make_immutable;
