=head1 NAME

  Bagger::Storage::Dimension -- Partitioning Dimension Management of Bagger

=cut

package Bagger::Storage::Dimension;

=head1 SYNOPSIS

   my $dimension = Bagger::Storage::Dimension->new(
           { fieldname   => 'service', 
             ordinality  => 1,
             default_val => 'none'
          });
   $dimension = $dimension->append(); # may change ordinality

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use PGObject::Util::DBMethod;
with 'Bagger::Storage::PGObject';


=head1 DESCRIPTION

Dimensions represent the dimension partitions for Bagger tables.  Each 
dimension is extracted from the incoming JSON document in order and this
information is used to write the document to the correct table.  The current
routines have provisions for default values although it is not clear if these
will be supported in version 1 of Bagger.

=head1 PROPERTIES

=head2 fieldname

The fieldname is the field in the JSON which holds the key for partitionin in
this dimension.

=cut

has fieldname => (is => 'ro', isa => 'Str', required => 1);

=head2 default_val

This represents the default value for partitioning of a value.  This may not be
supported in Bagger v1 but can be stored nonetheless.

=cut

has default_val => (is => 'ro', isa => 'Str');

=head2 ordinality

This represents the ordinality of the field.  Note that this should generally
not change once it is stored in the database in the current version of the
software.  Future versions may allow new partition schemes to start in certain
circumstances but this is not yet supported.

=cut

has ordinality => (is => 'ro', isa => 'Int');

=head1 METHODS

=head2 list()

Returns a list of dimensions as found in the database in order of ordinality.

=cut

dbmethod list => (funcname => 'get_dimensions', returns_objects => 1);

# =head2 insert()  not supported yet due to inability to set effective time
# of new partitioning

=head2 append()

Appends the new dimension onto the list at the last ordinality and returns
the new item as saved.

Note that the database will refuse to append the same fieldname more than once.

=cut

dbmethod append => (funcname => 'append_dimension', returns_objects => 1);

1;
