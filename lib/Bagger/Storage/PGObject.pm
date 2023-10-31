=head1 NAME
 Bagger::Storage::PGObject - PGObject setup for Bagger

=cut

package Bagger::Storage::PGObject;

=head1 SYNOPSIS

 use Moose;
 with 'Bagger::Storage::PGObject';
 ...
 sub foo {
    return $self->call_dbmethod(
        funcname => 'foo',
        args     => { bar => 'baz' }
    );
 };

Note that properties from $self are interpolated in automatically.

=head1 DESCRIPTION

This provides a Moose role for Bagger tooling to interact with the
lenkwerk database (which provides control, catalog, and metadata
services to Bagger components) and thus set/administer the cluster.

The module here assumes PGObject::Simple mappings.

This module will not be suitable for any web services for querying
Bagger, and subclasses will be required for this.

Here by default all objects will be found in the storage database
namespace.

=cut

use Moose::Role;
use strict;
use warnings;
use namespace::autoclean;
use PGObject;
use Try::Tiny;
use DBI;
use Bagger::Storage::LenkwerkSetup;

with 'PGObject::Simple::Role';

our $VERSION = '0.0.1';

# schema where functions are found.
sub _get_schema() { 'storage' }


=head1 DATABASE HANDLES

In this implementation, database handles will be created
lazily on the first use and reused as a singleton within this
module.

=cut

{
my $dbh;
sub _get_dbh() {
   return $dbh if $dbh; # retrieve singleton if available
   return _new_dbh();
}

sub _new_dbh() {
   $dbh = DBI->connect(
            Bagger::Storage::LenkwerkSetup->dbi_str,
            Bagger::Storage::LenkwerkSetup->dbuser,
            Bagger::Storage::LenkwerkSetup->dbpass,
        {AutoCommit => 0, RaiseError => 1 }) 
               or die Bagger::Type::Exception::DB->new();
   return $dbh;
}

}

around qw(call_procedure call_dbmethod) => sub {
    my $orig = shift;
    my $self = shift;
    my @args = @_;
    try {
        $self->$orig(@args);
    } catch {
        die Bagger::Type::Exception::Database->new($self->_dbh);
    };
};

=head1 Utility Functions

=head2 bool(val)

Returns 1 if true and 0 if false.

Useful if a value needs to fit into a Bool Moose type.

=cut

sub bool {
    my ($val) = @_;
    return $val ? 1 : 0;
}

=head1 MORE INFORMATION

For more information see CPAN docs for the following modules:

=over

=item PGObject

=item PGObject::Simple

=item PGObject::Simple::Role

=back

=cut

1;

# vim:ts=4:sw=4:expandtab
