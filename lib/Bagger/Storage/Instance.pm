=head1 NAME

   Bagger::Storage::Instance -- Tracking Storage PostgreSQL Instances

=cut

package Bagger::Storage::Instance;

=head1 SYNOPSIS

   use Bagger::Storage::Instance;

   $my_instance = Bagger::Storage::Instance->get(34);
   # or
   $my_instance = Bagger::Storage::Instance->get_by_info($host, $port);
   $my_instance->set_status(Bagger::Storage::Instance::OFFLINE);

=head1 DESCRIPTION

This module provides utilities for registering, retrieving, and setting
status for storage instances in Bagger clusters.

=cut

use Moose;
use strict;
use warnings;
use namespace::autoclean;
with 'Bagger::Storage::PGObject';
use PGObject::Util::DBMethod;

our $VERSION = '0.0.1';

=head1 STATUS_CONSTANTS

=over

=item OFFLINE is the status for neither reading nor writing.

=item RO is the status for read only (can query but do not ingest)

=item WO is that status for write-only (can ingest but do not query)

=item ONLINE is the status for fully online (can ingest and query)

=back

=cut

use constant {
   OFFLINE => 0,
   RO      => 1,
   WO      => 2,
   ONLINE  => 3,
   F_READ  => 1,
   F_WRITE => 2
};

=head1 ATTRIBUTES

=head2 id

A numeric id for referencing the instance in the database.  This is only set on
instances which have been stored or retrieved from the database.

=cut

has id => (is => 'ro', isa => 'Int', required => 0);

=head2 host

This is a host designation, i.e. either a hostname or ip address.  Required.

=cut

has host => (is => 'ro', isa => 'Str', required => 1);

=head2 port

An integer representation of the database port. Required.  By default set to
5432.

=cut

has port => (is => 'ro', isa => 'Int', default => '5432');

=head2 username

This is the user that Schaufel and related tooling connects as.  Required.

=cut

has username => (is => 'ro', isa => 'Str', required => 1);

=head2 status

This is a numeric representation of the node status.  See status constants
for more on this.  This should not be set on new nodes.

=cut

has status => (is => 'ro', isa => 'Int', default => 0);

=head2 can_read

This indicates whether the node can be queried.  This is generated from
the status.

=cut

has can_read => (is => 'ro', isa => 'Bool', lazy => 1, builder => '_can_read');

sub _can_read {
    my ($self) = @_;
    return bool($self->status & F_READ);
}

=head2 can_write

This indicates whether the node can ingest data.  This is generated from
status.

=cut

has can_write => (is => 'ro', isa => 'Bool', lazy => 1,
                  builder => '_can_write');

sub _can_write {
    my ($self)  = @_;
    return bool($self->status & F_WRITE);
}

=head1 METHODS

=head2 register

This saves the object in the database and returns a new object with status and
id set by the database.  Use as follows:

   $instance = $instance->register();

Or alternatively you can save it as a different variable for comparison:

   my $new_instance = $instance->register();

=cut

dbmethod register => (funcname => 'register_pg_instance', returns_objects => 1);


=head2 get($id)

Returns the db instance by id.

=cut

sub get {
    my ($self, $id) = @_;
    my ($result) = __PACKAGE__->call_procedure(
                     funcname => 'get_pg_instance_by_id', args => [$id]);
    return __PACKAGE__->new($result);
}

=head2 get_by_info($host, $port)

Returns the db instance by hostname and port.

=cut

sub get_by_info {
    my ($self, $host, $port) = @_;
    my ($result) = __PACKAGE__->call_procedure(
                     funcname => 'get_pg_instance_by_host_and_port',
                     args     => [$host, $port]
    );
    return __PACKAGE__->new($result);
}

=head2 set_status($status)

This sets the instance status and returns a new object.

=cut

sub set_status {
    my ($self, $status) = @_;
    my ($result) = $self->call_dbmethod(funcname => 'set_pg_instance_status',
            args => {status => $status});
    return __PACKAGE__->new($result);
}

=head2 list()

This returns a list of instances, set up as objects from the database.

=cut

sub list {
    my ($self) = @_;
    my @results = $self->call_dbmethod(funcname => 'list_pg_instances');
    return map { __PACKAGE__->new($_) } @results;
}

=head2 export()

This returns a hashref with the basic information needed for storing host info
for servermaps etc.

=cut

sub export {
    my $self = shift;
    return { id => $self->id, host => $self->host, port => $self->port }
}

=head2 TO_JSON()

Exports a full copy of the object as a hashref for JSON serialization

=cut

sub TO_JSON { %{$_[0]} }


=head1 SEE ALSO

=cut

__PACKAGE__->meta->make_immutable();

# vim:ts=4:sw=4:expandtab
