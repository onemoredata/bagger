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

1;
