eval {require DB_File};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Store::DB_File;
use DB_File;

my $mydir = int(rand(1000));
mkdir "./$mydir", 0777;
chdir $mydir;

print "1..4\n";

my $session = {serialized => '12345', data => {_session_id => 'test1'}, args => {FileName => 'foo.dbm'}};

my $store = new Apache::Session::Store::DB_File;

$store->insert($session);

if (-e "./foo.dbm") {
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}

undef $store;

$store = new Apache::Session::Store::DB_File;
$session->{serialized} = '';
$store->materialize($session);

if ($session->{serialized} eq '12345') {
    print "ok 2\n";
}
else {
    print "not ok 2\n";
}

$session->{serialized} = 'hi';
$store->update($session);
undef $store;

my %hash;
tie %hash, 'DB_File', './foo.dbm';
if ($hash{test1} eq 'hi') {
    print "ok 3\n";
}
else {
    print "not ok 3\n";
}

$store = new Apache::Session::Store::DB_File;
$store->remove($session);

eval {
    $store->materialize($session);
};
if ($@) {
    print "ok 4\n";
}
else {
    print "not ok 4\n";
}

undef $store;

unlink "./foo.dbm";

chdir "..";
rmdir $mydir || die $!;
