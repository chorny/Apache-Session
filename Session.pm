############################################################################
#
# Apache::Session
# Apache persistent user sessions
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session;

use strict;
use vars qw($VERSION);

$VERSION = '0.99.5';

use MD5; #yes, you need MD5.pm

#State constants
#
#These constants are used in a bitmask to store the
#object's status.  New indicates that the object 
#has not yet been inserted into the object store.
#Modified indicates that a member value has been
#changed.  Deleted is set when delete() is called.
#Synced indicates that an object has been materialized
#from the datastore.

sub NEW      {1};
sub MODIFIED {2};
sub DELETED  {4};
sub SYNCED   {8};



#State methods
#
#These methods tweak the state constants.



sub is_new          { $_[0]->{status} & NEW }
sub is_modified     { $_[0]->{status} & MODIFIED }
sub is_deleted      { $_[0]->{status} & DELETED }
sub is_synced       { $_[0]->{status} & SYNCED }

sub make_new        { $_[0]->{status} |= NEW }
sub make_modified   { $_[0]->{status} |= MODIFIED }
sub make_deleted    { $_[0]->{status} |= DELETED }
sub make_synced     { $_[0]->{status} |= SYNCED }

sub make_old        { $_[0]->{status} &= ($_[0]->{status} ^ NEW) }
sub make_unmodified { $_[0]->{status} &= ($_[0]->{status} ^ MODIFIED) }
sub make_undeleted  { $_[0]->{status} &= ($_[0]->{status} ^ DELETED) }
sub make_unsynced   { $_[0]->{status} &= ($_[0]->{status} ^ SYNCED) }



#Tie methods
#
#Here we are hiding our complex data persistence framework behind
#a simple hash.  See the perltie manpage.



sub TIEHASH {
    my $class = shift;
    
    my $session_id = shift;
    my $args       = shift;

    #Make sure that the arguments to tie make sense
        
    if($session_id =~ /[^a-f0-9]/) {
        die "Garbled session id";
    }
    if(ref $args ne "HASH") {
        die "Additional arguments should be in the form of a hash reference";
    }

    #Set-up the data structure and make it an object
    #of our class
    
    my $self = {
        args   => $args,
        data   => { _session_id => $session_id },
        lock   => 0,
        status => undef
    };
    
    bless $self, $class;

    #If a session ID was passed in, this is an old hash.
    #If not, it is a fresh one.

    if (defined $session_id) {
        $self->make_old;
        $self->restore;
    }
    else {
        $self->make_new;
        $self->{data}->{_session_id} = generate_id();
        $self->save;
    }
    
    return $self;
}

sub FETCH {
    my $self = shift;
    my $key  = shift;
        
    return $self->{data}->{$key};
}

sub STORE {
    my $self  = shift;
    my $key   = shift;
    my $value = shift;
    
    $self->{data}->{$key} = $value;
    
    $self->make_modified;
    
    return $self->{data}->{$key};
}

sub DELETE {
    my $self = shift;
    my $key  = shift;
    
    $self->make_modified;
    
    delete $self->{data}->{$key};
}

sub CLEAR {
    my $self = shift;

    $self->make_modified;
    
    $self->{data} = {};
}

sub EXISTS {
    my $self = shift;
    my $key  = shift;
    
    return exists $self->{data}->{$key};
}

sub FIRSTKEY {
    my $self = shift;
    
    my $reset = keys %{$self->{data}};
    return each %{$self->{data}};
}

sub NEXTKEY {
    my $self = shift;
    
    return each %{$self->{data}};
}

sub DESTROY {
    my $self = shift;
    
    $self->save;
    $self->release_all_locks;
}



#
#Persistence methods
#


sub restore {
    my $self = shift;
    
    return if $self->is_synced;
    return if $self->is_new;
    
    $self->acquire_read_lock;

    my $object_store = $self->get_object_store;
    
    $object_store->materialize($self);
    
    $self->make_unmodified;
    $self->make_synced;
}

sub save {
    my $self = shift;
    
    return unless ($self->is_modified || $self->is_new || $self->is_deleted);
    
    $self->acquire_write_lock;
    
    my $object_store = $self->get_object_store;
    
    if ($self->is_deleted) {
        $object_store->remove($self);
        $self->make_synced;
        $self->make_unmodified;
        return;
    }
    if ($self->is_modified) {
        $object_store->update($self);
        $self->make_unmodified;
        $self->make_synced;
        return;
    }
    if ($self->is_new) {
        $object_store->insert($self);
        $self->make_old;
        $self->make_synced;
        $self->make_unmodified;
        return;
    }
}

sub delete {
    my $self = shift;
    
    return if $self->is_new;
    
    $self->make_deleted;
    $self->save;
}    



#
#Locking methods
#

sub READ_LOCK  {1};
sub WRITE_LOCK {2};

sub has_read_lock    { $_[0]->{lock} & READ_LOCK }
sub has_write_lock   { $_[0]->{lock} & WRITE_LOCK }

sub set_read_lock    { $_[0]->{lock} |= READ_LOCK }
sub set_write_lock   { $_[0]->{lock} |= WRITE_LOCK }

sub unset_read_lock  { $_[0]->{lock} &= ($_[0]->{lock} ^ READ_LOCK) }
sub unset_write_lock { $_[0]->{lock} &= ($_[0]->{lock} ^ WRITE_LOCK) }

sub acquire_read_lock  {
    my $self = shift;

    return if $self->has_read_lock;

    my $lock_manager = $self->get_lock_manager;
    $lock_manager->acquire_read_lock($self);

    $self->set_read_lock;
}

sub acquire_write_lock {
    my $self = shift;

    return if $self->has_write_lock;

    my $lock_manager = $self->get_lock_manager;
    $lock_manager->acquire_write_lock($self);

    $self->set_write_lock;
}

sub release_read_lock {
    my $self = shift;

    return unless $self->has_read_lock;

    my $lock_manager = $self->get_lock_manager;
    $lock_manager->release_read_lock($self);

    $self->unset_read_lock;
}

sub release_write_lock {
    my $self = shift;

    return unless $self->has_write_lock;

    my $lock_manager = $self->get_lock_manager;
    $lock_manager->release_write_lock($self);
    
    $self->unset_write_lock;
}

sub release_all_locks {
    my $self = shift;
    
    return unless ($self->has_read_lock || $self->has_write_lock);
    
    my $lock_manager = $self->get_lock_manager;
    $lock_manager->release_all_locks($self);

    $self->unset_read_lock;
    $self->unset_write_lock;
}        



#
#Utility methods
#



sub generate_id {
    return substr(MD5->hexhash(time(). {}. rand(). $$. 'blah'), 0, 16);
}

1;
