############################################################################
#
# Apache::Session::IPC
# Apache persistent user session via SysV IPC shared memory
# Copyright(c) 1998 Jeffrey William Baker
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::IPC;
use Apache::Session;
@Apache::Session::IPC::ISA     = qw(Apache::Session);
$Apache::Session::IPC::VERSION = '0.01';

use IPC::Shareable;
use MD5;
use strict;
use vars qw/%sessions %locker/;

%sessions = ();
%locker   = ();

bind_sessions() unless tied(%sessions);
sub bind_sessions {  
  die "Couldn't bind shared memory"
    unless tie( %sessions, 'IPC::Shareable', 'ApSI',
                {create=>1,mode=>0666}
              );
  die "Couldn't bind global lock"
    unless tie( %locker, 'IPC::Shareable', 'ApSI',
      	      	{create=>1,mode=>0666}
	      );
}

sub glock {
  while(1) {
    tied( %locker )->shlock();
    if ($locker{'lock'} == 1 ) {
      tied( %locker )->shunlock();
      select(undef, undef, undef, 0.25);
      next;
    }
    $locker{'lock'} = 1;
    last;
  }
  tied( %locker )->shunlock();
  return 1;
}

sub gunlock {
  tied( %locker )->shlock();
  delete $locker{'lock'};
  tied( %locker )->shunlock();
  return 1;
}

sub options {
  { autocommit => 0,
    lifetime   => $ENV{'SESSION_LIFETIME'},
  };
}

sub create {
  my $class = shift;
  my $id    = shift;
  
  my $lockhash = $$.$ENV{'SERVER_NAME'};
#  my $locker = tied( %sessions);
#  $locker->shlock();
  
  tied( %sessions )->shlock();;
  if ( ++$sessions{ 'gc_counter' } % 100 == 0 ) {
    my $key;
    foreach $key ( keys %sessions ) {
      next unless ( $sessions{ $key } =~ /HASH/ );
      if ( $sessions{ $key }->{ '_EXPIRES' } < time()
           && !( defined $sessions{ $key }->{ '_LOCK' } ) ) {
        delete $sessions{ $key };
      }
    }
  }
  
  if ( defined $sessions{ $id } ) {
    if ( defined $sessions{ $id }->{ '_LOCK' } ) {
      if ( $sessions{ $id }->{ '_LOCK' } ne $lockhash ) {
        tied( %sessions )->shunlock();;
        return undef;
      }
    }
    if ( defined $sessions{ $id }->{ '_EXPIRES' } ) {
      if ( $sessions{ $id }->{ '_EXPIRES' } < time() ) {
        delete $sessions{ $id };
      }
      else {
        tied( %sessions )->shunlock();;
        return undef;
      }
    }
  }
  
  $sessions{ $id } = { '_ID'   => $id,
                       '_LOCK' => $lockhash
                     };
  
  tied( %sessions )->shunlock();;
  return { '_ID'   => $id,
           '_LOCK' => $lockhash
         };
}

sub fetch {
  my $class = shift;
  my $id    = shift;
  
  return undef unless $id;
  my $lockhash = $$.$ENV{'SERVER_NAME'};


  #my $locker = tied( %sessions );
  #$locker->shlock();
  
  tied( %sessions )->shlock();;
  if ( defined $sessions{ $id } ) {
    if ( keys % { $sessions{ $id } } == 0 ) {
      tied( %sessions )->shunlock();;
      return undef;
    }
    if ( defined $sessions{ $id }->{ '_LOCK' } ) {
      if ( $sessions{ $id }->{ '_LOCK' } ne $lockhash ) {
        tied( %sessions )->shunlock();;
        return undef;
      }
    }
    
    my %copy_of_hash = % { $sessions{ $id } };
    $copy_of_hash{ '_LOCK' } = $lockhash;
    $sessions{ $id } = \%copy_of_hash;
    tied( %sessions )->shunlock();;
    return \%copy_of_hash;
  }

  tied( %sessions )->shunlock();;
  return undef;
}

sub commit {
  tied( %sessions )->shlock();;
  my $class = shift;
  my $hashref = shift;
  my $id = $hashref->{ '_ID' };
  
  $sessions{ $id } = $hashref;
  tied( %sessions )->shunlock();;
}

sub destroy {
  tied( %sessions )->shlock();;
  my $self = shift;
  delete $sessions{ $self->{ '_ID' } };
  tied( %sessions )->shunlock();;
}

sub DESTROY {
  tied( %sessions )->shlock();;
  my $self = shift;
  my $id = $self->{ '_ID' };
  
  if (defined $sessions{ $id }) {  
    my %copy_of_hash = % { $sessions{ $id } };
    delete $copy_of_hash{ '_LOCK' };
    $sessions{ $id } = \%copy_of_hash;
  }
  tied( %sessions )->shunlock();;
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
    'IPCSession' => 'IPC Session Objects',
    sub {
        my $counter;
        my($r, $q) = @_;
        my(@s) = "<TABLE border=1><TR><TD>Session ID</TD><TD>Expires</TD><TD>Lock</TD></TR>";
        foreach my $session ( sort keys %sessions) {
          next unless ( $sessions{ $session } =~ /HASH/ );
          my $expires = localtime($sessions{$session}->{'_EXPIRES'});
          push @s, '<TR><TD>', $session, '</TD><TD>', $expires, '</TD><TD>', $sessions{$session}->{ '_LOCK' }, "</TR>\n";
          $counter++;
        }
        push @s, '</TABLE>';
        push @s, "According to the garbage collector, there have been $sessions{ 'gc_counter' } sessions.";
        push @s, "<br>$counter sessions remain in memory.";
        return \@s;
   }

) if ($INC{'Apache.pm'} && Apache->module('Apache::Status'));

1;
  
__END__

=head1 NAME

Apache::Session::IPC - Store client sessions via IPC::Shareable

=head1 SYNOPSIS

use Apache::Session::IPC

=head1 DESCRIPTION

This is an IPC storage subclass for Apache::Session.  Client state is stored
in a shared memory block.  Try C<perldoc Session> for more info.

=head1 INSTALLATION

=head2 Getting started

Build, test, and install IPC::Shareable, from CPAN.  If you don't have IPC
on your system, you can't use this module.

Build and install Apache::Session

=head2 Environment

Apache::Session::IPC does not define any environment variables beyond those
of Apache::Session.  See that package for details.

=head1 USAGE

This package complies with the API defined by Apache::Session.  For details,
please see that package's documentation.

The default for autocommit in Apache::Session::IPC is 0, which means that you
will need to either call $session->store() when you are done or set
autocommit to 1 via the open() and new() functions.

=head1 NOTES

Performance of IPC on my test system (Linux 2.0.34) is boy-howdy slow.  DBI
is approx. 80 times faster.  Also, IPC::Shareable will eventually fall over 
under heavy load.  Try to use one of the other subclasses unless your 
system's IPC is vastly better than what I have seen.

=head1 AUTHORS

Jeffrey Baker <jeff@godzilla.tamu.edu>, author and maintainer.

Redistribute under the Perl Artistic License.

