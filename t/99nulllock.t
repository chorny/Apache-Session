use Apache::Session::Lock::Null;

print "1..4\n";

my $s = {};
my $l = new Apache::Session::Lock::Null;

$l->acquire_read_lock($s);

print "ok 1\n";

$l->acquire_write_lock($s);

print "ok 2\n";

$l->release_all_locks($s);

print "ok 3\n";

undef $l;

print "ok 4\n";

