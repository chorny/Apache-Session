############################################################################
#
# Apache::Session
# Apache persistent user sessions
# Copyright(c) 1998 Jeffrey William Baker (jeff@godzilla.tamu.edu)
# Distribute under the Artistic License
#
############################################################################

package Apache::Session;

$Apache::Session::VERSION = '0.13';

use strict;
use vars qw(@ISA);
use MD5;
use Carp;
require Tie::Hash;

@ISA = qw(Tie::StdHash);

use constant SECRET     => $ENV{'SESSION_SECRET'}  || 'not very secret'; # bit of uncertainty
use constant LIFETIME   => $ENV{'SESSION_LIFETIME'} || 60*60;            # expire sessions after n seconds (default: 1 hour)
use constant ID_LENGTH  => $ENV{'SESSION_ID_LENGTH'} || 16;              # size of the session_id
use constant MAX_TRIES  => $ENV{'SESSION_MAX_ATTEMPTS'} || 5;            # number of times to try to get a unique id

sub new { 
  my $class = shift;
  my ( $opt ) = @_;

  my $id;

  # build a hash consisting of default values, plus any overrides passed in as %$opt:
  my %t;
  my $self = bless \%t, $class;
  
  $opt = $class->Options( $opt );
    
  my $control = tie( %t, 'Apache::TiedSession', {}, $self) || confess "couldn't create tied hash to $class";
 
  $self->insert($opt);
  $self->touch();
  
  return $self;  
}


sub insert {  
  my $self = shift;
  my $opt = shift;
  my $id = $self->hash( $self. rand(). SECRET );

  $self->{'_ID'} = $id;
  $self->{'_LIFETIME'} = $opt->{'lifetime'};
  $self->{'_AUTOCOMMIT'} = $opt->{'autocommit'};

  my $tries;
  while(1) {
    last if $self->create($id);
    croak "Can't get a free ID" if ++$tries > MAX_TRIES;
    $id = $self->hash($id);
  }

}

sub delete {  # delete a session-variable, or a whole session;
  my $self = shift;
  my $name = shift;
  
  if( $name ) {
    delete $self->{$name};
  } else {
    $self->destroy();
  }
}

sub touch {
  my $self = shift;
  my $control = shift;
  
  $self->{'_ACCESSED'} = time();
  $self->{'_EXPIRES'} = time() + $self->{'_LIFETIME'};
  
  return $self->{'_EXPIRES'};
}

sub store {
  1;
}

sub hash {
  my $self = shift;
  my $value = shift;
  
  return substr(MD5->hexhash($value),0,ID_LENGTH);
}

sub open {  
  my $class = shift;
  my $session = shift;
  my $opt = shift;

  $opt = $class->Options($opt);

  my $self = $session;

  $self->{'_LIFETIME'} = $opt->{'lifetime'};
  $self->{'_AUTOCOMMIT'} = $opt->{'autocommit'};

  $self = $self->expire();
  if (defined $self) { $self->touch(); }

  return $self; 
}

sub Options {
  my $class = shift;
  my $runtime = shift;
  my $default = shift;

  my $class_default = { lifetime => LIFETIME, autocommit => 1 };
  $default ||= {}; 
  $runtime ||= {};

  my $it = { %$class_default, %$default, %$runtime };

  carp( "$class: no 'autocommit' element in option list.  I hope you're commit()ing following code" ) unless exists $it->{'autocommit'};
  
  return $it; 
}

sub expire {
  my $self = shift;
  my $class = ref( $self ) || $self;
  if( $class ne $self ) {    #ensure the object hasn't been deleted.

    if( $class->fetch( $self->{'_ID'} ) ) {
      return $self;
    }
    $self->destroy();
    return undef;
  }
  return 1;
}

sub id {
  my $self = shift;
  return $self->{'_ID'};
}

sub commit {
  my $self = shift;
  $self->store();
}

sub unlock {
  1;
}
# -------------- end of package Apache::Session ---------------

package Apache::TiedSession;

# these define the proper methods for getting through to the proper bits of
# information associated with a tied Apache session.  Some are for run-time
# options and some are for persistent session information.  Think of them as
# options for authors of storage subclasses and for users of storage
# subclasses, respectively.

use Carp;

sub TIEHASH {
  my $class = shift;
  my $data = shift;
  my $self = shift;
  
  
  my $this = {
    'REF_TO_SELF'=> $self,
    'DATA'       => $data
  };
  
  return bless $this, $class;
}

sub FIRSTKEY {            # start key-looping
  my $self = shift;

  my $reset = keys %{ $self->{'DATA'} };
  each %{ $self->{'DATA'} };
}

sub NEXTKEY {            # continue key-looping (through each of 2 hashes)
  my $self = shift;
  my $last = shift;

  return each %{ $self->{'DATA'} };
}

sub EXISTS {
  my $self = shift;
  my $key =shift;

  return exists $self->{'DATA'}->{$key};
}

sub CLEAR {
  carp( "CLEAR operation not supported" );
}

