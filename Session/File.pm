############################################################################
#
# Apache::Session::File
# Apache persistent user sessions via the filesystem.
# Copyright(c) 1998 Jeffrey William Baker (jeff@godzilla.tamu.edu)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::File;

$Apache::Session::File::VERSION = '0.01';

use Carp;
use Storable qw(nstore_fd retrieve_fd);
use strict;
use vars qw(@ISA);

@ISA=qw(Apache::Session);

use constant DIR   => $ENV{'SESSION_FILE_DIRECTORY'}   || croak "SESSION_FILE_DIRECTORY not set";
use constant HOLD  => $ENV{'SESSION_FILE_LOCK_TIMEOUT'}|| 3600;
use constant MAX   => $ENV{'SESSION_FILE_RETRIES'}     || 5;
use constant DELAY => $ENV{'SESSION_FILE_WAIT'}        || 1;
use constant WARN  => $ENV{'SESSION_FILE_WARN'}        || undef;

sub lock {
  my $fn = shift;
  my $lifetime = HOLD;
  
  if (-e "$fn.lock") {
    open (OLDLOCK, "<$fn.lock") || warn "Couldn't open old lock for read, $^E", return undef;
    my @lockinfo = <OLDLOCK>;
    close OLDLOCK;
    if ($lockinfo[2] < time()) {
      unlink "$fn.lock";
    }
    else {
      if ( ( $lockinfo[0] == $$ ) && ( $lockinfo[1] == $ENV{'SERVER_NAME'} )) {
        unlink "$fn.lock";
      }
      else {
        return undef;
      }
    }
  }

  open (LOCK, ">$fn.lock") || warn "couldn't open lockfile for write: $^E", return undef;
  
  my $expires = time() + $lifetime;
  print LOCK "$$\n$ENV{'SERVER_NAME'}\n$expires";
  
  return close LOCK;

};
  

sub expire {
  my $self = shift;
  my $class = ref( $self ) || $self;
  
  if ($self->{'_EXPIRES'} < time()) {
    $self->destroy();
    return undef;
  }

  $self->SUPER::expire();
}

sub open {  
  my $class = shift;
  my $id = shift;  
  my $opts = shift || {};
  
  my $session = $class->fetch($id);
  if (!$session) {
    unlock (DIR."/".$id);
    return undef;
  }

  $session = bless $session, $class;

  my $self = $class->SUPER::open($session, $opts );
  
  return $self;
}

sub store {
  my $self = shift;
  my $id = $self->{'_ID'};
  my $fh = DIR."/".$id;
   
  lock($fh) || warn "Couldn't get a lock to store $id", return undef;
  open(ME, ">$fh") || warn "Couldn't store() session $id: $^E", return undef;
  nstore_fd $self, \*ME;
  close ME || warn "Close failed in store(): $^E", return undef;
  
  return 1;
}

sub Options {
  my( $class, $runtime_opts ) = @_;
  $class->SUPER::Options( $runtime_opts, { autocommit => 1 , lifetime => $ENV{'SESSION_LIFETIME'}} );
}  


sub fetch {
  my $class = shift;
  my $id = shift;
  my $fh = DIR."/".$id;


  lock($fh) || warn "Lock failed on session $id, $^E", return undef;
  open (ME, "<$fh") || warn "Couldn't open session $id, $^E", return undef;
    
  my $sessionref;
    
  eval {
    local $SIG{__DIE__};
    $sessionref = retrieve_fd(*ME);
  };
    
  close ME || warn "Close failed for session $id";
  
  return $sessionref;
}

sub create {
  my $self = shift;
  my $class = ref( $self ) || $self;
  my $id = shift;
  my $fh = DIR."/".$id;

  if (-e "$fh") { #check the expiration on an existing session
    my $session = $class->fetch($id);

    if (!$session) {
      return undef; #couldn't open it, maybe another PID has it locked?
    }
    
    if ($session->{'_EXPIRES'} < time()) {
      $session->destroy();
    }
    else {
      return undef; #this session is still good, try another id
    }
  }

    my $rv = lock($fh);
    if (!$rv) {
      warn "Could not acquire lock on session $fh";
      return undef;
    }

    open (ME, ">$fh") || warn "Didn't open $id for create(), $^E", return undef;

    nstore_fd ($self, \*ME);

    $rv = close ME;
    if (!$rv) {
      warn "Something went wrong while closing session $id";
      unlock($fh);
      return undef;
    }
    
  return $self;
}

sub destroy {
  my $self = shift;
  my $id = $self->{'_ID'};
  my $fh = DIR."/".$id;

  unlock($fh); 
  unlink $fh || warn "Explicit destroy failed for session $id, $^E", return undef;
  return 1;
}

sub dump_to_html {
  my $self = shift;
  my $s;
  my $key;
  
  $s = $s."<table border=1>\n\t<tr>\n\t\t<td>Variable Name</td>\n\t\t<td>Scalar Value</td>\n\t</tr>";
  foreach $key (sort(keys(% { $self }))) {
      $s = $s."\n\t<tr>\n\t\t<td>$key</td>\n\t\t<td>$self->{$key}</td>";
  }
  $s = $s."\n</table>\n";
  return $s;
}

sub unlock {
  my $fh = shift;
  if (ref($fh)) {
    $fh = DIR."/".$fh->{'_ID'};
  }

  return unlink "$fh.lock";

}

sub DESTROY {
  my $self = shift;
  my $id = $self->{'_ID'};
  my $fh = DIR."/".$id;

}

1;
