use Test2::V0 -target => {pkg => 'Bagger::Storage::Config' };

plan 9;

ok(pkg()->new(key => 't', value => 'foo'), 'string -> string value');
ok(pkg()->new(key => 't', value => 123), 'string -> int value');
ok(pkg()->new(key => 't', value => ['foo']), 'string -> arrayref value');
ok(pkg()->new(key => 't', value => { foo => 'foo'}), 'string -> hashref value');

ok(dies { pkg()->new(key => 't') }, 'dies without value');
ok(dies { pkg()->new(value => 't') }, 'dies without key');
ok(dies { pkg()->new(key => 't', value => sub { 1 } ) } , 'dies on coderef value');
ok(dies { pkg()->new(key => 't', value => undef) }, 'dies on undef value');
my $foo = '123';
ok(dies { pkg()->new(key => 't', value => \$foo) }, 'dies on scalar reference')


