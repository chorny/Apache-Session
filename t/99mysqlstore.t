eval {require DBI; require DBD::mysql;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Store::MySQL;
use DBI;

use strict;

print "1..1\n";

my $foo = new Apache::Session::Store::MySQL;

if (ref $foo) {
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}

