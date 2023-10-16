use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Bagger',
    VERSION_FROM     => 'lib/Bagger/Storage/PGObject.pm',
    ABSTRACT         => 'Perl Tooling for Bagger',
    AUTHOR           => 'OneMoreData',
    MIN_PERL_VERSION => '5.14.0', # know it needs at least 5.10
    PREREQ_PM        => { # may add versions later
                          'Moose'                    => 0,
                          'PGObject'                 => 0,
                          'PGObject::Simple'         => 0,
                          'PGObject::Simple::Role'   => 0,
                          'PGObject::Util::DBMethod' => 0,
			  'PGObject::Type::JSON'     => 2.0.3,
                         },
    TEST_REQUIRES    => {
                          'Test2::V0'                => 0,
                          'File::Find'               => 0,
                        },
);

# vim:ts=4:sw=4:expandtab
