use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "Apache::Session",
    VERSION_FROM => "Session.pm",
    PREREQ_PM    => {
                     'Test::More'      => '0.47',
                     'Test::Deep'      => '0.082',
                     'Test::Exception' => '0.15',
                    },
);
