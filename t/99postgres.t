eval {require DBI; require DBD::Pg;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Postgres;

print "1..8\n";

my $s = {};

tie %$s, 'Apache::Session::Postgres', undef, {
    DataSource => 'dbi:Pg:dbname=sessions', 
    UserName => 'pg', 
    Password => 'pg',
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

tie %$s, 'Apache::Session::Postgres', $id, {
    DataSource => 'dbi:Pg:dbname=sessions', 
    UserName => 'pg', 
    Password => 'pg',
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

untie %$s;
undef $s;
$s = {};

my $dbh = DBI->connect('dbi:Pg:dbname=sessions', 'pg', 'pg', {RaiseError => 1, AutoCommit => 0});

tie %$s, 'Apache::Session::Postgres', $id, {Handle => $dbh, Commit => 0};

if (tied %$s) {
    print "ok 6\n";
}
else {
    print "not ok 6\n";
}

if ($s->{_session_id} eq $id) {
    print "ok 7\n";
}
else {
    print "not ok 7\n";
}

if ($s->{foo} eq 'bar' && $s->{baz}->[0] eq 'tom' && $s->{baz}->[2] eq 'harry'){
    print "ok 8\n";
}
else {
    print "not ok 8\n";
}

tied(%$s)->delete;

$dbh->commit;
$dbh->disconnect;
