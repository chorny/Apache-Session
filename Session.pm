############################################################################
#
# Apache::Session
# Apache persistent user sessions
# Copyright(c) 1998 Jeffrey William Baker (jeff@godzilla.tamu.edu)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session;

$Apache::Session::VERSION = '0.16';

require Apache if exists $ENV{'MOD_PERL'};
use MD5;
use Carp;

use constant SECRET     => $ENV{'SESSION_SECRET'}       || 'not very secret'; # bit of uncertainty
use constant LIFETIME   => $ENV{'SESSION_LIFETIME'}     || 60*60;             # expire sessions after n seconds (default: 1 hour)
use constant ID_LENGTH  => $ENV{'SESSION_ID_LENGTH'}    || 16;                # size of the session_id
use constant MAX_TRIES  => $ENV{'SESSION_MAX_ATTEMPTS'} || 5;                 # number of times to try to get a unique id

sub new { 
  my $class = shift;
  my $opt   = shift;
  my $notie = shift;

  my ($hashref, $id) = insert( $class );
  return undef unless $hashref;

  my $ahash = {};
  if ( !$notie ) {
    tie( %$ahash, 'Apache::TiedSession', $class, $hashref ) ||
      confess "couldn't create tied hash to $class";
  }
  else {
    $ahash = $hashref;
  }

  my $self = bless $ahash, $class;
  $self->{'_ID'} = $id;
  
  $opt = options( $opt, $class->options() );
  foreach my $key ( keys %$opt ) {
    $newkey = '_'.uc( $key );
    $self->{$newkey} = $opt->{$key};
  }

  $self->touch();
  
  return $self;  
}

sub open {
  my $class = shift;
  my $id    = shift;
  my $opt   = shift;
  my $notie = shift;

  my $session = $class->fetch( $id );
  return undef unless ( ref ( $session ) =~ /HASH/);

  my $ahash = {};
  my $self = bless $ahash, $class;
  
  if ( !$notie ) {
    tie (%$self, 'Apache::TiedSession', $class, $session)  ||
       confess "couldn't create tied hash to $class";
  }

  $opt = options( $opt, $class->options() );
  foreach my $key (keys %$opt) {
    $newkey = '_'.uc( $key );
    $self->{$newkey} = $opt->{$key};
  }

  $self = $self->expire();
  $self->touch() if $self;
  return $self;
}

sub expire {
  my $self = shift;
  if ( $self->{'_EXPIRES'} < time() ) {
    $self->destroy();
    return undef;
  }
  return $self;
}

sub insert {
  my $class = shift;
  my $id = hash( time(). {}. rand(). $$. SECRET ); #some platforms have more entropy than others
  my $hashref;
  my $tries;

  while(1) {    
    $hashref = $class->create( $id );
    last if $hashref;
    
    croak "Can't get a free ID" if ++$tries > MAX_TRIES;
    $id = hash( $id );
  }
  return $hashref, $id;
}

sub options {
  my $runtime = shift || {};
  my $default = shift || {};

  my $class_default = { lifetime => LIFETIME, autocommit => 1 };
  my $it = { %$class_default, %$default, %$runtime };

  return $it; 
}

sub touch {
  my $self    = shift || {};
  my $control = shift;

  return undef unless exists $self->{'_LIFETIME'};  

  $self->{'_ACCESSED'} = time();
  $self->{'_EXPIRES'}  = time() + $self->{'_LIFETIME'};
  
  return $self->{'_EXPIRES'};
}

sub store {
  my $self = shift;
  my $data = shift;
  
  if ( ref( $self ) ) { # called via $obj->store()
    my $key;
    my $hashref;
    foreach $key ( keys %$self ) {
      $hashref->{$key} = $self->{$key};
    }
    return $self->commit( $hashref );
  }
  else { # called via $class->store($data)
    return $self->commit( $data );
  }
}

