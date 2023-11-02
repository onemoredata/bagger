use Test2::V0 -target => {proc => 'Bagger::Agent::Storage::Schaufel',
                          inst => 'Bagger::Storage::Instance' };
use AnyEvent; # needed to test exit handling
use AnyEvent::Loop;

# Constructor tests
plan 13;
my $proc;
my $hosts = [ inst()->new(host => 'foo', port => 5432, username => 'test'),
              inst()->new(host => 'bar', port => 5432, username => 'test') ];

ok($proc = proc()->new(
        broker => 'test',  threads => 2, hosts => $hosts,
        topic  => 'test1', group   => 'test'
    ), 'Created initial Schaufel object');

is($proc->pid, undef, 'Pid is not defined after created');
is($proc->log, '/var/log/schaufel/bagger.log', 'Default log correct');
is($proc->cmd, '/usr/bin/schaufel', 'Default command correct');
is($proc->args, [
        -l => $proc->log,     -i => 'k',          -b => 'test',
        -g => 'test',         -o => 'p',          -t => 'test1',
        -p => 2,              -H => 'foo:5432,bar:5432' ],
    'Default args correct');

# start/stop tests
ok(my $sleep = proc()->new(
        broker => 'test',  threads => 2,      hosts => $hosts,
        topic  => 'test1', group   => 'test', args  => ['30'],
        cmd    => 'sleep'
    ), 'Created sleeper process handle');

# sentinel handler for capturing SIGCHILD Signals
# This particular listener will never get triggered but it
# sets up infrastructure needed to guarantee capture of child
# exit events

my $w = AnyEvent->child(pid => $$, cb => sub {} );

$sleep->start;
ok(my $pid = $sleep->pid, 'Got a pid now');
$w = AnyEvent->child(pid => $sleep->pid, cb => sub {
     pass('Sleep process stopped');
     is($_[0], $pid, 'Got pid back from sleep');
     is($_[1], 15, 'Exit status 15') # but note, schaufel masks signals
                                     # and returns 0
 } );
$sleep->stop;
AnyEvent::Loop::one_event();
is($sleep->pid, 0, 'Sleep is now undef');
ok($sleep, 'Sleep still an object');

# Exit Handling Tests

ok(my $false = proc()->new(
        broker => 'test',  threads => 2,      hosts => $hosts,
        topic  => 'test1', group   => 'test', args  => ['30'],
        cmd    => 'false'
    ), 'Created sleeper process handle');

my $run = 1;
$false->start;
$pid = $false->pid;
$w = AnyEvent->child(pid => $false->pid, cb => sub {
     pass('False process stopped');
     is($_[0], $pid, 'Got pid back from sleep');
     ok($_[1], 'Non-zero exit status');
     $run = 0;
 } );

AnyEvent::Loop::one_event() while $run;

