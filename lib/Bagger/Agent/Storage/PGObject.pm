=head1 NAME

    Bagger::Agent::Storage::PGObject -- The PGObject mapper for inbound messages

=cut

package Bagger::Agent::Storage::PGObject;

=head1 SYNOPSIS

    package Bagger::Agent::Storage::Message;
    use Moose;
    with 'Bagger::Agent::Storage::PGObject';

=cut

use strict;
use warnings;
use Moose::Role;
with 'Bagger::Storage::PGObject';

=head1 DESCRIPTION

This PGObject role provides a role for accessing the B<storage> note's lenkwerk
database schema.  This shares most functionality with the
C<Bagger::Storage::PGObject> module, but uses a connection to the storage db
instead.

=head1 REQUIRED ATTRIBUTES

=head2 instance

Must be of  a C<Bagger::Storage::Instance> type.  This is the source of the
database connection.

Now, we can always assume that this database connection is valid for the life
of the connection.

=cut

has instance => (is => 'ro', isa => 'Bagger::Storage::PGObject');

sub _get_dbh { $_[0]->instance->cnx }

1;
