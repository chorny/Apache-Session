#############################################################################
#
# Apache::Session::TreeStore
# Implements session object storage via flat files in a directory hierarchy
# Copyright(c) 1998, 1999 Jeffrey William Baker (jeffrey@kathyandjeffrey.net)
# Copyright(c) 1999 Andreas Koenig <andreas.koenig@anima.de>
# Distribute under the Artistic License
#
############################################################################

# Experimental code
# Works like FileStore but scales well with many session files
# To be called with args: { Directory => basedirectory,
#                           DirLevels => number of levels (0..2 recommended) }
#
# e.g.
#
# tie %s, "Apache::Session::Tree", undef,
#               { Directory => "/tmp/Apache-Session-bench",
#                 DirLevel  => 1 };


package Apache::Session::TreeStore;
use Symbol qw(gensym);

use strict;
use Storable qw(nstore_fd retrieve_fd);
use vars qw($VERSION);

$VERSION = '1.00';

sub new { bless {}, shift }

sub insert {
  my $self    = shift;
  my $session = shift;
  my $storefile = $self->storefilename($session);
  die "Object already exists in the data store" if -e $storefile;
  my $fh = gensym;
  open $fh, ">$storefile" or
      die "Could not open file $storefile for writing: $!
Maybe you haven't initialized the storage directory with
Apache::Session::TreeStore->tree_init(\$dir,\$levels)";
  nstore_fd $session->{data}, $fh;
  close $fh;
}

sub update {
  my $self    = shift;
  my $session = shift;
  my $storefile = $self->storefilename($session);
  my $fh = gensym;
  open $fh, ">$storefile" or
      die "Could not open file $storefile for writing: $!
Maybe you haven't initialized the storage directory with
Apache::Session::TreeStore->tree_init(\$dir,\$levels)";
  nstore_fd $session->{data}, $fh;
  close $fh;
}

sub materialize {
  my $self    = shift;
  my $session = shift;
  my $storefile = $self->storefilename($session);
  my $fh = gensym;
  open $fh, "<$storefile" or
      die "Could not open file $storefile for reading: $!";
  $session->{data} = retrieve_fd $fh;
  close $fh or die $!;
}

sub remove {
  my $self    = shift;
  my $session = shift;
  my $storefile = $self->storefilename($session);
  unlink $storefile or warn "Object $storefile does not exist in the data store";
}

sub storefilename {
  my $self    = shift;
  my $session = shift;
  die "The argument 'Directory' for object storage must be passed as an argument"
      unless defined $session->{args}{Directory};
  my $dir = $session->{args}{Directory};
  my $levels = $session->{args}{DirLevels} || 0;
  my $file = $session->{data}{_session_id};
  while ($levels) {
    $file =~ s|((..){$levels})|$1/|;
    $levels--;
  }
  "$dir/$file";
}

sub tree_init {
  my $self    = shift;
  my $dir = shift;
  my $levels = shift;
  my $n = 0x100 ** $levels;
  warn "Creating directory $dir and $n subdirectories in $levels level(s)\n";
  warn "This may take a while\n" if $levels>1;
  require File::Path;
  $|=1;
  my $feedback =
      sub {
       $n--;
       printf "\r$n directories left             " unless $n % 256;
       print "\n" unless $n;
      };
  File::Path::mkpath($dir);
  make_dirs($dir,$levels,$feedback); # function for speed
}

sub make_dirs {
  my($dir, $levels, $feedback) = @_;
  $levels--;
  for (my $i=0; $i<256; $i++) {
    my $subdir = sprintf "%s/%02x", $dir, $i;
    -d $subdir or mkdir $subdir, 0755 or die "Couldn't mkdir $subdir: $!";
    $feedback->();
    make_dirs($subdir, $levels, $feedback) if $levels;
  }
}

1;
