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

=head1 SYNOPSIS

=head1 DESCRIPTION

Apache::Session::DBI is wrapper for the Apache::Session::DBIStore and
Apache::Session::PosixFileLocker modules.  Please consult the documentation
for those modules.

=cut


package Apache::Session::DBI;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '1.00';
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
