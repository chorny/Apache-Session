#############################################################################
#
# Apache::Session::File
# Apache persistent user sessions in the filesystem
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::File;

use strict;
use vars qw(@ISA);

@ISA = qw(Apache::Session);

use Apache::Session;
use Apache::Session::SysVSemaphoreLocker;
use Apache::Session::FileStore;

sub get_object_store {
    my $self = shift;

    if(!defined $self->{_object_store}) {
        $self->{_object_store} = new Apache::Session::FileStore;
    }
    
    return $self->{_object_store}
}

sub get_lock_manager {
    my $self = shift;
    
    if(!defined $self->{_lock_manager}) {
        $self->{_lock_manager} = new Apache::Session::SysVSemaphoreLocker;
    }
    
    return $self->{_lock_manager}
}

1;
