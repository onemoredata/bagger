=head1 NAME

   Bagger::Type::Exception::Database -- Database Exceptions for Bagger

=cut

package Bagger::Type::Exception::Database;

=head1 SYNOPSIS

    $dbh->do($query) or die Bagger::Type::Exception::Database->new( $dbh );
    # on connection this can be captured as
    DBI->Connect($cnx) or die Bagger::Type::Exception::Database->new();

=cut

use overload '""' => 'stringify';
use strict;
use warnings;

our $STRINGIFY_STACKTRACE = 1; # set to off to capture stack traces

=head1 DESCRIPTION

This module is a cery simple exception class which stores information about the
database errors which can be helpful in troubleshooting or understanding
database problems.

The exception is intended to be fairly easy to use.  If C<Devel::Stacktrace> is
loaded, then we will gather stack traces as well and these will be available
by default in stringified versions (to avoid reference checking problems).

=head1 FIELDS AND STRINGIFICATION

The exception is a hashref which contains the following fields:

=over

=item state is the SQLSTATE at the time of the error

=item errstr is the error string the database raised

=item stacktrace (if C<Devel::StackTrace> is loaded)

he stacktrace at time of error

=back

The exception stringifies as:

$sqlstate: $errstr

=cut

sub stringify { 
    my $self = shift;
    $self->{state} //= '';
    $self->{errstr} //= '';
    return "$self->{state}: $self->{errstr}";
}

=head1 FUNCTIONS

=head2 new($dbh) or $new()

Creates a new exception with the information provided by $dbh if available.

=cut

sub new {
    my $class= shift;
    my $dbh = shift;
    my $self = {};
    $self->{state} =  ($dbh ? $dbh->state  : $DBI::state);
    $self->{errstr} = ($dbh ? $dbh->errstr : $DBI::errstr);
    if (scalar grep { $_ eq 'Devel/StackTrace.pm' } keys %INC){
        $self->{stacktrace} = $STRINGIFY_STACKTRACE ? Devel::StackTrace->new
                                                    : Devel::StackTrace->new->as_string;
    }
    bless $self;
}

1;
