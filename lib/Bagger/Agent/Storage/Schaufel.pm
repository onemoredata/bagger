=head1 NAME

    Bagger::Agent::Storage::Schaufel -- Schaufel Control Routines for Bagger

=cut

package Bagger::Agent::Storage::Schaufel;

=head1 SYNOPSIS

    my $schaufel = Bagger::Agent::Storage::Schaufel->new(
        cmd     => $schaufel_cmd, log     => $schaufel_log, 
        hosts   => @instances,    broker  => $kafka_broker,
        topic   => $kafka_topic,  group   => $kafka_consumer_group,
        threads => $schaufel_threads,
    );
    $schaufel->start;
    $schaufel->stop; # returns exit code and self-destructs

    # to stop with a specific signal (default is TERM):
    $schaufel->stop('INT');

=cut

use strict;
use warnings;
use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

=head1 DESCRIPTION

This module provides the general control functionalty for Schaufel for loading
data into Bagger.

A Schaufel object here represents a single Schaufel process from the preloading
through termination.  Once the process is terminated, the object is destroyed.

=head1 ATTRIBUTES

=head2 cmd Str

This is the command used to run Schaufel.  It defaults to C</usr/bin/schaufel>

=cut

has cmd => (is => 'ro', isa => 'Str', default => '/usr/bin/schaufel');

=head2 log Str

This is the log file where the Schaufel process should log.

It defaults to C</var/log/schaufel/bagger.log>.

=cut

has log => (is => 'ro', isa => 'Str', default => '/var/log/schaufel/bagger.log');

=head2 hosts ArrayRef[Bagger::Storage::Instance], Required

This is an ARRAYREF of two Bagger::Storage::Instance types, though this may
change in future versions to be more accommodating for different replication
factors etc.

=cut

has hosts => (is => 'ro', isa => 'ArrayRef[Bagger::Storage::Instance]', required => 1);

=head2 broker Str, required

This is the location of the Kafka broker

=cut

has broker => (is => 'ro', isa => 'Str', required => 1);

=head2 topic Str, required

This is the name of the Kafka topic

=cut

has topic => (is => 'ro', isa => 'Str', required => 1);

=head2 group Str, required

This is the ID of the kafka consumer grou.

=cut

has group => (is => 'ro', isa => 'Str', required => 1);

=head2 threads, Int, default 1

This is the number of threads to use for loading data.  Defaults to 1

=cut

has threads => (is => 'ro', isa => 'Int', default => 1);

=head2 args (generated)

These are the arguments to be passed to Schaufel

=cut

sub _build_args {
    my $self = shift;
    # Host_string is a comma separated list of host:port identifiers
    
    my $host_string = join ',',
                       map { join(':', $_->host, $_->port) }
                      @{$self->hosts};
    # False positive for perl critic
    ## no critic qw(InputOutput::ProhibitInteractiveTest)
    my @schaufel_args = (
        -l => $self->log,     -i => 'k',          -b => $self->broker,
        -g => $self->group,   -o => 'p',          -t => $self->topic,
        -p => $self->threads, -H => $host_string,
    );
    ## use critic
    return \@schaufel_args;
}



has args => (is   => 'ro', isa      => 'ArrayRef[Str]', 
             lazy => 1,     builder => '_build_args');

=head2 pid (set on start)

This is the process id of the actual schaufel child process.  It represents
a handle for signals intended to cause the process to terminate or to watch
for its termination.

A value of 0 means the process has been stopped.

=cut

has pid => (is => 'ro', isa => 'Int', writer => '_set_pid');

=head1 METHODS

=head1 start

This starts the schaufel process and returns $self->pid.

=cut

sub start {
    my ($self) = @_;
    my $pid = fork;

    # if parent process set the pid and return
    if ($pid) {
        $self->_set_pid($pid);
        return $pid;
    }

    exec($self->cmd, @{$self->args}); # safe since we always have more than one
    exit; # just to tell Perl we know we will exit after
}

=head1 stop($sig),

Stops the process.  The status is intended to be handled by the listener.

$sig, the signal to use, is optional and defaults to TERM.

=cut

sub stop {
    my ($self, $sig) = @_;
    $sig //= 'TERM';
    kill $sig, $self->pid;
    $self->_set_pid(0);
}

__PACKAGE__->meta->make_immutable;
