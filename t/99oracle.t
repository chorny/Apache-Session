use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];

plan skip_all => "Optional modules (DBD::Oracle, DBI) not installed"
  unless eval {
               require DBI;
               require DBD::Oracle;
              };
plan skip_all => "Not running RDBM tests without APACHE_SESSION_MAINTAINER=1"
  unless $ENV{APACHE_SESSION_MAINTAINER};

my $origdir = getcwd;
my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
chdir( $tempdir );

plan tests => 13;

my $package = 'Apache::Session::Oracle';
use_ok $package;

my $session = {};

tie %{$session}, $package, undef, {
    DataSource => "dbi:Oracle:$ENV{ORACLE_SID}", 
    UserName => $ENV{AS_ORACLE_USER}, 
    Password => $ENV{AS_ORACLE_PASS},
    Commit   => 1
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
    DataSource => "dbi:Oracle:$ENV{ORACLE_SID}", 
    UserName => $ENV{AS_ORACLE_USER}, 
    Password => $ENV{AS_ORACLE_PASS},
    Commit   => 1
};

ok tied(%{$session}), 'session tied';

is $session->{_session_id}, $id, 'id retrieved matches one stored';

cmp_deeply $session->{foo}, $foo, "Foo matches";
cmp_deeply $session->{baz}, $baz, "Baz matches";

$session->{long} = 'A'x(10*2**10);

untie %{$session};
undef $session;
$session = {};

my $dbh = DBI->connect("dbi:Oracle:$ENV{ORACLE_SID}", $ENV{AS_ORACLE_USER}, $ENV{AS_ORACLE_PASS}, {RaiseError => 1, AutoCommit => 0});

tie %{$session}, $package, $id, {
    Handle      => $dbh,
    Commit      => 0,
    LongReadLen => 20*2**10,
};

ok tied(%{$session}), 'session tied';

is $session->{long}, 'A'x(10*2**10), 'long read worked';

delete $session->{long};

untie %{$session};
undef $session;
$session = {};

tie %{$session}, $package, $id, {
    Handle => $dbh,
    Commit => 0,
};

ok tied(%{$session}), 'session tied';

is $session->{_session_id}, $id, 'id retrieved matches one stored';

cmp_deeply $session->{foo}, $foo, "Foo matches";
cmp_deeply $session->{baz}, $baz, "Baz matches";

tied(%{$session})->delete;
untie %{$session};

$dbh->commit;
$dbh->disconnect;

chdir( $origdir );
