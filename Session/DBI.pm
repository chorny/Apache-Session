#############################################################################
#
# Apache::Session::DBI
# Apache persistent user sessions in a DBI database
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::DBI;

use strict;
use vars qw(@ISA);

@ISA = qw(Apache::Session);

use Apache::Session;
use Apache::Session::SysVSemaphoreLocker;
use Apache::Session::DBIStore;

sub get_object_store {
    my $self = shift;

    return new Apache::Session::DBIStore;
}

sub get_lock_manager {
    my $self = shift;
    
    return new Apache::Session::SysVSemaphoreLocker;
}

1;