sub hash {
  my $value = shift;

  return substr( MD5->hexhash( $value ), 0, ID_LENGTH );
}

sub id {
  my $self = shift;
  return $self->{'_ID'};
}

sub rewrite {
  my $self = shift;
  
  my $r = Apache->request();
  my $s = $r->server();
  my $name = $s->server_hostname();
  my $port = $s->port();
  my $uri = $r->uri();
  my $path_info = $r->path_info;

  $uri =~ s/$path_info$//;
  
  $port = ( $port == 80 ) ? undef : ":$port";
  
  return "http://$name$port$uri/$self->{ '_ID' }";
}

# --------- start of tied interface to Apache::Session --------------

sub create_session_object {
  my ($self) = @_;

  my $sessionobj = $self->{'DATA'};

  return $sessionobj if ( $sessionobj );

  my $id = $self->{'ID'};
  my $subclass = $self->{'SUBCLASS'};

  if ( $id ) {
    $sessionobj = $subclass->open ($id, $self->{'OPTIONS'}, 1) or die "Cannot open session $id";
  }

  if ( !$sessionobj ) {
    $sessionobj = $subclass->new( $self->{'OPTIONS'}, 1 ) or die "Cannot create new session";
    $self->{'ID'} = $sessionobj->id;
  }

  $self->{'DATA'} = $sessionobj;

  return $sessionobj;
}


sub TIEHASH {
  my ( $class, $subclass, $id, $options ) = @_;

  $subclass = $class.'::'.$subclass if ( !( $subclass =~ /::/ ) );
  $options  = {} if ( !$options );

  my $this = {
    'ID'               => $id,
    'SUBCLASS'         => $subclass,
    'DATA'             => undef,
    'OPTIONS'          => $options,
    'STORE_ON_DESTROY' => defined ( $options->{'store_on_destroy'} ) ? $options->{'store_on_destroy'} : 1,
    'AUTOCOMMIT'       => $options->{'autocommit'} || 0,
    'DIRTY'            => 0
  };

  my $self = bless $this, $class;

  $self->create_session_object if ( $options->{ 'not_lazy' } );

  return $self;
}

sub FIRSTKEY {            # start key-looping
  my $self = shift;

  my $so = $self->{'DATA'};
  $so = $self->create_session_object if ( !$self->{'DATA'} && $self->{'ID'} );
  my $reset = scalar keys %{ $so };
  each %{ $so };
}

sub NEXTKEY {            # continue key-looping 
  my $self = shift;

  return each %{ $self->{'DATA'} };
}

sub EXISTS {
  my $self = shift;
  my $key  = shift;

  $self->create_session_object  if ( !$self->{'DATA'} && $self-> {'ID'}) ;

  return exists $self->{'DATA'}->{$key};
}

sub CLEAR {
  my $self = shift;
  $self->{'DATA'} = undef;
  carp( "CLEAR operation not supported" );
}

sub STORE {
  my $self = shift;
  my $key  = shift;
  my $val  = shift;

  my $rv;
  warn "Okay, got to STORE";
  $self->create_session_object if ( !$self->{'DATA'} );

  $rv = $self->{'DATA'}->{$key} = $val;
  if ( $self->{'STORE_ON_DESTROY'} ) { 
    $self->{'DIRTY'} = 1; 
  }
  elsif ( $self->{'AUTOCOMMIT'} ) { 
    $self->{'DATA'}->store;
  }

  return $rv;
}

sub FETCH {
  my $self = shift;
  my $key = shift;
  
  return $self->{'ID'} if ($key eq '_ID');

  my $rv;
  $self->create_session_object if (!$self->{'DATA'} && $self-> {'ID'} );
  
  $rv = $self->{'DATA'}->{$key};
  
  return $rv;
}

