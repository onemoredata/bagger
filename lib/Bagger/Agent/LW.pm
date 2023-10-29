=head1 NAME

   Bagger::Agent::LW -- Lenkwerk Agent Main Logic

=cut

package Bagger::Agent::LW;

=head1 SYNOPSIS

    use Bagger::Agent::LW;
    Bagger::Agent::LW->run; # Singleton, can only run once per process

=cut

use strict;
use warnings;
use Coro;
use Coro::AnyEvent;
use AnyEvent;
use AnyEvent::Loop;
use Bagger::Agent::Storage::Mapper qw(kval_key);
use Bagger::Agent::KVStore;
use Bagger::Agent::Drivers::TestDecoding 'parse';
use AnyEvent::PgRecvlogical;
use Bagger::Storage::LenkwerkSetup;
use Bagger::Storage::Config;
use JSON;

=head1 DESCRIPTION

The Lenkwerk Agent component of the Bagger system which watches for changes in
the Lenkwerk database and publish these changes to a key/value store such as
etcd. A separate storage agent then listens to these changes and both
publishes them to the local storage databases and acts on them.

The overall structure of this agent is to simply process a pipeline.  The
Lenkwerk data is not likely to be rapidly changing and so the process here
is operationally critical but not performance-critical.

The agent processes are designed to be singletons and can only be run once in
a single process.

=head1 FUNCTIONS

=head2 run()

Begins to copy data from the Lenkwerk database into the Key/Value store. The
messages are parsed and then published to etcd.

=head1 TESTING AND DEBUGGING

Injection points are stored in the C<%_INJECTION> hash and these can be
defined by test scripts for purposes such as message capture.  These are
ignored unless the TEST_AGENT environment variable is set (which can be
done in the test scripts.

Available injection points are:

=over

=item before_parse($message)

=item after_parse($message, $hashref)

=item before_kvwrite($key, $value) (not run if parse conditins not met)

=item after_kvwrite($response) (not met if parse conditions not met)

=back

Parse conditions are met when parse() returns a hashref and the schema
matches the expected schema.

You can also reach the C<AnyEvent::PGRecvLogical> handler via the

_recv() function.

=cut

our %_INJECTION = ();

sub _run_injection {
    my $injectpoint = shift @_;
    $_INJECTION{$injectpoint}(@_) if ref $_INJECTION{$injectpoint};
}

my $done = AnyEvent->condvar;
my $recv;

sub recv { $recv }

sub start {
    my $inject = $ENV{TEST_AGENT}; # faster
    # It is fine to die here if not found
    my $kvstoremod = Bagger::Storage::Config->get('kvstore_type')->value_string;
    my $kvstoreconfig = Bagger::Storage::Config->get('kvstore_config')->value;
   
    my $kvstore = Bagger::Agent::KVStore->new(module => $kvstoremod, config => $kvstoreconfig);

    # the callback is a coderef here for procesing the messages and sending them forward.
    # The bulk of the work here is in this function.
    
    my $callback = unblock_sub {
        my ($message, $guard) = @_;
        $inject = $ENV{TEST_AGENT};
        _run_injection('before_parse', $message) if $inject;
        my $hashref = parse($message);
        _run_injection('after_parse', $message, $hashref) if $inject;
        if ($hashref && ($hashref->{schema} eq 'storage')) {
             my $key = kval_key($hashref->{tablename}, $hashref->{row_data});
             my $value = encode_json($hashref);
             my $cv = AnyEvent::condvar;
             _run_injection('before_kvwrite', $key, $value) if $inject;
             my $resp = $kvstore->write($key, $value);
             undef $guard if $resp; # processing complete
             _run_injection('after_kvwrite', $resp) if $inject;
         } else {
             # message not of interest, can undef the guard
             undef $guard;
         }
         warn "message $message unprocessed" if $guard;
     };

     # For the actual replication.....

    $recv = AnyEvent::PgRecvlogical->new(
        dbname         => Bagger::Storage::LenkwerkSetup->lenkwerkdb,
        slot           => 'lw_agent',
        do_create_slot => 1,
        slot_exists_ok => 1,
        options        => { 'skip-empty-xacts' => 1, 'include-xids' => 0 },
        on_message     => $callback,
        on_error       => sub { warn $_[0]; },
        _assemble_args(),
    );
    return $recv->start;
}

sub loop {
    AnyEvent::Loop::run();
}

sub run {
    my $promise = start;
    loop;
}

sub _done_cv { $done };

sub stop {
    $recv->stop;
    exit(8);
}

sub _assemble_args {
    my $host = Bagger::Storage::LenkwerkSetup->dbhost;
    my $port = Bagger::Storage::LenkwerkSetup->dbport;
    my $user = Bagger::Storage::LenkwerkSetup->dbuser;
    return (
        ($host ? (host     => $host) : ()),
        ($port ? (port     => $port) : ()),
        ($user ? (username => $user) : ()),
    )
}

$done->cb( sub { stop } );

1;
