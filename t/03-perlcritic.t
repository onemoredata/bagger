use 5.010;
use strict;
use warnings;
use Test2::V0;

use File::Find;
use List::MoreUtils 'uniq';
use Data::Dumper;
use Perl::Critic;

my $excluded_policies = [
    'RegularExpressions::RequireExtendedFormatting', # Too burdensome for small regexps
    'Modules::RequireEndWithOne', # does not play well with Moose
    'Documentation::RequirePodSections', # leaving some for main modules only
    'CodeLayout::RequireTrailingCommas', # does not play well with Moose syntax
    'ControlStructures::ProhibitPostfixControls', # Postfix controls are useful
    'Subroutines::RequireArgUnpacking', # We will manually check these
    'Modules::RequireVersionVar', #may want to later change this one
    'ValuesAndExpressions::ProhibitInterpolationOfLiterals', # too strict
    'Subroutines::ProhibitUnusedPrivateSubroutines', # does not play well with Moose
    'Documentation::RequirePodAtEnd', # we want to do the opposite
    'CodeLayout::RequireTidyCode', # does not allow POD at start
    'Subroutines::RequireFinalReturn', # To be manually enforced
    'ErrorHandling::RequireCarping', # to be manually evaluated
    'CodeLayout::ProhibitParensWithBuiltins', # often necessary for join and map
    'ValuesAndExpressions::ProhibitEmptyQuotes', # too many legit uses
    'ValuesAndExpressions::ProhibitNoisyQuotes', # too strict/false positives
    'References::ProhibitDoubleSigils', # better for simple cases
    'RegularExpressions::RequireDotMatchAnything', # false positivity rate
    'RegularExpressions::RequireLineBoundaryMatching', # too many legitmate uses
    'ValuesAndExpressions::ProhibitMagicNumbers', # problems for arg number detection
    'ValuesAndExpressions::RequireNumberSeparators', # better manual
    'Variables::ProhibitPunctuationVars', # We only use these where necessary
    'ValuesAndExpressions::ProhibitConstantPragma', # these have uses
    'RegularExpressions::ProhibitEscapedMetacharacters', # These are common
    'RegularExpressions::ProhibitUnusualDelimiters', # common uses
    'ValuesAndExpressions::ProhibitLongChainsOfMethodCalls', # useful
    'Miscellanea::ProhibitTies', # has a good interface for ConfigFiles
    'ControlStructures::ProhibitUnlessBlocks', # lexical closures
    'RegularExpressions::ProhibitUselessTopic', # unclear
    'BuiltinFunctions::ProhibitUselessTopic', #unclear
    'BuiltinFunctions::ProhibitStringySplit', # useful
    'BuiltinFunctions::ProhibitBooleanGrep', # useful
    ### Below here are ones to gradually remove as we can get things passing
    'CodeLayout::ProhibitTrailingWhitespace', # TODO
];

my $critic = Perl::Critic->new(-exclude => $excluded_policies, -severity => 1);
Perl::Critic::Violation::set_format( 'S%s %p %f: %l\n');

my @modules;

find(sub { push @modules, $File::Find::name }, 'lib');
for my $mod (grep { $_ =~ /\.pm$/} @modules){
    # Remove this and check after #94 is committed
    next if $mod eq 'lib/Bagger/Agent/Drivers/TestDecoding.pm';
    my @findings = $critic->critique($mod);
    is(scalar @findings, 0, "$mod is clean") or diag join "", @findings;
}

done_testing;

