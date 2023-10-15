use Test2::V0 -target => { pkg => 'Bagger::Storage::LenkwerkSetup' };
use strict;
use warnings;

skip_all('BAGGER_TEST_LW environment variable not set') unless defined
                                                        $ENV{BAGGER_TEST_LW};

bail_out('BAGGER_TEST_LW_DB environment variable not set') unless defined
                                                       $ENV{BAGGER_TEST_LW_DB};

pkg()->set_lenkwerkdb($ENV{BAGGER_TEST_LW_DB});
pkg()->set_dbhost($ENV{BAGGER_TEST_LW_HOST}) if defined $ENV{BAGGER_TEST_LW_HOST};
pkg()->set_dbport($ENV{BAGGER_TEST_LW_PORT}) if defined $ENV{BAGGER_TEST_LW_PORT};
pkg()->set_dbuser($ENV{BAGGER_TEST_LW_USER}) if defined $ENV{BAGGER_TEST_LW_USER};


plan 2;

ok(pkg()->createdb(), 'Successfully created the Lenkwerk DB') 
        or bail_out('FATAL: db creation failed');
ok(pkg()->load(), 'Successfully loaded Lenkwerk DB')
        or bail_out('FATAL: db load failed');

