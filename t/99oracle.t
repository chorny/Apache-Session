eval {require DBI; require DBD::Oracle;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Oracle;

print "1..10\n";

my $s = {};

tie %$s, 'Apache::Session::Oracle', undef, {
    DataSource => "dbi:Oracle:$ENV{ORACLE_SID}", 
    UserName => $ENV{AS_ORACLE_USER}, 
    Password => $ENV{AS_ORACLE_PASS},
    Commit   => 1
};

if (tied %$s) {
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}

if (exists $s->{_session_id}) {
    print "ok 2\n";
}
else {
    print "not ok 2\n";
}

my $id = $s->{_session_id};

$s->{foo} = 'bar';
$s->{baz} = ['tom', 'dick', 'harry'];

untie %$s;
undef $s;
$s = {};

tie %$s, 'Apache::Session::Oracle', $id, {
    DataSource => "dbi:Oracle:$ENV{ORACLE_SID}", 
    UserName => $ENV{AS_ORACLE_USER}, 
    Password => $ENV{AS_ORACLE_PASS},
    Commit   => 1
};

if (tied %$s) {
    print "ok 3\n";
}
else {
    print "not ok 3\n";
}

if ($s->{_session_id} eq $id) {
    print "ok 4\n";
}
else {
    print "not ok 4\n";
}

if ($s->{foo} eq 'bar' && $s->{baz}->[0] eq 'tom' && $s->{baz}->[2] eq 'harry'){
    print "ok 5\n";
}
else {
    print "not ok 5\n";
}

$s->{long} = 'A'x(10*2**10);

untie %$s;
undef $s;
$s = {};

my $dbh = DBI->connect("dbi:Oracle:$ENV{ORACLE_SID}", $ENV{AS_ORACLE_USER}, $ENV{AS_ORACLE_PASS}, {RaiseError => 1, AutoCommit => 0});

tie %$s, 'Apache::Session::Oracle', $id, {Handle => $dbh, Commit => 0, LongReadLen => 20*2**10};

if (tied %$s) {
    print "ok 6\n";
}
else {
    print "not ok 6\n";
}

if ($s->{long} eq 'A'x(10*2**10)) {
    print "ok 7\n";
}
else {
    print "not ok 7\n";
}

delete $s->{long};

untie %$s;
undef $s;
$s = {};

tie %$s, 'Apache::Session::Oracle', $id, {Handle => $dbh, Commit => 0};

if (tied %$s) {
    print "ok 8\n";
}
else {
    print "not ok 8\n";
}

if ($s->{_session_id} eq $id) {
    print "ok 9\n";
}
else {
    print "not ok 9\n";
}

if ($s->{foo} eq 'bar' && $s->{baz}->[0] eq 'tom' && $s->{baz}->[2] eq 'harry'){
    print "ok 10\n";
}
else {
    print "not ok 10\n";
}

$dbh->commit;
$dbh->disconnect;
