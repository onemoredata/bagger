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
use Parse::RecDescent;
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

my $grammar = <<'_ENDGRAMMAR';
    tablerec : header operation ":" col(s)
             {$Bagger::Agent::Drivers::TestDecoding::parsed->{operation} = $item{operation}}
    header : "table " schema "." tablename ":" 
             {$Bagger::Agent::Drivers::TestDecoding::parsed->{schema} = $item{schema}}
             {$Bagger::Agent::Drivers::TestDecoding::parsed->{tablename} = $item{tablename}}
    col : column(s)
    schema : sqlident
    tablename : sqlident
    column : /\s?/ colname "[" coltype "]" ":" value
    {$Bagger::Agent::Drivers::TestDecoding::parsed->{row_data}->{$item{colname}} = $item{value} }
    colname : sqlident
    coltype : /[a-zA-Z0-9() ]+/
    value   : literal
    sqlident : /\w+/ | /"([^"]|"")+"/
    literal : /\w+/ | /'([^']|'')+'/
    operation : "INSERT" | "UPDATE" | "DELETE"
             {$Bagger::Agent::Drivers::TestDecoding::parsed->{operation} = $item[1]; }
_ENDGRAMMAR

#recdescent apparently needs to access these things via direct fully
#qualified variables, which means lexically scoped variables cannot
#be used in this way.  This is fine since we can just locally scope it.

our $parsed;
my $parser = Parse::RecDescent->new($grammar);

sub parse {
    local $parsed;
    my $msg = shift;
    return unless $msg =~ /^table\s+/;
    $parser->tablerec($msg);
    my $retval = {%$parsed};
    for my $k (keys %{$retval->{row_data}}){
        if ($retval->{row_data}->{$k} =~ /^'/){
            $retval->{row_data}->{$k} =~ s/''/'/g;
            $retval->{row_data}->{$k} =~ s/(^'|'$)//g;
        }
    }
    return $retval;
}


1;
