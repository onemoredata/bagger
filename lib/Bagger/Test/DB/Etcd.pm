=head1 NAME

   Bagger::Test::DB::Etcd -- Testing setup for etcd

=cut

package Bagger::Test::DB::Etcd;

=head1 SYNOPSIS 

   use Bagger::Test::DB::Etcd;
   my $guard = Bagger::Test::DB::Etcd->guard;

   # do tests here
   #
   undef $guard; #optional, will get called at end of script.


=head1 DESCRIPTION

This module sets up the etcd testing parameters.  In this case etcd will be set
up as a standalone system, without peers listening on a port defined in the
environment variables set in t/README.txt. Additionally the relevant settings
for connection will be set in the Lenkwerk database so that tests can proceed to
use it.

This module will only run if a testing lenkwerkdb setup is set.

The module makes use of a guard pattern allowing you to control when the etcd
setup is removed. The guard truncates the storage.config table and terminates
the etcd process when it is destroyed or goes out of scope.

=cut

use Bagger::Test::DB::LW;
use Bagger::Storage::Config;
use Bagger::Type::JSON;
use Capture::Tiny;
use Test2::V0;
use strict;
use warnings;

=head1 FUNCTIONS

=head2 import

Sets up the tests.  SKIPs the current tests unless the etcd testing.

Also runs etcd on the specified port and sets up the config in Lenkwerk.

=cut

sub import {
    skip_all 'BAGGER_TEST_ETCD not set' unless $ENV{BAGGER_TEST_ETCD};
    skip_all 'BAGGER_TEST_ETCD_PORT needed' unless $ENV{BAGGER_TEST_ETCD_PORT};
    start_etcd();
    config();
}


=head2 start_etcd

Starts the etcd on the specified port.

=cut

my $pid;


sub start_etcd {
    my $url = "http://127.0.0.1:$ENV{BAGGER_TEST_ETCD_PORT}";
    my $path = '';
    $path = $ENV{BAGGER_TEST_ETCD_PATH} if $ENV{BAGGER_TEST_ETCD_PATH};
    $path .= '/' if $path and ($path !~ m|/$|);
    $path .= 'etcd' unless $path =~ 'etcd$';
    if ($pid = fork){
        # nothing to do
    } else {
        capture {
          system($path, '--listen-client-urls', $url, 
              '--advertise-client-urls', $url, '--data-dir', 't/data',
              '--log-level=error', '--logger=zap'
          );
        }; # and do nothing with it
    }
}

=head2 config

Inserts the configuration data into the Lenkwerk database.

=cut

my $config;

sub get_config { $config }


## no critic qw(Subroutines::ProtectPrivateSubs)
sub config {
    my $port = $ENV{BAGGER_TEST_ETCD_PORT};
    $config = {host => '127.0.0.1', port => $port};
    Bagger::Storage::Config->new(key => 'kvstore_type', value => 'etcd')->save;
    Bagger::Storage::Config->new(key => 'kvstore_config', 
                               value => Bagger::Type::JSON
                                        ->new($config)
                                   )->save->_dbh->commit;
}

## use critic

=head2 cleanup

Runs the actual cleanup.  You cna run this manually if you actually have to.

This stops etcd running on the port in question.  It also truncates the config
table in the lenkwerk database.

=cut

sub cleanup {
    kill(15, $pid);
    system('fuser', '-k', '-n', 'tcp', $ENV{BAGGER_TEST_ETCD_PORT});
    system('rm', '-r', '-f', 't/data/member'); # etcd data dir
    #   Bagger::Storage::Config->_get_dbh->do('TRUNCATE storage.config');
}

sub DESTROY { cleanup }

=head2 guard

Returns a guard that runs cleanup() when it goes out of scope.  This allows for
automatic cleanup to the extent permitted by circumstance.  This currently does
not allow for subclassing.

=cut

sub guard {
    my $pkg = __PACKAGE__;
    my $guard = \$pkg;
    bless $guard, $pkg;
}
1;
