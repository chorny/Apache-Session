############################################################################
#
# Apache::Session::Lock::MySQL
# MySQL locking for Apache::Session
# Copyright(c) 2000 Jeffrey William Baker (jwbaker@acm.org)
# Distribute under the Perl License
#
############################################################################

package Apache::Session::Lock::MySQL;

use strict;

use DBI;
use vars qw($VERSION);

$VERSION = '1.01';

sub new {
    my $class = shift;
    
    return bless {lock => 0, lockid => undef, dbh => undef, mine => 0}, $class;
}

sub acquire_read_lock  {
    my $self    = shift;
    my $session = shift;
    
    return if $self->{lock};

    if (!defined $self->{dbh}) {
        if (defined $session->{args}->{LockHandle}) {
            $self->{dbh} = $session->{args}->{LockHandle};
        }
        else {
            if (!$session->{args}->{LockDataSource}) {
                die "LockDataSource not provided for Apache::Session::Lock::MySQL";
            }
            $self->{dbh} = DBI->connect(
                $session->{args}->{LockDataSource},
                $session->{args}->{LockUserName},
                $session->{args}->{LockPassword},
                { RaiseError => 1, AutoCommit => 1 }
            );
            $self->{mine} = 1;
        }
    }

    local $self->{dbh}->{RaiseError} = 1;

    $self->{lockid} = "Apache-Session-$session->{data}->{_session_id}";
    
    #MySQL requires a timeout on the lock operation.  There is no option
    #to simply wait forever.  So we'll wait for a hour.
    
    my $sth = $self->{dbh}->prepare_cached(q{SELECT GET_LOCK(?, 3600)}, {}, 1);
    $sth->execute($self->{lockid});
    $sth->finish();
    
    $self->{lock} = 1;
}

sub acquire_write_lock {
    $_[0]->acquire_read_lock($_[1]);
}

sub release_read_lock {
    my $self = shift;

    if ($self->{lock}) {
        local $self->{dbh}->{RaiseError} = 1;
        
        my $sth = $self->{dbh}->prepare_cached(q{SELECT RELEASE_LOCK(?)}, {}, 1);
        $sth->execute($self->{lockid});
        $sth->finish();
        
        $self->{lock} = 0;
    } 
}

sub release_write_lock {
    $_[0]->release_read_lock;
}

sub release_all_locks  {
    $_[0]->release_read_lock;
}

sub DESTROY {
    my $self = shift;
    
    $self->release_all_locks;
    
    if ($self->{mine}) {
        $self->{dbh}->disconnect;
    }
}

1;

=pod

=head1 NAME

Apache::Session::Lock::MySQL - Provides mutual exclusion using MySQL

=head1 SYNOPSIS

 use Apache::Session::Lock::MySQL;

 my $locker = Apache::Session::Lock::MySQL->new();

 $locker->acquire_read_lock($ref);
 $locker->acquire_write_lock($ref);
 $locker->release_read_lock($ref);
 $locker->release_write_lock($ref);
 $locker->release_all_locks($ref);

=head1 DESCRIPTION

Apache::Session::Lock::MySQL fulfills the locking interface of 
Apache::Session.  Mutual exclusion is achieved through the use of MySQL's
GET_LOCK and RELEASE_LOCK functions.  MySQL does not support the notion
of read and write locks, so this module only supports exclusive locks.  When
you request a shared read lock, it is instead promoted to an exclusive
write lock.

=head1 CONFIGURATION

The module must know how to connect to your MySQL database to acquire locks.
You must provide a datasource name, a user name, and a password.  These options
are passed in the usual Apache::Session style, and are very similar to the
options for Apache::Session::Store::MySQL.  Example:

 tie %hash, 'Apache::Session::MySQL', $id, {
     LockDataSource => 'dbi:mysql:database',
     LockUserName   => 'database_user',
     LockPassword   => 'K00l'
 };

Instead, you may pass in an already opened DBI handle to your database.

 tie %hash, 'Apache::Session::MySQL', $id, {
     LockHandle => $dbh
 };

=head1 AUTHOR

This module was written by Jeffrey William Baker <jwbaker@acm.org>.

=head1 SEE ALSO

L<Apache::Session>
