# Coding Conventions for the this project

This documnet highlights the general coding conventions discussed here for
this project.  Conventions are there to help us work together and produce
software which is easy to read and reason about and which displays with
reasonable similarity in ach of our environments.

This document discusses each language or file type in its own section.

## Perl

### POD
Perl files should include proper Plain Old Documentation (POD)-formatted
documentation for the module, public functions etc.  The documentation should
be as comprehensive as possible and discuss what users of the API (including
within this project) can rely on.  The documentation should be clear and
descriptive.

The Perl code should be intermingled with the POD so that the code is as close
as possible to the documentation discussing its uses.

Comments on the other hand are for implementation detail discourse.  If a
user of an API needs to know the detail, it belongs in POD.  If not, it belongs
in a comment.

For example:

```
=head2 write_config

This function writes the config file at a location specified by -g or
--genconfig and exits.  Note that you can specify -c for a config file in and
overwrite other arguments on the command line.

=cut

# Note we use the tied hash API for Config::IniFiles here which means we don't
# get autovivification and some other goodies. 

sub write_config {
    ...
}

```

### Formatting and Bracing
We cuddle braces and indent blocks by 4 spaces.  Some editors will indent with
tabs, and this must be avoided.  Tests are added to prevent this from going
undetected.

Continuation lines are indented at the discretion of the developer but must be
easily identified as such.

When creating extended hashes and hashrefs, the fat commas should be lined up so
that the hash table can be read as a table.  This can be done with multiple
columns if appropriate.  List-returning functions added at the end do not have
to follow this pattern.

Lines are set to a maximum of 80 characters long by best effort. Longer lines
should be broken up if practical to do so.  This is partly due to character
terminal window sizes, but more often because shorter lines are more easily
readable.

Examples:

```
sub process_options {
    GetOptions(
        'host|h=s'  => \$host,  'username|u' => \$username,
        'port|p=i"  => \$port,  'database|d' => \$database,
        get_even_more_options() # get from submodule
    );
    if (defined $host) {
        set_host($host);
    } else {
        my $host = get_host();
    }
    die 'No host found' unless defined $host;
}
```

### use strict and use warnings
These should always be enabled on all modules and scripts.  In the rare cases
that some checks must be turned off, this should be done for as  small a space
as possible.  It is acceptable to put a couple statements in a closure while
disabling a relevant check.

### Functions and Explicit Returns
Oneliner functions may use implicit returns.  Complex functions should return
explicitly.  This avoids misreading what the function doess.

Examples:
```
sub get_hostname { $hostname } # ok

# Here we need an explicit return since it isn't obvious what the return value
# is.
sub build_dsn {
    my $self = shift;
    ...
    return $dsn;
}
```

### Open questions

Should we use prototypes?

## Makefiles

Makefiles treat tabs as semantically significant and therefore tabs are
accepted for these files
