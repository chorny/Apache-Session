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

sub new {
    my $class = shift;
    
    return bless {}, $class;
}

sub connection {
    my $self    = shift;
    my $session = shift;
    
    return if (defined $self->{dbh});

    $self->{dbh} = DBI->connect($session->{args}->{DataSource},
        $session->{args}->{UserName}, $session->{args}->{Password},
        { RaiseError => 1, AutoCommit => 1 }) || die $DBI::errstr;
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

    my $serialized = freeze $session->{data};

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


    my $serialized = freeze $session->{data};

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
