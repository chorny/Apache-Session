############################################################################
#
# Apache::Session::PosixFileLocker
# flock(2) locking for Apache::Session
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::PosixFileLocker;

#This is the best locker so far.  If session A is writing, session B will not
#block.  Hooray.

use strict;

use Fcntl qw(:flock);
use Symbol;

$Apache::Session::PosixFileLocker::lockdir = '/tmp';

sub new {
    my $class = shift;
    
    return bless { read => 0, write => 0, opened => 0, id => 0 }, $class;
}

sub acquire_read_lock  {
    my $self    = shift;
    my $session = shift;
    
    return if $self->{read};

    if (!$self->{opened}) {
        my $fh = Symbol::gensym();
        
        my $lockdir = $session->{args}->{LockDir} || 
            $Apache::Session::PosixFileLocker::lockdir;
            
        open($fh, ">".$lockdir."/Apache-Session-".$session->{data}->{_session_id}.".lock") || die $!;

        $self->{fh} = $fh;
        $self->{opened} = 1;
    }
        
    flock($self->{fh}, LOCK_SH);
    $self->{read} = 1;
}

sub acquire_write_lock {
    my $self    = shift;
    my $session = shift;

    return if $self->{write};
    
    if (!$self->{opened}) {
        my $fh = Symbol::gensym();
        
        my $lockdir = $session->{args}->{LockDir} || 
            $Apache::Session::PosixFileLocker::lockdir;
            
        open($fh, ">".$lockdir."/Apache-Session-".$session->{data}->{_session_id}.".lock") || die $!;

        $self->{fh} = $fh;
        $self->{opened} = 1;
    }
        
    flock($self->{fh}, LOCK_EX);    
    $self->{write} = 1;
}

sub release_read_lock  {
    my $self    = shift;
    my $session = shift;
    
    die unless $self->{read};
    
    if (!$self->{write}) {
        close $self->{fh};
        
        $self->{opened} = 0;
    }
    
    $self->{read} = 0;
}

sub release_write_lock {
    my $self    = shift;
    my $session = shift;
    
    die unless $self->{write};
    
    if ($self->{read}) {
        flock($self->{fh}, LOCK_SH);
    }
    else {
        close $self->{fh};
        
        $self->{opened} = 0;
    }
    
    $self->{write} = 0;
}
sub release_all_locks  {
    my $self    = shift;
    my $session = shift;

    if ($self->{opened}) {
        close $self->{fh} || die;

        my $lockdir = $session->{args}->{LockDir} || 
            $Apache::Session::PosixFileLocker::lockdir;

        unlink $lockdir."/Apache-Session-".$session->{data}->{_session_id}.".lock" || die $!;
    }
    
    $self->{opened} = 0;
    $self->{read}   = 0;
    $self->{write}  = 0;
}

1;
