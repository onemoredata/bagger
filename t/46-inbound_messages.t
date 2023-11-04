use Test2::V0 -target => { msg => 'Bagger::Agent::Storage::Message', 
                           ins => 'Bagger::Storage::Instance', 
                           cfg => 'Bagger::Storage::Config', 
                           dim => 'Bagger::Storage::Dimension',
                           idx => 'Bagger::Storage::Index',
                           fld => 'Bagger::Storage::Index::Field',
                           ldb => 'Bagger::Storage::LenkwerkSetup'};
use Bagger::Test::DB::LW;


plan 15;

cfg()->new(key => 'bagger_db', value => ldb()->lenkwerkdb)->save;

my $dbh = ins()->_get_dbh;
my $sth = $dbh->prepare(q(select setting from pg_settings where name = 'unix_socket_directories'));
$sth->execute;
my ($dirlist) = $sth->fetchrow_array();
my ($path) = split /,/, $dirlist;

### setup tests
ok(my $inst = ins()->new(
        host => ldb()->dbhost // $path , port => ldb()->dbport, username => ldb()->dbuser
    ), 'Created an instance to connect to db');

ok($inst->cnx, 'Instance can connect to the db');

ok($inst->cnx->ping, 'Pinged the db');

### Insert and retrieval tests
ok(my $msg = msg()->new(instance => $inst,
        key => '/PostgresInstance/foo/5432',
        value => '{"host": "foo", "port": 5432, "username": "bagger", "id": 100, "status": 0}',
    ), 'New message for new instance 100');
is($msg->relname, 'postgres_instance');
ok($inst->cnx->ping, 'still connected to db');
ok($msg->_dbh->ping, 'DB connection working');
ok($msg->save, 'Saved instance message');
ok(my $var = ins()->get_by_info('foo', '5432'), 'Retrieved my instance');
is($var->id, 100, 'Got back correct instance id');
ok($msg = msg()->new(instance => $inst,
        key => '/Dimension/100',
        value => '{"id": 100, "valid_from": "-infinity", "valid_until": "infinity", 
        "ordinality": 0, "fieldname": "foo", "default_val": "none"}'
    ), 'Created Dimension Message');
ok($msg->save, 'Saved dimension message');
ok(($var) = dim()->list, 'Got dimension back');
is($var->ordinality, 0, 'Ordinality set correctly');
is($var->id, 100, 'Ordinality set correctly');
