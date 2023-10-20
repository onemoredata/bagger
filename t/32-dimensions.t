use Test2::V0 -target => { pkg => 'Bagger::Storage::Dimension' , 
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

plan 14;

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
