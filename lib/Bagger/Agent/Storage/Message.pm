=head1 NAME

    Bagger::Agent::Storage::Message -- Inbound Message Handler of Storage Agent

=cut

package Bagger::Agent::Storage::Message;

=head1 SYNOPSIS

    my $msg = Bagger::Agent::Storage::Message->new(
        instance => $instance, key => $key, value = $value);
    $msg->save;

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use Bagger::Agent::Storage::Mapper 'key_to_relname';
use PGObject::Util::DBMethod;
with 'Bagger::Agent::Storage::PGObject';

=head1 DESCRIPTION

This module provides the basic routines for handling KVStore serialized JSON to
the storage node's own configuration store.  This module is intended to allow a
sort of logical replication from the kvstore of choice into the PostgreSQL
relations used for configuration.  The mechanism is designed to work solely for
Bagger's internal use.

=head1 ATTRIBUTES

=head2 instance (required)

This is brought in via the Bagger::Agent::Storage::PGObject role and provides a
starting point for the interfaces which allow us to write this data to the
storage nodes.

=head2 key (string, required)

This required attribute is the string sent as the key for the kvstore
implementation.

=cut

has key => (is => 'ro', isa => 'Str', required => 1);

=head2 value (string, required)

This required attribute is the JSON received from the kvstore as JSON.

=cut

has value => (is => 'ro', isa => 'Str', required => 1);

=head2 relname (lazy, string0

This is calculated based on the key.  It is used to tell PostgreSQL where to
save the data.

=cut

sub _build_relname { key_to_relname($_[0]->key) };

has relname => (is => 'ro', lazy => 1, builder => '_build_relname');

=head1 METHODS

=head2 save

Writes this to the storage node.

=cut

dbmethod save => (funcname => 'inbound_from_kvstore');
before save => sub { $_[0]->relname };
after save => sub { $_[0]->_dbh->commit}; # needed for visibility.

__PACKAGE__->meta->make_immutable;
