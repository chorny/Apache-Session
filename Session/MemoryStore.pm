#############################################################################
#
# Apache::Session::MemoryStore
# Implements session object storage in a hash
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::MemoryStore;

use strict;

BEGIN {
    $Apache::Session::MemoryStore::store = {};
}

sub new {
    my $class = shift;
    
    return bless {}, $class;
}


sub insert {
    my $self    = shift;
    my $session = shift;
 
    $Apache::Session::MemoryStore::store->{$session->{data}->{_session_id}} = 
        $session->{data};
}


sub update {
    my $self    = shift;
    my $session = shift;
 
    $self->insert($session);
}

sub materialize {
    my $self    = shift;
    my $session = shift;

    $session->{data} = $Apache::Session::MemoryStore::store->{$session->{data}->{_session_id}};
}

sub remove {
    my $self    = shift;
    my $session = shift;

    delete $Apache::Session::MemoryStore::store->{$session->{data}->{_session_id}};
}

1;
