#############################################################################
#
# Apache::Session
# Apache persistent user sessions
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Distribute under the Artistic License
#
#############################################################################

=head1 NAME

Apache::Session - A persistence framework for session data

=head1 SYNOPSIS

  use Apache::Session::DBI;
  
  my %session;
  
  #make a fresh session for a first-time visitor
  tie %session, 'Apache::Session::DBI';

  #stick some stuff in it
  $session{visa_number} = "1234 5678 9876 5432";
  
  #get the session id for later use
  my $id = $session{_session_id};
  
  #...time passes...
  
  #get the session data back out again
  my %session;
  tie %session, 'Apache::Session::DBI', $id;
  
  &validate($session{visa_number});
  
  #delete a session from the object store permanently
  tied(%session)->delete;
  

=head2 NOTE

There was an earlier attempt at creating a session handler, which 
existed until Apache::Session 0.17.  This version is completely 
incompatible with that version.  If you are using Embperl, as of this
writing you need to use Apache::Session 0.17.

=head1 THE GAME

HTTP is a stateless protocol, which makes it difficult to track 
a user between requests.  Apache::Session bridges this problem.

=head1 DESCRIPTION

Apache::Session is a persistence framework which is particularly useful
for tracking session data between httpd requests.  Apache::Session is
designed to work with Apache and mod_perl, but it should work under
CGI and other web servers.

Apache::Session consists of three components: the interface, the object
store, and the lock manager.  The interface is defined in Session.pm,
which is meant to be easily subclassed.  The object store is implemented
by Session::DBIStore, Session::FileStore, and Session::MemoryStore.  
Various locking schemes are implemented in Session::PosixFileLocker, 
Session::SysVSemaphoreLocker, and Session::NullLocker.

A derived class of Apache::Session is used to tie together the three
components.  The derived class inherits the interface from Apache::Session,
and specifies which store and locker classes to use.  Apache::Session::DBI,
for instance, uses the DBIStore class and the SysVSemaphoreLocker class.
You can easily plug in your own object store or locker class.

=head1 INTERFACE

The interface to Apache::Session is very simple: tie a hash to the
desired class and use the hash as normal.  The constructor takes two
optional arguments.  The first argument is the desired session ID
number, or undef for a new session.  The second argument is a hash
of options that will be passed to the object store and locker classes.

=head2 tieing the session

Get a new session using DBI:

 tie %session, 'Apache::Session::DBI', undef,
    { DataSource => 'dbi:Oracle:db' };
    
Restore an old session from the database:

 tie %session, 'Apache::Session::DBI', $session_id,
    { DataSource => 'dbi:Oracle:db' };


=head2 Storing and retrieving from the session

Hey, how much easier could it get?

 $session{first_name} = "Chuck";
 $session{an_array_ref} = [ $one, $two, $three ];
 $session{an_object} = new Some::Class;

=head2 Reading the session ID

The session ID is the only magic entry in the session object,
but anything beginning with a "_" is considered reserved for
future use.

 my $id = $session{_session_id};


=head2 Permanently removing the session from storage

 tied(%session)->delete;

=head1 BEHAVIOR

Apache::Session tries to behave the way the author believes that
you would expect.  When you create a new session, Session immediately
saves the session to the data store, or calls die() if it cannot.  It
also obtains an exclusive lock on the session object.  If you retrieve
an existing session, Session immediately restores the object from storage,
or calls die() in case of an error.  Session also obtains an non-exclusive
lock on the session.

As you put data into the session hash, Session squirrels it away for
later use.  When you untie() the session hash, or it passes out of
scope, Session checks to see if anything has changed. If so, Session 
gains an exclusive lock and writes the session to the data store.  
It then releases any locks it has acquired.

When you call the delete() method on the session object, the
object is immediately removed from the object store, if possible.

When Session encounters an error, it calls die().  You will probably 
want to wrap your session logic in an eval block to trap these errors.

=head1 IMPLEMENTATION

The way you implement Apache::Session depends on what you are
trying to accomplish.  Here are some hints on which classes to
use in what situations

=over 4

=item Single machine *nix Apache

Use DBIStore and SysVSemaphoreLocker

=item Single machine Win32 Apache

Use DBIStore or MemoryStore, if persistence between server invocations is not
neccessary.  Use the NullLocker for best speed.

=item Multiple *nix machines

Use DBIStore and the DaemonLocker, or use PosixFileLocker on an NFS mount

=item Multiple machines on multiple platforms

Use DBIStore and DaemonLocker

=back

=head1 STRATEGIES

Apache::Session is mainly designed to track user session between 
http requests.  However, it can also be used for any situation
where data persistence is desirable.  For example, it could be
used to share global data between your httpd processes.  The 
following examples are short mod_perl programs which demonstrate
some session handling basics.

=head2 Sharing data between Apache processes