sub DELETE {
  my $self = shift;
  my $key = shift;
  my $rv;

  $self->create_session_object if ( !$self->{'DATA'} );

  $rv = $self->{$key};
  $self->{$key} = undef;

  if ( $self->{'STORE_ON_DESTROY'} ) {
    $self->{'DIRTY'} = 1;
  }
  elsif ( $self->{'AUTOCOMMIT'}) {
    $self->{'DATA'}->store;
  }

  return $rv;
}

sub DESTROY {
  my $self = shift;
  warn "Now would be a good time to commit..";
  $self->{'DATA'}->store if $self->{'DIRTY'};
}


# -------------- end of package Apache::Session ---------------

package Apache::TiedSession;

#this is how Apache::Session talks to the storage subclasses, unless the user
#chooses to use the tied hash interface.

use Carp;

sub TIEHASH {
  my $class        = shift;
  my $sessionclass = shift;
  my $data         = shift;  
  
  my $this = {
    'CLASS' => $sessionclass,
    'DATA'  => $data
  };
  
  return bless $this, $class;
}

sub FIRSTKEY {            # start key-looping
  my $self = shift;

  my $reset = scalar keys %{ $self->{'DATA'} };
  each %{ $self->{'DATA'} };
}

sub NEXTKEY {            # continue key-looping 
  my $self = shift;
  my $last = shift;

  return each %{ $self->{'DATA'} };
}

sub EXISTS {
  my $self = shift;
  my $key  = shift;

  return exists $self->{'DATA'}->{$key};
}

sub CLEAR {
  carp( "CLEAR operation not supported" );
}

sub STORE {
  my $self = shift;
  my $key  = shift;
  my $val  = shift;
  
  my $rv;
  
  $rv = $self->{'DATA'}->{$key} = $val;
  $self->{'CLASS'}->store( $self->{'DATA'} ) if $self->{'DATA'}->{'_AUTOCOMMIT'};
  
  return $rv;
}

sub FETCH {
  my $self = shift;
  my $key  = shift;
  
  my $rv;
  
  $rv = $self->{'DATA'}->{$key};
  
  return $rv;
}

sub DELETE {
  my $self = shift;
  my $key  = shift;

  my $rv;

  $rv = $self->{'DATA'}->{$key};
  delete $self->{'DATA'}->{$key};
  
  $self->{'CLASS'}->store( $self->{'DATA'} ) if $self->{'DATA'}->{'_AUTOCOMMIT'};

  return $rv;
}

1;

# ------------ end of package Apache::TiedSession


__END__

=head1 NAME

Apache::Session - Maintain session state across HTTP requests

=head1 SYNOPSIS

  use Apache::Session::Win32; # use a global hash on Win32 systems
  use Apache::Session::DBI;   # use a database for real storage
  use Apache::Session::File;  # or maybe an NFS filesystem
  use Apache::Session::IPC;   # or an IPC shared memory block
  
  # setup the session options
  $opts = { autocommit => 0,
            lifetime   => 60
          };
          
  # Create a new unique session.
  $session = Apache::Session::Win32->new( $opts );

  # fetch the session ID
  $id      = $session->{ '_ID' };
 
  # open an old session, or undef if not defined
  $session = Apache::Session::Win32->open( $id, $opts );

  # store data into the session (can be a simple
  # scalar, or something more complex).
  
  $session->{ 'foo' } = 'Hi!';
  $session->{ 'bar' } = { complex => [ qw(list of settings) ] };
  
  $session->store();  # write to storage


=head1 DESCRIPTION

This module provides the Apache/mod_perl user a mechanism for storing
persistent user data in a global hash, which is independent of its real
storage mechanism.  Apache::Session provides an abstract baseclass from
which storage classes can be derived.  Existing classes include:

    Apache::Session::DBI
    Apache::Session::Win32
    Apache::Session::File
    Apache::Session::IPC

=head1 CHOOSING A SUBCLASS

Before you begin you will need to know what subclass you are going to use.  Here are
my recommendations:

