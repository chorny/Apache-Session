############################################################################
#
# Apache::Session::Win32
# Apache persistent user session via Win32 global memory
# Copyright(c) 1998 Jeffrey William Baker
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::IPC;

$Apache::Session::IPC::VERSION = '0.01';

use IPC::Shareable;
use vars qw(@ISA);
@ISA=qw(Apache::Session);

use strict;
use vars qw/%SESSIONS/;

# bind session structure to shared memory
bind_sessions() unless defined(%SESSIONS) && tied(%SESSIONS);
sub bind_sessions {
    die "Couldn't bind shared memory"
        unless tie(%SESSIONS,'IPC::Shareable','THIS',
                   {create=>1,mode=>0666});
}

use strict;

sub create {
  my $self = shift;
  my $class = ref( $self ) || $self;
  my $id = shift;
  
  if ( $SESSIONS{$id} && ( $SESSIONS{$id}->{'_EXPIRES'} > time() ) ) {
    warn "Tried to clobber unexpired session $id in $class->create()";
    return undef;
  }
  
  if ( $SESSIONS{$id} && ( $SESSIONS{$id}->{'_EXPIRES'} < time() ) ) {
    warn "Session $id is expired, reissuing id number";
    my $expired_session = bless $Apache::Session::IPC::sessions->{$id}, $class;
    $expired_session->destroy();
  }
  
  warn "Inserting new session $id, $self";
  
  $SESSIONS{$id} = $self;
  
  warn "After insert, it is $SESSIONS{$id}";
  return $self;
}

###########################################################
# sub open
#
# The subclass's open will be called from the client program.
# Open takes two args, the id number and a hash of options.
# Open needs to call fetch to retrieve the session from
# physical storage, call $class->SUPER::open with a
# blessed reference to the object and the hash of options.
# Return undef on failure.
###########################################################

sub open {  
  my $class = shift;
  my $id = shift;  
  my $opts = shift || {};
  
  my $session = $class->fetch($id);
  return undef unless $session;
  warn "didn't return undef";
  my $self = $class->SUPER::open($session, $opts );
  return $self;
}

###########################################################
# sub fetch
#
# Fetch is used to retrieve the sesion from physical storage.
# Fetch is called from the subclass's open().  
#
###########################################################

sub fetch {
  my $class = shift;
  my $id = shift;
  warn "Fetching $id";
  my $rv = $SESSIONS{$id};
  warn "Returning $rv";
  return $rv;
}

###########################################################
# sub store
#
# Store is used to commit changes in the session object to
# physical storage.  Store is called depending on whether
# autocommit is on or off in the options hash.  If autocommit
# is true, store() is called every time the session object is
# modified.  If autocommit is false, store() is only called if
# the client program calls it explicitly.  If your subclass
# doesn't need to do anything special to update the physical
# storage, you don't need to implement store().
###########################################################


###########################################################
# sub expire
#
# Expire needs to make sure that the object being open()ed 
# hasn't expired yet.  Expired objects should destroy them-
# selves and return undef.  Good object should call 
# $self->SUPER::expire()
#
###########################################################


sub expire {
  my $self = shift;
  my $class = ref( $self ) || $self;
  
  my $id = $self->{'_ID'};
  warn "made it to self->expire, $id";
  if ( $SESSIONS{$id} && ( $SESSIONS{$id}->{'_EXPIRES'} < time() ) ) {
    warn "Tried to open session $id, which is expired.";
    $self->destroy();
    return undef;
  }
  warn "ABout to call superclass, ";
  $self->SUPER::expire();
}

###########################################################
#
# sub Options
#
# Options should merge the user's runtime options with 
# class defaults, then call Options in the superclass.  Note
# that anything you hard-code as defaults here will override
# the user's environment settings from httpd.conf, so be 
# thoughtful when coding this routine.
#
# You should define a default value for autocommit: either 1 or 0,
# depending on how much overhead you incur in writing to you
# physical storage.
#
###########################################################

sub Options {
  my( $class, $runtime_opts ) = @_;
  $class->SUPER::Options( $runtime_opts, { autocommit => 1 });
}  

###########################################################
#
# sub destroy
#
# Destroy should remove the object from physical storage,
# and clean up any locking mechanisms.
#
###########################################################

sub destroy {
  my $self = shift;
  delete $SESSIONS{ $self->{'_ID'} };
}

###########################################################
#
# These next two are handy, but you don't need to implement
# them.
#
###########################################################

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
  

Apache::Status->menu_item(
    'IPCSession' => 'IPC::Shareable Session Objects',
    sub {
        my($r, $q) = @_;
        my(@s) = "<TABLE border=1><TR><TD>Session ID</TD><TD>Expires</TD></TR>";
        foreach my $session (keys %SESSIONS) {
          my $expires = localtime($SESSIONS{$session}->{'_EXPIRES'});
          push @s, '<TR><TD>', $session, '</TD><TD>', $expires, "</TD></TR>\n";
        }
        push @s, '</TABLE>';
        return \@s;
   }

) if ($INC{'Apache.pm'} && Apache->module('Apache::Status'));

1;
