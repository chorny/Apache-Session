use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];

plan skip_all => "Optional modules (DBD::mysql, DBI) not installed"
  unless eval {
               require DBI;
               require DBD::mysql;
              };
plan skip_all => "Not running RDBM tests without APACHE_SESSION_MAINTAINER=1"
  unless $ENV{APACHE_SESSION_MAINTAINER};

my $origdir = getcwd;
my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
chdir( $tempdir );

plan tests => 13;

my $package = 'Apache::Session::MySQL';
use_ok $package;

my $session = {};

tie %{$session}, $package, undef, {
    DataSource     => 'dbi:mysql:sessions', 
    UserName       => 'test', 
    Password       => '',
    LockDataSource => 'dbi:mysql:sessions',
    LockUserName   => 'test',
    LockPassword   => ''
};

ok tied(%{$session}), 'session tied';

ok exists($session->{_session_id}), 'session id exists';

my $id = $session->{_session_id};

my $foo = $session->{foo} = 'bar';
my $baz = $session->{baz} = ['tom', 'dick', 'harry'];

untie %{$session};
undef $session;
$session = {};

tie %{$session}, $package, $id, {
    DataSource     => 'dbi:mysql:sessions', 
    UserName       => 'test', 
    Password       => '',
    LockDataSource => 'dbi:mysql:sessions',
    LockUserName   => 'test',
    LockPassword   => ''
};

ok tied(%{$session}), 'session tied';

is $session->{_session_id}, $id, 'id retrieved matches one stored';

cmp_deeply $session->{foo}, $foo, "Foo matches";
cmp_deeply $session->{baz}, $baz, "Baz matches";

untie %{$session};
undef $session;
$session = {};

tie %{$session}, $package, undef, {
    DataSource     => 'dbi:mysql:sessions', 
    UserName       => 'test', 
    Password       => '',
    TableName      => 's',
    LockDataSource => 'dbi:mysql:sessions',
    LockUserName   => 'test',
    LockPassword   => ''
};

ok tied(%{$session}), 'session tied';

ok exists($session->{_session_id}), 'session id exists';

untie %{$session};
undef $session;
$session = {};

my $dbh = DBI->connect('dbi:mysql:sessions', 'test', '', {RaiseError => 1});

tie %{$session}, $package, $id, {
    Handle     => $dbh,
    LockHandle => $dbh,
};

ok tied(%{$session}), 'session tied';

is $session->{_session_id}, $id, 'id retrieved matches one stored';

cmp_deeply $session->{foo}, $foo, "Foo matches";
cmp_deeply $session->{baz}, $baz, "Baz matches";

tied(%{$session})->delete;
untie %{$session};
$dbh->disconnect;

chdir( $origdir );
