#############################################################################
#
# Apache::Session::DBIStore
# Implements session object storage via DBI
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

=head1 NAME

Apache::Session::DBIStore - Session persistence via DBI

=head1 SYNOPSIS

=head1 DESCRIPTION

Apache::Session::DBIStore is a backing store module for Apache::Session.
Session data is stored in a DBI-accessible database.

=head1 SCHEMA

To use this module, you will need these columns in a table 
called 'sessions':

 id char(16)
 length int(11)
 a_session text

Where the a_session column needs to be able to handle arbitrarily
long binary data.

=head1 CONFIGURATION

When using DBI, the module must know what datasource, username, and password
to use when connecting to the database.  These values can be set for all
sessions by using package globals, or for each individual session using
the options hash (see Apache::Session documentation).  The options are:

Package globals:

=over 4

=item $Apache::Session::DBIStore::DataSource

=item $Apache::Session::DBIStore::UserName

=item $Apache::Session::DBIStore::Password

=back

Corresponding options:

=over 4

=item DataSource

=item UserName

=item Password

=back

Example with options:

 tie %hash, 'Apache::Session::DBI', $id, {
     DataSource => 'dbi:driver:database',
     UserName   => 'database_user',
     Password   => 'K00l'
 };
 
Example with package globals:

 $Apache::Session::DBIStore::DataSource = 'dbi:driver:database';
 $Apache::Session::DBIStore::UserName   = 'database_user';
 $Apache::Session::DBIStore::Password   = 'K00l';
 
 tie %hash, 'Apache::Session::DBI', $id;


=cut

package Apache::Session::DBIStore;

use strict;

use DBI;
use Storable qw(nfreeze thaw);

use vars qw($VERSION);

$VERSION = '1.00';

$Apache::Session::DBIStore::DataSource = undef;
$Apache::Session::DBIStore::UserName   = undef;
$Apache::Session::DBIStore::Password   = undef;

sub new {
    my $class = shift;
    
    return bless {}, $class;
}

sub connection {
    my $self    = shift;
    my $session = shift;
    
    return if (defined $self->{dbh});

    my $datasource = $session->{args}->{DataSource} || 
        $Apache::Session::DBIStore::DataSource;
    my $username = $session->{args}->{UserName} ||
        $Apache::Session::DBIStore::UserName;
    my $password = $session->{args}->{Password} ||
        $Apache::Session::DBIStore::Password;
        
    $self->{dbh} = DBI->connect(
        $datasource,
        $username,
        $password,
        { RaiseError => 1, AutoCommit => 1 }
    ) || die $DBI::errstr;
}

sub insert {
    my $self    = shift;
    my $session = shift;
 
    $self->connection($session);

    if (!defined $self->{insert_sth}) {
        $self->{insert_sth} = 
            $self->{dbh}->prepare_cached(qq{
                INSERT INTO sessions (id, length, a_session) VALUES (?,?,?)});
    }

    my $serialized = nfreeze $session->{data};
    
    $self->{insert_sth}->bind_param(1, $session->{data}->{_session_id});
    $self->{insert_sth}->bind_param(2, length $serialized);
    $self->{insert_sth}->bind_param(3, $serialized);
    
    $self->{insert_sth}->execute;

    $self->{insert_sth}->finish;
}


sub update {
    my $self    = shift;
    my $session = shift;
 
    $self->connection($session);

    if (!defined $self->{update_sth}) {
        $self->{update_sth} = 
            $self->{dbh}->prepare_cached(qq{
                UPDATE sessions SET length = ?, a_session = ? WHERE id = ?});
    }


    my $serialized = nfreeze $session->{data};

    $self->{update_sth}->bind_param(1, length $serialized);
    $self->{update_sth}->bind_param(2, $serialized);
    $self->{update_sth}->bind_param(3, $session->{data}->{_session_id});
    
    $self->{update_sth}->execute;

    $self->{update_sth}->finish;
}

sub materialize {
    my $self    = shift;
    my $session = shift;

    $self->connection($session);

    if (!defined $self->{materialize_sth}) {
        $self->{materialize_sth} = 
            $self->{dbh}->prepare_cached(qq{
                SELECT a_session FROM sessions WHERE id = ?});
    }
    
    $self->{materialize_sth}->bind_param(1, $session->{data}->{_session_id});
    
    $self->{materialize_sth}->execute;
    
    my $results = $self->{materialize_sth}->fetchrow_arrayref;

    if (!(defined $results)) {
        die "Object does not exist in the data store";
    }

    $self->{materialize_sth}->finish;

    $session->{data} = thaw $results->[0];
}

sub remove {
    my $self    = shift;
    my $session = shift;

    $self->connection($session);

    if (!defined $self->{remove_sth}) {
        $self->{remove_sth} = 
            $self->{dbh}->prepare_cached(qq{
                DELETE FROM sessions WHERE id = ?});
    }

    $self->{remove_sth}->bind_param(1, $session->{data}->{_session_id});
    
    $self->{remove_sth}->execute;
    $self->{remove_sth}->finish;
}

sub DESTROY {
    my $self = shift;
    
    if (ref $self->{dbh}) {
        $self->{dbh}->disconnect;
    }
}

1;