Apache::Sessions::DBI is the fastest and most reliable of all the storage classes.
If you have a database available, I would recommend using the DBI module.  DBI
sessions can be shared between different servers, running different plaforms, and
they survive server shutdowns.

For Win32, Apache::Session::Win32 is a good choice if you don't need the sessions
to survive a server restart.  Win32 does frequent garbage collection to keep the
httpd process from growing out of control.  Win32 also provides run-time monitoring
via Apache::Status, and is also very fast.

Apache::Session::File is useful for low-traffic servers.  Unfortunately, as traffic
increases performance worsens.  The culprit is C<-e filename>, which can be extremely
slow in a directory with hundreds of thousands of files.  Apache::Session::File does
not currently do aggressive garbage collection, but this is planned.  File could be
used on a server farm where DBI isn't available.

Apache::Session::IPC looked promising at first, but now I don't recommend it.  Maybe
it is my platform (Linux 2.0.34), but IPC on my test machine is ridiculously slow.
Also, IPC::Shareable will sometimes fall over under heavy load.  Try to use one of
the other classes if you can.

=head1 INSTALLATION

You will need to build, test, and install the MD5 module, plus one or more of 
FreezeThaw, Storable, DBI, and IPC::Shareable, depending on the storage subclass
you intend to use.  See the subclass documentation for more details.

 perl Makefile.PL
 make
 make install

=head1 ENVIRONMENT

Apache::Session will respect the environment variables SESSION_SECRET, 
SESSION_LIFETIME, SESSION_ID_LENGTH, and SESSION_MAX_ATTEMPTS.  Derived
subclasses may define their own environment variables.

=over 4

=item SESSION_SECRET 

SESSION_SECRET is fed to MD5->hexhash to generate session IDs.  
This is not used for security, but you should change it to reduce the possibility
of someone predicting your ID sequence.  The default value is "not very secret".

=item SESSION_LIFETIME

SESSION_LIFETIME is the default lifetime of a session object in seconds.
This value can be overridden by the calling program during session 
creation/retrieval.  If the environment variable is not set, 3600 seconds
(1 hour) is used.

=item SESSION_ID_LENGTH

SESSION_ID_LENGTH is the number of characters in the session ID.  The
default is 16.  Since the session IDs are hexadecimal strings, this allows
for 18,446,744,079 billion concurrent sessions.

=item SESSION_MAX_ATTEMPTS

SESSION_MAX_ATTEMPTS is the number of times that the package will attempt
to create a new session.  The package will choose a new random session ID 
for each attempt.  The default value is 5.

=back

The relevant sections of my httpd.conf look like:

 PerlSetEnv SESSION_SECRET a%A^Djhcx6:
 PerlSetEnv SESSION_ID_LENGTH 16
 PerlSetEnv SESSION_LIFETIME 10

=head1 USAGE

=head2 Creating a new session object

 $opts = { 'subclass-specific' => 'option overrides' };
  
 $session = Apache::Session->new();  
 $session = Apache::Session->new( $opts );  
 $session = Apache::Session->new( { autocommit => 1 } );

Note that you must consult $session->{ '_ID' } to learn the session ID for
persisting it with the client.  The new ID number is generated afresh,
you are not allowed to specify it for a new object.

$opts, if provided, must be a hash reference.  See the next section for defined
options.

=head2 Fetching a session object

 $session = Apache::Session->open( $id );
 $session = Apache::Session->open( $id, 
             { autocommit => 1 , lifetime => 600 } );

where $id is a session handle returned by a previous call to new().  You are
free to use cookies, header munging, or extra-sensory perception to
determine the session id to fetch.

The hashref of runtime options allows you to override the options that 
were used during the object creation.  The standard options are "autocommit"
and "lifetime", but your storage mechanism may define others.

Autocommit defines whether your session is update in real storage every time
it is modified, or only when you call store().  If you set autocommit to 0
but do not call $session->store(), your changes will be lost.  Setting autocommit
to 1 may adversely effect performance.

