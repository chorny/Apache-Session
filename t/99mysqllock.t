use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];

plan skip_all => "Not running RDBM tests without APACHE_SESSION_MAINTAINER=1"
  unless $ENV{APACHE_SESSION_MAINTAINER};
plan skip_all => "Optional modules (DBD::mysql, DBI) not installed"
  unless eval {
               require DBI;
               require DBD::mysql;
              };

plan tests => 4;

my $package = 'Apache::Session::Lock::MySQL';
use_ok $package;

#my $origdir = getcwd;
#my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
#chdir( $tempdir );

my $session = {
    args => {
        LockDataSource => 'dbi:mysql:test',
        LockUserName   => 'test',
        LockPassword   => ''
    },
    data => {
        _session_id => '09876543210987654321098765432109',
    }
};

my $lock = $package->new;
my $dbh  = DBI->connect('dbi:mysql:test', 'test', '', {RaiseError => 1});
my $sth  = $dbh->prepare(q{SELECT GET_LOCK('Apache-Session-09876543210987654321098765432109', 0)});
my $sth2 = $dbh->prepare(q{SELECT RELEASE_LOCK('Apache-Session-09876543210987654321098765432109')});

$lock->acquire_write_lock($session);

$sth->execute();
is +($sth->fetchrow_array)[0], 0, 'could not get lock';

$lock->release_write_lock($session);

$sth->execute();
is +($sth->fetchrow_array)[0], 1, 'could get lock';

$sth2->execute;
undef $lock;

$session->{args}->{LockHandle} = $dbh;

$lock = $package->new;

$lock->acquire_read_lock($session);

$sth->execute();
$sth->execute();
is +($sth->fetchrow_array)[0], 1, 'could get lock';

undef $lock;

$sth->finish;
$sth2->finish;
$dbh->disconnect;

#chdir( $origdir );
