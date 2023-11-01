=head1 NAME

   Bagger::Type::DateTime -- Datetime types with DB wrappers

=cut

package Bagger::Type::DateTime;

=head1 SYNOPSIS

   my $dt = Bagger::Type::DateTime(...); # same constructor methods as DateTime

   # or if you need infinites

   my $dt = Bagger::Type::DateTime->inf_future;

   or
  
   $dt = Bagger::Type::DateTime->inf_past;

=cut

use parent 'PGObject::Type::DateTime'; # includes basic serializations
use strict;
use warnings;
use Moose::Util::TypeConstraints;
use Carp 'croak';

subtype 'PGObject::Type::DateTime'
 => as  'PGObject::Type::DateTime';

Bagger::Type::DateTime->register();

=head1 DESCRIPTION

   The Bagger::Type::DateTime module provides a number of important functions,
   including database serialization for database types and transparent handling
   of infinite timestamps in PostgreSQL.  These functions may be contributed to
   the upstream PGObject::Type::DateTime project.

   Additionally, this module provides some basis for tuning settings for
   partition boundaries.  These are specific to Bagger and will be retained here.

=cut

=head1 BAGGER-SPECIFIC Functions

=head2 Bagger::Type::DateTime->hour_bound_plus($hours)

   Returns a new Bagger::Type::DateTime object from the current time starting
   on the next hour plus $int hours more.

   So if it is '2023-08-02 23:59:59' then calling this method with an argumment
   of 1 will lead to '2023-08-03 01:00:00'

   Positive ints are required to ensure that the agents have time to update
   partition, index, etc information before the data is expected to be there.

   Although an hour is probably too long, this ensures at least one
   hourly partitioning time boundary to pass before these new settings take
   effect.

   Note this MUST be called with -> notation due to the need to ensure the
   correct class of the output.

=cut

sub hour_bound_plus{
    my ($self, $hours) = @_;
    croak 'Hours must be an int!' if int($hours) ne $hours;
    croak 'Hours must be positive' if $hours < 1;
    my $retval =  $self->now->truncate(to => 'hour')->add( hours => (1 + $hours));
    $retval->{_pgobject_is_tz} = 0;
    return $retval;
}

1;
