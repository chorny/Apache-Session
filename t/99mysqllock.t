eval {require DBI; require DBD::mysql;};
if ($@ || !$ENV{APACHE_SESSION_MAINTAINER}) {
    print "1..0\n";
    exit;
}

use Apache::Session::Lock::MySQL;
use DBI;

print "1..3\n";

my $s = {
    args => {
        LockDataSource => 'dbi:mysql:test',
        LockUserName   => 'test',
        LockPassword   => ''
    },
    data => {
        _session_id => '09876543210987654321098765432109',
    }
};

my $l = new Apache::Session::Lock::MySQL;
my $dbh = DBI->connect('dbi:mysql:test', 'test', '', {RaiseError => 1});
my $sth = $dbh->prepare(q{SELECT GET_LOCK('Apache-Session-09876543210987654321098765432109', 0)});
my $sth2 = $dbh->prepare(q{SELECT RELEASE_LOCK('Apache-Session-09876543210987654321098765432109')});

$l->acquire_write_lock($s);

$sth->execute();
my @array = $sth->fetchrow_array;

if ($array[0] == 0) {
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}

$l->release_write_lock($s);

$sth->execute();
@array = $sth->fetchrow_array;

if ($array[0] == 1) {
    print "ok 2\n";
}
else {
    print "not ok 2\n";
}

$sth2->execute;

undef $l;

$s->{args}->{LockHandle} = $dbh;

$l = new Apache::Session::Lock::MySQL;

$l->acquire_read_lock($s);

$sth->execute();
@array = $sth->fetchrow_array;

if ($array[0] == 1) {
    print "ok 3\n";
}
else {
    print "not ok 3\n";
}

$sth->finish;
$sth2->finish;
$dbh->disconnect;
