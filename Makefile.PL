use ExtUtils::MakeMaker;


WriteMakefile(

  NAME => "Apache::Session",
  VERSION_FROM => "Session.pm",
  PREREQ_PM => { MD5 => 0, Storable => 0 },
  'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);
