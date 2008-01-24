use 5.003_07; #earliest version on CPAN
#Symbol.pm requires 5.002
use ExtUtils::MakeMaker;

print << 'EOT';

*** REQUEST ***
Please use Test::Reporter to report test results - it's the only way to measure
popularity of distribution.

If you use perl older than 5.6 - write to alexchorny[AT]gmail.com
and tell me what version do you use, and why.

EOT

WriteMakefile(
    NAME         => "Apache::Session",
    VERSION_FROM => "Session.pm",
    ($ExtUtils::MakeMaker::VERSION gt '6.30'? 
     ('LICENSE'		=> 'perl', ) : ()),
    PREREQ_PM    => {
                     'Test::More'      => '0.47',
                     'Test::Deep'      => '0.082',
                     'Test::Exception' => '0.15',
                     'File::Temp'      => 0, #core from 5.6.1
                     'Storable'        => '0.6', #Will be raised later
                     'constant'        => 0, #Available on CPAN now
#                     'MIME::Base64'    => 0, #new versions require 5.6
#                     'DB_File'         => 0, #test
#                     'Digest::MD5'     => 0, #new versions require 5.6
                    },
    AUTHOR          => 'Casey West <casey[at]geeknest.com>',
    ABSTRACT        => 'A persistence framework for session data',
);
