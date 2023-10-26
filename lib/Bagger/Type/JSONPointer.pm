=head1 NAME

   Bagger::Type::JSONPointer -- JSON Pointer support for Bagger

=cut

package Bagger::Type::JSONPointer;
use Moose::Util::TypeConstraints;
use Bagger::Type::JSONPointer;
use overload '""' => 'stringify';
use Carp 'croak';

=head1 SYNOPSIS

   my $ptr = Bagger::Type::JSONPointer->new(
         'foo', 'bar', '1', '2', 'type'
   );

   #or
   #
   my $ptr = Bagger::Type::JSONPointer->new(
       "/foo/bar/1/2/type"
   );

   # If you need to create a one-element jsonpointer that starts with /, then
   # use arrayrefs

   my $ptr = Bagger::Type::JSONPointer->new(["/foo"]);

   # can address elements as arrayref entries.

   say $ptr->[3];
   # prints 2

=cut

use strict;
use warnings;

=head1 DESCRIPTION

   This module provides basic routines for working with JSONPointers.  The idea
   is to provide database-friendly routines for storing and parsing these in
   Perl.

=head1 Construction

   Internally, jsonpointers are represented as arrayrefs of unescaped elements.

   They can be created from the textual representation, from lists, or from
   arrayrefs.  In list or arrayref form, the elements are unescaped.  In string
   form the split string elements are then unescaped.

   For example, the following are identical:

   my $ptr = Bagger::Type::JSONPointer->new('foo', 'bar', '1', '2', 'ba/r');
   my $ptr = Bagger::Type::JSONPointer->new(['foo', 'bar', '1', '2', 'ba/r']);
   my $ptr = Bagger::Type::JSONPointer->new( '/foo/bar/1/2/ba~1r' );

   Note that if only one argument is provided and it starts with a '/' then it
   will be considered a string representation of a jsonpointer and parsed.

   Exceptions Thrown:

   If any argument passed in is a reference (except for a single arrayref,
   "Cannot pass reference" is thrown.

=cut

# _escape escapes values for stringification
# _unescape unescapes values for parsing

sub _escape {
    my $arg = shift;
    $arg =~ s#~#~0#g;
    $arg =~ s#/#~1#g;
    return $arg;
}

sub _unescape {
    my $arg = shift;
    $arg =~ s#~1#/#g;
    $arg =~ s#~0#~#g;
    return $arg;
}

sub _parse {
    my $ptr = shift;
    return [] if $ptr eq '';
    return [$ptr] unless $ptr =~ m#^/#;
    my @elems = split '/', $ptr;
    shift @elems; # remove empty element
    return [ map { _unescape($_) } @elems];
} 

sub new {
    my ($class, @args) = @_;
    if (scalar @args == 1){
        croak "Ref is not arrayref" if ref $args[0] and $args[0] !~ /ARRAY/;
    } else {
        croak 'Cannot pass reference' if grep { ref $_ } @args;
    }
    my $elems;
    for (scalar @args) {
        if ($_ == 0) { $elems = []; }
        if ($_ == 1) { $elems = ref $args[0] ? [@{$args[0]} ] : _parse($args[0]); }
        if ($_ > 1) { $elems = [@args]; }
    }
    bless $elems, $class;
}

=head1 Stringification

   In string contexts, the string representation of the jsonpointer is used.

=cut

sub stringify {
    my $self = shift;
    return '' unless scalar @$self; # return empty if no elements
    return '/' . join '/', map { _escape $_ } @$self;
}

=head1 Moose Integration

  This module defines a Moose type with its class.  No coercions are declared
  because these don't get exported.

=cut

subtype 'Bagger::Type::JSONPointer'
=>  as  'Bagger::Type::JSONPointer';

=head1 Database-facing functions

   We do not currently grab database types since only text types are currently
   supported.  Therefore register() is not required. Instead use Moose
   coercions.  to_db though is supported for PGObject integratoin.

   This is just a way to call stringify.

=head2 to_db

   Serializes the object to a string for storage in the db via PGObject.

=cut

sub to_db {
    my $self = shift;
    return $self->stringify;
}

1;
