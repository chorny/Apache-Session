use ExtUtils::MakeMaker;


WriteMakefile(

  NAME => "Apache::Session",
  VERSION_FROM => "Session.pm",
  'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);
