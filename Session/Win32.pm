package Apache::Session::Win32;

$Apache::Session::Win32::VERSION = '0.01';

use vars qw(@ISA);

@ISA=qw(Apache::Session);

BEGIN{ $Apache::Session::Win32::sessions = {} };

###########################################################
# sub create
#
# The subclass's create routine is called by the base class's
# insert routine, after an object has been blessed into your
# subclass.  Create() needs to check to make sure that it
# can create a session with the requested ID, and then create 
# the session in the physical storage.  Return undef
# on failure, $self on success.
###########################################################

sub create {
	my $self = shift;
	my $class = ref( $self ) || $self;
	my $id = shift;
  
	if ( $Apache::Session::Win32::sessions->{$id} && ( $Apache::Session::Win32::sessions->{$id}->{'_EXPIRES'} > time() ) ) {
		warn "Tried to clobber unexpired session $id in $class->create()" if ($ENV{'SESSION_DEBUG'} eq "On");
		return undef;
	}
	
	if ( $Apache::Session::Win32::sessions->{$id} && ( $Apache::Session::Win32::sessions->{$id}->{'_EXPIRES'} < time() ) ) {
		warn "Session $id is expired, reissuing id number" if ($ENV{'SESSION_DEBUG'} eq "On");
		my $expired_session = bless $Apache::Session::Win32::sessions->{$id}, $class;
		$expired_session->destroy();
	}
	
	$Apache::Session::Win32::sessions->{$id} = $self;
	
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

	my $self = $class->SUPER::open($session, $opts );
	return $self;
}

###########################################################
# sub fetch
#
# Fetch is used to retrieve the sesion from physical storage.
# Fetch is called from the subclass's open().
###########################################################

sub fetch {
	my $class = shift;
	my $id = shift;
	
	return $Apache::Session::Win32::sessions->{$id};
}

###########################################################
# sub store
#
# Store is used to commit changes in the session object to
# physical storage.  Store is called depending on whether
# autocommit is on or off in the options hash.  If autocommit
# is true, store() is called every time the session object is
# modified.  If autocommit is false, store() is only called if
# the client program calls it explicitly.
###########################################################

sub store {
	1;
}

###########################################################
# sub expire

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


sub Options {
	my( $class, $runtime_opts ) = @_;
	$class->SUPER::Options( $runtime_opts, { autocommit => 1 , lifetime => 3600} );
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