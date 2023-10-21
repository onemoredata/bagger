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
use Bagger::Type::DateTime::Infinite;
use Carp 'croak';

Bagger::Type::DateTime->register();

=head1 DESCRIPTION

   The Bagger::Type::DateTime module provides a number of important functions,
   including database serialization for database types and transparent handling
   of infinite timestamps in PostgreSQL.  These functions may be contributed to
   the upstream PGObject::Type::DateTime project.

   Additionally, this module provides some basis for tuning settings for
   partition boundaries.  These are specific to Bagger and will be retained here.

=cut

=head1 Infinite Timestamp Handling

   This module provides timestamp handling for infinity and -infinity values
   from PostgreSQL transparently.  These are mapped to subclasses of the
   appropriate DateTime subclasses.

   Values are properly serialized to/from the database.  If you need
   obtain a timestamp infinitely far in the future or past, you can call these
   functions.

=head2 inf_future()

   Returns a timestamp infinitely far in the future.

   See DateTime::Infinite::Future for more details.

=cut

sub inf_future {
    return Bagger::Type::DateTime::Infinite::Future->new();
}

=head2 inf_past

   Returns a timestmap infinitely far in the past.

   See DateTime::Infinite::Past for more details.

=cut

sub inf_past {
    return Bagger::Type::DateTime::Infinite::Past->new();
}

=head2 from_db($string_value)

   Returns an object of this class or a subclass based on the stored data int
   the database.

   infinity or +infinity maps to inf_future

   -infinity maps to inf_past

=cut

sub from_db {
    my ($class, $val) = @_;
    return $class->inf_future if ($val =~ /^\+?infinity$/);
    return $class->inf_past if $val eq '-infinity';
    my $retval = $class->SUPER::from_db($val);
    bless $retval, $class;
}

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
    return $self->now->truncate(to => 'hour')->add( hours => (1 + $hours));
}

1;
