############################################################################
#
# Apache::Session::Win32
# Apache persistent user session via Win32 global memory
# Copyright(c) 1998 Jeffrey William Baker
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::Win32;
use Apache::Session ();
@ISA=qw(Apache::Session);

$Apache::Session::Win32::VERSION = '0.03';

use vars qw($gc_counter $sessions);

BEGIN{ $Apache::Session::Win32::sessions = {} };

sub options {
  { autocommit => 1,
    lifetime   => $ENV{'SESSION_LIFETIME'}
  };
}

sub create {
  my $class = shift;
  my $id    = shift;
  
  if ( defined $Apache::Session::Win32::sessions->{ $id } ) {
    if ( $Apache::Session::Win32::sessions->{ $id }->{ '_EXPIRES' } < time() ) {
      delete $Apache::Session::Win32::sessions->{$id};
    }
    else {
      return undef;
    }
  }
  
  if ( ++$Apache::Session::Win32::gc_counter % 100 == 0 ) {
    my $key;    
    foreach $key (keys %$Apache::Session::Win32::sessions) {
      if ( $Apache::Session::Win32::sessions->{ $key }->{ '_EXPIRES' } <= time() ) {
        delete $Apache::Session::Win32::sessions->{ $key };
      }
    }
  }
  
  $Apache::Session::Win32::sessions->{ $id } = {};
  return {};
}

sub fetch {
  my $class = shift;
  my $id    = shift;
  
  return undef unless $Apache::Session::Win32::sessions->{ $id };

  my $rv = {}; 
  my $key;
  foreach $key ( keys %{ $Apache::Session::Win32::sessions->{ $id } } ) {
    $rv->{ $key } = $Apache::Session::Win32::sessions->{ $id }->{ $key };
  }

  return $rv;
}

sub commit {
  my $class = shift;
  my $hashref = shift;
  my $id = $hashref->{ '_ID' };
  

  $Apache::Session::Win32::sessions->{$id} = {};
  my $key;
  foreach $key (keys %$hashref) {
    $Apache::Session::Win32::sessions->{ $id }->{ $key } = $hashref->{$key};
  }
}

sub destroy {
  my $self = shift;
  delete $Apache::Session::Win32::sessions->{$self->{'_ID'}};
}
  
sub DESTROY { 
  my $self = shift;
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
  

Apache::Status->menu_item(
    'W32Session' => 'Win32 Session Objects',
    sub {
        my($r, $q) = @_;
        my(@s) = "<TABLE border=1><TR><TD>Session ID</TD><TD>Expires</TD></TR>";
        foreach my $session (keys %$Apache::Session::Win32::sessions) {
          my $expires = localtime($Apache::Session::Win32::sessions->{$session}->{'_EXPIRES'});
          push @s, '<TR><TD>', $session, '</TD><TD>', $expires, "</TD></TR>\n";
        }
        push @s, '</TABLE>';
        return \@s;
   }

) if ($INC{'Apache.pm'} && Apache->module('Apache::Status'));

1;

__END__

=head1 NAME

Apache::Session::Win32 - Store client sessions in a global hash

=head1 SYNOPSIS

use Apache::Session::Win32

=head1 DESCRIPTION

This is a Win32 storage subclass for Apache::Session.  Client state is stored
in a global hash.  Since Win32 Apache is multithreaded instead of multiprocess,
this actually works and is extremely quick.  
Try C<perldoc Session> for more info.

=head1 INSTALLATION

Follow the installation instructions from Apache::Session.

=head2 Environment

Apache::Session::Win32 does not define any environment variables beyond those
defined by Apache::Session.

=head1 USAGE

This package complies with the API defined by Apache::Session.  For details,
please see that package's documentation.

This package installs an entry on the Apache::Status menu which will let you
monitor sessions in real-time.

=head1 AUTHORS

Jeffrey Baker <jeff@godzilla.tamu.edu>, author and maintainer.

Redistribute under the Perl Artistic License.

