eval {require IPC::SysV; require IPC::Semaphore;};
if ($@) {
    print "1..0\n";
    exit;
}

use Apache::Session::Lock::Semaphore;
use IPC::SysV qw(IPC_CREAT S_IRWXU SEM_UNDO);
use IPC::Semaphore;

print "1..28\n";

my $semkey = int(rand(2**15-1));

my $session = {
    data => {_session_id => 'foo'},
    args => {SemaphoreKey => $semkey}    
};

my $n = 1;

for (my $i = 2; $i <= 8; $i += 2) {
    $session->{args}->{NSems} = $i;
    my $locker = new Apache::Session::Lock::Semaphore $session;

    if (ref $locker) {
        print "ok $n\n";
    }
    else {
        print "not ok $n\n";
    }
    $n++;

    $locker->acquire_read_lock($session);
    my $semnum = $locker->{read_sem};

    my $sem = new IPC::Semaphore $semkey, $i, S_IRWXU;

    if (ref $sem) {
        print "ok $n\n";
    }
    else {
        print "not ok $n\n";
        exit;
    }
    $n++;
    
    my @sems = $sem->getall;

    if ($sems[$semnum] == 1 && $sems[$semnum+$i/2] == 0) {
        print "ok $n\n";
    }
    else {
        print "not ok $n\n";
    }
    $n++;

    $locker->acquire_write_lock($session);

    @sems = $sem->getall;

    if ($sems[$semnum] == 0 && $sems[$semnum+$i/2] == 1) {
        print "ok $n\n";
    }
    else {
        print "not ok $n\n";
    }
    $n++;

    $locker->release_write_lock($session);
    
    @sems = $sem->getall;

    if ($sems[$semnum] == 0 && $sems[$semnum+$i/2] == 0) {
        print "ok $n\n";
    }
    else {
        print "not ok $n\n";
    }
    $n++;

    $locker->acquire_write_lock($session);
    $locker->release_all_locks($session);
    
    @sems = $sem->getall;

    if ($sems[$semnum] == 0 && $sems[$semnum+$i/2] == 0) {
        print "ok $n\n";
    }
    else {
        print "not ok $n\n";
    }
    $n++;

    $locker->acquire_read_lock($session);
    $locker->release_all_locks($session);
    
    @sems = $sem->getall;

    if ($sems[$semnum] == 0 && $sems[$semnum+$i/2] == 0) {
        print "ok $n\n";
    }
    else {
        print "not ok $n\n";
    }
    $n++;

    $sem->remove;
}
