############################################################################
#
# Apache::Session::File
# Apache persistent user sessions via the filesystem.
# Copyright(c) 1998 Jeffrey William Baker (jeff@godzilla.tamu.edu)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::File;
use Apache::Session ();

@Apache::Session::File::ISA = qw(Apache::Session);
$Apache::Session::File::VERSION = '0.02';

use Carp;
use Storable qw(nstore_fd retrieve_fd);
use strict;

use constant DIR   => $ENV{'SESSION_FILE_DIRECTORY'}   || "/tmp";
use constant HOLD  => $ENV{'SESSION_FILE_LOCK_TIMEOUT'}|| 60;

#BEGIN: {
  # garbage collector

#  warn "enterring garbage collector";
#  opendir ( DH, DIR ) || warn "Garbage collection failed: $!";
#  my @files = readdir DH;
#  my $file;
#  foreach $file (@files) {
#    next if $file =~ /\./;
#    next unless lock(DIR."/".$file);
#    open (FH, '<'.DIR."/".$file) || warn "Couldn't GC session $file", next;
#    my $hashref = retrieve_fd(*FH);
#    if ( $hashref->{'_EXPIRES'} < time() ) {
#      destroy($hashref);
#    }
#    close FH;
#    unlock(DIR."/".$file);
#  }
#  closedir DH;
#}

sub options {
  { autocommit => 0,
    lifetime   => ( $ENV{'SESSION_LIFETIME'} || 3600 )
  };
}

sub lock {
  my $fn = shift;
  my $lifetime = HOLD;

  if (-e "$fn.lock") {
    open (OLDLOCK, "<$fn.lock") || warn "Couldn't open old lock for read, $^E", return undef;
    my @lockinfo;
    while ( <OLDLOCK> ) {
      chomp $_;
      push @lockinfo, $_;
    }

    close OLDLOCK;

    if ( $lockinfo[2] < time() ) {
      unlink "$fn.lock";
    }
    else {
      if ( ( $lockinfo[0] == $$ ) && ( $lockinfo[1] eq $ENV{'SERVER_NAME'} )) {
        unlink "$fn.lock";
      }
      else {
        return undef;
      }
    }
  }

  open (LOCK, ">$fn.lock") || warn "couldn't open lockfile for write: $^E", return undef;
  my $expires = time() + $lifetime;
  my $name = $ENV{'SERVER_NAME'} || `hostname`;
  chomp $name;
  print LOCK "$$\n$name\n$expires";
  
  return close LOCK;

}

sub unlock {
  my $fh = shift;
  if (ref($fh)) {
    $fh = DIR."/".$fh->{'_ID'};
  }

  return unlink "$fh.lock";

}
  

sub commit {
  my $class = shift;
  my $hashref = shift;
  my $id = $hashref->{ '_ID' };
  my $fh = DIR."/".$id;
  
  open(ME, ">$fh") || warn "Couldn't store() session $id: $^E", return undef;
  nstore_fd $hashref, \*ME;
  close ME || warn "Close failed in store(): $^E", return undef;
  
  return 1;
}

sub fetch {
  my $class = shift;
  my $id    = shift;
  my $fh    = DIR."/".$id;

  lock($fh) || warn "Lock failed on session $id, $^E", return undef;
  open (ME, "<$fh") || warn "Couldn't open session $id, $^E", unlock($fh), return undef;
    
  my $hashref;
    
  eval {
    local $SIG{__DIE__};
    $hashref = retrieve_fd(*ME);
  };
  
  close ME || warn "Close failed for session $id";
  return $hashref;
}

sub create {
  my $class = shift;
  my $id    = shift;
  my $fh    = DIR."/".$id;  

  if (-e "$fh") { #check the expiration on an existing session
    my $hashref = $class->fetch($id);

    if (!$hashref) {
      unlock($fh);
      return undef; #couldn't open it, maybe another PID has it locked?
    }
    
    if ($hashref->{'_EXPIRES'} < time()) {
      destroy($hashref);
    }
    else {
      unlock($fh);
      return undef; #this session is still good, try another id
    }
  }

    my $rv = lock($fh);
    if (!$rv) {
      warn "Could not acquire lock on session $fh";
      return undef;
    }

    open (ME, ">$fh") || warn "Didn't open $id for create(), $^E", unlock($fh), return undef;

    my $self = {};
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

  unlink $fh;
  unlock($fh); 
  return 1;
}

sub DESTROY {
  my $self = shift;
  my $id = $self->{'_ID'};
  my $fh = DIR."/".$id;
  unlock($fh);
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

1;

__END__

=head1 NAME

Apache::Session::File - Store client sessions in your filesystem

=head1 SYNOPSIS

use Apache::Session::File

=head1 DESCRIPTION

This is a File storage subclass for Apache::Session.  Client state is stored
in flat files.  Try C<perldoc Session> for more info.

=head1 INSTALLATION

=head2 Getting started

You will need to create a directory for Apache to store the session files.
This directory must be writeable by the httpd process.

=head2 Environment

You will need to configure your environment to get Session::File to work.  You
should define the variable SESSION_FILE_DIRECTORY with the name of the 
directory that you prepared above.  The package will croak if you don't 
define this.

I define this variables in my httpd.conf:

 PerlSetEnv SESSION_FILE_DIRECTORY /tmp/sessions

=head1 USAGE

This package complies with the API defined by Apache::Session.  For details,
please see that package's documentation.

The default for autocommit in Apache::Session::File is 0, which means that you
will need to either call $session->store() when you are done or set
autocommit to 1 via the open() and new() functions.

=head1 NOTES

The session hashes are stored in network order, so you should be able to
use this package on an NFS filesystem for a whole server farm.

Performance worsens every time a new sessions is created.  The session
directory should be cleaned out occasionally.  There is a garbage collector
at the top of this file which you may want to uncomment and play with.

Let me know if it works.

=head1 AUTHORS

Jeffrey Baker <jeff@godzilla.tamu.edu>, author and maintainer.

Redistribute under the Perl Artistic License.


