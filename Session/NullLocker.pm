############################################################################
#
# Apache::Session::NullLocker
# Pretends to provide locking for Apache::Session
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::NullLocker;

use strict;
use vars qw($VERSION);

$VERSION = '1.00';

#This package is fake.  It fulfills the API that Apache::Session
#outlines but doesn't actually do anything, least of all provide
#serialized access to your data store.

sub new {
    my $class = shift;
    
    return bless {}, $class;
}

sub acquire_read_lock  {1}
sub acquire_write_lock {1}
sub release_read_lock  {1}
sub release_write_lock {1}
sub release_all_locks  {1}

1;