When you share data between Apache processes, you need to decide on a
session ID number ahead of time and make sure that an object with that
ID number is in your object store before starting you Apache.  How you
accomplish that is your own business.  I use the session ID "1".  Here
is a short program in which we use Apache::Session to store out 
database access information.

 use Apache;
 use Apache::Session::File;
 use DBI;

 use strict;
  
 my %global_data;
 
 eval {
     tie %global_data, 'Apache::Session::File', 1,
        {Directory => '/tmp/sessiondata'};
 };
 if ($@) {
    die "Global data is not accessible: $@";
 }

 my $dbh = DBI->connect($global_data{datasource}, 
    $global_data{username}, $global_data{password}) || die $DBI::errstr;

 undef %global_data;
 
 #program continues...
 
As shown in this example, you should undef or untie your session hash
as soon as you are done with it.  This will free up any locks associated
with your process.

=head2 Tracking users with cookies

The choice of whether to use cookies or path info to track user IDs 
is a rather religious topic among Apache users.  This example uses cookies.
The implementation of a path info system is left as an exercise for the
reader.

 use Apache::Session::DBI;
 use Apache;

 use strict;

 #read in the cookie if this is an old session

 my $r = Apache->request;
 my $cookie = $r->header_in('Cookie');
 $cookie =~ s/SESSION_ID=(\w*)/$1/;

 #create a session object based on the cookie we got from the browser,
 #or a new session if we got no cookie

 my %session;
 tie %session, 'Apache::Session::DBI', $cookie,
     {DataSource => 'dbi:mysql:sessions', #these arguments are
      UserName   => 'mySQL_user',         #required when using
      Password   => 'password'            #DBIStore.pm
     };

 #Might be a new session, so lets give them their cookie back

 my $session_cookie = "SESSION_ID=$session{_session_id};";
 $r->header_out("Set-Cookie" => $session_cookie);

 #program continues...

=head1 SEE ALSO

Apache::Session::DBIStore, Apache::Session::FileStore, 
Apache::Session::MemoryStore, Apache::Session::PosixFileLocker,
Apache::Session::SysVSemaphoreLocker, Apache::Session::NullLocker

The O Reilly book "Apache Modules in Perl and C" has a chapter
on keeping state.

=head1 AUTHORS

Jeffrey Baker <jeffrey@kathyandjeffrey.net> is the author of 
Apache::Session.

Gerald Richter <richter@ecos.de> had the idea for a tied hash interface
and provided the initial code for it.  He also uses Apache::Session in
his Embperl module.

Jochen Wiedeman <joe@ipsoft.de> contributed patches for bugs and
improved performance.

Steve Shreeve <shreeve@uci.edu> squashed a bug in 0.99.0 whereby
a cleared hash or deleted key failed to set the modified bit.

Peter Kaas <Peter.Kaas@lunatech.com> sent quite a bit of feedback
with ideas for interface improvements.

Randy Harmon <rjharmon@uptimecomputers.com> contributed the original
storage-independent object interface with input from:

  Bavo De Ridder <bavo@ace.ulyssis.student.kuleuven.ac.be>
  Jules Bean <jmlb2@hermes.cam.ac.uk>
  Lincoln Stein <lstein@cshl.org>

=cut

package Apache::Session;

use strict;
use vars qw($VERSION);

$VERSION = '0.99.7';

use MD5; #yes, you need MD5.pm

#State constants
#
#These constants are used in a bitmask to store the
#object's status.  New indicates that the object 
#has not yet been inserted into the object store.
#Modified indicates that a member value has been
#changed.  Deleted is set when delete() is called.
#Synced indicates that an object has been materialized
#from the datastore.

sub NEW      () {1};
sub MODIFIED () {2};
sub DELETED  () {4};
sub SYNCED   () {8};



#State methods
#
#These methods tweak the state constants.



sub is_new          { $_[0]->{status} & NEW }
sub is_modified     { $_[0]->{status} & MODIFIED }
sub is_deleted      { $_[0]->{status} & DELETED }
sub is_synced       { $_[0]->{status} & SYNCED }

sub make_new        { $_[0]->{status} |= NEW }
sub make_modified   { $_[0]->{status} |= MODIFIED }
sub make_deleted    { $_[0]->{status} |= DELETED }
sub make_synced     { $_[0]->{status} |= SYNCED }

sub make_old        { $_[0]->{status} &= ($_[0]->{status} ^ NEW) }
sub make_unmodified { $_[0]->{status} &= ($_[0]->{status} ^ MODIFIED) }
sub make_undeleted  { $_[0]->{status} &= ($_[0]->{status} ^ DELETED) }
sub make_unsynced   { $_[0]->{status} &= ($_[0]->{status} ^ SYNCED) }



#Tie methods
#
#Here we are hiding our complex data persistence framework behind
#a simple hash.  See the perltie manpage.



sub TIEHASH {
    my $class = shift;
    
    my $session_id = shift;
    my $args       = shift || {};

    #Make sure that the arguments to tie make sense
        
    &validate_id($session_id);
    
    if(ref $args ne "HASH") {
        die "Additional arguments should be in the form of a hash reference";
    }

    #Set-up the data structure and make it an object
    #of our class
    
    my $self = {
        args         => $args,
        data         => { _session_id => $session_id },
        lock         => 0,
        lock_manager => undef,
        object_store => undef,
        status       => undef
    };
    
    bless $self, $class;

    #If a session ID was passed in, this is an old hash.
    #If not, it is a fresh one.

    if (defined $session_id) {
        $self->make_old;
        $self->restore;
    }
    else {
        $self->make_new;
        $self->{data}->{_session_id} = generate_id();
        $self->save;
    }
    
    return $self;
}

