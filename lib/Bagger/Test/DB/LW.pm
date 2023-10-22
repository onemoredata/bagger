=head1 NAME

   Bagger::Test::PGTap -- Test class for running pgTAP files

=cut

package Bagger::Test::PGTap;

=head1 SYNOPSIS

   skipall => 'pgTap not available' unless Test::PGTap->pgtap_available;
   Test::PGTap->set_dir('t/sql');
   # can also set db connection params for psql
   Test::PGTap->set_psql_params(-U => 'postgres', -p => 5433, -d => 'mydb');
   # or set dsn
   Test::PGTap->set_dsn('postgresql://postgres@:5433/mydb');
   Test::PGTap->run('mytest.pg');

=cut
use strict;
use warnings;
use Carp 'croak';
use Capture::Tiny;

=head1 FUNCTIONS

=head2 set_psql_params(list)

Sets the parameters for psql.

References may not be passed in.

The arguments are in the order they will be passed to psql.

=cut

my @args;

sub set_psql_params {
    my $self = shift;
    my @t_args = @_;
    unshift @t_args, $self if $self =~ /^-/ || $self !~ /::/ ;
    for my $a (@t_args) {
        croak 'No references allowed for arguments' if ref $a;
    }
    @args = @t_args;
}

=head2 set_psql_path

Sets the path to the psql binary if not in the PATH environment
variable.  Note that the psql binary itself should NOT be part
of this path.

=cut

my $psql_path;

sub set_psql_path {
    my $self = shift;
    $psql_path = shift // $self
};

=head2 set_dsn

This allows you to set the dsn to use for connecting via psql.

When both dsn and parameters are set, the parameters take precedence.

=cut

my $dsn;

sub set_dsn {
    my $self = shift;
    $dsn  = shift // $self;
}

=head2 set_dir

This sets the directory for the test cases files.

It should not include the file itself.

=cut

my $test_dir;

sub set_dir {
    my $self = shift;
    $test_dir = shift // $self;
}

=head2 pg_tap_available

Checks the available extensions and returns true if pgTAP is available.

Returns false if not.

=cut

sub pg_tap_available{
    my $self = shift;
    my $q = "select count(*) from pg_available_extensions() where name = 'pgtap'";
    my ($stdout, $stderr, $exit) = capture {
        return system('psql', (scalar @args ? (@args) : ($dsn)),
            -c => $q, '-t')
    };
    warn $stderr if $stderr;
    return int($stdout);
}

=head2 run($filename)

This runs a filename specified and prints the output to
standard output for the test harness.

If params and a dsn are both set, the params take precedence.

=cut

sub params { scalar @args ? (@args) : ($dsn) }

sub run {
    my $self = shift;
    my $file = shift // $self;
    system('psql', params);
}

=head1 Bagger Initialization for Tests

If we ever try to componentize this, the sections below here have to go.

=head2 init($file)

Sets up and runs file based on standard test boilerplate.

=head2 lw_setup()

Sets up the lenkwerk database parameters

=head2 db

Returns the name of the db setup class

In this case, 'Bagger::Storage::LenkwerkSetup'

=cut
use Bagger::Storage::LenkwerkSetup;
sub db { 'Bagger::Storage::LenkwerkSetup' };

sub lw_setup{

    skip_all('BAGGER_TEST_LW environment variable not set') unless defined
                                                        $ENV{BAGGER_TEST_LW};

    bail_out('BAGGER_TEST_LW_DB environment variable not set') unless defined
                                                       $ENV{BAGGER_TEST_LW_DB};


    db()->set_lenkwerkdb($ENV{BAGGER_TEST_LW_DB});
    db()->set_dbhost($ENV{BAGGER_TEST_LW_HOST}) if defined $ENV{BAGGER_TEST_LW_HOST};
    db()->set_dbport($ENV{BAGGER_TEST_LW_PORT}) if defined $ENV{BAGGER_TEST_LW_PORT};
    db()->set_dbuser($ENV{BAGGER_TEST_LW_USER}) if defined $ENV{BAGGER_TEST_LW_USER};
    __PACKAGE__->set_psql_params(
        (db()->dbuser ? (-U => db()->dbuser) : ()),
        (db()->dbhost ? (-h => db()->dbhost) : ()),
        (db()->dbport ? (-p => db()->dbport) : ()),
        (db()->lenkwerkdb ? (-d => db()->lenkwerkdb) : ()),
    );
}

sub init{
    my ($self, $file) = @_;
    lw_setup;
    __PACKAGE__->run($file);
}

lw_setup; # always just initialize it for these tests.

1;

