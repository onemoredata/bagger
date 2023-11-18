use Bagger::Agent::LW;
use Coro;
use Bagger::Test::DB::LW;
use Bagger::Test::DB::Etcd;
use Test2::V0 -target => { inst => Bagger::Storage::Instance,
                           conf => Bagger::Storage::Config,
                           smap => Bagger::Storage::Servermap,
                           indx => Bagger::Storage::Index,
                           fld  => Bagger::Storage::Index::Field,
                           dim  => Bagger::Storage::Dimension,
                           ae   => AnyEvent,
                       };

 
                       #plan 36; 
my $guard = Bagger::Test::DB::Etcd->guard;
$ENV{TEST_AGENT} = 1;

# Since we don't have any obvious synchronization points, we need to set up
# the replication slot first with WAL retention.

inst->call_procedure(funcname => 'pg_create_logical_replication_slot',
    funcschema => 'pg_catalog',
    args => ['lw_agent', 'test_decoding']);
inst->_get_dbh->commit;

# This test framework is going to be a little tricky because of the fact that
# we are injecting tests into an event loop. The test loop must run a finite
# number of times and then disconnect

# idx repeated since the same tests will have to be run on the index record and
# both field records

# What we will actually do hereis use the start rather than run method and
# receive inbound data using condvars.

my @exp_messages = (
    "BEGIN",
    qq!table storage.postgres_instance: INSERT: id[integer]:6 host[character varying]:'host1' port[integer]:5432 username[character varying]:'bagger' status[smallint]:0!,
    "COMMIT",
    'BEGIN',
    qq!table storage.postgres_instance: INSERT: id[integer]:7 host[character varying]:'host2' port[integer]:5432 username[character varying]:'bagger' status[smallint]:0!,
    qq!table storage.postgres_instance: INSERT: id[integer]:8 host[character varying]:'host3' port[integer]:5432 username[character varying]:'bagger' status[smallint]:0!,
    "COMMIT",
    'BEGIN',
    qq|table storage.config: INSERT: id[integer]:13 key[text]:'testing1' value[json]:'"1"'|,
    qq|table storage.config: INSERT: id[integer]:14 key[text]:'testing2' value[json]:'"Foo"'|,
    'COMMIT',

);

my $starting_id = 5;
my @exp_hashref = (
    undef,
    { tablename => 'postgres_instance',
        schema  => 'storage',
          type  => 'dml',
      operation => 'INSERT',
       row_data => { host => 'host1', port => '5432', username => 'bagger', status => 0, id => 6 }},
    undef,
    undef,
    { tablename => 'postgres_instance',
        schema  => 'storage',
          type  => 'dml',
      operation => 'INSERT',
       row_data => { host => 'host2', port => '5432', username => 'bagger', status => 0, id => 7 }},
    { tablename => 'postgres_instance',
        schema  => 'storage',
          type  => 'dml',
      operation => 'INSERT',
       row_data => { host => 'host3', port => '5432', username => 'bagger', status => 0, id => 8 }},
   undef,
   undef,
    { tablename => 'config',
         schema => 'storage',
          type  => 'dml',
      operation => 'INSERT',
       row_data => { key => 'testing1', value => '"1"', id => 13 }},
    { tablename => 'config',
         schema => 'storage',
          type  => 'dml',
      operation => 'INSERT',
       row_data => {'key' => 'testing2', value => '"Foo"', id => 14 }},
   undef,
);

my @exp_keys = (
    '/PostgresInstance/host1/5432',
    '/PostgresInstance/host2/5432',
    '/PostgresInstance/host3/5432',
    '/Config/testing1',
    '/Config/testing2',
);
%Bagger::Agent::LW::_INJECTION = (
    before_parse   => sub { my $msg = shift;
                            is($msg, shift @exp_messages, "Got expected message $msg");
                            Bagger::Agent::LW::stop() if $msg eq 'COMMIT';
                        },
    after_parse    => sub { my ($msg, $hashref) = @_;
                            my $exp = shift @exp_hashref;
                            is($hashref, $exp, "Got back expected hashref for $msg");
                        },
    before_kvwrite => sub { my ($key, $value) = @_;
                           is($key, shift @exp_keys, "Got correct key $key");
                       },
    after_kvwrite  => sub {  my ($resp) = @_;
                             ok($resp, 'Write to kvstore succeeded');
                         },
);

ok(Bagger::Agent::LW->start, 'Started Agent');


my $var;
ok($var = inst->new(host => 'host1', port => '5432', username => 'bagger')->register, 
    'Registered first item');
$var->_dbh->commit;

Bagger::Agent::LW::loop();
schedule while Coro::nready;
cede;

ok($var = inst->new(host => 'host2', port => '5432', username => 'bagger')->register, 
    'Registered second item');
ok($var = inst->new(host => 'host3', port => '5432', username => 'bagger')->register, 
    'Registered third item');
$var->_dbh->commit;

Bagger::Agent::LW::loop();
schedule while Coro::nready;
cede;

ok($var = conf->new('key' => 'testing1', value =>'1')->save, 'Saved config 1');
ok($var = conf->new('key' => 'testing2', value =>'Foo')->save, 'saved config 2');
$var->_dbh->commit;
Bagger::Agent::LW::loop();
schedule while Coro::nready;

done_testing();
# the guard must be undef'd only after the plan is sent.
# Otherwise the test harness gets confused.
undef $guard;
