#############################################################################
#
# Apache::Session::DBI
# Apache persistent user sessions in a DBI database
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

=head1 NAME

Apache::Session::DBI - Session persistence via DBI

=head1 SCHEMA

To use this module, you will need these columns in a table 
called 'sessions':

 id char(16)
 length int(11)
 a_session text

Where the a_session column needs to be able to handle arbitrarily
long binary data.

=cut


package Apache::Session::DBI;

use strict;
use vars qw(@ISA);

@ISA = qw(Apache::Session);

use Apache::Session;
use Apache::Session::SysVSemaphoreLocker;
use Apache::Session::DBIStore;

sub get_object_store {
    my $self = shift;

    return new Apache::Session::DBIStore $self;
}

sub get_lock_manager {
    my $self = shift;
    
    return new Apache::Session::SysVSemaphoreLocker $self;
}

1;
