use Test2::V0 -target => {inst => 'Bagger::Storage::Instance'};
use Bagger::Test::DB::LW;

plan(12);

my ($inst1, $inst2);

ok($inst1 = inst()->new(host => 'host1', port => '5433', username => 'bagger'),
    'Instance 1 created');
is($inst1->id, undef, 'Id for instance 1 is undef before saving');
ok($inst1 = $inst1->register(), 'Saved instance 1');
ok($inst2 = inst()->new(host => 'host2', port => '5433', username => 'bagger'),
    'Instance 2 created');
is($inst2->id, undef, 'Id for instance 2 is undef before saving');
ok($inst2 = $inst2->register());

ok($inst1->id, 'Instance 1 has id after save');
ok($inst2->id, 'Instance 2 has id after save');

is($inst1->export, {id => $inst1->id, host => 'host1', port => '5433' }, 
    'inst 1 has correct export');
is($inst2->export, {id => $inst2->id, host => 'host2', port => '5433' },
    'inst 2 has correct export');

is(inst()->get($inst1->id), $inst1, 'Instance 1 retrieved');
is([inst()->list], [$inst1, $inst2], 'List retrieved both instances in order');
