#############################################################################
#
# Apache::Session::DBIStore
# Implements session object storage via DBI
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::DBIStore;

use strict;
use DBI;
use Storable qw(freeze thaw);

$Apache::Session::DBIStore::dbh = DBI->connect('dbi:mysql:sessions','root','',
    { RaiseError => 1, AutoCommit => 1 }) || die $DBI::errstr;

$Apache::Session::DBIStore::insert_sth = 
    $Apache::Session::DBIStore::dbh->prepare_cached(qq{
        INSERT INTO sessions VALUES (?,?,?)});

$Apache::Session::DBIStore::update_sth = 
    $Apache::Session::DBIStore::dbh->prepare_cached(qq{
        UPDATE sessions SET length = ?, a_session = ? WHERE id = ?});

$Apache::Session::DBIStore::remove_sth = 
    $Apache::Session::DBIStore::dbh->prepare_cached(qq{
        DELETE FROM sessions WHERE id = ?});

$Apache::Session::DBIStore::materialize_sth = 
    $Apache::Session::DBIStore::dbh->prepare_cached(qq{
        SELECT a_session FROM sessions WHERE id = ?});


sub new {
    my $class = shift;
    
    return bless {}, $class;
}

sub connection {
    my $self    = shift;
    my $session = shift;
    
    my $dbh = DBI->connect($session->{args}->{DataSource},
        $session->{args}->{UserName}, $session->{args}->{Password},
        { RaiseError => 1, AutoCommit => 1 }) || die $DBI::errstr;

    return $dbh;
}

sub insert {
    my $self    = shift;
    my $session = shift;
 
    my $serialized = freeze $session->{data};

    $Apache::Session::DBIStore::insert_sth->bind_param(1, $session->{data}->{_session_id});
    $Apache::Session::DBIStore::insert_sth->bind_param(2, length $serialized);
    $Apache::Session::DBIStore::insert_sth->bind_param(3, $serialized);
    
    $Apache::Session::DBIStore::insert_sth->execute;

    $Apache::Session::DBIStore::insert_sth->finish;
}


sub update {
    my $self    = shift;
    my $session = shift;
 
    my $serialized = freeze $session->{data};

    $Apache::Session::DBIStore::update_sth->bind_param(1, length $serialized);
    $Apache::Session::DBIStore::update_sth->bind_param(2, $serialized);
    $Apache::Session::DBIStore::update_sth->bind_param(3, $session->{data}->{_session_id});
    
    $Apache::Session::DBIStore::update_sth->execute;

    $Apache::Session::DBIStore::update_sth->finish;
}

sub materialize {
    my $self    = shift;
    my $session = shift;

    $Apache::Session::DBIStore::materialize_sth->bind_param(1, $session->{data}->{_session_id});
    
    $Apache::Session::DBIStore::materialize_sth->execute;
    
    my $results = $Apache::Session::DBIStore::materialize_sth->fetchrow_arrayref;

    if (!(defined $results)) {
        die "Object does not exist in the data store";
    }

    $Apache::Session::DBIStore::materialize_sth->finish;

    $session->{data} = thaw $results->[0];
}

sub remove {
    my $self    = shift;
    my $session = shift;

    $Apache::Session::DBIStore::remove_sth->bind_param(1, $session->{data}->{_session_id});
    
    $Apache::Session::DBIStore::remove_sth->execute;
    $Apache::Session::DBIStore::remove_sth->finish;
}

1;
