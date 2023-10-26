=head1 NAME

   Bagger::Agent::Drivers::KVStore -- KVStore API for Bagger Agents

=cut

package Bagger::Agent::Drivers::KVStore;

use strict;
use warnings;
use Moose::Role;

=head1 SYNOPSIS

   This package does nothing.  It only enforces API requirements
   for KVStore drivers.

=head1 REQUIRED IMPLEMENTATIONS

Classes implementing this role MUST provide the following methods:

=over

=item kvconnect(hashref) which returns a driver instance object

=item kvread(key) which returns an object from the key/value store

=item kvwrite(key, value) which writes a value to the key/value store

=item kvwatch() which must watch the specific range of values we need

=back

=cut

requires qw(kvconnect kvread kvwrite kvwatch);

1;
