$^W = 0;

print "1..24\n";

require Apache::Session::File;
print "ok 1\n";

my $new = Apache::Session::File->new();
print $new ? "ok 2\n" : "not ok 2\n";

print ( ( $new->{'_EXPIRES'} > time() )   ? "ok 3\n" : "not ok 3\n" );
print ( ( $new->{'_LIFETIME'} > 0 )       ? "ok 4\n" : "not ok 4\n" );
print ( ( $new->{'_ID'} =~ /[a-f0-9]/ )   ? "ok 5\n" : "not ok 5\n" );
print ( ( $new->{'_AUTOCOMMIT'} ne "" )   ? "ok 6\n" : "not ok 6\n" );
print ( ( $new->{'_ACCESSED'} <= time() ) ? "ok 7\n" : "not ok 7\n" );

#string storage
my $scalar = qq/test123,.;'[]\-=<>?:"{}|_+!@#$%^&*()`~/;
$new->{'test'} = $scalar;
print ( ( $new->{'test'} eq $scalar ) ? "ok 8\n" : "not ok 8\n" );

#string deletion
delete $new->{'test'};
print ( defined ( $new->{'test'} )  ? "not ok 9\n" : "ok 9\n" );

#array storage
my @array = (1,2,3,4,5);
$new->{'array'} = \@array;
print ( ( $new->{'array'}->[0] == $array[0] ) ? "ok 10\n" : "not ok 10\n" );

#array iteration
my @test = ();
foreach ( @{$new->{'array'}} ) {
  push @test, $_;
}
print ( ( @test == @array ) ? "ok 11\n" : "not ok 11\n" );

#array deletion
delete $new->{'array'};
print ( defined ( $new->{'array'} )  ? "not ok 12\n" : "ok 12\n" );

#hash storage
my %hash = ( 'this' => 'that', 'those' => 'these' );
$new->{'hash'} = \%hash;
print ( ( $new->{'hash'}->{'this'} eq $hash{'this'} ) ? "ok 13\n" : "not ok 13\n" );

#hash iteration
my $key;
my %test;
foreach $key ( keys %{$new->{'hash'}} ) {
  $test{$key} = $new->{'hash'}->{$key};
}

print ( ( ( $test{'this'} eq 'that' ) && ( $test{'those'} eq 'these' ) ) ? "ok 14\n" : "not ok 14\n" );

#hash key deletion
delete $new->{'hash'}->{'this'};
print ( defined ( $new->{'hash'}->{'this'} ) ? "not ok 15\n" : "ok 15\n" );

#hash deletion
delete $new->{'hash'};
print ( defined ( $new->{'hash'} ) ? "not ok 16\n" : "ok 16\n" );

#data persistence
$new->{'scalar'} = $scalar;
$new->{'array'} = \@array;
$new->{'hash'} = \%hash;
$new->store();

my $id = $new->{'_ID'};
undef $new;

my $old = Apache::Session::File->open( $id );
print "ok 17\n";

print ( ( $old->{'_ID'} eq $id )        ? "ok 18\n" : "not ok 18\n" );
print ( ( $old->{'scalar'} eq $scalar ) ? "ok 19\n" : "not ok 19\n" );
print ( ( @{$old->{'array'}} eq @array)  ? "ok 20\n" : "not ok 20\n" );
print ( ( %{$old->{'hash'}} eq %hash)    ? "ok 21\n" : "not ok 21\n" );

#data destruction
$old->destroy();
undef $old;

my $destroyed = Apache::Session::File->open( $id );
print "ok 22\n";

print ( $destroyed ? "not ok 23\n" : "ok 23\n" );

#locking
my $locked = Apache::Session::File->new();
my $contentious = Apache::Session::File->open( $locked->{'_ID'} );
print $contentious ? "not ok 24\n" : "ok 24\n";

exit 0
