=head1 NAME

    Bagger::Type::JSON -- Database-facing JSON type

=cut

package Bagger::Type::JSON;
use parent 'PGObject::Type::JSON';
use Moose::Util::TypeConstraints;
use strict;
use warnings;
use Carp 'croak';

subtype __PACKAGE__
 => as  __PACKAGE__;

=head1 SYNOPSIS

  my $json = Bagger::Type::JSON->new($val_or_ref);
  
  my $orig = Bagger::Type::JSON->orig;

=head1 DESCRIPTION

  This module provides proper JSON serialization and deserialization
  from the database via PGObject::Type::JSON.  However, it also provides
  an orig function to get back whatever was passed in.  This is intended
  to make integration with Moose classes far easier.

=head1 METHODS

=head2 Inherited Methods

=over

=item new

=item to_db

=item from_db

=item TO_JSON

=item reftype

=back

=head2 orig

  Returns the original item passed into the constructor and optionally
  persisted/retrieved from the database.

  Note for reference types, the references will still be blessed and we
  just return $self.

=cut

sub orig {
    my $self = shift;
    return $$self if $self->reftype eq 'SCALAR';
    return $self;
}


1;
# vim:ts=4:sw=4:expandtab
