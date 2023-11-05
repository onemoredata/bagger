=head1

   Bagger::Storage::Time_Bound -- Common Methods for Time Bound DB Objects

=cut

package Bagger::Storage::Time_Bound;

=head1 SYNOPSIS

   package MyClass;
   use Moose;
   with 'Bagger::Storage::Time_Bound';

   sub _config_hrs_out { 'MyConfig_in_hours' }

   # then you can
   #
   $foo = MyClass->new;
   $exire_proxy = $foo->_expire_proxy;

=cut

use strict;
use warnings;
use Moose::Role;
use Bagger::Storage::Config;
use Moose::Util::TypeConstraints;
use Bagger::Type::DateTime;
use namespace::autoclean;

=head1 DESCRIPTION

Some Bagger entities can be added and need to take effect only in the futre at
defined points for future partitions.  These include partitioning dimensions,
indexes, and index fields.  In other words, different indexes can be created or
retired, and fields can be added or removed, but only for future partitions.

In order to ensure a sane cluster state, we require some time in between the
change and its impact, with additional checks happening along the
implementation pathway.  The system is also designed to provide some time for
human operators to respond to potential issues either by pushing changes out or
by resolving cluster issues.

=head2 Time-Bound Change Restrictions

The earliest a timebound object may change is at first start of the hour at
least one hour in the future.  This provides time for the changes to be pushed
out to the cluster, for monitoring to reconcile the changes, and for human
operators to find and correct errors if the cluster does not reach a consistent
state quickly.

Additionally modules can specify a configuration variable which, if set, will
specify the number of hours out.  This variable MUST be set to a positive
integer, and this module B<will> throw errors if this is not set.

=head1 REQUIRED INTERFACES

=head2 _config_hours_out

Any C<Time_Bound> Object must have a configuration variable set up to determine
how far out changes will be applied.

=cut

requires '_config_hours_out';

=head1 ATTRIBUTES

This type has two attributes which are stored as C<Bagger::Type::DateTime>
objects.  These objects are coerceable from strings and invoke the standard
database parsing routines specified by C<Bagger::Type::DateTime> which inherits
some or all of this functionality from C<PGObject::Type::DateTime>.

=head2 valid_from

This represents the first time the dimension is valid.

In production this dimension is valid at the hour boundary
dimensions_hrs_in_future in the future.  When not in production this is valid
for all time.

=cut

coerce 'PGObject::Type::DateTime'
=> from 'Str'
=> via { Bagger::Type::DateTime->from_db($_) };

sub _config_dim_timing {
    my $self = shift;
    my $production = Bagger::Storage::Config->get('production');
    $production = $production->value_string if defined $production;
    my $hours_out;
    my $in_hrs = Bagger::Storage::Config->get($self->_config_hours_out);
    $hours_out = $in_hrs->value_string if defined $in_hrs;
    die 'Production config value invalid'
                                       if $production and ($production ne '1');
    die 'Invalid dimensions_hrs_in_future config variable must be positive int'
                                    if $hours_out and ($hours_out =~ /\D/);
    return ($production, $hours_out // 1);
}

sub _def_valid_from {
    my $self = shift;
    my ($production, $hrs_out) = $self->_config_dim_timing;
    return Bagger::Type::DateTime->inf_past unless $production;
    return Bagger::Type::DateTime->hour_bound_plus($hrs_out);
}


has valid_from => (is => 'ro', isa => 'PGObject::Type::DateTime', coerce => 1,
    builder => '_def_valid_from');

=head2 valid_until

This represnets the beginning of the interval the when the dimension is no
longer valid.

By default, this is valid forever.

To get next expiratoin_date, use the next_expiration_date function.

See C<Bagger::Storage::Time_Bound> for details.

=cut

sub _def_valid_until {
    return Bagger::Type::DateTime->inf_future;
}

has valid_until => (is => 'ro', isa => 'PGObject::Type::DateTime', coerce => 1,
    builder => '_def_valid_until');

=head1 METHODS

=head2 next_expiration_date()

When not in production, returns Past Infinity, because we can back-date
expirations.

In production, returns the next available dimension change point, namely

the next hour boundary plus dims_in_hrs config variable.

=cut

sub next_expiration_date {
    my $self = shift;
    my ($production, $dims_in_hrs) = $self->_config_dim_timing;
    return Bagger::Type::DateTime->inf_past unless $production;
    return Bagger::Type::DateTime->hour_bound_plus($dims_in_hrs or 1);
}

=head1 expire_proxy

Returns a copy of the object with the valid_until replaced with the
next available expiration time.

This is primarily intended for use in calling ->expire methods.

=cut

sub expire_proxy {
    my $self = shift;
    return $self->new(%$self, valid_until => $self->next_expiration_date);
}

=head1 in_time_bounds

Returns 1 if the current time is between the valid_from and valid_until times

=cut

sub in_time_bounds {
    my $self = shift;
    my $now = Bagger::Type::DateTime->now();
    return ($self->valid_from <= $now)
        && ($self->valid_until > $now);
    return 1;
}

1;
