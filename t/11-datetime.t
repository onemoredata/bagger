use Test2::V0 -target => { pkg => 'Bagger::Type::DateTime' };
use strict; # just a reminder
use warnings;

plan 18;

my $now = pkg()->now();
my $inf = pkg()->inf_future;
my $infpast = pkg()->inf_past;

for my $dt($now, $inf, $infpast) {
    ok($dt->to_db, 'Serialization to db is true for datetime:' . $dt->to_db);
    isa_ok($dt, 'DateTime', 'PGObject::Type::DateTime');
}
isa_ok($now, 'Bagger::Type::DateTime');

isa_ok($inf, 'DateTime::Infinite::Future');
isa_ok($infpast, 'DateTime::Infinite::Past');

my @dtstrings = (
    'infinity',
    '-infinity',
    '2023-01-01 00:00:00.0',
    '3033-01-01 23:58:59.0'
);

for my $dts (@dtstrings){
    is(pkg()->from_db($dts)->to_db, $dts, "'$dts' round trip matches");
}

is(pkg()->hour_bound_plus(1)->iso8601, DateTime->now()->truncate(to => 'hour')->
    add(hours => 2)->iso8601, 'Hour bound plus works properly with arg of 1');
ok(dies { pkg()->hour_bound_plus(0) }, 'dies on 0');
ok(dies { pkg()->hour_bound_plus(-1) }, 'dies on -1');
ok(dies { pkg()->hour_bound_plus(1.5) }, 'dies on 1.5');
ok(dies { pkg()->hour_bound_plus('1foo') }, 'dies on non-int string');
