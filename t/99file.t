eval {require Fcntl;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::File;

my $mydir = int(rand(1000));
mkdir "./$mydir", 0777;
chdir $mydir;

print "1..5\n";

my $s = {};

tie %$s, 'Apache::Session::File', undef, {
    Directory     => '.',
    LockDirectory => '.'
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

tie %$s, 'Apache::Session::File', $id, {
    Directory     => '.',
    LockDirectory => '.'
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

tied(%$s)->delete;


unlink "./Apache-Session-$id.lock" || die $!;
chdir "..";
rmdir $mydir || die $!;

