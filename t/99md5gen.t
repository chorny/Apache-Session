eval {require Digest::MD5;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Generate::MD5;

print "1..36\n";

my $session = {};

Apache::Session::Generate::MD5::generate($session);

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

if ($session->{data}->{_session_id} =~ /^[0-9a-fA-F]{32}$/) {
    print "ok 3\n";
}
else {
    print "not ok 3\n";
}

my $old = $session->{data}->{_session_id};

Apache::Session::Generate::MD5::generate($session);

if ($old ne $session->{data}->{_session_id}) {
    print "ok 4\n";
}
else {
    print "not ok 4\n";
}

my $n = 5;
for (my $i = 1; $i <= 32; $i++) {
    $session->{args}->{IDLength} = $i;
    
    Apache::Session::Generate::MD5::generate($session);

    if ($session->{data}->{_session_id} =~ /^[0-9a-fA-F]{$i}$/) {
        print "ok $n\n";
    }
    else {
        print "not ok $n\n";
    }
    
    $n++;
}
