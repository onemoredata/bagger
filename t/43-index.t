use Test2::V0 -target => {pkg => 'Bagger::Storage::Index',
                           db => 'Bagger::Storage::LenkwerkSetup',
                          cfg => 'Bagger::Storage::Config',
                           dt => 'Bagger::Type::DateTime',
                          fld => 'Bagger::Storage::Index::Field',
                      };
use strict;
use warnings;

skip_all('BAGGER_TEST_LW environment variable not set') unless defined
                                                        $ENV{BAGGER_TEST_LW};

bail_out('BAGGER_TEST_LW_DB environment variable not set') unless defined
                                                       $ENV{BAGGER_TEST_LW_DB};


db()->set_lenkwerkdb($ENV{BAGGER_TEST_LW_DB});
db()->set_dbhost($ENV{BAGGER_TEST_LW_HOST}) if defined $ENV{BAGGER_TEST_LW_HOST};
db()->set_dbport($ENV{BAGGER_TEST_LW_PORT}) if defined $ENV{BAGGER_TEST_LW_PORT};
db()->set_dbuser($ENV{BAGGER_TEST_LW_USER}) if defined $ENV{BAGGER_TEST_LW_USER};

plan 23;

### Constructor tests, without index_am

ok(pkg()->new(id => 1, indexname => 'test', access_method => 'btree', 
   tablespc => 'test', fields => []),
   'Test id 1, basic happy path constructor');


ok(pkg()->new(indexname => 'test', access_method => 'gin'),
   'Test without id, new index normal case');

ok(my $basic_idx = pkg()->new(indexname => 'test', access_method => 'gin'), 'Gin index defined');
is($basic_idx->valid_from, dt()->inf_past, 'By default, index valid_from forever');
is($basic_idx->valid_until, dt()->inf_future, 'By default, index does not expire');

ok(dies { pkg()->new() }, 'empty args dies');

ok(dies { pkg()->new(indexname => 'test') }, 'dies without access_method');
ok(dies { pkg()->new(access_method=> 'btree') }, 'dies without index_name');
ok(dies { pkg()->new(indexname => 'test', access_method => 'gin', 
                fields => ['foo']) }, 'dies on wrong types for fields');

ok(dies { pkg()->new(indexname => ['foo'], access_method => 'gin') },
   "Dies on wrong type for indexname");

ok(dies { pkg()->new(indexname => 'test', access_method => ['gin']) },
   "Dies on wrong type for access_method");

## Field-saving tests

my $field = 

## Production tests

ok(cfg()->new('key' => 'production', value => 1)->save, 'Set production status');

ok($basic_idx = pkg()->new(indexname => 'test', access_method => 'gin'), 'Gin index defined');
is($basic_idx->valid_from, dt()->hour_bound_plus(1), 'By default, index set to start at next hr + 1hr');
is($basic_idx->valid_until, dt()->inf_future, 'By default, index does not expire');
ok(my $idx = $basic_idx->save, 'Saved idx');

is($idx->expire->valid_until, dt()->hour_bound_plus(1), 'Expired to correct hour bound');


ok(cfg()->new('key' => 'indexes_hrs_in_future', value => 3)->save, 'Indexes bounds set to +3 hrs');
ok($basic_idx = pkg()->new(indexname => 'test', access_method => 'gin'), 'Gin index defined');
is($basic_idx->valid_from, dt()->hour_bound_plus(3), 'By default, index set to start at next hr + 1hr');
is($basic_idx->valid_until, dt()->inf_future, 'By default, index does not expire');
ok($idx = $basic_idx->save, 'Saved idx');


is($idx->expire->valid_until, dt()->hour_bound_plus(3), 'Expired to correct hour bound');
