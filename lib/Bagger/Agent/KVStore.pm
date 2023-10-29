=head1 NAME

   Bagger::Agent::KVStore -- Key/Value Store Handling for Bagger agents

=cut

package Bagger::Agent::KVStore;

=head1 SYNOPSIS

   my $kvstore = Bagger::Agent::KVStore->new(module => 'etcd', config => $config);
   my $object = $kvstore->read('/Servermap');
   $kvstore->write('/servermap', '{"version" : '1'}');
   $kvstore->watch(sub { handle_change(@_) });

=cut
use strict;
use warnings;
use Moose;
use Carp 'croak';
use Bagger::Type::JSON;
use Moose::Util::TypeConstraints;
use Bagger::Agent::Storage::Mapper qw(pg_object kval_key);
use namespace::autoclean;

=head1 DESCRIPTION

Bagger stores minimal cluster state information (such as known storage notes,
their states, ingestion topology information, and configuration information) in
a key-value store such as etcd or zookeeper (though as of 1.0, only etcd is
supported).

The key value store provides what is effectively a notification service to the
agents running on storage nodes and it allows these notifications to scale well
regardless of other considerations.  This module provides the primary way of
interacting with it.

Note that there is an apparent inconsistency in the API between the reading and
writing.  Reading assumes we return objects while writing assumes we receive 
already-serialized JSON.  The reason for this is due to the information flow
between the various agents.

The intended flow is that tooling and agents make changes in the Lenkwerk
database.  These are then logically captured by Postgres in JSON format and
replicated to the key value store via this module.  For this reason we expect
JSON values in.

Then storage agents listen for changes and have to act on these changes.  These
then need to be returned in the form of objects for proper handling.  The point
of truth is Lenkwerk, and the key-value store provides a means of publication.

The inconsistencies then in the API specifically help to function as a safety
to ensure that all data proper ends up in the right places.

=head1 ATTRIBUTES

=head2 module Str  Required

This is the name of the module to load.  Currently only 'etcd' is supported.

=cut

subtype 'kvstore_module',
     as 'Str',
     where { my $m = $_; scalar( grep { $m eq $_ } qw(etcd)) },
     message { "$_ is not a valid module, must be one of (etcd)" };

has module => (is =>'ro', isa => 'kvstore_module', required => 1);

has _proxy => (is => 'ro', builder => '_connect', lazy => 1);

sub _connect {
    my $self = shift;
    my $module = 'Bagger::Agent::Drivers::KVStore::' . ucfirst($self->module);
    {
        local $@;
        eval "require $module";
        die $@ if $@;
    }
    return $module->kvconnect($self->config);
}

=head1 config Hashref  Required

This is the configuration passed to the module's connect method.

=cut

coerce 'HashRef'
=> from 'Bagger::Type::JSON'
=> via { return { %{$_} } };

has config => (is => 'ro', isa => 'HashRef', coerce => 1, required => 1);

has _proxy => (is => 'ro', isa => 'Object', builder => '_connect', lazy => 1);

=head1 METHODS

=head2 read($key)

Reads a key, returns the string stored in the KVStore. Use get_object below
to wrap this in an object.

=cut

sub read {
    my ($self, $key) = @_;
    my $value = $self->_proxy->kvread($key);
    return $value;
}

=head2 get_object($key)

Reads the key from the KV Store, determines the appropriate object type
from the eky, and returns the key.  Returns undef if no class found.

=cut

sub get_object {
    my ($self, $key) = @_;
    my $value = $self->read($key);
    $value = Bagger::Type::JSON->from_db($self->_proxy->kvread($key));
    my $class = pg_object($key);
    return defined $class ? $class->new($value) : undef;
}

=head2 write($key, $value)

Writes the value to the database.  This is to be a pre-serialized JSON value.

=cut

sub write {
    my ($self, $key, $value) = @_;
    croak 'Cannot write reference!' if ref $value;
    return $self->_proxy->kvwrite($key, $value);
}


=head2 watch($callback)

Adds a watch event with a callback on events.  Currently only all events are
supported.

=cut

sub watch {
    my ($self, $callback) = @_;
    return $self->_proxy->kvwatch($callback);
}
1;
__PACKAGE__->meta->make_immutable;
