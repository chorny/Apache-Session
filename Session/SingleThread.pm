#############################################################################
#
# Apache::Session::SingleThread
# Apache persistent user sessions in memory for Win32
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::SingleThread;

use strict;
use vars qw(@ISA);

@ISA = qw(Apache::Session);

use Apache::Session;
use Apache::Session::NullLocker;
use Apache::Session::MemoryStore;

sub get_object_store {
    my $self = shift;

    return new Apache::Session::MemoryStore;
}

sub get_lock_manager {
    my $self = shift;

    return new Apache::Session::NullLocker;
}

1;
