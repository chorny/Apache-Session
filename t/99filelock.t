eval {require Fcntl;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Lock::File;

print "1..3\n";

my $dir = int(rand(1000));
mkdir $dir, 0700;
chdir $dir;

my $l = new Apache::Session::Lock::File;
my $s = {data => {_session_id => 'foo'}, args => {LockDirectory => '.'}};

$l->acquire_read_lock($s);

if (-e './Apache-Session-foo.lock') {
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}

undef $l;

unlink('./Apache-Session-foo.lock');

$l = new Apache::Session::Lock::File;

$l->acquire_write_lock($s);

if (-e './Apache-Session-foo.lock') {
    print "ok 2\n";
}
else {
    print "not ok 2\n";
}

$l->release_all_locks($s);


$l->clean('.', 0);

if (!-e './Apache-Session-foo.lock') {
    print "ok 3\n";
}
else {
    print "not ok 3\n";
}

chdir '..';
rmdir $dir;
