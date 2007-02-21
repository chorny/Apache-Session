use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];

plan skip_all => "Optional module (Fcntl) not installed"
  unless eval {
               require Fcntl;
              };

#my $origdir = getcwd;
#my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
#chdir( $tempdir );

plan tests => 4;

my $package = 'Apache::Session::Lock::Null';
use_ok $package;

my $session = {};
my $lock = $package->new;

ok $lock->acquire_read_lock($s), 'got read';

ok $lock->acquire_write_lock($s), 'got write';

ok $lock->release_all_locks($s), 'released all';

undef $lock;

#chdir( $origdir );