sub STORE {
  my $self = shift;
  my $key = shift;
  my $val = shift;
  
  my $rv;
  
  $rv = $self->{'DATA'}->{$key} = $val;
  
  $self->{'REF_TO_SELF'}->store() if $self->{'DATA'}->{'_AUTOCOMMIT'};
  
  return $rv;
}

sub FETCH {
  my $self = shift;
  my $key = shift;
  
  my $rv;
  
  $rv = $self->{'DATA'}->{$key};
  
  return $rv;
}

sub DELETE {
#  warn "untested: DELETE(@_)";
  
  my $self = shift;
  my $key = shift;

  my $rv;

  $rv = $self->{$key};    
  $self->{$key} = undef;

  $self->{'REF_TO_SELF'}->store() if $self->{'DATA'}->{'_AUTOCOMMIT'};

  return $rv;
}

# ------------ end of package Apache::TiedSession


__END__

=head1 NAME

 Apache::Session - Maintain session state across HTTP requests

=head1 SYNOPSIS


  use Apache::Session::Win32; # use a global hash on Win32 systems
  use Apache::Session::DBI; # use a database for real storage
  use Apache::Session::File; # or maybe an NFS filesystem
  use Apache::Session::ESP; # or use your own subclass
  
  # Create a new unique session.
  $session = Apache::Session::Win32->new($opts);

  # fetch the session ID
  $id      = $session->id;
 
  # open an old session, or undef if not defined
  $session = Apache::Session::Win32->open($id,$opts);

  # store data into the session (can be a simple
  # scalar, or something more complex).
  
  $session->{foo} = 'Hi!';
  $session->{bar} = { complex => [ qw(list of settings) ] };
  
  $session->store();  # write to storage
  $session->unlock(); # always do this!


=head1 DESCRIPTION

This module provides the Apache/mod_perl user a mechanism for storing
persistent user data in a global hash, which in independent of its real
storage mechanism.  Apache::Session provides an abstract baseclass from
which storage classes can be derived.  Existing classes include:

=item Apache::Session::Win32

=item Apache::Session::File

=item Apache::Session::DBI     /=These two are half-

=item Apache::Session::IPC     \=done, but broken.  Hrmm

 
This package should be considered alpha, as the interface may 
change, and as it may not yet be fully functional.  The docu-
mentation and/or source codemay be erroneous.  Use it at your
own risk.

=head1 ENVIRONMENT

Apache::Session will respect the environment variables SESSION_SECRET, 
SESSION_LIFETIME, SESSION_ID_LENGTH, and SESSION_MAX_ATTEMPTS. 

SESSION_SECRET is a secret string used to create MD5 hashes.  The
default value is "not very secret", and this can be changed in the 
source code.

SESSION_LIFETIME is the default lifetime of a session object in seconds.
This value can be overridden by the calling program during session 
creation/retrieval.  If the environment variable is not set, 3600 seconds
is used.

SESSION_ID_LENGTH is the number if characters in the session ID.  The
default is 16.

SESSION_MAX_ATTEMPTS is the number of times that the package will attempt
to create a new session.  The package will choose a new random session ID 
for each attempt.  The default value is 5, and should be set with regard to
the type of real storage you will be using.

=head1 USAGE

=head2 Creating a new session object

  $opts = { 'subclass-specific' => 'option overrides' };
  
  $session = Apache::Session->new();  
  $session = Apache::Session->new( $opts );  
  $session = Apache::Session->new( { autocommit => 1 } );

Note that you must consult $session->{id} to learn the session ID for
persisting it with the client.  The new ID number is generated afresh,
you are not allowed to specify it for a new object.

$opts, if provided, must be a hash reference.

=head2 Fetching a session object

  $session = Apache::Session->open( $id );

  $session = Apache::Session->open( $id, { autocommit => 1 , lifetime => 600} );

where $id is a session handle returned by a previous call to new().  You are
free to use cookies, header munging, or extra-sensory perception to
determine the session id to fetch.

The hashref of runtime options allows you to override the options that 
were used during the object creation.  The standard options are "autocommit"
and "lifetime", but your storage mechanism may define others.

Autocommit defines whether your session is update in real storage every time
it is modified, or only when you call store().  If you set autocommit to 0
but don't call $session->store(), your changes will be lost.

Lifetime changes the current lifetime of the object.

=head2 Deleting a session object

 $session->destroy();

Deletes the session from physical storage.  

=head2 Committing changes

  If you defined autocommit as false, you must do $session->store();
  at the end of your script, or you will lose your changes.

=head2 Locking

  Some storage methods, such as DBI, IPC, and File, require a
  locking mechanism of some kind.  Sessions are locked throughout
  the duration of your script.  The lock is obtained when the
  session object is created (via new() or open()), and it cannot
  be released automatically.
  
  *** ALWAYS CALL UNLOCK() AT THE END OF YOUR PROGRAM ***
  
  I wish there was a better way to do this, but there isn't(?)  A
  script using Apache::Session should always end this way, just to
  be safe:
  
  $session->store();
  $session->unlock();
  

=head2 Data Methods

=over 4

=item $session->{variable_name} = <value>; 

=item $foo = $session->{variable_name};

=item $foo = delete $session->{variable_name};

