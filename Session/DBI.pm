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
$Apache::Session::DBI::VERSION = '0.02';

use Carp;
use DBI;
use FreezeThaw qw(freeze thaw);
use strict;

use constant DSN   => $ENV{'SESSION_DBI_DATASOURCE'} || croak "SESSION_DBI_DATASOURCE not set";
use constant USER  => $ENV{'SESSION_DBI_USERNAME'}   || undef;
use constant PASS  => $ENV{'SESSION_DBI_PASSWORD'}   || undef;

my $db_ac = ( DSN =~ /mSQL/ || DSN =~ /mysql/)  ? 1 : 0; #m(y)SQL doesn't support transactions

my $dbh = DBI->connect(DSN, USER, PASS, {
   PrintError => 1,
   AutoCommit => $db_ac
}) || die $DBI::errstr;

#preparing the statement handles and using bind_param at runtime 
#results in about 2x speed improvement on my system
my $sth_lock    = $dbh->prepare( "INSERT INTO locks (id) VALUES (?)" ) || die $DBI::errstr;
my $sth_unlock  = $dbh->prepare( "DELETE FROM locks WHERE id = ?" ) || die $DBI::errstr;
my $sth_get     = $dbh->prepare( "SELECT id, session FROM sessions WHERE id = ?" ) || die $DBI::errstr;
my $sth_destroy = $dbh->prepare( "DELETE FROM sessions WHERE id = ?" ) || die $DBI::errstr;
my $sth_create  = $dbh->prepare( "INSERT INTO sessions (id, session) VALUES ( ?, ? )" ) || die $DBI::errstr;
my $sth_update  = $dbh->prepare( "UPDATE sessions SET session = ? WHERE id = ?" ) || die $DBI::errstr;

sub glock {
  my $id = shift;
  return undef unless $id;

#  my $dbh = safe_connect();
#  if (!$dbh) {
#    return undef;
#  }

  $sth_lock->bind_param( 1, $id, $DBI::SQL_STRING );
  eval {
    local $SIG{__DIE__};
    $sth_lock->execute() || die $DBI::errstr;
  };
    
  if ($@) {
    warn "Lock for $id failed: $@";
    $dbh->rollback() unless $db_ac;
    return undef;
  }
  
  $dbh->commit() unless $db_ac;
  return 1;
}

sub gunlock {
  my $id = shift;
#  my $dbh = safe_connect();
#  if (!$dbh) {
#    return undef;
#  }

  $sth_unlock->bind_param( 1, $id, $DBI::SQL_STRING );
  eval {
    local $SIG{__DIE__};
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
  return undef unless ( $frozen =~ /FrT/ );
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
  
  $sth_get->bind_param( 1, $id, $DBI::SQL_STRING );
  eval {
    local $SIG{__DIE__};
    $sth_get->execute() || die $DBI::errstr;
  };
  
  if ( $@ ) {
    warn "Database error in create: $@";
    gunlock( $id );
    return undef;
  }
  
  my( $old_id, $old_data );
  $sth_get->bind_columns( undef, \$old_id, \$old_data );
  $sth_get->fetch;
  
  if ( $old_id ) { #if this session already exists...
    my $oldhash = safe_thaw( $old_data );
    unless ( $oldhash =~ /HASH/ ) {
      gunlock( $id );
      return undef;
    }
    if ( $oldhash->{ '_EXPIRES' } < time() ) { #check its expiration time
      $sth_destroy->bind_param( 1, $id, $DBI::SQL_STRING );
      eval {
        local $SIG{__DIE__};
        $sth_destroy->execute() || die $DBI::errstr;
      };
      
      if ( $@ ) {
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
  }
  
  my $rv = {};
  my $frozen = freeze( $rv );

  $sth_create->bind_param( 1, $id, $DBI::SQL_STRING );
  $sth_create->bind_param( 2, $frozen, $DBI::SQL_STRING );
  
  eval {
    local $SIG{__DIE__};
    $sth_create->execute() || die $DBI::errstr;
  };
  
  if ($@) {
    gunlock( $id );
    $dbh->rollback() unless $db_ac; 
    return undef;
  }

  $dbh->commit() unless $db_ac;
  
  return $rv;
}

sub fetch {
  my $class = shift;
  my $id    = shift;
    
  return undef unless glock( $id );

  $sth_get->bind_param( 1, $id, $DBI::SQL_STRING );
  eval {
    local $SIG{__DIE__};
    $sth_get->execute() || die $DBI::errstr;
  };
  
  if ( $@ ) {
    warn "Fetch failed for session $id: $@";
    gunlock( $id );
    return undef;
  }
  
  my ($db_id, $db_data);
  $sth_get->bind_columns(undef, \$db_id, \$db_data);
  $sth_get->fetch;
  
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
  
  my $id = $hashref->{ '_ID' };
  my $frozen_self = freeze ($hashref);

  $sth_update->bind_param( 1, $frozen_self, $DBI::SQL_STRING );
  $sth_update->bind_param( 2, $id, $DBI::SQL_STRING );
  
  eval {  
    local $SIG{__DIE__}; 
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
    
  $sth_destroy->bind_param( 1, $id, $DBI::SQL_STRING );
  
  eval {
    local $SIG{__DIE__}; 
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
They are named "sessions" and "locks".  Sessions should have two columns, 
"id" and "session", where id is the primary key or unique index.  id should
have a datatype of CHAR(n), where n is the length of your session id (default 
16).  The column "session" needs to be a variable-length field which can hold
ASCII data.  Depending on you DBMS, "session" will be of type TEXT or LONG.  A
typical SQL statement to setup this table might look like:
 
 CREATE TABLE sessions (
   id CHAR(16) NOT NULL, 
   sessions TEXT, 
   PRIMARY KEY ( id ) 
 )

The table "locks" needs on ly one column, "id", which is identical to the id
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

