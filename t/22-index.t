use Test2::V0 -target => { pkg => 'Bagger::Storage::Index',
                           dt  => 'Bagger::Type::DateTime'};

plan 7;
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

### Constructor tests, without index_am

ok(my $idx = pkg()->new(id => 1, indexname => 'test', access_method => 'btree', 
   tablespc => 'test', fields => [], 
   valid_from => dt->inf_past, valid_to => dt()->inf_future),
   'Test id 1, basic happy path constructor');

is($idx->fields, [], 'Initial fields is an empty arrayref');
is($idx->next_ordinal, 0, 'Next ordinal is 0');
