use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];

plan skip_all => "Optional modules (IPC::SysV, IPC::Semaphore) not installed"
  unless eval {
               require IPC::SysV;
               require IPC::Semaphore;
              };

my $origdir = getcwd;
my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
chdir( $tempdir );

plan tests => 29;

my $package = 'Apache::Session::Lock::Semaphore';
use_ok $package;
use IPC::SysV qw(IPC_CREAT S_IRWXU SEM_UNDO);
use IPC::Semaphore;

my $semkey = int(rand(2**15-1));

my $session = {
    data => {_session_id => 'foo'},
    args => {SemaphoreKey => $semkey}    
};

my $number = 1;
for my $iter (2,4,6,8) {
    $session->{args}->{NSems} = $iter;
    my $locker = $package->new($session);
    
    isa_ok $locker, $package;

    $locker->acquire_read_lock($session);
    my $semnum = $locker->{read_sem};

    my $sem = IPC::Semaphore->new($semkey, $number++, S_IRWXU);

    isa_ok $sem, 'IPC::Semaphore';

    my @sems = $sem->getall;

    ok $sems[$semnum] == 1 && $sems[$semnum+$iter/2] == 0,
       'the semaphores seem right';

    $locker->acquire_write_lock($session);

    @sems = $sem->getall;

    ok $sems[$semnum] == 0 && $sems[$semnum+$iter/2] == 1,
       'semaphores seem right again';

    $locker->release_write_lock($session);
    
    @sems = $sem->getall;

    ok $sems[$semnum] == 0 && $sems[$semnum+$iter/2] == 0,
       'the semaphores seem right x3';

    $locker->acquire_write_lock($session);
    $locker->release_all_locks($session);
    
    @sems = $sem->getall;

    ok $sems[$semnum] == 0 && $sems[$semnum+$iter/2] == 0,
       'the semaphores seem right x4';

    $locker->acquire_read_lock($session);
    $locker->release_all_locks($session);
    
    @sems = $sem->getall;

    ok $sems[$semnum] == 0 && $sems[$semnum+$iter/2] == 0,
       'the semaphores seem right x5';

    $sem->remove;
}

chdir( $origdir );
