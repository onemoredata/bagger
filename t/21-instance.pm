use Test2::V0;
use Bagger::Storage::Instance;

# In the future, will add tests for the whole db round trip but have more
# things to add before that can happen.  So for now, will test that the
# infariants of the constants are respected.

plan 20;

is(Bagger::Storage::Instance->OFFLINE & Bagger::Storage::Instance->F_READ, 0,
   'Offline cannot read');
is(Bagger::Storage::Instance->OFFLINE & Bagger::Storage::Instance->F_WRITE, 0,
   "Offline cannot write");
ok(Bagger::Storage::Instance->RO & Bagger::Storage::Instance->F_READ,
   "Read-Only Can Read");
is(Bagger::Storage::Instance->RO & Bagger::Storage::Instance->F_WRITE, 0,
   "Read-Only Cannot Write");
is(Bagger::Storage::Instance->WO & Bagger::Storage::Instance->F_READ, 0,
   "Write-Only Cannot Read");
ok(Bagger::Storage::Instance->WO & Bagger::Storage::Instance->F_WRITE,
   "Write-Only Can Write");
ok(Bagger::Storage::Instance->ONLINE & Bagger::Storage::Instance->F_READ,
   "Online can read");
ok(Bagger::Storage::Instance->ONLINE & Bagger::Storage::Instance->F_WRITE,
   "Online can write");

my %args = (
    host => 'localhost',
    port => 5432,
    username => 'test',
);

ok(my $offline_inst = Bagger::Storage::Instance->new(%args,
     status => Bagger::Storage::Instance->OFFLINE));

ok(my $ro_inst = Bagger::Storage::Instance->new(%args,
     status => Bagger::Storage::Instance->RO));

ok(my $wo_inst = Bagger::Storage::Instance->new(%args,
     status => Bagger::Storage::Instance->WO));

ok(my $online_inst = Bagger::Storage::Instance->new(%args,
     status => Bagger::Storage::Instance->ONLINE));

# testing for strict 0/1 for Moose bool compat here
is($offline_inst->can_read, 0, 'Offline Host Cannot Read');
is($offline_inst->can_write, 0, 'Offline Host Cannot Write');
is($ro_inst->can_read, 1, 'Read Only Host Can Read');
is($ro_inst->can_write, 0, 'Read-Only Host Cannot Write');
is($wo_inst->can_read, 0, 'Write-Only Host Cannot Read');
is($wo_inst->can_write, 1, 'Write-Only Host Can Read');
is($online_inst->can_read, 1, 'Online Host Can Read');
is($online_inst->can_read, 1, 'Online Host Can Read');
