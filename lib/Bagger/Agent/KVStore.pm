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
extends 'AnyEvent::KVStore';

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

This is the name of the module to load. Etcd is currently the only supported
driver.

=cut

=head1 config Hashref  Required

This is the configuration passed to the module's connect method.

=cut

coerce 'HashRef'
=> from 'Bagger::Type::JSON'
=> via { return { %{$_} } };

has '+config' => (coerce => 1);


=head1 METHODS

These are the same as L<AnyEvent::KVStore>.

=cut

__PACKAGE__->meta->make_immutable;
