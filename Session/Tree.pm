#############################################################################
#
# This module was written by Andreas Koenig <andreas.koenig@anima.de>
#
############################################################################

package Apache::Session::Tree;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '1.00';
@ISA = qw(Apache::Session);

use Apache::Session;
use Apache::Session::SysVSemaphoreLocker;
use Apache::Session::TreeStore;

sub get_object_store {
    my $self = shift;

    return new Apache::Session::TreeStore $self;
}

sub get_lock_manager {
    my $self = shift;

    return new Apache::Session::SysVSemaphoreLocker $self;
}

1;
