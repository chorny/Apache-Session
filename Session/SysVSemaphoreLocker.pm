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

$Apache::Session::SysVSemaphoreLocker::sem_key = 32818;

sub new {
    my $class = shift;
    
    return bless {read => 0, write => 0, sem => undef}, $class;
}

sub acquire_read_lock  {
    my $self    = shift;
    my $session = shift;

    return if $self->{read};
    die if $self->{write};

    if (!$self->{sem}) {
        my $sem_key = $session->{args}->{SemaphoreKey} ||
            $Apache::Session::SysVSemaphoreLocker::sem_key;
    
        $self->{sem} = new IPC::Semaphore($sem_key, 32, IPC_CREAT | S_IRWXU)
            || die $!;
    }
    
    my $read_sem = hex substr($session->{data}->{_session_id}, 0, 1);

    $self->{sem}->op($read_sem + 16, 0, SEM_UNDO,
                     $read_sem,      1, SEM_UNDO);
    
    $self->{read} = 1;
}

sub acquire_write_lock {    
    my $self    = shift;
    my $session = shift;

    return if($self->{write});

    if (!$self->{sem}) {
        my $sem_key = $session->{args}->{SemaphoreKey} ||
            $Apache::Session::SysVSemaphoreLocker::sem_key;
    
        $self->{sem} = new IPC::Semaphore($sem_key, 32, IPC_CREAT | S_IRWXU)
            || die $!;
    }
    
    $self->release_read_lock($session) if $self->{read};

    my $read_sem = (hex substr($session->{data}->{_session_id}, 0, 1));

    $self->{sem}->op($read_sem,      0, SEM_UNDO,
                     $read_sem + 16, 0, SEM_UNDO,
                     $read_sem + 16, 1, SEM_UNDO);
    
    $self->{write} = 1;
}

sub release_read_lock  {
    my $self    = shift;
    my $session = shift;
    
    die unless $self->{read};

    my $read_sem = (hex substr($session->{data}->{_session_id}, 0, 1));

    $self->{sem}->op($read_sem, -1, SEM_UNDO);
    
    $self->{read} = 0;
}

sub release_write_lock {
    my $self    = shift;
    my $session = shift;
    
    die unless $self->{write};
    
    my $read_sem = (hex substr($session->{data}->{_session_id}, 0, 1));

    $self->{sem}->op($read_sem + 16, -1, SEM_UNDO);

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
