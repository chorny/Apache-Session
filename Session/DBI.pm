package Apache::Session::DBI;

use CGI::Carp qw(fatalsToBrowser);
use DBI;
use Apache::DBI;
use Storable qw(freeze thaw);
use strict;
use vars qw(@ISA);

@ISA=qw(Apache::Session);

use constant DSN   => $ENV{'SESSION_DBI_DATASOURCE'}  || croak "SESSION_DBI_DATASOURCE not set";
use constant USER  => $ENV{'SESSION_DBI_USERNAME'} || croak "SESSION_DBI_USERNAME not set";
use constant PASS  => $ENV{'SESSION_DBI_PASSWORD'} || croak "SESSION_DBI_PASSWORD not set";
use constant TABLE => $ENV{'SESSION_DBI_TABLE'} || croak "SESSION_DBI_TABLE not set";

sub open {  
	my $class = shift;
	my $id = shift;  
	my $opts = shift || {};
  
	my $session = $class->fetch($id);
	return undef unless $session;

	my $self = $class->SUPER::open($session, $opts );
	return $self;
}

sub fetch {
	my $self = shift;
	my $id = shift;
	
	my $dbh;
	my $sth;	
	
	eval {
		local $SIG{__DIE__}; 
		$dbh = DBI->connect(DSN, USER, PASS, {
				PrintError => 1,
				AutoCommit => 0
		}) || die $DBI::errstr;
	};
	
	croak "Database not connected to DSN" if $@;
	
	eval {
	
		local $SIG{__DIE__}; 
		$sth = $dbh->prepare("SELECT data FROM ".TABLE." WHERE id = '$id'");
		$sth->execute;
	
	};
	
	croak "Could not prepare SQL statement" if $@;

	my ( $session )= $sth->fetchrow_array;
	
	$sth->finish();
	$dbh->disconnect();
	
	$session = thaw($session);
	
	return $session;
}

sub expire {
	my $self = shift;
	my $class = ref( $self ) || $self;
  
	my $id = $self->{'META'}->{'ID'};
	
	#garbage collector
#	foreach my $session (keys(%$Apache::Session::Win32::sessions)) {
#	  if ( $Apache::Session::Win32::sessions->{$session}->{'expiration_time'} < time() ) {
#	    delete $Apache::Session::Win32::sessions->{$session};
#	  }
#	}

	if ( $self->{'META'}->{'EXPIRES'} < time() ) {
		warn "Tried to open session $id, which is expired." if ($ENV{'SESSION_DEBUG'} eq "On");
		
		$self->destroy();
	}

	$self->SUPER::expire();
}


sub store {
	my $self = shift;
	
	my $id = $self->{'META'}->{'ID'};
	
	my $dbh;
	my $sth;
	
	my $frozen_self = freeze ($self);
	
	eval {
		local $SIG{__DIE__}; 
		$dbh = DBI->connect(DSN, USER, PASS, {
				PrintError => 1,
				AutoCommit => 0
		}) || die $DBI::errstr;
	};
	
	croak "Database not connected to DSN" if $@;
	
	eval {
	
		local $SIG{__DIE__}; 
		$sth = $dbh->prepare("UPDATE ".TABLE." SET data = $frozen_self WHERE id = '$id.'");
		$sth->execute;
	
	};
	
	if ($@) {
		$dbh->rollback();
		$dbh->disconnect();
		
		croak "Could not update $id in storage";
	}
	
	$dbh->commit();
	$sth->finish();
	$dbh->disconnect();
	
	1;
}

sub Options {
	my( $class, $runtime_opts ) = @_;
	$class->SUPER::Options( $runtime_opts, { autocommit => 1 , lifetime => 3600} );
}  


sub create {
	my $self = shift;
	my $class = ref( $self ) || $self;
	my $id = shift;
	
	my $dbh;
	my $sth;	
	
	eval {
		local $SIG{__DIE__}; 
		$dbh = DBI->connect(DSN, USER, PASS, {
				PrintError => 1,
				AutoCommit => 0
		}) || die $DBI::errstr;
	};
	
	croak "Database not connected to DSN" if $@;
	
	eval {
	
		local $SIG{__DIE__}; 
		$sth = $dbh->prepare("SELECT data FROM ".TABLE." WHERE id = '$id.'");
		$sth->execute;
	
	};
	
	if ($@) {
		$sth->finish();
		$dbh->disconnect();
		
		croak "Could not execute SQL statement in create" if $@;
	}
	
	my ( $session )= $sth->fetchrow_array;
	
	warn "In create, fetched session is $session";

	$session = thaw ($session);
	
	warn "After thaw, \$session is $session";

	if ( (defined $session) && ($session->{'META'}->{'EXPIRES'} > time())) {
		warn "Tried to clobber unexpired session $id in $class->create()" if ($ENV{'SESSION_DEBUG'} eq "On");

		$sth->finish();
		$dbh->disconnect();

		return undef;
	}
	
	if ( (defined $session) && ( $session->{'META'}->{'EXPIRES'} < time() ) )  {
		warn "Session $id is expired, reissuing id number" if ($ENV{'SESSION_DEBUG'} eq "On");
		
		my $expired_session = bless \$session, $class;
		$expired_session->destroy($id);
	}
	
	warn "Before freeze in create, self is $self";
	my $frozen_self = freeze ($self);
	warn "After freeze in create, frozen_self is $frozen_self";
	
	open (FH, '>c:/raw.txt');
	print FH $frozen_self;
	close FH;
	
	eval {
	
		local $SIG{__DIE__}; 
		$sth = $dbh->prepare("INSERT INTO ".TABLE." VALUES ('$id', ?)");
		$sth->bind_param("1",$frozen_self, { ora_type => 24});
		$sth->execute;
	
	};
	
	if (@$) {
		$dbh->rollback();
		$dbh->disconnect();
		
		croak "Could not insert new session $id";
	}

	$dbh->commit();
	$sth->finish();
	$dbh->disconnect();
	
	return $self;
}

sub destroy {
	my $self = shift;
	my $id = shift;
	
	my $dbh;
	my $sth;	
	
	eval {
		local $SIG{__DIE__}; 
		$dbh = DBI->connect(DSN, USER, PASS, {
				PrintError => 1,
				AutoCommit => 0
		}) || die $DBI::errstr;
	};
	
	croak "Database not connected to DSN" if $@;
	
	eval {
	
		local $SIG{__DIE__}; 
		$sth = $dbh->prepare("DELETE FROM ".TABLE." WHERE id = '".$id."'");
		$sth->execute;
	
	};
	
	if ($@) {
		$dbh->rollback();
		$dbh->disconnect();
		
		croak "$@, Could not delete session from storage";
	}
	
	$sth->finish();
	$dbh->disconnect();

	return 1;
}

1;
