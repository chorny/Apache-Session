############################################################################
#
# Apache::Session::DBI
# Apache persistent user sessions via a DBI compliant DBMS.
# Copyright(c) 1998 Jeffrey William Baker (jeff@godzilla.tamu.edu)
# Distribute under the Artistic License
#
############################################################################


package Apache::Session::DBI;
use Apache::Session ();

@Apache::Session::DBI::ISA = qw(Apache::Session);
$Apache::Session::DBI::VERSION = '0.04';

use Carp;
use DBI;
use FreezeThaw qw(freeze thaw);
use strict;

use constant DSN   => $ENV{'SESSION_DBI_DATASOURCE'} || warn "SESSION_DBI_DATASOURCE should be set in httpd.conf";
use constant USER  => $ENV{'SESSION_DBI_USERNAME'}   || undef;
use constant PASS  => $ENV{'SESSION_DBI_PASSWORD'}   || undef;

my $db_ac = ( DSN =~ /mSQL|mysql/ )  ? 1 : 0; #m(y)SQL doesn't support transactions

my ( $dbh, $sth_lock, $sth_unlock, $sth_destroy, $sth_create, $sth_update, $sth_get_length );
sub init_connection {
  if ( $dbh ) {
    eval {
      local $SIG{__DIE__};
      $dbh->ping() || die;
    };
    if ( !$@ ) {
      return;
    }
  }

  warn "Session manager opening persistent connection";
  
  $dbh = DBI->connect(DSN, USER, PASS, {
     PrintError  => 1,
     RaiseError  => 1,
     AutoCommit  => $db_ac,
     LongReadLen => 0
  }) || die $DBI::errstr;

  #preparing the statement handles and using bind_param at runtime 
  #results in about 2x speed improvement on my system
  $sth_lock       = $dbh->prepare( "INSERT INTO locks VALUES ( ? )" )                                       || die $DBI::errstr;
  $sth_unlock     = $dbh->prepare( "DELETE FROM locks WHERE id = ?" )                                          || die $DBI::errstr;
  $sth_destroy    = $dbh->prepare( "DELETE FROM sessions WHERE id = ?" )                                       || die $DBI::errstr;
  $sth_create     = $dbh->prepare( "INSERT INTO sessions (id, expires, length, a_session) VALUES ( ?, ?, ?, ? )" )         || die $DBI::errstr;
  $sth_update     = $dbh->prepare( "UPDATE sessions SET a_session = ?, length = ?, expires = ? WHERE id = ?" ) || die $DBI::errstr;
  $sth_get_length = $dbh->prepare( "SELECT length FROM sessions WHERE id = ?" )                                || die $DBI::errstr;
}

sub glock {
  my $id = shift;
  return undef unless $id;

  init_connection;

  eval {
    local $SIG{__DIE__};
    $sth_lock->bind_param( 1, $id, $DBI::SQL_VARCHAR );
    $sth_lock->execute();
  };
    
  if ($@) {
    warn "Lock for session $id failed: $@";
    $dbh->rollback() unless $db_ac;
    return undef;
  }
  
  $dbh->commit() unless $db_ac;
  return 1;
}

sub gunlock {
  my $id = shift;

  init_connection;

  eval {
    local $SIG{__DIE__};
    $sth_unlock->bind_param( 1, $id, $DBI::SQL_VARCHAR );
    $sth_unlock->execute() || die $DBI::errstr;
  };
  
  if ($@) {
    warn "unlock for $id failed: $@";
    $dbh->rollback() unless $db_ac;
    return undef;
  }
  
  $dbh->commit() unless $db_ac;
  return 1;
}

sub safe_connect {
  my $dbh;
  
  eval {
    local $SIG{__DIE__}; 
    $dbh = DBI->connect(DSN, USER, PASS, {
        PrintError => 1,
        AutoCommit => $db_ac
    }) || die $DBI::errstr;
  };
  
  if ($@) {
    warn "Database not connected: $@";
    return undef;
  }
  
  return $dbh;
}

sub safe_thaw {
  my $frozen = shift;
  return undef unless ( $frozen =~ /^FrT/ );
  return thaw( $frozen );
}

sub options {
  { autocommit => 0,
    lifetime   => $ENV{'SESSION_LIFETIME'}
  };
}

