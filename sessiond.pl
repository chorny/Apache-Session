#!/usr/bin/perl

use IO::Socket;
use IO::Select;
use POSIX;
use strict;

use constant SECRET => 'secret';

my $sessions = {}; # this is where the sessions go
my $sockets  = {}; # phone book

my $main_sock = new IO::Socket::INET ( LocalHost => 'superchunk',
                                       LocalPort => 2015,
                                       Proto     => 'tcp',
                                       Listen    => 50,
                                       Reuse     => 1
                                     );

die "Main socket could not be created. $!" unless $main_sock;

my $ready_to_read  = new IO::Select;
my $ready_to_write = new IO::Select;
my $error          = new IO::Select;

$ready_to_read->add($main_sock);
$ready_to_write->add($main_sock);
$error->add($main_sock);

while (1) {
  my ($socks_to_read, $socks_to_write, $socks_with_errors) = IO::Select->select($ready_to_read, $ready_to_write, $error, undef);
  print "Select has returned! $socks_to_read->[0], $socks_to_write->[0], $socks_with_errors->[0]\n";
  my $sock;

  foreach $sock (@$socks_to_read) {

    if ($sock == $main_sock) {
      print "It looks like a new socket!\n";
      my $new_sock = $sock->accept();
      
      my $their_sockaddr = getpeername($new_sock);
      my ($port, $iaddr) = unpack_sockaddr_in($their_sockaddr);
      my $their_straddr  = inet_ntoa($iaddr);
 
      fcntl ($new_sock, F_SETFL(), O_NONBLOCK());
      
      $ready_to_read->add($new_sock);
      $ready_to_write->add($new_sock);
      $error->add($new_sock);
      $sockets->{scalar($new_sock)} = ( undef, undef, undef );
      
      print "Accepted connection from $their_straddr\n";
    }
    
    else {
      print "This is an existing socket\n";
      if ( defined $sockets->{$sock}->[0] ) {
        print "The bytes to recv is ".$sockets->{$sock}->[0]."\n";
        print "I've already read $sockets->{$sock}->[1]\n";
        if ( $sockets->{$sock}->[0] == 0 ) {
          print "I'm going to read whatever else there is to read\n";
          my $these = 64;
        while ($these) {
          my $buf;
          my $bytes_read = sysread( $sock, $buf, $these );
          
          if ( defined( $bytes_read ) ) {
            if ( $bytes_read == 0 ) {
              $ready_to_read->remove($sock);
              $ready_to_write->remove($sock);
              $error->remove($sock);
              delete $sockets->{$sock};
              close $sock;
              print "Connection closed on $sock\n";
              last;
            }
            else {
              print "reading $buf from $sock\n";
              $these -= $bytes_read;
            }
          }
          else {
            if ($! == EAGAIN()) {
              print "$sock wanted to block, so back to select\n";
              last;
            }
          }
        }
        
          
        } else  {
        while ($sockets->{$sock}->[0]) {
          my $buf;
          my $bytes_read = sysread( $sock, $buf, $sockets->{$sock}->[0] );
          
          if ( defined( $bytes_read ) ) {
            if ( $bytes_read == 0 ) {
              $ready_to_read->remove($sock);
              $ready_to_write->remove($sock);
              $error->remove($sock);
              delete $sockets->{$sock};
              close $sock;
              print "Connection closed on $sock\n";
              last;
            }
            else {
              print "reading $buf from $sock\n";
              $sockets->{$sock}->[1] .= $buf;
              $sockets->{$sock}->[0] -= $bytes_read;
            }
          }
          else {
            if ($! == EAGAIN()) {
              print "$sock wanted to block, so back to select\n";
              last;
            }
          }
        }
      }
      }
      else {
        print "Looks like bytes_to_read isn't set yet\n";
        print "But the incoming message is already $sockets->{$sock}->[1]\n";
        my $bytes_to_read = 8 - length ($sockets->{$sock}->[1]);
        print "So I need to read $bytes_to_read bytes\n";
        while ($bytes_to_read) {
          my $buf;
          my $bytes_read = sysread( $sock, $buf, $bytes_to_read );
          
          if ( defined( $bytes_read ) ) {
            if ( $bytes_read == 0 ) {
              $ready_to_read->remove($sock);
              $ready_to_write->remove($sock);
              $error->remove($sock);
              delete $sockets->{$sock};
              close $sock;
              print "Connection closed on $sock\n";
              last;
            }
            else {
              print "reading $buf from $sock\n";
              $sockets->{$sock}->[1] .= $buf;
              print "Now the msg_to_recv is $sockets->{$sock}->[1]\n";
              $bytes_to_read -= $bytes_read;
              print "And bytes_to_read is $bytes_to_read\n";
            }
          }
          else {
            if ($! == EAGAIN()) {
              print "$sock wanted to block, back to select\n";
              last;
            }
          }
        }
        if ($bytes_to_read == 0) {
          print "Got the total length: $sockets->{$sock}->[1]\n";
          $sockets->{$sock}->[0] = $sockets->{$sock}->[1];
          $sockets->{$sock}->[1] = undef;
        }
      }
    }        
  }
  foreach $sock (@$socks_to_write) {
    print "Socket $sock was ready to be written\n";
    if ($sock == $main_sock) {
      print "It looks like a new socket!\n";
      my $new_sock = $sock->accept();
      
      my $their_sockaddr = getpeername($new_sock);
      my ($port, $iaddr) = unpack_sockaddr_in($their_sockaddr);
      my $their_straddr  = inet_ntoa($iaddr);
 
      fcntl ($new_sock, F_SETFL(), O_NONBLOCK());
      
      $ready_to_read->add($new_sock);
      $ready_to_write->add($new_sock);
      $error->add($new_sock);
      $sockets->{scalar($new_sock)} = ( undef, undef, undef );
      
      print "Accepted connection from $their_straddr\n";
    }
  }

  foreach $sock (@$socks_with_errors) {
    print "Socket $sock had an error\n";
#    $ready_to_read->remove($sock);
#    $ready_to_write->remove($sock);
#    $error->remove($sock);
    
#    close $sock;
  }
}

close $main_sock;
