eval {require Fcntl;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Store::File;

my $mydir = int(rand(1000));
mkdir "./$mydir", 0777;
chdir $mydir;

print "1..6\n";

my $session = {serialized => '12345', data => {_session_id => 'test1'}};

$Apache::Session::Store::File::Directory = '.';

my $store = new Apache::Session::Store::File;

$store->insert($session);

if (-e "./test1") {
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}

undef $store;

open (TEST, '<./test1') || die $!;

my $foo;
while (<TEST>) {$foo .= $_};

if ($foo eq $session->{serialized} && $foo eq '12345') {
    print "ok 2\n";
}
else {
    print "not ok 2\n";
}

close TEST;

$store = new Apache::Session::Store::File;
$session->{serialized} = '';
$store->materialize($session);

if ($session->{serialized} eq '12345') {
    print "ok 3\n";
}
else {
    print "not ok 3\n";
}

$session->{serialized} = 'hi';
$store->update($session);
undef $store;

open (TEST, '<./test1') || die $!;

$foo = '';
while (<TEST>) {$foo .= $_};

if ($foo eq $session->{serialized} && $foo eq 'hi') {
    print "ok 4\n";
}
else {
    print "not ok 4\n";
}

close TEST;

$store = new Apache::Session::Store::File;
$store->remove($session);

if (-e "./test1") {
    print "not ok 5\n";
}
else {
    print "ok 5\n";
}

eval {
    $store->materialize($session);
};
if ($@) {
    print "ok 6\n";
}
else {
    print "not ok 6\n";
}

unlink "./test1";

chdir "..";
rmdir $mydir || die $!;
