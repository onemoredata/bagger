use Test2::V0 -target => {smap => 'Bagger::Storage::Servermap',
                          inst => 'Bagger::Storage::Instance' };
use Bagger::Test::DB::LW;

plan(19);

my ($inst1, $inst2, $inst3, $smap);

ok($inst1 = inst()->new(host => 'host1', port => '5433', username => 'bagger'),
    'Instance 1 created');
is($inst1->id, undef, 'Id for instance 1 is undef before saving');
ok($inst1 = $inst1->register(), 'Saved instance 1');
ok($inst2 = inst()->new(host => 'host2', port => '5433', username => 'bagger'),
    'Instance 2 created');
is($inst2->id, undef, 'Id for instance 2 is undef before saving');
ok($inst2 = $inst2->register());
ok($inst3 = inst()->new(host => 'host3', port => '5433', username => 'bagger'),
    'Instance 3 created');
is($inst3->id, undef, 'Id for instance 3 is undef before saving');
ok($inst3 = $inst3->register());
ok($inst1->id, 'Instance 1 has id');
ok($inst2->id, 'Instance 2 has id');
ok($inst3->id, 'Instance 3 has id');

ok($smap = smap()->new, 'Created new servermap');
my $expected_smap =  { host1_5433 => { schaufel =>   $inst1->export,
                                       copies   => [ $inst1->export, 
                                                     $inst2->export ], },
                       host2_5433 => { schaufel =>   $inst2->export,
                                       copies   => [ $inst2->export,
                                                     $inst3->export, ], },
                       host3_5433 => { schaufel =>   $inst3->export,
                                       copies   => [ $inst3->export,
                                                     $inst1->export, ], },
                       version => 1};
is($smap->server_map, $expected_smap, 'Servermap is correct');
is($smap->id, undef, 'Servermap id is undefined.');
ok($smap = $smap->save, 'Saved smap');
ok($smap->id, 'Servermap now has an id');
is(smap()->most_recent, $smap, 'get_most_recent returns what we just saved');
is(smap()->get($smap->id), $smap, 'get by id returns correct smap');
                      
