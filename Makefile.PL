use 5.002; #Symbol.pm
use ExtUtils::MakeMaker;

print << 'EOT';

*** REQUEST ***
Please use Test::Reporter to report test results - it's the only way to measure
popularity of distribution.

EOT

WriteMakefile(
    NAME         => "Apache::Session",
    VERSION_FROM => "Session.pm",
    ($ExtUtils::MakeMaker::VERSION ge '6.30_00'? 
     ('LICENSE'		=> 'perl', ) : ()),
    PREREQ_PM    => {
                     'Test::More'      => '0.47',
                     'Test::Deep'      => '0.082',
                     'Test::Exception' => '0.15',
                     'File::Temp'      => 0, #core from 5.6.1
                     'Storable'        => '0.6', #Will be raised later
                     'MIME::Base64'    => 0, #test
                     'DB_File'         => 0, #test
                    },
    AUTHOR          => 'Casey West <casey[at]geeknest.com>',
    ABSTRACT        => 'A persistence framework for session data',
);
