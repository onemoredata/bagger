=head1 NAME

   Bagger::Storage::Config -- Configuration Routines for Bagger Storage

=cut

package Bagger::Storage::Config;

=head1 SYNOPSIS

   my $config = Bagger::Storage::Config(
             key   => 'additional_index_types', 
	     value => ['rum', 'sp-gist']
   );
   $config->save

=cut

use PGObject::Type::JSON;
use strict;
use warnings;
use Moose;
use PGObject::Util::DBMethod;
use namespace::autoclean;
with 'Bagger::Storage::PGObject';
PGObject::Type::JSON->register; # become the codec for Perl <-> json
                                # but not jsonb by default

=head1 DESCRIPTION

 The Bagger Storage Config module exists to configure anything needed regarding
 Bagger storage nodes as a cluster.  It is expected that this data will somehow
 be synchronized to the storage nodes themselves along with dimensions and
 index information.

 The configuration system is intended to be flexible and portable.  Values can
 be anything, but undef is not accepted and a value must be provided.  Strings,
 array and hashrefs, and references are all supported.

 The data values are serialized to JSON in the database, which has one important
 side effect.  If you pass a scalar reference to value, then when you retrieve
 that reference, it will be returned as a scalar.

=head1 PROPERTIES

=over

=item id Int, assigned by the database

=cut

has id => (is => 'ro', isa => 'Int');

=item key Str, required

=cut

has key => (is => 'ro', isa => 'Str', required => 1);

=item value -- Arbitrary scalar, hashref, or arrayref.  Required

=cut

# TODO move to a more rigid subtype for deep checking
has value => (is      => 'ro', 
             isa      => 'Str | ArrayRef | HashRef',
             required => 1);


=head1 METHODS

=head2 get($key)

 Looks up the config item by key and returns it.

=cut

sub get {
    my $self = shift;
    my $key = (shift // $self);
    my ($config) = $self->call_procedure(funcname => 'get_setting',
                          args => [$key]);
    return __PACKAGE__->new($config);
}

=head2 save

  Persists the current object to the database, overwriting any previous item
  with the same key.

=cut

dbmethod save => (funcname => 'save_config', returns_objects => 1);

1;
