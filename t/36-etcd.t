use Bagger::Test::DB::Etcd;
use Bagger::Agent::KVStore;
use Test2::V0 -target => {kvs  => 'Bagger::Agent::KVStore',
                          etcd => 'Bagger::Agent::Drivers::KVStore::Etcd',
                          cnf  => 'Bagger::Storage::Config',};
use Data::Dumper;
my $guard = Bagger::Test::DB::Etcd->guard;
plan 5;

# TODO add watch tests for storage agent phase
my $config = cnf->get('kvstore_config')->value;
ok(my $kvstore = kvs()->new(module => 'etcd', config => $config), 'New kvs store');
ok($kvstore->write('/foo', 'bar'), 'Wrote a key');
is($kvstore->read('/foo'), 'bar', 'Got the value back') or (diag Dumper($kvstore->read('/foo')));
ok($kvstore->write('/foo', 'baz'), 'Wrote a key again');
is($kvstore->read('/foo'), 'baz', 'Got the value back') or (diag Dumper($kvstore->read('/foo')));
undef $guard;
