use Test2::V0 -target => { pkg => 'Bagger::Storage::Config' , 
                            db => 'Bagger::Storage::LenkwerkSetup'};
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

plan 8;

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

is(pkg()->get($scal_cfg->key)->value, $initial_str, 'Initial string returned');
is(pkg()->get($aref_cfg->key)->value, $initial_array, 'Initial aref returned');
is(pkg()->get($href_cfg->key)->value, $initial_href, 'Initial href returned');
is(pkg()->get($struct_cfg->key)->value, $initial_struct, 'Struct round trip');
