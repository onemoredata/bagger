=head1 NAME

   Bagger::Type::DateTime::Infinite -- Infinity Handling for DB Datetimes

=head1 SYNOPSIS

   Bagger provides subclasses for the infinite datetimes

   Bagger::Type::DateTime::Infinite::Future -- Infinite timestamp in the future
   Bagger::Type::DateTime::Infinite::Past -- Infinite timestamp in the past.

   These are simple subclasses of Bagger::Type::DateTime and the infinite
   subclass  from the relevant subclasses in DateTime::Infinite.

=cut

package Bagger::Type::DateTime::Infinite;
use parent 'Bagger::Type::DateTime', 'DateTime::Infinite';

# nothing to do but this makes sure everything is loaded and ready to go.
=head1 DB SERIALIZATION

   These types serialize to:

   infinity for Bagger::Type::DateTime::Infinite::Future and
   -infinity for Bagger::Type::DateTime::Infinite::past

=head2 to_db

   This is the default database serialization.

=cut

package Bagger::Type::DateTime::Infinite::Future;
use parent -norequire, qw(DateTime::Infinite::Future Bagger::Type::DateTime);

sub new {
    my $class = shift;
    my $val = DateTime::Infinite::Future->new;
    bless $val, ($class // __PACKAGE__);
}

sub to_db { 'infinity' }

package Bagger::Type::DateTime::Infinite::Past;
use parent -norequire, qw(DateTime::Infinite::Past Bagger::Type::DateTime);

sub new {
    my $class = shift;
    my $val = DateTime::Infinite::Past->new;
    bless $val, ($class // __PACKAGE__);
}

sub to_db { '-infinity' }

1;
