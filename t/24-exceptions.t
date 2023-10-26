use Test2::V0 -target => {exc => Bagger::Type::Exception::Database };
use Try::Tiny;
use DBI;

plan 5;

ok(my $exc = exc->new(), 'Can instantiate without a dbh');

$exc->{state} = '12345';
$exc->{errstr} = 'Test';
is("$exc", "12345: Test", 'Stringified');

try {
    DBI->connect('dbi:Pg:host=localhost;port=1') or die exc->new();
} catch {
    is($_->{state}, '08006', "SQL State is set to");
    is($_->{errstr}, q|connection to server at "localhost" (::1), port 1 failed: Connection refused
	Is the server running on that host and accepting TCP/IP connections?
connection to server at "localhost" (127.0.0.1), port 1 failed: Connection refused
	Is the server running on that host and accepting TCP/IP connections?|, 'Error string set');
    is("$_", qq|08006: connection to server at "localhost" (::1), port 1 failed: Connection refused
\tIs the server running on that host and accepting TCP/IP connections?
connection to server at "localhost" (127.0.0.1), port 1 failed: Connection refused
\tIs the server running on that host and accepting TCP/IP connections?|, "Stringified");
};