Hash-access is the preferred method for working with persistent session
data.  set(), read() and delete() are no longer supported as of 0.12.

=back

=head2 Metadata

Metadata, such as the session ID, access time, lifetime, and expiration
time are all stored in the session object.  Therefore, the following hash
keys are reserved and should not be assigned to:

_ID
_EXPIRES
_LIFETIME
_ACCESSED
_AUTOCOMMIT

These keys can be used to retrieve the desired information.

my $id = $session->{'_ID'};

But please don't do this:

$session->{'_ID'} = "Foo";

=head2 Other Methods

=over 4

=item dump_to_html()

Dumps your session hash to an HTML table.

=back

=head1 STORAGE CLASSES

=head2 Apache::Session::Win32

Uses a global hash to store sessions.  Win32 does not listen
to any special evironment variables.

=head2 Apache::Session::File

Stores each session in its own flat file.  Files will be stored
under the directory in $ENV{'SESSION_FILE_DIR'}.  Without this
environment variable, the package will die on startup.

Apache::Session::File uses a custom locking mechanism that should
work regardless of whether the filesystem is local or networked.
However, locks are not (currently) released when the session object
is destroyed.  If your program dies before it calls unlock(), the
session will be lost.  Comments and ideas on this problem are 
welcome.

=head2 Apache::Session::DBI and Apache::Session::IPC

These are not fully implemented.  IPC is starting to annoy me.

=head1 SUBCLASSING

The Apache::Session module allows you to use the included Win32
implementation, but also makes it easy to subclass.  Just ensure that your
subclass includes each of the following functions:

=over 4

=item $class->fetch( $id )

Performs the very-basic physical fetch operation.  This is used by open(),
as well as by the base class's expire() routine, for the purpose of ensuring
that the current session has not been deleted by the round of expire()s.
Should return undef on failure.

=item $class->open( $id [, \%options ] )

Fetches a pre-existing session from physical storage.  You'll want to:

 - ensure that $options is a hashref

 - fetch the session from physical storage by calling fetch().
   e.g. my $session = $class->fetch($id);

 - set $self = $class->SUPER::open($session, $options )

 - return $self or undef on failure.

The SUPER::open() will take care of merging your class's default Options()
with the end-user's overrides, bless()ing the reference and tie()ing the
hash in the proper way.

=back

=over 4

=item create( $id [, \%options ] )

Creates a session, with the given id, in the physical storage.
Create() should do some garbage collections, also.  If a request is made
to create an object with an ID which is already taken, create() should
check to see whether the existing object is expired, and do the right 
thing.  Create() should return undef on failure.

=item Options( \%overrides )

Returns a hashref of options for your physical session storage, merging your
class's default options with the end-user's overrides. If you wish, you may
implement this like so:

 sub Options {
   my( $class, $runtime_opts ) = @_;
   $class->SUPER::Options( $runtime_opts, 
    { your => 'class', default => 'options', coded => 'here' } );
 }  

...and Apache::Session will do the work for you.

Ensure that your class has a default setting for autocommit, or you'll get a
warning.

Apache::Session defines a single default setting, autocommit => 1, which may
suit your needs fine.  In this case, you don't have to override this method.

=item $session->destroy()

Removes the session from the physical storage.

=item $session->store()

Writes the session's persistent data to physical storage.  This allows for a
series of changes to be made to a session, followed by a commit() which
stores those changes.

This function is called if $session->{'_AUTOCOMMIT'} is true, each time a
value is stored into the session or removed from the session.

This function is duplicate in ->commit().

=item $session->expire()

Ensures that the given session is not expired; removes the session from
physical storage if the session is expired.  Implementations may remove all
expired sessions from storage, at the discretion of the implementor.  Inside
your implementation, returning $self->SUPER::expire() will check the storage
to ensure that the current $self was not just deleted, and will return $self
or undef as appropriate.  $class->SUPER::expire will always return 1, in
that there is no 'self' which might have been zapped from storage.

=item $session->touch()

Updates the session's physical storage to reflect a new expiration time
based on the current clock-tick plus the session lifetime.

=item $session->lock()

Places a lock - in the physical storage - on the given session, ensuring
that no other client to that physical storage may utilize the same session. 
Returns immediately if the lock can not be acheived.

=item $session->unlock()

Removes the lock - in the physical storage - on the given session, allowing
other clients to utilize that session.

=back

=head1 MISC

=head1 BUGS

=head1 TODO

Create a TransHandler to translate out the session number from the URL and
store it as the current session with the Apache request object as a note.

Create a current() method which will fetch the current session if it's valid.

Create a rewrite handler to translate outgoing HTML to include the current
session number.

=head1 AUTHORS

Jeffrey Baker <jeff@godzilla.tamu.edu>, author and maintainer

Randy Harmon <rjharmon@uptimecomputers.com> created storage independence
through subclassing, with useful comments, suggestions, and source code
from:

  Bavo De Ridder <bavo@ace.ulyssis.student.kuleuven.ac.be>
  Jules Bean <jmlb2@hermes.cam.ac.uk>
  Lincoln Stein <lstein@cshl.org>

Redistribute under the Perl Artistic License.
