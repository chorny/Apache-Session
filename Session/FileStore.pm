#############################################################################
#
# Apache::Session::FileStore
# Implements session object storage via flat files
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session::FileStore;

use strict;
use Storable qw(nstore_fd retrieve_fd);

sub new {
    my $class = shift;
    
    return bless {}, $class;
}

sub insert {
    my $self    = shift;
    my $session = shift;
 
    if (!(defined $Apache::Session::FileStore::Directory ||
          defined $session->{args}->{Directory})) {
        
        die "The directory for object storage must be passed as an argument or set in httpd.conf";
    }
    
    my $directory = $session->{args}->{Directory} || $Apache::Session::FileStore::Directory;

    if (-e $directory.'/'.$session->{data}->{_session_id}) {
        die "Object already exists in the data store";
    }
    
    open (ME, '>'.$directory.'/'.$session->{data}->{_session_id}) ||
        die "Could not open file for writing $!";
        
    nstore_fd $session->{data}, \*ME;
    
    close ME || die $!;
}

sub update {
    my $self    = shift;
    my $session = shift;
    
    my $directory = $session->{args}->{Directory} || $Apache::Session::FileStore::Directory;

    open (ME, '>'.$directory.'/'.$session->{data}->{_session_id}) ||
        die "Could not open file for writing $!";
        
    nstore_fd $session->{data}, \*ME;
    
    close ME || die $!;
}

sub materialize {
    my $self    = shift;
    my $session = shift;
    
    if (!(defined $Apache::Session::FileStore::Directory ||
          defined $session->{args}->{Directory})) {
        
        die "The directory for object storage must be passed as an argument or set in httpd.conf";
    }
    
    my $directory = $session->{args}->{Directory} || $Apache::Session::FileStore::Directory;
    
    if (-e $directory.'/'.$session->{data}->{_session_id}) {
        open (ME, '<'.$directory.'/'.$session->{data}->{_session_id}) ||
            die "Could not open file for reading $!";

        $session->{data} = retrieve_fd \*ME;

        close ME || die $!;
    }
    else {
        die "Object does not exist in the data store";
    }
}    

sub remove {
    my $self    = shift;
    my $session = shift;
        
    if (!(defined $Apache::Session::FileStore::Directory ||
          defined $session->{args}->{Directory})) {
        
        die "The directory for object storage must be passed as an argument or set in httpd.conf";
    }
    
    my $directory = $session->{args}->{Directory} || $Apache::Session::FileStore::Directory;

    if (-e $directory.'/'.$session->{data}->{_session_id}) {
        unlink ($directory.'/'.$session->{data}->{_session_id}) ||
            die "Could not open file for reading $!";
    }
    else {
        die "Object does not exist in the data store";
    }
}
    
1;
