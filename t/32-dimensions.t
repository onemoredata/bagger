use Test2::V0 -target => { pkg => 'Bagger::Storage::Dimension' , 
                            db => 'Bagger::Storage::LenkwerkSetup',
                           cfg => 'Bagger::Storage::Config'};
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

plan 24;

## test setup

ok (my $dim1 = pkg()->new(fieldname => 'foo',
                          default_val => 'na'),
     'dimension for field foo');
ok (my $dim2 = pkg()->new(fieldname => '/bar/baz'), 
     'dimension for /bar/baz');

ok (my $dim1s = $dim1->append, 'Appended foo dimension');
ok (my $dim2s = $dim2->append, 'appended /bar/baz dimension');

is ( $dim1->fieldname,  ['foo'], "Foo fieldname validated");
is ( $dim2->fieldname,  ['bar', 'baz'], '/bar/baz fieldnames validated');
is ( $dim1s->fieldname, $dim1->fieldname, 'Fieldname foo survived append');
is ( $dim2s->fieldname, $dim2->fieldname, 'Fieldname /bar/baz survived append');
is ( $dim1s->ordinality, 0, 'First dimension has ordinality 0');
is ( $dim2s->ordinality, 1, 'Second dimension has ordinality 1');
is ( $dim2s->valid_until->to_db, 'infinity', "Valid forever" );
is ( $dim2s->valid_from->to_db, '-infinity', "Valid from" );
isa_ok ( $dim2s->valid_from, 'DateTime::Infinite::Past');
is ( [pkg()->list], [$dim1s, $dim2s], 'Listing provides correct dimensions');

## Expiration and production setup tests.

# setting to Production mode

ok(cfg()->new(key => 'production', value => 1)->save, 'Setting production mode');

ok(my $dim3 = pkg()->new(fieldname => '/baz/1'));
is($dim3->valid_from, Bagger::Type::DateTime->hour_bound_plus(1), 
     'Valid_from correct for default values in production');
is($dim3->valid_until->to_db, 'infinity', 'Valid forever in production');
is($dim1s->expire->valid_until, Bagger::Type::DateTime->hour_bound_plus(1),
     'Expiration happens at correct time, default production mode');

ok(cfg()->new(key => 'dimensions_hrs_in_future', value => 3)->save, 
    'Setting changes to happen 3 hrs in the future');

ok($dim3 = pkg()->new(fieldname => '/baz/1'));
is($dim3->valid_from, Bagger::Type::DateTime->hour_bound_plus(3),
    'Valid_from honors dims_hrs_in_future');
is($dim3->valid_until->to_db, 'infinity', 'Valid forever in production');
is($dim2s->expire->valid_until, Bagger::Type::DateTime->hour_bound_plus(3),
     'Expiration honors dims_hrs_in_future');

# expiration
