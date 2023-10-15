use Test2::V0 -target => {pkg => 'Bagger::Storage::Index'};
use strict;
use warnings;

plan 14;

### Constructor tests, without index_am

ok(pkg()->new(id => 1, indexname => 'test', access_method => 'btree', 
   tablespc => 'test', fields => []),
   'Test id 1, basic happy path constructor');

ok(pkg()->new(indexname => 'test', access_method => 'gin'),
   'Test without id, new index normal case');

my $basic_idx = pkg()->new(indexname => 'test', access_method => 'gin');

is($basic_idx->fields, [], 'Initial fields is an empty arrayref');
is($basic_idx->next_ordinal, 0, 'Next ordinal is 0');

ok(dies { pkg()->new() }, 'empty args dies');

ok(dies { pkg()->new(indexname => 'test') }, 'dies without access_method');
ok(dies { pkg()->new(access_method=> 'btree') }, 'dies without index_name');
ok(dies { pkg()->new(indexname => 'test', access_method => 'gin', 
                fields => ['foo']) }, 'dies on wrong types for fields');

ok(dies { pkg()->new(indexname => ['foo'], access_method => 'gin') },
   "Dies on wrong type for indexname");

ok(dies { pkg()->new(indexname => 'test', access_method => ['gin']) },
   "Dies on wrong type for access_method");
### Indexam tests

is([pkg()->supported_index_ams], ['btree', 'hash', 'gist', 'gin'],
   'Initial supported index types correct');

pkg()->add_index_am('rum');


is([pkg()->supported_index_ams], ['btree', 'hash', 'gist', 'gin', 'rum'],
   'Supported index types correct after adding rum');

pkg()->remove_index_am('rum');

is([pkg()->supported_index_ams], ['btree', 'hash', 'gist', 'gin'],
   'Supported index types correct after removing rum');

pkg()->remove_index_am('hash');

is([pkg()->supported_index_ams], ['btree', 'gist', 'gin'],
   'Supported index types correct after removing hash');


