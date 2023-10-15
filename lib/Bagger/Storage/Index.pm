=head1 NAME

  Bagger::Storage::Index - Index Management Routines for Bagger

=cut

package Bagger::Storage::Index;

=head1 SYNOPSIS

    my $index = Bagger::Storage::Index->new(
           indexname => 'base_idx', access_method => 'gin'
    );
    $index->save;

    # or
    my $index = Bagger::Storage::Index->get('base_idx');
    my @fields = @{$index->fields};

=cut

use 5.010;
use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;
use Bagger::Storage::Index::Field;
use Carp 'croak';
with 'Bagger::Storage::PGObject';

=head1 DESCRIPTION

This module provides the basic entry point to the management of indexes in
Bagger.  This includes the ability to define indexes to be created as well
as introspect existing index definition entries.

Bagger makes extensive use of multi-column indexes, and multiple indexes
per table, using even different index access methods are supported.  This
provides the most flexibility possible while allowing for divergent access
patterns.

=head1 BEST PRACTICES

In defining indexes, it is important to note that indexes take up additional
space that could be used for data, and that they cause write amplification
because of the additional records and rebalancing required.  For this reason
additional indexes may impose hardware or hosting costs, and more.

Additionally PostgreSQL can use multiple indexes in a single lookup but this is
by nature inefficient.  So one should plan usage patterns as requiring only a
single index.

=head1 SUPPORTED INDEX ACCESS METHODS

By default, we support btree, gin, gist, and hash indexes, though we expect that
gin and btree indexes will be the most common.  SP-Gist indexes are not
supported because of their one-column-only approach (but see below).

=head2 Adding additional supported index methods

This module is extensible.  The list of access methods is set out in a private
array.   There are three functions in the module which provide access to this:

=over

=item supported_index_ams()

Returns a COPY of the array (not a reference).

=item remove_index_am($am)

Removes $am from the array.

=item add_index_am($am)

Adds $am to the array

=back

=cut

my @index_ams = (
    "btree",
    "hash",
    "gist",
    "gin",
);

sub supported_index_ams { @index_ams };

sub remove_index_am {
    my $self = shift;
    my $am = lc(shift // $self); # handle :: and -> syntax
    @index_ams = grep { $_ ne $am } @index_ams; 
}

sub add_index_am {
    my $self = shift;
    my $am = lc(shift // $self); # handle :: and -> syntax
    push @index_ams, $am;
}

# The where clause below is not very elegant....
subtype 'am_str',
   as 'Str',
   where { my $am = $_; grep { $am eq $_ } @index_ams },
   message { "Index type $_ not a supported index access method" };

=head1 PROPERTIES

=over

=item id int - id as stored in the database

=cut

has id => (is => 'ro', isa => 'Int');

=item indexname str - Index name (to be prefixed by table name

=cut

has indexname => (is => 'ro', isa => 'Str', required => 1);

=item access_method str - Index access method, of supported types (see above)

=cut

has access_method => (is => 'ro', isa => 'am_str', required => 1);

=item tablespc Str - Tablespace to store the index

Abbreviated to avoid SQL keywords.

=cut

has tablespc => (is => 'ro', isa => 'Str');

=item fields arrayref[Bagger::Index::Field] - fields to index

Note that since this is an arrayref we can push/pop on it even though it is
read-only.  What is read-only is the reference assignment.

=back

=cut

sub _get_fields { 
    my $self = shift;
    return [] unless $self->id;
    return [Bagger::Storage::Index::Field->list($self->id)];
}

has fields => (
              is      => 'ro', 
              isa     => 'ArrayRef[Bagger::Index::Fields]',
	      lazy    => 1,
              builder => '_get_fields',
	      required => 0,
);


=head1 METHODS

=head2 $index = Bagger::Storage::Index->get(index_name) - get by index name

This returns the index from the database.  Note the fields are only lazily 
retrieved.

=cut

sub get {
    my ($self, $indexname) = @_;
    return __PACKAGE__->new(
        __PACKAGE__->call_procedure(funcname => 'get_index',
                                    args     => [$indexname])
    );
};

=head2 $newindex = $index->save()

This function saves the index (if no id set yet) and all fields where id is
not set.  It then returns the values stored in the database.

=cut

sub save {
    my ($self) = @_;
    my $new_idx = $self;
    # after this, $new_idx is guaranteed to have an id, and $self will have
    # fields
    if (not $self->id){
        $new_idx = $self->call_dbmethod(funcname => 'save_index');
    }
    for my $f (grep { not defined $_->id } $self->fields){
        $f->index_id($new_idx->id);
        $f->save;
    };
    # fields will be populated lazily from db
    return $new_idx;
}

=head2 int next_ordinal

Returns the next available field for index fields.  Note that ordinals are
0-based, and so this can also be used for a correct check for whether fields
have already been added.

=cut

sub next_ordinal {
    my ($self) = @_;
    return 0 unless defined $self->fields and @{$self->fields};
    my ($max_ordinal) = 
		   sort { $b->ordinality <=> $a->ordinality }
		   @{$self->fields};
    return $max_ordinal->ordinality + 1;
}

=head2 $create_statement = $index->create_statement($schema_name, $table_name)

This function generates a CREATE INDEX statement from the current object.

This is intended to be useful for backfilling indexes onto older partitions and
is unlikely to be called routinely.

=cut

sub create_statement {
    my ($self, $schema_name, $table_name) = @_;
    croak 'Must supply a schema_name to create_statement' unless $schema_name;
    croak 'Must supply a table_name to create_statement' unless $table_name;
    croak "Index must have fields added first" unless $self->next_ordinal;
    
    my $idx_name    = $self->_dbh->quote_identifier(
                      $table_name . '_' . $self->indexname);
    $schema_name = $self->_dbh->quote_identifier($schema_name);
    $table_name  = $self->_dbh->quote_identifier($table_name);

    my $field_str   = join ',', 
                   map { "($_)" } # indexes require this extra paren set
		   sort { $a->ordinality <=> $b->ordinality }
		   @{$self->fields};

    my $stmt =  "CREATE INDEX $idx_name ON $schema_name.$table_name ".
           "($field_str) using " . $self->access_method;
    $stmt .= " TABLESPACE " .
	   $self->_dbh->quote_identifier($self->tablespc) if $self->tablespc;
	  
}

1;
