eval {
  local $SIG{__DIE__};
  require IPC::Shareable;
  require;
};

if ($@) { 
  print "1..0\n";
  exit 0;
}

print "1..1\n";

require Apache::Session::IPC;
print "ok 1\n";

exit 0;
