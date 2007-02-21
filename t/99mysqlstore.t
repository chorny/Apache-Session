use Test::More;
use Test::Deep;
use Test::Exception;
use File::Temp qw[tempdir];
use Cwd qw[getcwd];

plan skip_all => "Not running RDBM tests without APACHE_SESSION_MAINTAINER=1"
  unless $ENV{APACHE_SESSION_MAINTAINER};
plan skip_all => "Optional modules (DBD::mysql, DBI) not installed"
  unless eval {
               require DBI;
               require DBD::mysql;
              };

#my $origdir = getcwd;
#my $tempdir = tempdir( DIR => '.', CLEANUP => 1 );
#chdir( $tempdir );

plan tests => 2;

my $package = 'Apache::Session::Store::MySQL';
use_ok $package;

my $foo = $package->new;

isa_ok $foo, $package;

#chdir( $origdir );