Lifetime changes the current lifetime of the object, in seconds.

=head2 Deleting a session object

 $session->destroy();

Deletes the session from physical storage.  

=head2 Storing and autocommit

 $session->store();

If you set autocommit to 0 during open() or new(), you must call $session->store()
to save your changes.  You can also call store() when autocommit is 1, so it might
be a good idea to always call store() regardless of autocommit.

=head2 Data

 $session->{ 'varname' } = $complex_data_structure;
 $complex_data_structure = $session->{ 'varname' };
 delete $session{ 'varname' };

Hash access is the only method for storing session data.  Treat the session object
like a normal hash, and it will take care of the rest.  Don't clobber any of the 
metadata (see below).

=head2 Metadata

Metadata, such as the session ID, access time, lifetime, and expiration
time are all stored in the session object.  Therefore, the following hash
keys are reserved and should not be assigned to:

 _ID
 _EXPIRES
 _LIFETIME
 _ACCESSED
 _AUTOCOMMIT
 _LOCK

You can safely do this:

 my $id = $session->{ '_ID' };

But please don't do this:

 $session->{ '_ID' } = "Foo"; #wrong!

=head2 Other Methods

 print $session->dump_to_html();

Dumps your session hash to an HTML table.

 $session->rewrite();

Rewrite() returns a fully-qualified URL with the session ID embedded as path info.  A
good use for this might be:

 print "<a href=".$session->rewrite().">Click Here</a>"

=head1 SUBCLASSING

The Apache::Session module allows you to use the included 
implementations, but also makes it easy to subclass.  Just ensure that your
subclass includes each of the following functions:

=over 4

=item $class->fetch( $id )

Performs the very basic physical fetch operation.  This is used by open().
Fetch should return a hash reference, or undef on failure.

=item $class->create( $id )

Creates a session, with the given id, in the physical storage.
Create() should do some garbage collections, also.  If a request is made
to create an object with an ID which is already taken, create() should
check to see whether the existing object is expired, and do the right 
thing.  Create() should return a hashref, or undef on failure.

=item $class->options()

Returns a hashref of options for your physical session storage, which the 
superclass will merge with the global defaults and runtime overrides.  This
method should return a hashref with each option as a key.  If you wish, you may
implement this like so:

 sub options {
   { autocommit => 0,
     lifetime   => $ENV{'SESSION_LIFETIME'},
     other      => options
   };
 }  

...and Apache::Session will do the work for you.

Apache::Session defines a single default setting, autocommit => 1, which may
suit your needs fine.  In this case, you don't have to override this method.

=item $class->commit( $hashref );

The commit method should write the given hash into the physical storage.  How you
do that is up to you as long as you can get the hash back out again.  This method
may be critical for performance, especially if autocommit is true.

=item $object->destroy()

Removes the session from the physical storage.  This should remove all traces of 
the session, including any associated locks.

=item $object->DESTROY()

This method will get called when the session object goes out-of-scope.  You might
want to use this method to clean up any locks that are associated with the object.

=item locking

Depending on the nature of your storage system, you may need to implement a locking
structure to serialize/atomize read and write operations.  This locking structure
should be transparent to the end user.

=back

=head1 BUGS

Apache::Session::IPC is known break under heavy loads on Linux.  Apache::Session::File
slowly degrades over time unless you periodically clean out the session file
directory.

=head1 TODO

Apache::Session::Daemon

=head1 AUTHORS

Jeffrey Baker <jeff@godzilla.tamu.edu>, author and maintainer.

Randy Harmon <rjharmon@uptimecomputers.com> created storage independence
through subclassing, with useful comments, suggestions, and source code
from:

  Bavo De Ridder <bavo@ace.ulyssis.student.kuleuven.ac.be>
  Jules Bean <jmlb2@hermes.cam.ac.uk>
  Lincoln Stein <lstein@cshl.org>

Redistribute under the Perl Artistic License.
