use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];
use strict;
use Config;

plan skip_all => "Only for perl 5.8.0 or later"
  unless eval {
   require 5.8.0;
   #perl 5.6 don't like this test. See RT#16539.
  };
#use Module::Mask;my $mask = new Module::Mask ('Storable');
plan skip_all => "Optional modules (Fcntl, DB_File, Digest::MD5, Storable) not installed"
  unless eval {
               require Fcntl;
               require DB_File;
               require Digest::MD5;
               require Storable;
              };

plan tests => 12;

my $package = 'Apache::Session::Flex';
use_ok $package;

#$Apache::Session::Lock::File::LockDirectory=$tempdir;
my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
my $origdir = getcwd;
chdir( $tempdir );

{
    my $session = tie my %session, $package, undef, {
        Store     => 'File',
        Lock      => 'File',
        Generate  => 'MD5',
        Serialize => 'Storable',
#        Directory     => $tempdir,
#        LockDirectory => $tempdir,
    };
    isa_ok $session->{object_store}, 'Apache::Session::Store::File';
    isa_ok $session->{lock_manager}, 'Apache::Session::Lock::File';
    is ref($session->{generate}),    'CODE', 'generate is CODE';
    is ref($session->{serialize}),   'CODE', 'serialize is CODE';
    is ref($session->{unserialize}), 'CODE', 'unserialize is CODE';
}

SKIP: { #Flex that uses IPC
    skip "semget not implemented",5 unless $Config{d_semget};
    skip "Cygserver is not running",5 
     if $^O eq 'cygwin' && (!exists $ENV{'CYGWIN'} || $ENV{'CYGWIN'} !~ /server/i);
    skip "NetBSD does not like anonymous semaphores",5 
     if $^O =~ /netbsd/i;
    skip "Optional modules (IPC::Semaphore, IPC::SysV, MIME::Base64) not installed",5
     unless eval {
               require IPC::Semaphore;
               require IPC::SysV;
               require MIME::Base64;
              };

    require Apache::Session::Lock::Semaphore;
    $Apache::Session::Lock::Semaphore::sem_key=undef;
    $Apache::Session::Lock::Semaphore::sem_key=$Apache::Session::Lock::Semaphore::sem_key;
    my $session = tie my %session, $package, undef, {
        Store     => 'DB_File',
        Lock      => 'Semaphore',
        Generate  => 'MD5',
        Serialize => 'Base64',
#        SemaphoreKey => undef,
#        SemaphoreKey => 31817,
    }; #Apache::Session::save in TIEHASH does acquire_write_lock

    isa_ok $session->{object_store}, 'Apache::Session::Store::DB_File';
    isa_ok $session->{lock_manager}, 'Apache::Session::Lock::Semaphore';
    is ref($session->{generate}),    'CODE', 'generate is CODE';
    is ref($session->{serialize}),   'CODE', 'serialize is CODE';
    is ref($session->{unserialize}), 'CODE', 'unserialize is CODE';
}

{
    {
        package Apache::Session::Store::Test;
        use base 'Apache::Session::Store::File';
    }

    {
        package Apache::Session::Lock::Test;
        use base 'Apache::Session::Lock::File';
    }

    {
        package Apache::Session::Generate::Test;

        # This wack double assignment prevents "... used only once"
        # warnings.
        *Apache::Session::Generate::Test::generate =
        *Apache::Session::Generate::Test::generate =
            \&Apache::Session::Generate::MD5::generate;
        *Apache::Session::Generate::Test::validate =
        *Apache::Session::Generate::Test::validate =
            \&Apache::Session::Generate::MD5::validate;
    }

    {
        package Apache::Session::Serialize::Test;

        *Apache::Session::Serialize::Test::serialize =
        *Apache::Session::Serialize::Test::serialize =
            \&Apache::Session::Serialize::Storable::serialize;
        *Apache::Session::Serialize::Test::unserialize =
        *Apache::Session::Serialize::Test::unserialize =
            \&Apache::Session::Serialize::Storable::unserialize;
    }

    my $session = tie my %session, $package, undef, {
        Store     => 'Test',
        Lock      => 'Test',
        Generate  => 'Test',
        Serialize => 'Test',
    };
    isa_ok $session->{object_store}, 'Apache::Session::Store::Test';
}

chdir( $origdir );
