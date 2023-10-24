=head1 NAME

   Bagger::Storage::Index::Field - Index Field Handling for Bagger

=cut

package Bagger::Storage::Index::Field;

=head1 SYNOPSIS

   $field = Bagger::Storage::Index::Field->new(
            ordinality => $index->next_ordinal,
            expression => cast(json_field('foo'), 'int')
   );
   push @{$index->fields} $field;

   Note you can pass a Bagger::Type::JSONPointer object to expression
   and have it automatically converted!

=cut

use strict;
use warnings;
use Moose;
use Carp 'croak';
use PGObject::Util::DBMethod;
use Moose::Util::TypeConstraints;
with 'Bagger::Storage::PGObject', 'Bagger::Storage::Time_Bound';

sub _config_hours_out {'indexes_hrs_in_future'}
sub root_element { 'data' }

=head1 DESCRIPTION

This module exists to model index fields.

=head1 PROPERTIES

=over

=item id -- id (when stored in the db)

=cut

has id => (is => 'ro', isa => 'Int');

=item index_id -- id of index (when stored in db)

Can be set once only.

=cut

sub _check_indexid {
    my ($self, $new_val, $old_val) = @_;
    croak "We already had an index_id" if defined $old_val;
}

has index_id => (is => 'rw', isa => 'Int');

=item ordinality -- field order number.  Required.

=cut

has ordinality => (is => 'ro', isa => 'Int', required => 1);

=item expression -- indexed expression.  Required. See helper funcs below

Note that if expression is a C<Bagger::Type::JSONPointer> type, it will
be converted into an expression automatically.

=back

=cut

subtype 'Bagger::Type::JSONPointer' => as  'Bagger::Type::JSONPointer';

coerce 'Str' 
   => from 'Bagger::Type::JSONPointer'
   => via { __PACKAGE__->from_json_pointer($_) };

has expression => (is => 'ro', isa => 'Str', required => 1, coerce => 1);

=head1 EXPRESSON HELPER FUNCTIONS

=head2 cast(expression, type)

Returns an expression casing one SQL expression to given type.  The type name
will be escaped.

This can be called with either -> or :: calling conventions but must otherwise
have exactly two arguments.

Due to the pain of reindexing large data sets, this function is very strict
about number of arguments.
=cut

sub cast {
    my ($self, $expression, $type); # due to lexical scopes
    if (@_ == 2) { # for :: calling conventions
        ($expression, $type) = @_;
    }
    elsif (@_ == 3) {
        ($self, $expression, $type) = @_;
    } elsif (@_ < 3 ) { # for -> calling conventions
        croak 'Too many arguments to cast!  Expected 2.';
    } else {
        croak 'Not enough arguments to cast!  Expected 2.';
    }
    return "${expression}::" . $self->_get_dbh->quote_identifier($type);
}

=head2 extract_from_json_object($expression, $field)

This returns a chained expression extracting the field $field from the
JSON output of $expression.

This function is very strict regarding parameters but can be called with
either :: or -> conventions

=cut

sub extract_from_json_object{
    my ($self, $expression, $field); # due to lexical scopes
    if (@_ == 2) { # for :: calling conventions
        ($expression, $field) = @_;
    }
    elsif (@_ == 3) {
        ($self, $expression, $field) = @_;
    } elsif (@_ < 3 ) { # for -> calling conventions
        croak 'Too many arguments to extract_from_json_object!  Expected 2.';
    } else {
        croak 'Not enough arguments to extract_from_json_object!  Expected 2.';
    }
    return "($expression)->" . $self->_get_dbh->quote($field);
}

=head2 json_field

Returns an expression as extraction of the named field from the JSON field
used in the top-level of the json object stored by Bagger.

=cut

sub json_field {
    my ($self, $field) = @_;
    croak "Must provide a field name!" unless defined $field;
    return root_element . '->' . $self->_get_dbh->quote($field);
}

=head2 from_json_pointer

  Bagger::Storage::Index::Field->from_json_pointer($jsonptr)

This method taks a Bagger::Type::JSONPointer type in and converts it to a sql
expression.

=cut

sub from_json_pointer {
    my ($class, $jsonptr) = @_;
    my @elems = @$jsonptr; #copy so we can shift
    my $exp = $class->json_field(shift @elems);
    for my $elem (@elems) {
        $exp = $class->extract_from_json_object($exp, $elem);
    }
    return $exp;
}

=head1 METHODS

=head2 list($index_id)

Returns a list of index fields for the given index id.

=cut

dbmethod list => (funcname => 'get_index_fields', arg_list => ['index_id'], 
    returns_objects => 1);

=head2 save

=cut

dbmethod save => (funcname => 'append_index_field', returns_objects => 1);

1;

# vim:ts=4:sw=4:expandtab
