use Apache::Session::Generate::ModUniqueId;

print "1..3\n";

$ENV{UNIQUE_ID} = '12345678790abcdef';

my $session = {};

Apache::Session::Generate::ModUniqueId::generate($session);

if (exists $session->{data}->{_session_id}) {
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}

if ((scalar keys %{$session->{data}}) == 1) {
    print "ok 2\n";
}
else {
    print "not ok 2\n";
}

if ($session->{data}->{_session_id} eq $ENV{UNIQUE_ID}) {
    print "ok 3\n";
}
else {
    print "not ok 3\n";
}