sub FETCH {
    my $self = shift;
    my $key  = shift;
        
    return $self->{data}->{$key};
}

sub STORE {
    my $self  = shift;
    my $key   = shift;
    my $value = shift;
    
    $self->{data}->{$key} = $value;
    
    $self->make_modified;
    
    return $self->{data}->{$key};
}

sub DELETE {
    my $self = shift;
    my $key  = shift;
    
    $self->make_modified;
    
    delete $self->{data}->{$key};
}

sub CLEAR {
    my $self = shift;

    $self->make_modified;
    
    $self->{data} = {};
}

sub EXISTS {
    my $self = shift;
    my $key  = shift;
    
    return exists $self->{data}->{$key};
}

sub FIRSTKEY {
    my $self = shift;
    
    my $reset = keys %{$self->{data}};
    return each %{$self->{data}};
}

sub NEXTKEY {
    my $self = shift;
    
    return each %{$self->{data}};
}

sub DESTROY {
    my $self = shift;
    
    $self->save;
    $self->release_all_locks;
}



#
#Persistence methods
#


sub restore {
    my $self = shift;
    
    return if $self->is_synced;
    return if $self->is_new;
    
    $self->acquire_read_lock;

    if (!defined $self->{object_store}) {
        $self->{object_store} = $self->get_object_store;
    }
    
    $self->{object_store}->materialize($self);
    
    $self->make_unmodified;
    $self->make_synced;
}

sub save {
    my $self = shift;
    
    return unless ($self->is_modified || $self->is_new || $self->is_deleted);
    
    $self->acquire_write_lock;
    
    if (!defined $self->{object_store}) {
        $self->{object_store} = $self->get_object_store;
    }
    
    if ($self->is_deleted) {
        $self->{object_store}->remove($self);
        $self->make_synced;
        $self->make_unmodified;
        return;
    }
    if ($self->is_modified) {
        $self->{object_store}->update($self);
        $self->make_unmodified;
        $self->make_synced;
        return;
    }
    if ($self->is_new) {
        $self->{object_store}->insert($self);
        $self->make_old;
        $self->make_synced;
        $self->make_unmodified;
        return;
    }
}

sub delete {
    my $self = shift;
    
    return if $self->is_new;
    
    $self->make_deleted;
    $self->save;
}    



#
#Locking methods
#

sub READ_LOCK  () {1};
sub WRITE_LOCK () {2};

sub has_read_lock    { $_[0]->{lock} & READ_LOCK }
sub has_write_lock   { $_[0]->{lock} & WRITE_LOCK }

sub set_read_lock    { $_[0]->{lock} |= READ_LOCK }
sub set_write_lock   { $_[0]->{lock} |= WRITE_LOCK }

sub unset_read_lock  { $_[0]->{lock} &= ($_[0]->{lock} ^ READ_LOCK) }
sub unset_write_lock { $_[0]->{lock} &= ($_[0]->{lock} ^ WRITE_LOCK) }

sub acquire_read_lock  {
    my $self = shift;

    return if $self->has_read_lock;

    if (!defined $self->{lock_manager}) {
        $self->{lock_manager} = $self->get_lock_manager;
    }

    $self->{lock_manager}->acquire_read_lock($self);

    $self->set_read_lock;
}

sub acquire_write_lock {
    my $self = shift;

    return if $self->has_write_lock;

    if (!defined $self->{lock_manager}) {
        $self->{lock_manager} = $self->get_lock_manager;
    }

    $self->{lock_manager}->acquire_write_lock($self);

    $self->set_write_lock;
}

sub release_read_lock {
    my $self = shift;

    return unless $self->has_read_lock;

    if (!defined $self->{lock_manager}) {
        $self->{lock_manager} = $self->get_lock_manager;
    }

    $self->{lock_manager}->release_read_lock($self);

    $self->unset_read_lock;
}

sub release_write_lock {
    my $self = shift;

    return unless $self->has_write_lock;

    if (!defined $self->{lock_manager}) {
        $self->{lock_manager} = $self->get_lock_manager;
    }

    $self->{lock_manager}->release_write_lock($self);
    
    $self->unset_write_lock;
}

sub release_all_locks {
    my $self = shift;
    
    return unless ($self->has_read_lock || $self->has_write_lock);
    
    if (!defined $self->{lock_manager}) {
        $self->{lock_manager} = $self->get_lock_manager;
    }

    $self->{lock_manager}->release_all_locks($self);

    $self->unset_read_lock;
    $self->unset_write_lock;
}        



#
#Utility methods
#



sub generate_id {
    return substr(MD5->hexhash(time(). {}. rand(). $$. 'blah'), 0, 16);
}

sub validate_id {
    if(defined $_[0] && $_[0] =~ /[^a-f0-9]/) {
        die "Garbled session id";
    }
}

1;
