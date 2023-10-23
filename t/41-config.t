use Test2::V0 -target => { pkg => 'Bagger::Storage::Config' };
use Bagger::Test::PGTap;
use Bagger::Test::DB::LW;
use strict;
use warnings;

plan 9;

# Test data setup
my $initial_str = 'Nontrivial String {"\u0000"}[]';
my $scal_cfg = pkg()->new(key => 'scalar_test', value => $initial_str);

my $initial_array = [1, 2, 3, 4, 'foo', 'bar', '"\u0000"'];
my $aref_cfg = pkg()->new(key => 'aref_test', value => $initial_array);

my $initial_href = { 'foo' => $initial_str, 'bar' => 123 };
my $href_cfg = pkg()->new(key => 'href_test', value => $initial_href);

my $initial_struct = { 'foo' => $initial_array, 'bar' => $initial_href };
my $struct_cfg = pkg()->new(key => 'struct_test', value => $initial_struct);

# Round trip tests

ok($scal_cfg->save, 'Can save scalar config');
ok($aref_cfg->save, 'Can save arrayref config');
ok($href_cfg->save, 'Can save href config');
ok($struct_cfg->save, 'Can save struct config');

is(pkg()->get($scal_cfg->key)->value_string, $initial_str, 'Initial string returned');
is(pkg()->get($aref_cfg->key)->value, $initial_array, 'Initial aref returned');
is(pkg()->get($href_cfg->key)->value, $initial_href, 'Initial href returned');
is(pkg()->get($struct_cfg->key)->value, $initial_struct, 'Struct round trip');
is(pkg()->get('kfje1432gfds'), undef, 'Unknown key returns undef');
