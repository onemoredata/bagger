use Test2::V0;
use Bagger::Agent::Drivers::TestDecoding 'parse';

plan 3;

is(parse('BEGIN 529'), undef, 'BEGIN messages undef');
is(parse(q(table public.data: INSERT: id[integer]:3 data[text]:'5')),
        { schema => 'public', tablename => 'data', operation => 'INSERT',
          row_data => { id => 3, data => 5 }},
      "Simple row insert correct");
is(parse(q(table public.foo: UPDATE: id[integer]:3 payload[text]:'foo 3')),
        { schema => 'public', tablename => 'foo', operation => 'UPDATE',
          row_data => {id => 3, payload => 'foo 3'}});
