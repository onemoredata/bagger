use 5.010;
use strict;
use warnings;
use Test2::V0;

use File::Find;
use List::MoreUtils 'uniq';

my @modules;

sub fname_to_module {
    my ($fname) = shift;
    $fname =~ s#^lib/##;
    $fname =~ s#/#::#g;
}

find(sub { push @modules, $File::Find::name }, 'lib');

@modules =
           map  { fname_to_module($_) }
	   grep { $_ =~ /\.pm$/} @modules;
ok eval("require $_"), $@ for @modules;

done_testing;

