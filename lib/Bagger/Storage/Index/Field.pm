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

=cut

use strict;
use warnings;
use Moose;
use Carp 'croak';
with 'Bagger::Storage::PGObject', 'Bagger::Storage::Time_Bound';

sub _config_hours_out {'indexes_hrs_in_future'}

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

=back

=cut

has expression => (is => 'ro', isa => 'Str', required => 1);

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
    return "${expression}::" . $self->_dbh->quote_identifier($type);
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
    return "($expression)->" . $self->_dbh->quote($field);
}

=head2 json_field

Returns an expression as extraction of the named field from the JSON field
used in the top-level of the json object stored by Bagger.

=cut

sub json_field {
    my ($self) = shift;
    my $field = shift // $self;
    croak "Must provide a field name!" unless defined $field;
    return 'data->' . $self->_dbh->quote($field);
}

=head1 METHODS

=head2 list($index_id)

Returns a list of index fields for the given index id.

=cut

sub list {
    my ($self, $index_id) = @_;
    return map { __PACKAGE__->new($_) }
          $self->call_procedure(funcname => 'get_index_fields',
                                    args => [$index_id]);

}

=head2 save

=cut

1;

# vim:ts=4:sw=4:expandtab
