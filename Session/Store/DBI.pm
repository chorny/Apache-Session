#############################################################################
#
# Apache::Session::Store::DBI
# A base class for the MySQL, Postgres, and other DBI stores
# Copyright(c) 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::Store::DBI;

use strict;
use DBI;

use vars qw($VERSION);

$VERSION = '1.01';

sub new {
    my $class = shift;
    
    return bless {}, $class;
}

sub insert {
    my $self    = shift;
    my $session = shift;
 
    $self->connection($session);

    local $self->{dbh}->{RaiseError} = 1;

    if (!defined $self->{insert_sth}) {
        $self->{insert_sth} = 
            $self->{dbh}->prepare_cached(qq{
                INSERT INTO sessions (id, a_session) VALUES (?,?)});
    }

    $self->{insert_sth}->bind_param(1, $session->{data}->{_session_id});
    $self->{insert_sth}->bind_param(2, $session->{serialized});
    
    $self->{insert_sth}->execute;

    $self->{insert_sth}->finish;
}


sub update {
    my $self    = shift;
    my $session = shift;
 
    $self->connection($session);

    local $self->{dbh}->{RaiseError} = 1;

    if (!defined $self->{update_sth}) {
        $self->{update_sth} = 
            $self->{dbh}->prepare_cached(qq{
                UPDATE sessions SET a_session = ? WHERE id = ?});
    }

    $self->{update_sth}->bind_param(1, $session->{serialized});
    $self->{update_sth}->bind_param(2, $session->{data}->{_session_id});
    
    $self->{update_sth}->execute;

    $self->{update_sth}->finish;
}

sub materialize {
    my $self    = shift;
    my $session = shift;

    $self->connection($session);

    local $self->{dbh}->{RaiseError} = 1;

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

    $session->{serialized} = $results->[0];
}

sub remove {
    my $self    = shift;
    my $session = shift;

    $self->connection($session);

    local $self->{dbh}->{RaiseError} = 1;

    if (!defined $self->{remove_sth}) {
        $self->{remove_sth} = 
            $self->{dbh}->prepare_cached(qq{
                DELETE FROM sessions WHERE id = ?});
    }

    $self->{remove_sth}->bind_param(1, $session->{data}->{_session_id});
    
    $self->{remove_sth}->execute;
    $self->{remove_sth}->finish;
}

1;
