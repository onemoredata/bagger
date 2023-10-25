=head1 NAME

   Bagger::Storage::Servermap -- Servermap generation/persistance in Bagger

=cut

package Bagger::Storage::Servermap;

=head1 SYNOPSIS

    my $servermap = Bagger::Storage::Servermap->most_recent();

    # or to get a specific one
    #
    my $servermap = Bagger::Storage::Servermap->get(1);

    # or to generate and save a new one:
    my $servermap = Bagger::Storage::Servermap->new->save;

=cut

use strict;
use warnings;
use Moose;
use namespace::autoclean;
use Bagger::Storage::Instance;
use Bagger::Type::JSON;
use PGObject::Util::DBMethod;
use Moose::Util::TypeConstraints;
with 'Bagger::Storage::PGObject';

Bagger::Type::JSON->register;

=head1 DESCRIPTION

The servermap provides Bagger infrastructure with a general understanding of
what storage nodes contain copies of which data, and therefore assists in
both ingestion management and query building.

Unlike more dynamic distributed data environments, Bagger's network data
distribution is fixed at the point of ingestion.  No provisions for moving
data around are present.  These are not C<Bagger::Storage::Time_Bound>
however because they are chaos-sharded and so servermaps do not need to
respect partition boundaries.

=head1 PROPERTIES

In addition to the typical Time_Bound properties (valid_to, valid_until),
servermap objects also have the following properties, all of which are optional:

=over

=item id int

This is the database-specified identifier for the record.

=cut

has id => (is => 'ro', isa => 'Int');

=item server_map Bagger::Type::JSON hashref

This contains the actual server map.  It is generated on creation if not
provided.

=back

=cut

has server_map => (is => 'ro', isa => 'Bagger::Type::JSON',
                   builder => 'generate_server_map');

=head1 METHODS

The following general methods are used here.  These are also exposed to the 
user but not always used.

=over

=item generate_server_map

This produces the hash data for the server_map and sets up the serialization to
JSON.

As of this version, we use a simple circular algorith where a copy of the data
is stored on a different physical host in a circle.

For version 1, only a replication factor of 2 is supported.

Version 1 of the servermap has a structure as follows

 {
    host1_port1_id1 => { shaulfel => { host info},
                         copies   => { [ 
                                      { primary host info } , 
                                      { seconary host info }
                                     ] }
    ...
 }

=cut

# Not the most computationally efficient approach but this isn't a frequent
# task.
sub generate_server_map {
    my ($self) = @_;
    my @hosts = sort { $a->host cmp $b->host } Bagger::Storage::Instance->list;
    my $rotate = $self->call_procedure(funcname => 'servermap_rotate_num');
    ($rotate) = values %$rotate; 
    my $first = $hosts[0];
    my $primaries = [@hosts];
    my $secondaries = [@hosts]; # independent copies
    # Rotate physical hosts
    for (1 .. $rotate){
        my $s = shift @$secondaries;
        push @$secondaries, $s;
    }
    my $servmap = { version => 1 };
    for (@hosts) {
        my $primary = shift @$primaries;
        my $secondary = shift @$secondaries;
        my $keystr = join('_', $primary->host, $primary->port);
        $servmap->{$keystr} = { schaufel => $primary->export,
                                copies   => [ $primary->export,
                                              $secondary->export, ],
                              }
    }
    return Bagger::Type::JSON->new($servmap);
}

=item save

This method saves the object and returns a new one with the database-specified
values filled in.

=cut

dbmethod save => (funcname => 'save_servermap', returns_objects => 1);

=item most_recent

Returns the most recent servermap

=cut

dbmethod most_recent => (funcname => 'most_recent_servermap', returns_objects => 1);

=item get($id)

Returns the servermap row by id.

=cut

dbmethod get => (funcname => 'get_servermap', arg_list => ['id'], returns_objects => 1);

=back

=cut

1;