sub create {
  my $class = shift;
  my $id    = shift;
  return undef unless glock( $id );

  init_connection;

  my $sth_get = "";
  my $expires = 0;
  eval {
    local $SIG{__DIE__};
    $sth_get = $dbh->prepare( "SELECT expires FROM sessions WHERE id = ?" ) || die $DBI::errstr;
    $sth_get->bind_param( 1, $id, $DBI::SQL_VARCHAR );
    $sth_get->execute() || die $DBI::errstr;
    $sth_get->bind_columns( undef, \$expires);
    $sth_get->fetch;
  };
  
  if ( $@ ) {
    warn "Database error in create: $@";
    gunlock( $id );
    return undef;
  }

  if ( $expires < time() ) { #check its expiration time
    eval {
      local $SIG{__DIE__};
      $sth_destroy->bind_param( 1, $id, $DBI::SQL_VARCHAR );
      $sth_destroy->execute() || die $DBI::errstr;
    };

    if ( $@ ) {
      warn "Destruction of expired session $id failed: $@";
      gunlock( $id );
      $dbh->rollback() unless $db_ac;
      return undef;
    }

    $dbh->commit() unless $db_ac;
  }

  else { #old session wasn't expired yet
    gunlock( $id );
    return undef;
  }
  
  my $rv = {};
  my $frozen = freeze( $rv );

  
  eval {
    local $SIG{__DIE__};
    $sth_create->bind_param( 1, $id,               $DBI::SQL_VARCHAR );
    $sth_create->bind_param( 2, undef,             $DBI::SQL_INTEGER );    
    $sth_create->bind_param( 3, length( $frozen ), $DBI::INTEGER );
    $sth_create->bind_param( 4, $frozen,           $DBI::SQL_VARCHAR );
    $sth_create->execute() || die $DBI::errstr;
  };
  
  if ($@) {
    warn "Database error in create(): $@";
    $dbh->rollback() unless $db_ac; 
    return undef;
  }

  $dbh->commit() unless $db_ac;
  return $rv;
}

sub fetch {
  my $class = shift;
  my $id    = shift;
  
  init_connection;
  
  return undef unless glock( $id );
  
  my $length;
  eval {
    local $SIG{__DIE__};
    $sth_get_length->bind_param( 1, $id, $DBI::SQL_VARCHAR );
    $sth_get_length->execute();
    ( $length ) = $sth_get_length->fetchrow_array();
  };

  $dbh->{'LongReadLen'} = $length;
  
  my ($sth_get, $db_id, $db_data);
  eval {
    local $SIG{__DIE__};
    $sth_get = $dbh->prepare( "SELECT id, a_session FROM sessions WHERE id = ?" ) || die $DBI::errstr;
    $sth_get->bind_param( 1, $id, $DBI::SQL_VARCHAR );
    $sth_get->execute() || die $DBI::errstr;
    $sth_get->bind_columns(undef, \$db_id, \$db_data);
    $sth_get->fetch();
  };

  $dbh->{'LongReadLen'} = 0;

  if ( $@ ) {
    warn "Fetch failed for session $id: $@";
    gunlock( $id );
    return undef;
  }
  
  my ( $oldhash ) = safe_thaw( $db_data );
  
  if ( ! ( $oldhash =~ /HASH/ ) ) {
    gunlock( $id );
    return undef;
  }
  
  return $oldhash;
}

sub commit {
  my $class   = shift;
  my $hashref = shift;

  init_connection;
  
  my $id = $hashref->{ '_ID' };
  my $frozen_self = freeze ($hashref);

  eval {  
    local $SIG{__DIE__}; 
    $sth_update->bind_param( 1, $frozen_self, $DBI::SQL_VARCHAR );
    $sth_update->bind_param( 2, length( $frozen_self ), $DBI::SQL_VARCHAR );
    $sth_update->bind_param( 3, $hashref->{'_EXPIRES'}, $DBI::SQL_INTEGER );
    $sth_update->bind_param( 4, $id, $DBI::SQL_VARCHAR );
    $sth_update->execute() || die $DBI::errstr;
  };
  
  if ( $@ ) {
    $dbh->rollback() unless $db_ac;
    return undef;
  }
  
  $dbh->commit() unless $db_ac;
  return 1;
}

sub destroy {
  my $self = shift;
  my $id   = $self->{ '_ID' };
    
  init_connection;
  
  eval {
    local $SIG{__DIE__}; 
    $sth_destroy->bind_param( 1, $id, $DBI::SQL_VARCHAR );
    $sth_destroy->execute() || die $DBI::errstr;
  };
  
  if ($@) {
    gunlock( $id );
    $dbh->rollback() unless $db_ac;    
    return undef;
  }
  
  $dbh->commit() unless $db_ac;
  gunlock( $id );
  return 1;
}

