use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];

plan skip_all => "Optional modules (DBD::Pg, DBI) not installed"
  unless eval {
               require DBI;
               require DBD::Pg;
              };
plan skip_all => "Not running RDBM tests without APACHE_SESSION_MAINTAINER=1"
  unless $ENV{APACHE_SESSION_MAINTAINER};

my $origdir = getcwd;
my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
chdir( $tempdir );

plan tests => 13;

my $package = 'Apache::Session::Postgres';
use_ok $package;

my $session = {};

my ($dbname, $user, $pass) = ('sessions', 'postgres', '');

tie %{$session}, $package, undef, {
    DataSource => "dbi:Pg:dbname=$dbname",
    UserName   => $user, 
    Password   => $pass,
    Commit     => 1
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
    DataSource => "dbi:Pg:dbname=$dbname",
    UserName   => $user, 
    Password   => $pass,
    Commit   => 1
};

ok tied(%{$session}), 'session tied';

is $session->{_session_id}, $id, 'id retrieved matches one stored';

cmp_deeply $session->{foo}, $foo, "Foo matches";
cmp_deeply $session->{baz}, $baz, "Baz matches";

untie %{$session};
undef $session;
$session = {};

tie %{$session}, $package, undef, {
    DataSource => "dbi:Pg:dbname=$dbname",
    UserName   => $user, 
    Password   => $pass,
    Commit   => 1,
    TableName => 's'
};

ok tied(%{$session}), 'session tied';

ok exists($session->{_session_id}), 'session id exists';

untie %{$session};
undef $session;
$session = {};

my $dbh = DBI->connect("dbi:Pg:dbname=$dbname", $user, $pass, {RaiseError => 1, AutoCommit => 0});

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
