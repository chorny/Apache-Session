use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];

plan skip_all => "Optional modules (Fcntl, DB_File, IPC::Semaphore, IPC::SysV) not installed: $@"
  unless eval {
               require Fcntl;
               require DB_File;
               require IPC::Semaphore;
               require IPC::SysV;
              };

my $origdir = getcwd;
my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
chdir( $tempdir );

plan tests => 11;

my $package = 'Apache::Session::Flex';
use_ok $package;

{
    my $session = tie my %session, $package, undef, {
        Store     => 'File',
        Lock      => 'File',
        Generate  => 'MD5',
        Serialize => 'Storable',
    };
    isa_ok $session->{object_store}, 'Apache::Session::Store::File';
    isa_ok $session->{lock_manager}, 'Apache::Session::Lock::File';
    is ref($session->{generate}),    'CODE', 'generate is CODE';
    is ref($session->{serialize}),   'CODE', 'serialize is CODE';
    is ref($session->{unserialize}), 'CODE', 'unserialize is CODE';
}

{
    my $session = tie my %session, $package, undef, {
        Store     => 'DB_File',
        Lock      => 'Semaphore',
        Generate  => 'MD5',
        Serialize => 'Base64',
    };
    isa_ok $session->{object_store}, 'Apache::Session::Store::DB_File';
    isa_ok $session->{lock_manager}, 'Apache::Session::Lock::Semaphore';
    is ref($session->{generate}),    'CODE', 'generate is CODE';
    is ref($session->{serialize}),   'CODE', 'serialize is CODE';
    is ref($session->{unserialize}), 'CODE', 'unserialize is CODE';
}

chdir( $origdir );
