use Test2::V0 -target => {pkg => 'Bagger::Storage::Index',
                          cfg => 'Bagger::Storage::Config',
                           dt => 'Bagger::Type::DateTime',
                          fld => 'Bagger::Storage::Index::Field',
                      };
use Bagger::Test::DB::LW;
use strict;
use warnings;

plan 30;

### Constructor tests, without index_am

ok(pkg()->new(id => 1, indexname => 'test', access_method => 'btree', 
   tablespc => 'test', fields => []),
   'Test id 1, basic happy path constructor');


ok(pkg()->new(indexname => 'test', access_method => 'gin'),
   'Test without id, new index normal case');

ok(my $basic_idx = pkg()->new(indexname => 'test', access_method => 'gin'), 'Gin index defined');
is($basic_idx->valid_from, dt()->inf_past, 'By default, index valid_from forever');
is($basic_idx->valid_until, dt()->inf_future, 'By default, index does not expire');
push @{$basic_idx->fields}, fld()->new(
      ordinality => $basic_idx->next_ordinal, expression => fld()->json_field('foo')
);
push @{$basic_idx->fields}, fld()->new(
      ordinality => $basic_idx->next_ordinal, expression => fld()->json_field('bar')
);
ok(my $idx = $basic_idx->save, 'Saved idx');
is($idx->create_statement('foo', 'bar'), 
    q#CREATE INDEX "bar_test" ON "foo"."bar" ((data->'foo'),(data->'bar')) using gin TABLESPACE "pg_default"#, 
    'Create Statement is correct');

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


## Production tests

ok(cfg()->new('key' => 'production', value => 1)->save, 'Set production status');

ok($basic_idx = pkg()->new(indexname => 'test2', access_method => 'gin'), 'Gin index defined');
is($basic_idx->valid_from, dt()->hour_bound_plus(1), 'By default, index set to start at next hr + 1hr');
is($basic_idx->valid_until, dt()->inf_future, 'By default, index does not expire');
push @{$basic_idx->fields}, fld()->new(
      ordinality => $basic_idx->next_ordinal, expression => fld()->json_field('foo')
);
push @{$basic_idx->fields}, fld()->new(
      ordinality => $basic_idx->next_ordinal, expression => fld()->json_field('bar')
);
ok($idx = $basic_idx->save, 'Saved idx');

ok($idx->fields->[0]->id, 'Saved idx has id for field 0');
ok($idx->fields->[1]->id, 'Saved idx has id for field 1');

is($idx->fields->[0]->valid_from, $idx->valid_from, 'Index and index_field 0 have same start time');
is($idx->fields->[1]->valid_from, $idx->valid_from, 'Index and index field 1 have same start time');

is($idx->create_statement('foo', 'bar'), '',
    'Create Statement is correct when time out of bounds');

is($idx->expire->valid_until, dt()->hour_bound_plus(1), 'Expired to correct hour bound');


ok(cfg()->new('key' => 'indexes_hrs_in_future', value => 3)->save, 'Indexes bounds set to +3 hrs');
ok($basic_idx = pkg()->new(indexname => 'test', access_method => 'gin'), 'Gin index defined');
is($basic_idx->valid_from, dt()->hour_bound_plus(3), 'By default, index set to start at next hr + 1hr');
is($basic_idx->valid_until, dt()->inf_future, 'By default, index does not expire');
ok($idx = $basic_idx->save, 'Saved idx');


is($idx->expire->valid_until, dt()->hour_bound_plus(3), 'Expired to correct hour bound');
