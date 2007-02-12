use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "Apache::Session",
    VERSION_FROM => "Session.pm",
    ($ExtUtils::MakeMaker::VERSION ge '6.30_00'? 
     ('LICENSE'		=> 'perl', ) : ()),
    PREREQ_PM    => {
                     'Test::More'      => '0.47',
                     'Test::Deep'      => '0.082',
                     'Test::Exception' => '0.15',
                    },
    AUTHOR          => 'Casey West <casey[at]geeknest.com>',
    ABSTRACT        => 'A persistence framework for session data',
);
