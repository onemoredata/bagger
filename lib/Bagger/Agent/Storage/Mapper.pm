=head1 NAME

   Bagger::Agent::Storage::Mapper -- Postgres <-> KVStore Mappers for Agents

=cut

package Bagger::Agent::Storage::Mapper;

=head1 SYNOPSIS

   # To etcd
   use Bagger::Agent::Storage::Mapper 'kval_key';

   my $key = kval_key('config', $config_hash);

   #or

   my $key = kval_key($object);

   # from etcd
   use Bagger::Agent::Storage::Mapper 'pg_obj';
   my $class = pg_obj($etcd_key);
   # or even
   my $obj = pg_obj($etcd_key)->new($etcd_value);

=cut

use strict;
use warnings;
use Exporter 'import';
use Scalar::Util 'blessed';
our @EXPORT_OK = qw(kval_key pg_object);

=head1 DESCRIPTION

This module provides modules for mapping Postgres and key/value store  data.
This mapping happens between objets or between table names/hash data and the
key/value store key.  A key is also sufficient to determine the class.

This module is written to ensure that we can store the configuratin structures
for the cluster in a key/value store such as Zookeeper, etcd or Consul.  It is
possible that some minor changes may be required to support more of these in
the future.

When loading data from etcd, this module also loads classes when they are
needed.  This makes it easy to use in this regard and if an agent only needs to
watch for some items, those types will be loaded only as needed.

=cut

# Once we add Perl::Critic tests, these will likely need some comments
# disabling policies due to the use of @_ directly.

my $delim = '/';

my @key_regex = (
    { regex => qr|^/Config|,           class => 'Bagger::Storage::Config' },
    { regex => qr|^/PostgresInstance|, class => 'Bagger::Storage::Instance' },
    { regex => qr|^/Servermap|,        class => 'Bagger::Storage::Servermap' },
    { regex => qr|^/Dimension|,        class => 'Bagger::Storage::Dimension' },
    { regex => qr|^/Index${delim}\d+${delim}\d|,
                                       class => 'Bagger::Storage::Index::Field' },
    { regex => qr|^/Index${delim}\d+$|,       class => 'Bagger::Storage::Index' },
);

sub _kjoin { return join($delim, @_) }

my %keygen = (
    config             => sub { return _kjoin('/Config', $_[0]->{key}) },
    postgres_instance  => sub { return _kjoin('/PostgresInstance',
                                              $_[0]->{host}, $_[0]->{port}) },
    servermap          => sub { return '/Servermap' },
    dimension          => sub { return _kjoin('/Dimension', $_[0]->{id}) },
    index              => sub { return _kjoin('/Index', $_[0]->{id}) },
    index_field        => sub { return _kjoin('/Index', $_[0]->{index_id},
                                              $_[0]->{id}) },
);

my %classmap = (
    'Bagger::Storage::Config'       => 'config',
    'Bagger::Storage::Instance'     => 'postgres_instance',
    'Bagger::Storage::Servermap'    => 'servermap',
    'Bagger::Storage::Dimension'    => 'dimension',
    'Bagger::Storage::Index::Field' => 'index_field',
    'Bagger::Storage::Index'        => 'index',
);

=head1 FUNCTIONS AND CONVERSION

The delimiter is currently set to '/' so key fields are separated by that
character.

The keys form a tree starting with '/' so if one watches for all keys with a
prefix of '/', the agent will get all bagger-related changes.

=head2 pg_object

This returns the class which the key is associated.  The value can then be
converted from JSON into Perl data structures and used to create an object of
this class.  The class is also autoloaded once it is identified.

This function will return undef if no class is found.

=cut

my %loaded = ();


# Note compiled regexes are significantly slower than static ones but
# this shouldn't matter since this is not frequently changing data.
sub pg_object {
    my ($key) = shift;
    for my $r (@key_regex) {
        if ($key =~ $r->{regex}){
            my $class = $r->{class};
            if (not $loaded{$class}){
                local $@;
                eval "require $class";
                warn $@ if $@;
                $loaded{$class} = 1;
            }
            return $class;
        }
    }
    return undef;
}

=head2 kval_key

This returns the key/val storekey from the object.  This requires either a
table name or a blessed object passed in the first spot, and if not, then a hash
(blessed or not, but usually not) passed in the second place.

Examples:

    kval_key('postgres_instances', {host => 'host1',
                                    port => 5432,
                                username => 'bagger',
                                  status => 0 })
    #returns '/PostgresInstance/host1/5432'


=cut

sub kval_key {
    my ($class, $val) = @_;
    if (ref $class) {
        $val = $class;
        $class = $classmap{blessed $class};
    }
    return $keygen{$class}($val) if defined $keygen{$class};
}

=head2 key_to_relname ($key)

Returns the relation name used by the key.  This allows a sort of logical
replication to be built between the KVStore and the storage node's Postgresql
instances.

=cut

sub key_to_relname {
    my ($key) = @_;
    my $class = pg_object($key);
    return unless $class;
    return $classmap{$class};
}

1;
