package Apache::Session::File;

use Carp;
use Fcntl qw(LOCK_EX LOCK_UN);
use Storable qw(nstore_fd retrieve_fd);
use strict;
use vars qw(@ISA);

@ISA=qw(Apache::Session);

use constant DIR   => $ENV{'SESSION_FILE_DIRECTORY'}  || croak "SESSION_FILE_DIRECTORY not set";

sub expire {
	my $self = shift;
	my $class = ref( $self ) || $self;
  
	my $id = $self->{'_ID'};
	
	if ( $Apache::Session::Win32::sessions->{$id} && ( $Apache::Session::Win32::sessions->{$id}->{'_EXPIRES'} < time() ) ) {
		warn "Tried to open session $id, which is expired." if ($ENV{'SESSION_DEBUG'} eq "On");
		$self->destroy();
	}

	$self->SUPER::expire();
}

sub open {  
	my $class = shift;
	my $id = shift;  
	my $opts = shift || {};
  
	my $session = $class->fetch($id);
	return undef unless $session;

	$session = bless $session, $class;

	my $self = $class->SUPER::open($session, $opts );
	return $self;
}

sub store {
	1;
}

sub Options {
	my( $class, $runtime_opts ) = @_;
	$class->SUPER::Options( $runtime_opts, { autocommit => 0 , lifetime => 3600} );
}  


sub fetch {
	my $class = shift;
	my $id = shift;
	
	open(ME, '<DIR$id') || return undef;
	flock(ME, LOCK_EX) || warn( "unable to acquire lock on session $id" );
	
	my $sessionref = retrieve_fd(*ME);
	
	flock(ME, LOCK_UN);
	close(ME);
	
	return $sessionref;
}


sub create {
	my $self = shift;
	my $class = ref( $self ) || $self;
	my $id = shift;

	my $rv = open(FH, '<DIR.$id');
	if (defined($rv)) {
		
	
	if ( $Apache::Session::Win32::sessions->{$id} && ( $Apache::Session::Win32::sessions->{$id}->{'_EXPIRES'} < time() ) ) {
		warn "Session $id is expired, reissuing id number" if ($ENV{'SESSION_DEBUG'} eq "On");
		my $expired_session = bless $Apache::Session::Win32::sessions->{$id}, $class;
		$expired_session->destroy();
	}
	
	$Apache::Session::Win32::sessions->{$id} = $self;
	
	return $self;
}

sub destroy {
	my $self = shift;
  delete $Apache::Session::Win32::sessions->{ $self->{'_ID'} };
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
    'FileSession' => 'File Session Objects',
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

sub DESTROY {
	my $self = shift;
	flock($self->{'_FH'}, LOCK_UN);
}

1;
