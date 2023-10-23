use Test2::V0 -target => { pkg => 'Bagger::Storage::LenkwerkSetup' };
use Bagger::Test::DB::LW;
use strict;
use warnings;


plan 2;

ok(pkg()->createdb(), 'Successfully created the Lenkwerk DB') 
        or bail_out('FATAL: db creation failed');
ok(pkg()->load(), 'Successfully loaded Lenkwerk DB')
        or bail_out('FATAL: db load failed');

