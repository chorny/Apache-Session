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
use vars qw($VERSION @ISA);

$VERSION = '0.99.0';
@ISA = qw(Apache::Session);

use Apache::Session;
use Apache::Session::NullLocker;
use Apache::Session::FileStore;

sub get_object_store {
    new Apache::Session::FileStore;
}

sub get_lock_manager {
    new Apache::Session::NullLocker;
}

1;
