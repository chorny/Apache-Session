use ExtUtils::MakeMaker;


print<<__EOS__;

################################################
# 
# This package contains a superclass, and three
# derived storage classes.  To use these storage
# classes, you must meet some or all of the 
# following requirements:
#
# Apache::Session - MD5
#                 - Carp
#                 - Tie::Hash
#
# Apache::Session::File - Storable
# 
# Apache::Session::Win32 - A Win32 OS
#                        
# Apache::Session::IPC - IPC::Shareable
#
# Apache::Session::DBI - DBI
#                        FreezeThaw
#
################################################

__EOS__

WriteMakefile(

  NAME => "Apache::Session",
  VERSION_FROM => "Session.pm",
  PREREQ_PM => { Apache => 0, MD5 => 0, Tie::Hash => 0 },
  'dist' => { COMPRESS=>"gzip", SUFFIX=>"gz" }
);
