BEGIN 
    { 
    $end = 0 ; 
    mkdir './tmp', 0755 ;
    $ENV{SESSION_FILE_DIRECTORY}='./tmp' ;
    }

END   { print "\n ERRORS detected! Not all Tests successfull!\n" if (!$end) ; }

use Apache::Session ;
use Apache::Session::IPC ;
use Apache::Session::Win32 ;
use Apache::Session::File ;


sub SimpleTestPut

    {
    my $subclass = shift ;
    my $testno	 = shift ;

    print "Simple Test for Apache::Session::$subclass (put data)\n" ;

    my %h1 ;
    my $id ;

    print "Try to tie hash ...           " ;
    tie %h1,'Apache::Session', $subclass or die "Cannot tie hash h1" ;

    print "ok\n" ;
    print "Try to put data into it ...   " ;

    $h1{'A'} = "$testno-1" ;

    print "ok\n" ;

    print "Try to put data into it ...   " ;

    $h1{'B'} = "$testno-2" ;

    print "ok\n" ;

    print "Let look at the ID ...        " ;
    $id = $h1{_ID} ;
    print "$id\n" ;

    print "And now untie ...             " ;
    untie %h1 ;
    print "ok\n" ;

    return $id ;
    }


sub SimpleTestGet

    {
    my $subclass = shift ;
    my $testno	 = shift ;
    my $id	 = shift ;

    print "Simple Test for Apache::Session::$subclass (get data)\n" ;

    my %h2 ;

    print "Try to tie to second hash ... $id " ;
    tie %h2,'Apache::Session', $subclass, $id or die "Cannot tie hash h2" ;

    print "ok\n" ;
    print "Try to get data ...           " ;

    $h2{'A'} eq "$testno-1" or die "Wrong data (is=$h1{'A'} should=$testno-1)" ;

    print "ok\n" ;

    print "Try to get data ...           " ;

    $h2{'B'} eq "$testno-2" or die "Wrong data (is=$h1{'B'} should=$testno-2)" ;

    print "ok\n" ;

    print "Let look at the ID ...        " ;
    $h2{_ID} eq $id or die "Wrong id (is=$h1{_ID} should=$id)" ;
    print "ok\n" ;

    print "And now untie ...             " ;
    untie %h2 ;
    print "ok\n" ;


    }

$| = 1 ;
select(STDERR) ;
$| = 1 ;
select(STDOUT) ;


@subclass = (
            'File',
            #'IPC',
            'Win32'
            ) ;

foreach $c (@subclass)
    {
    $id1 = SimpleTestPut ($c, 'A') ;
    SimpleTestGet ($c, 'A', $id1) ;
    $id2 = SimpleTestPut ($c, 'B') ;
    $id3 = SimpleTestPut ($c, 'C') ;
    SimpleTestGet ($c, 'B', $id2) ;
    SimpleTestGet ($c, 'C', $id3) ;
    }

$end = 1 ;

print "\nAll test successfull\n" ;
