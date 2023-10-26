use 5.010;
use strict;
use warnings;
use Test2::V0;
$ENV{BAGGER_TEST_LW} = 1;
$ENV{BAGGER_TEST_LW_PORT} = 12344;
$ENV{BAGGER_TEST_LW_DB} = 'gj345234jfk';

use File::Find;
use List::MoreUtils 'uniq';

my @modules;

sub fname_to_module {
    my ($fname) = shift;
    $fname =~ s#^lib/##;
    $fname =~ s#.pm$##;
    $fname =~ s#/#::#g;
    return $fname;
}

find(sub { push @modules, $File::Find::name }, 'lib');

#ok(require $_) or diag $@ for @modules;

#@modules =
ok(eval("require $_"), "Loading $_") or diag $@ for # @modules;
           map  { fname_to_module($_) }
	   grep { $_ =~ /\.pm$/} @modules;

done_testing;

