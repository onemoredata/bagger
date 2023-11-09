use strict;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Bagger',
    VERSION_FROM     => 'lib/Bagger/Storage/PGObject.pm',
    ABSTRACT         => 'Perl Tooling for Bagger',
    AUTHOR           => 'OneMoreData',
    MIN_PERL_VERSION => '5.14.0', # know it needs at least 5.10
    PREREQ_PM        => { # may add versions later
                          'Moose'                           => 0,
                          'PGObject'                        => 0,
                          'PGObject::Simple'                => 0,
                          'PGObject::Simple::Role'          => 0,
                          'PGObject::Util::DBMethod'        => 0,
                          'PGObject::Type::JSON'            => 2.1.1,
                          'PGObject::Type::DateTime'        => 0,
                          'URI::Escape'                     => 0,
                          'Capture::Tiny'                   => 0,
                          'Try::Tiny'                       => 0,
                          'Net::Etcd'                       => 0,
                          'Guard'                           => 0,
                          'AnyEvent::PgRecvlogical'         => 0,
                          'Config::IniFiles'                => 0,
                          'DBI'                             => 0,
                          'namespace::autoclean'            => 0,
                          'MIME::Base64'                    => 0,
                          'AnyEvent'                        => 0,
                          'Coro'                            => 0,
                          'Parse::RecDescent'               => 0,
                          'JSON'                            => 0,
                          # Mostly core dependencies shipping with Perl
                          'Coro::AnyEvent'                  => 0,
                          'AnyEvent::Loop'                  => 0,
                          'Carp'                            => 0,
                          'Data::Dumper'                    => 0,
                          'Exporter'                        => 0,
                          'Getopt::Long'                    => 0,
                          'JSON'                            => 0,
                          'List::MoreUtils'                 => 0,
                          'Moose::Role'                     => 0,
                          'Moose::Util::TypeConstraints'    => 0,
                          'Scalar::Util'                    => 0,
                          'autovivification'                => 0,
                          'constant'                        => 0,
                          'overload'                        => 0,
                          'parent'                          => 0,
                          'strict'                          => 0,
                          'warnings'                        => 0,
                         },
    TEST_REQUIRES    => {
                          'Test2::V0'                       => 0,
                          'File::Find'                      => 0,
                        },
);

sub MY::postamble {
return <<"MAKE_EOF";
.PHONY: lint
sql-lint:
\tsqlfluff lint

.PHONY: sql-fmt
sql-fmt:
\tsqlfluff format
MAKE_EOF
}

# vim:ts=4:sw=4:expandtab
