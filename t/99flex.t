eval {require Fcntl; require DB_File; require IPC::Semaphore; require IPC::SysV;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Flex;

print "1..2\n";

my (%s, $s);

$s = tie %s, 'Apache::Session::Flex', undef, {Store => 'File', Lock => 'File', Generate => 'MD5', Serialize => 'Storable'};

if (ref($s->{object_store}) =~ /Apache::Session::Store::File/ &&
    ref($s->{lock_manager}) =~ /Apache::Session::Lock::File/ &&
    ref($s->{generate}) eq 'CODE' &&
    ref($s->{serialize}) eq 'CODE' &&
    ref($s->{unserialize}) eq 'CODE') {
    print "ok 1\n";
}
else {
    print "not ok 1\n";
}

undef $s;
untie %s;

$s = tie %s, 'Apache::Session::Flex', undef, {Store => 'DB_File', Lock => 'Semaphore', Generate => 'MD5', Serialize => 'Base64'};

if (ref($s->{object_store}) =~ /Apache::Session::Store::DB_File/ &&
    ref($s->{lock_manager}) =~ /Apache::Session::Lock::Semaphore/ &&
    ref($s->{generate}) eq 'CODE' &&
    ref($s->{serialize}) eq 'CODE' &&
    ref($s->{unserialize}) eq 'CODE') {
    print "ok 2\n";
}
else {
    print "not ok 2\n";
}
