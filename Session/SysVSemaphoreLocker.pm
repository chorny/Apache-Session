############################################################################
#
# Apache::Session::SysVSemaphoreLocker
# IPC Semaphore locking for Apache::Session
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::SysVSemaphoreLocker;

use strict;
use IPC::SysV qw(IPC_CREAT S_IRWXU SEM_UNDO);
use IPC::Semaphore;

$Apache::Session::SysVSemaphoreLocker::nsems = 32; #good for linux, bad for solaris
$Apache::Session::SysVSemaphoreLocker::sem_key = 31818;

sub new {
    my $class   = shift;
    my $session = shift;
    
    my $nsems = $session->{args}->{NSems} ||
        $Apache::Session::SysVSemaphoreLocker::nsems;
    
    my $read_sem = int((hex substr($session->{data}->{_session_id}, 0, 1))*($nsems/32));

    my $sem_key = $session->{args}->{SemaphoreKey} ||
        $Apache::Session::SysVSemaphoreLocker::sem_key;

    return bless {read => 0, write => 0, sem => undef, nsems => $nsems, 
        read_sem => $read_sem, sem_key => $sem_key}, $class;
}

sub acquire_read_lock  {
    my $self    = shift;
    my $session = shift;

    return if $self->{read};
    die if $self->{write};

    if (!$self->{sem}) {    
        $self->{sem} = new IPC::Semaphore($self->{sem_key}, $self->{nsems},
            IPC_CREAT | S_IRWXU) || die $!;
    }
    
    $self->{sem}->op($self->{read_sem} + $self->{nsems}/2, 0, SEM_UNDO,
                     $self->{read_sem},                    1, SEM_UNDO);
    
    $self->{read} = 1;
}

sub acquire_write_lock {    
    my $self    = shift;
    my $session = shift;

    return if($self->{write});

    if (!$self->{sem}) {
        $self->{sem} = new IPC::Semaphore($self->{sem_key}, $self->{nsems}, 
            IPC_CREAT | S_IRWXU) || die $!;
    }
    
    $self->release_read_lock($session) if $self->{read};

    $self->{sem}->op($self->{read_sem},                    0, SEM_UNDO,
                     $self->{read_sem} + $self->{nsems}/2, 0, SEM_UNDO,
                     $self->{read_sem} + $self->{nsems}/2, 1, SEM_UNDO);
    
    $self->{write} = 1;
}

sub release_read_lock  {
    my $self    = shift;
    my $session = shift;
    
    die unless $self->{read};

    $self->{sem}->op($self->{read_sem}, -1, SEM_UNDO);
    
    $self->{read} = 0;
}

sub release_write_lock {
    my $self    = shift;
    my $session = shift;
    
    die unless $self->{write};
    
    $self->{sem}->op($self->{read_sem} + $self->{nsems}/2, -1, SEM_UNDO);

    $self->{write} = 0;
}

sub release_all_locks  {
    my $self    = shift;
    my $session = shift;

    if($self->{read}) {
        $self->release_read_lock($session);
    }
    if($self->{write}) {
        $self->release_write_lock($session);
    }
    
    $self->{read}  = 0;
    $self->{write} = 0;
}

1;
