eval {require Storable;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Serialize::UUEncode;

print "1..1\n";

my $s = \&Apache::Session::Serialize::UUEncode::serialize;
my $u = \&Apache::Session::Serialize::UUEncode::unserialize;

my $session = {serialized => undef, data => undef};
my $simple  = {foo => 1, bar => 2, baz => 'quux', quux => ['foo', 'bar']};

$session->{data} = $simple;

&$s($session);

$session->{data} = undef;

&$u($session);

if ($session->{data}->{foo} == 1 &&
    $session->{data}->{bar} == 2 &&
    $session->{data}->{baz} eq 'quux' &&
    $session->{data}->{quux}->[0] eq 'foo' &&
    $session->{data}->{quux}->[1] eq 'bar') {
    
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}
