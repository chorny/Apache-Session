############################################################################
#
# Apache::Session::Daemon
# Apache persistent user sessions via a network server.
# Copyright(c) 1998 Jeffrey William Baker (jeff@godzilla.tamu.edu)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::Daemon;
use Apache::Session ();
@ISA=qw(Apache::Session);

$Apache::Session::Daemon::VERSION = '0.00';

use Carp;
use Storable qw(nfreeze thaw);
use IO::Socket;
use IO::Select;
use POSIX;
use MD5;
use strict;

use constant HOST   => $ENV{'SESSION_DAEMON_HOST'} || '127.0.0.1';
use constant PORT   => $ENV{'SESSION_DAEMON_PORT'} || '2015';
use constant SECRET => 'secret';

BEGIN { 

  sub create_sock {
    $Apache::Session::Daemon::sock = new IO::Socket::INET ( 
      PeerAddr => HOST,
      PeerPort => PORT,
      Proto    => 'tcp'
      );
    warn "Trying to create socket to ".HOST." on ".PORT;
    die "Main socket could not be created. $!" unless $Apache::Session::Daemon::sock;

#    fcntl( $Apache::Session::Daemon::sock, F_SETFL(), O_NONBLOCK());
  }
  
  create_sock();
};

sub options {
  { autocommit => 1,
    lifetime   => $ENV{'SESSION_LIFETIME'}
  };
}

sub lock {
  my $id = shift;
  
  my $msg = "LOCK\nSESSION:$id\nPID:$$\n";
  my $hash = substr(MD5->hexhash($msg.SECRET),0,15);
  $msg .= "MD5:$hash";
  my $length = length( $msg );
  
  sock_write ( sprintf("%.8d",$length) ) || return undef;
  sock_write ( $msg )    || return undef;
  my $rv = sock_read(1)  || return undef;
  if ($rv == 1) {
    return 1;
  }
  return undef;
}

sub unlock {
  my $id = shift;
  
  my $msg = "UNLOCK\nSESSION:$id\n";
  my $hash = substr(MD5->hexhash($msg.SECRET),0,15);
  $msg .= "MD5:$hash";
  my $length = length( $msg );
  
  sock_write ( sprintf("%.8d",$length) ) || return undef;
  sock_write ( $msg ) || return undef;
  my $rv = sock_read(1) || return undef;
  if ($rv == 1) {
    return 1;
  }
  return undef;
}

sub create {
  my $class = shift;
  my $id    = shift;

  my $msg = "CREATE\nSESSION:$id\nPID:$$\n";
  my $hash = substr(MD5->hexhash($msg.SECRET),0,15);
  $msg .= "MD5:$hash";
  my $length = length( $msg );
  
  warn "sending $msg, $length";
  sock_write ( sprintf("%.8d",$length) ) || return undef;
  warn "made it past the first sock_write";
  sock_write ( $msg ) || return undef;
  warn "made it past the second sock_write";
#  my $rv = sock_read(1);

  if ($rv != 1) {
    warn "Sock_read returned ! 1";
    return undef;
  }
  
  my $self = {};
  my $frozen = nfreeze $self;
  
  $msg = "STORE\nSESSION:$id\nDATA:$frozen\n";
  $hash = substr(MD5->hexhash($msg.SECRET),0,15);
  $msg .= "MD5:$hash";
  $length = length( $msg );

  sock_write ( sprintf("%.8d",$length) ) || return undef;
  sock_write ( $msg ) || return undef;
#  $rv = sock_read(1) || return undef;

  if ($rv != 1) {
    return undef;
  }
  return $self;  
}

sub fetch {
  my $class = shift;
  my $id    = shift;
  
  return {};
}

sub store {
  return 1;
}

sub destroy {
  return 1;
}
  
sub sock_write {
  my $msg = shift;
  warn "Sending $msg to server";
  my $length = length( $msg );
  
  my $writeable = new IO::Select;
  $writeable->add($Apache::Session::Daemon::sock);
  
  while ($length) {
    my ($ready_to_read, $ready_to_write) = IO::Select->select(undef, $writeable, undef, 5);
    warn "My socket may be writeable";
    if (@$ready_to_write->[0]) {
      warn "socket @$ready_to_write->[0] is indeed writeable";
      my $bytes_written = syswrite( @$ready_to_write->[0], $msg, $length );
      warn "I wrote $bytes_written to the server";
      if (defined $bytes_written) {
        if ($bytes_written == 0) {
          warn "Socket failure in sock_write, rebuilding socket";
          close @$ready_to_write->[0];
          create_sock();
          return undef;
        }
        else {
          $length -= $bytes_written;
          $msg = substr($msg, $bytes_written);
          warn "Now length: $length, msg: $msg";
        }
      }
      else {
        if ($! == EAGAIN) {
          warn "My socket wanted to block, back to select";
          next;
        }
      }
    }
    else { #timeout on select
      warn "Select timeout in sock_write";
      return undef;
    }
  }
  1;
}

sub sock_read {
  my $length = shift;
  my $msg;
  
  my $readable = new IO::Select;
  $readable->add($Apache::Session::Daemon::sock);
  
  while ($length) {
    my ($ready_to_read, $ready_to_write) = IO::Select->select($readable, undef, undef, 5);

    if (@$ready_to_read->[0]) {
      my $buf;
      my $bytes_read = sysread( @$ready_to_read->[0], $buf, $length );
      if ( defined $bytes_read) {
        if ($bytes_read == 0) {
          warn "Socket failure in sock_read, rebuilding socket";
          close @$ready_to_read->[0];
          create_sock();
          return undef;
        }
        else {
          $length -= $bytes_read;
          $msg .= $buf;
        }
      }
      else {
        if ($! == EAGAIN) {
          next;
        }
      }
    }
    else { #timeout on select
      warn "Socket timeout in sock_read";
      return undef;
    }
  }
  return $msg;
}