sub DESTROY {
  my $self = shift;
  my $id = $self->{ '_ID' };
  gunlock( $id );
}
  
sub dump_to_html {
  my $self = shift;
  my $s = "";
  my $key = "";
  
  $s = $s."<table border=1>\n\t<tr>\n\t\t<td>Variable Name</td>\n\t\t<td>Scalar Value</td>\n\t</tr>";
  foreach $key ( sort( keys( % { $self } ) ) ) {
      $s = $s."\n\t<tr>\n\t\t<td>$key</td>\n\t\t<td>$self->{$key}</td>";
  }
  $s = $s."\n</table>\n";
  return $s;
}

1;

__END__

=head1 NAME

Apache::Session::DBI - Store client sessions in your DBMS

=head1 SYNOPSIS

use Apache::Session::DBI

=head1 DESCRIPTION

This is a DBI storage subclass for Apache::Session.  Client state is stored
in a database via the DBI module.  Try C<perldoc Session> for more info.

=head1 INSTALLATION

=head2 Getting started

The first thing that you will need to do is select a database for use by
this package.  The primary concerns are transaction support and the atomicity
of the C<INSERT> statement.  If your DBMS's C<INSERT> is non-atomic, there is
the possibility that the locking mechanism employed here will not work.  
Transaction support is not critical, but it can help stop the madness when 
something goes awry.

You will need to create two tables in your database for Session::DBI to use.
They are named "sessions" and "locks".  Sessions should have four columns, 
"id", "expires", "length", and "session", where id is the primary key or unique index.  id should
have a datatype of CHAR(n), where n is the length of your session id (default 
16).  The column "session" needs to be a variable-length field which can hold
ASCII data.  Depending on you DBMS, "session" will be of type TEXT or LONG.  A
typical SQL statement to setup this table might look like:
 
 CREATE TABLE sessions (
   id CHAR(16) NOT NULL, 
   expires INTEGER,
   length INTEGER,
   a_session TEXT, 
   PRIMARY KEY ( id ) 
 )

The "expires" column is largely ignored by the module.  Since the module
does not actively garbage collect, this column is conveniently provided so
that you can clean out your sessions table occassionally.

The table "locks" needs only one column, "id", which is identical to the id
in "sessions".  It is essential that "id" be a unique index.  For example:

 CREATE TABLE locks (
   id CHAR(16) NOT NULL,
   PRIMARY KEY ( id )
 )

Now, build, test, and install DBI, Apache::DBI, DBD::yourdbms, MD5, and
FreezeThaw.  Apache::DBI is not actually required, but it is recommended.
Finally, build and install Apache::Session.

=head2 Environment

You will need to configure your environment to get Session::DBI to work.  You
should define:

=over 4

=item SESSION_DBI_DATASOURCE

This is the DBI datasource string used in DBI->connect(), which is usually
in the form DBI:vendor:databasename.

=item SESSION_DBI_USERNAME

The username used to connect to the datasourse.  The user must have SELECT,
UPDATE, INSERT, and DELETE priviledges.

=item SESSION_DBI_PASSWORD

The password that corresponds to the user from above.

=back

I define these variables in my httpd.conf:

 PerlSetEnv SESSION_DBI_DATASOURCE DBI:mysql:sessions
 PerlSetEnv SESSION_DBI_USERNAME jeff
 PerlSetEnv SESSION_DBI_PASSWORD password
 
=head1 USAGE

This package complies with the API defined by Apache::Session.  For details,
please see that package's documentation.

The default for autocommit in Apache::Session::DBI is 0, which means that you
will need to either call $session->store() when you are done or set
autocommit to 1 via the open() and new() functions.  (Note: This
autocommit is separate from DBI's AutoCommit).

=head1 NOTES

I used FreezeThaw to serialize data structures here.  Storable is faster.
However, FreezeThaw returns ASCII strings which play nicely with all known
databases, while Storable generates binary scalars which are less friendly.
In particular, Storable-generated scalars cannot be thawed out of an mSQL
database.  If you are using a database such as Oracle or mysql, you 
may want to replace C<use FreezeThaw> with C<use Storable> at the top
of DBI.pm.  Actually, Storable's byte-order-independent C<nfreeze> would
be a better choice.

=head1 AUTHORS

Jeffrey Baker <jeff@godzilla.tamu.edu>, author and maintainer.

Redistribute under the Perl Artistic License.

