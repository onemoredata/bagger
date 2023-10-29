use Test2::V0;
use Bagger::Agent::Drivers::TestDecoding 'parse';

plan 4;

is(parse('BEGIN 529'), undef, 'BEGIN messages undef');
is(parse(q(table public.data: INSERT: id[integer]:3 data[text]:'5')),
        { schema => 'public', tablename => 'data', operation => 'INSERT',
          row_data => { id => 3, data => 5 }},
      "Simple row insert correct");
is(parse(q(table public.foo: UPDATE: id[integer]:3 payload[text]:'foo 3')),
        { schema => 'public', tablename => 'foo', operation => 'UPDATE',
          row_data => {id => 3, payload => 'foo 3'}});
is(parse(q(table storage.postgres_instance: INSERT: id[integer]:6 host[character varying]:'host1' port[integer]:5432 username[character varying]:'bagger' status[smallint]:0)),
        { schema => 'storage', tablename => 'postgres_instance', operation => 'INSERT', row_data => {host => 'host1', username => 'bagger', status => 0, id => 6, port => 5432}});
