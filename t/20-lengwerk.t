use Test2::V0 -target => { pkg => 'Bagger::Storage::LenkwerkSetup' };
use strict;
use warnings;

plan 18;

is(pkg()->dsn_uri, 'postgresql://:@:5432/lenkwerk', 'Default dsn uri correct');

is(pkg()->dbhost, undef, 'dbhost is originally undef');
pkg()->set_dbhost('localhost');
is(pkg()->dbhost, 'localhost', 'dbhost is successfully set to localhost');

is(pkg()->dsn_uri, 'postgresql://:@localhost:5432/lenkwerk', 'URI hostname correct');

is(pkg()->dbport, 5432, 'port initially set to 5432');
pkg()->set_dbport(5433);
is(pkg()->dbport, 5433, 'port successfully set to 5433');

is(pkg()->dsn_uri, 'postgresql://:@localhost:5433/lenkwerk', 'URI port changed');
pkg()->set_dbport(5432);

is(pkg()->lenkwerkdb, 'lenkwerk', q#lenkwerkdb initially sent to 'lenkwerk'#);
pkg()->set_lenkwerkdb('test');
is(pkg()->lenkwerkdb, 'test', q#lenkwerkdb successfully set to 'test'#);

is(pkg()->dsn_uri, 'postgresql://:@localhost:5432/test', 'URI dbname changed');

is(pkg()->dbuser, undef, 'dbuser initially not defined, defaults to os user');
pkg()->set_dbuser('test');
is(pkg()->dbuser, 'test', 'dbuser initially set to test');

is(pkg()->dsn_uri, 'postgresql://test:@localhost:5432/test', 'URI username correct');

is(pkg()->dbpass, undef, 'dbpass initially not defined');
pkg()->set_dbpass('test');
is(pkg()->dbpass, 'test', 'dbpass successfully set to test');

is(pkg()->dsn_uri, 'postgresql://test:test@localhost:5432/test', 'URI password correct');

pkg()->set_dbpass('e$r@12%df4>>');
is(pkg()->dsn_uri, 'postgresql://test:e%24r%4012%25df4%3E%3E@localhost:5432/test', 'URI handles special chars');

pkg()->set_dbpass('ð');
is(pkg()->dsn_uri, 'postgresql://test:%C3%B0@localhost:5432/test', 'URI handles utf8');
