package Apache::Session::Counted;

use strict;
use vars qw(@ISA);
@ISA = qw(Apache::Session);
use vars qw( $VERSION);
$VERSION = '1.00';

use Apache::Session;
use File::CounterFile;

{
  package Apache::Session::CountedStore;
  use Apache::Session::TreeStore;
  use Symbol qw(gensym);
  use vars qw(@ISA);
  @ISA = qw(Apache::Session::TreeStore);

  sub insert { shift->SUPER::update(@_) };
  sub storefilename {
    my $self    = shift;
    my $session = shift;
    die "The argument 'Directory' for object storage must be passed as an argument"
       unless defined $session->{args}{Directory};
    my $dir = $session->{args}{Directory};
    my $levels = $session->{args}{DirLevels} || 0;
    # here we depart from TreeStore:
    my($file) = $session->{data}{_session_id} =~ /^([\da-f]+)/;
    die "Too short ID part '$file' in session ID'" if length($file)<8;
    while ($levels) {
      $file =~ s|((..){$levels})|$1/|;
      $levels--;
    }
    "$dir/$file";
  }
}

sub get_object_store {
  my $self = shift;
  return new Apache::Session::CountedStore $self;
}

sub get_lock_manager {
  require Carp;
  Carp::confess "Should never be reached";
}

sub TIEHASH {
  my $class = shift;

  my $session_id = shift;
  my $args       = shift || {};

  # Make sure that the arguments to tie make sense
  # No. Don't Waste Time.
  # $class->validate_id($session_id);
  # if(ref $args ne "HASH") {
  #   die "Additional arguments should be in the form of a hash reference";
  # }

  #Set-up the data structure and make it an object
  #of our class

  my $self = {
             args         => $args,

             data         => { _session_id => $session_id },
             # we always have read and write lock:

             lock         => Apache::Session::READ_LOCK|Apache::Session::WRITE_LOCK,
             lock_manager => undef,
             object_store => undef,
             status       => 0,
            };

  bless $self, $class;

  #If a session ID was passed in, this is an old hash.
  #If not, it is a fresh one.

  if (defined $session_id) {
    $self->make_old;
    $self->restore;
    if ($session_id eq $self->{data}->{_session_id}) {
      # Fine. Validated. Kind of authenticated.
      # ready for a new session ID, keeping state otherwise.
      $self->make_modified if $self->{args}{AlwaysSave};
    } else {
      # oops, somebody else tried this ID, don't show him data.
      delete $self->{data};
      $self->make_new;
    }
  }
  $self->{data}->{_session_id} = $self->generate_id();
  # no make_new here, session-ID doesn't count as data

  return $self;
}

sub generate_id {
  my $self = shift;
  # wants counterfile
  my $cf = $self->{args}{CounterFile} or
      die "Argument CounterFile needed in the attribute hash to the tie";
  my $c;
  eval { $c = File::CounterFile->new($cf,"0"); };
  if ($@) {
    warn "CounterFile problem. Retrying after removing $cf.";
    unlink $cf; # May fail. stupid enough that we are here.
    $c = File::CounterFile->new($cf,"0");
  }
  my $rhexid = sprintf "%08x", $c->inc;
  my $hexid = scalar reverse $rhexid; # optimized for treestore. Not
                                      # everything in one directory
  my $password = $self->SUPER::generate_id;
  $hexid . "_" . $password;
}

1;

=head1 NAME

Apache::Session::Counted - Session management via a File::CounterFile

=head1 SYNOPSYS

 tie %s, 'Apache::Session::Counted', $sessionid, {
                                Directory => <root of directory tree>,
                                DirLevels => <number of dirlevels>,
                                CounterFile => <filename for File::CounterFile>,
                                AlwaysSave => <boolean>
                                                 }

=head1 DESCRIPTION

This session module is based on Apache::Session, but it persues a
different notion of a session, so you probably have to adjust your
expectations a little.

A session in this module only lasts from one request to the next. At
that point a new session starts. Data are not lost though, the only
thing that is lost from one request to the next is the session-ID. So
the only things you have to treat differently than in Apache::Session
are those parts that rely on the session-ID as a fixed token per user.
Everything else remains the same. See below for a discussion what this
model buys you.

The usage of the module is via a tie as described in the synopsis. The
arguments have the following meaning:

=over

=item Directory, DirLevels

Compare the desription in L<Apache::Session::TreeStore>.

=item CounterFile

A filename to be used by the File::CounterFile module. By changing
that file or the filename periodically, you can achieve arbitrary
patterns of key generation.

=item AlwaysSave

A boolean which, if true, forces storing of session data in any case.
If false, only a STORE, DELETE or CLEAR trigger that the session file
will be written when the tied hash goes out of scope. This has the
advantage that you can retrieve an old session without storing its
state again.

=back

=head2 What this model buys you

=over

=item storing state selectively

You need not store session data for each and every request of a
particular user. There are so many CGI requests that can easily be
handled with two hidden fields and do not need any session support on
the server side, and there are others where you definitely need
session support. Both can appear within the same application.
Apache::Session::Counted allows you to switch session writing on and
off during your application without effort. (In fact, this advantage
is shared with the clean persistence model of Apache::Session)

=item keeping track of transactions

As each request of a single user remains stored until you restart the
counter, there are all previous states of a single session close at
hand. The user presses the back button 5 times and changes a decision
and simply opens a new branch of the same session. This can be an
advantage and a disadvantage. I tend to see it as a very strong
feature. Your milage may vary.

=item counter

You get a counter for free which you can control just like
File::CounterFile (because it B<is> File::CounterFile).

=item cleanup

Your data storage area cleans up itself automatically. Whenever you
reset your counter via File::CounterFile, the storage area in use is
being reused. Old files are being overwritten in the same order they
were written, giving you a lot of flexibility to control session
storage time and session storage disk space.

=item performance

The notion of daisy-chained sessions simplifies the code of the
session handler itself quite a bit and it is likely that this
simplification results in an improved performance (not tested yet due
to lack of benchmarking apps for sessions). There are less file stats
and less sections that need locking, but without real world figures,
it's hard to tell what's up.

=back

As with other modules in the Apache::Session collection, the tied hash
contains a key <_session_id>. You must be aware that the value of this
hash entry is not the same as the one you passed in. So make sure that
you send your users a new session-id in each response, not the old one.

As an implemenation detail it may be of interest to you, that the
session ID in Apache::Session::Counted consists of two parts: an
ordinary number which is a simple counter and a session-ID like the
one in Apache::Session. The two parts are concatenated by an
underscore. The first part is used as an identifier of the session and
the second part is used as a one-time password. The first part is
easily predictable, but the second part is as unpredictable as
Apache::Session's session ID. We use the first part for implementation
details like storage on the disk and the second part to verify the
ownership of that token.

=head1 PREREQUISITES

Apache::Session::Counted needs Apache::Session,
Apache::Session::TreeStore, and File::CounterFile, all available from the CPAN.

=head1 EXAMPLES

XXX Two examples should show the usage of a date string and the usage
of an external cronjob to influence counter and cleanup.

=head1 AUTHOR

Andreas Koenig <andreas.koenig@anima.de>

=head1 COPYRIGHT

This software is copyright(c) 1999 Andreas Koenig. It is free software
and can be used under the same terms as perl, i.e. either the GNU
Public Licence or the Artistic License.

=cut

