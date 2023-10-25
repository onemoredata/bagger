=head1 NAME

    Bagger::Agent::Drivers::TestDecoding -- Parsing for Pg test_decoding

=cut

package Bagger::Agent::Drivers::TestDecoding;

=head1 SYNOPSIS

    use Bagger::Agent::Drivers::TestDecoding 'parse_msg';
    my $rep_msg = parse_msg($message_from_postgres);

=cut

use strict;
use warnings;
use JSON;
use Exporter 'import';
our @EXPORT_OK = qw(parse);

=head1 DESCRIPTION

This module parses inbound messages from PostgreSQL's test_decoding logical
replication plugin and returns a hashref containing key data.  This can then
be used to stream logical replication data from PostgreSQL into other data
sources.

This module is designed to work with C<AnyEvent::PgRecvlogical> and allow
applications to process inbound data as needed.

The module provides one method, parse, which returns a hashref.  See below.

=head1 FUNCTIONS

=head2 parse($message)

parse() takes in a message and returns a hashref with the following structure:

=over

=item schema -- sql schema/namespace where the table is located.

=item tablename -- table name affected

=item operation -- insert, update, delete

=item row_data  -- Current row as a hashref.  For a delete, this is the deleted row

=back

=cut

# I don't like this approach.  It is hard to read/reason about.
# Maybe we should move this ti Parse::RecDescent?  Another research project...
sub parse {
    my $msg = shift;
    return unless $msg =~ s/^table\s+//;
    $msg =~ s/^(\w+)\.(\w+):\s+([A-Z]+):\s//;
    my ($schema, $tablename, $op) = ($1, $2, $3);
    my $row = {};
    my @elems = split /\[[a-z]+\]:/, $msg;
    my $nextkey = shift @elems;
    for my $elem (@elems){
        my $key = $nextkey;
        $elem =~ s/\s+(\w+)$//;
        $elem =~ s/(^'|'$)//g;
        $nextkey = $1;
        $row->{$key} = $elem;
    }
    return  {
        schema     => $schema,
        tablename  => $tablename,
        operation  => $op,
        row_data   => $row,
    }
}


1;
