use Test2::V0 -target => { pkg => 'Bagger::Type::JSONPointer' };
use strict;
use warnings;

plan 38;

is(my $ptr = Bagger::Type::JSONPointer->new(), [], 'Empty JSONPointer supported');
is("$ptr", '', 'Empty JsonPointer stringifies to empty string, 1 of 3');
is($ptr->stringify, '', 'Empty JsonPointer stringifies to empty string, 2 of 3');
is($ptr->to_db, '', 'Empty JsonPointer stringifies to empty string, 3 of 3');
is(scalar @$ptr, 0, 'Empty pointer has zero elements');

ok($ptr = Bagger::Type::JSONPointer->new('foo'), 'Single raw element pointer');
is("$ptr", "/foo", 'Serializes as absolute path, starting with /');
is($ptr->[0], 'foo', 'Element 0 matches');
is($ptr->to_db, '/foo', "Serializes to the db as /foo");
is($ptr->stringify, '/foo', "Serializes to string as /foo");

ok($ptr = Bagger::Type::JSONPointer->new(['/foo']), 'Single arrayref element');
is("$ptr", "/~1foo", "Serializes with escape to /~1foo");
is($ptr->to_db, "/~1foo", "Serializes to db with escape to /~1foo");
is(scalar @$ptr, 1, 'Has one element');
is($ptr->[0], '/foo', 'First element is "/foo"');

ok($ptr = Bagger::Type::JSONPointer->new('foo', 'bar', 1, 2, '/bar', '~foo'),
    "Complex pointer type with escapes");
is($ptr, ['foo', 'bar', 1, 2, '/bar', '~foo'], 'Arrayref correct');
is("$ptr", "/foo/bar/1/2/~1bar/~0foo", 'Complex serialization to string');
is($ptr->to_db, "/foo/bar/1/2/~1bar/~0foo", 'Complex serialization to db');

## parsing

is(Bagger::Type::JSONPointer->new(''), [], 'Parsing of empty jsonpointer supported');
is(Bagger::Type::JSONPointer->new('/foo'), ['foo'], '/foo parses');
is(Bagger::Type::JSONPointer->new('/~1foo'), ['/foo'], '/~1foo parses');
is(Bagger::Type::JSONPointer->new('/foo/bar/1/2/~1bar/~0foo'), 
   ['foo', 'bar', 1, 2, '/bar', '~foo'],
   "'/foo/bar/1/2/~1bar/~0foo' parses");

## round trip

my @ptrs = (
    "",
    "/foo",
    "/~1foo",
    '/foo/bar/1/2/~1bar/~0foo',
    '/foo/bar/1/2/~10bar/~01foo',
);

for my $p (@ptrs) {
    is(Bagger::Type::JSONPointer->new($p)->to_db, $p, "$p db round trip");
    is(Bagger::Type::JSONPointer->new($p)->stringify, $p, "$p string round trip");
    $ptr = Bagger::Type::JSONPointer->new($p);
    is("$ptr", $p, "$p round trip, string context");
} 
