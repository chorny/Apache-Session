package Apache::Session;

$Apache::Session::VERSION = '0.10';

my $LIFETIME = 3600; #seconds
if ( $ENV{'APACHE_SESSION_LIFETIME'} ) {
	
	$LIFETIME = $ENV{'APACHE_SESSION_LIFETIME'};

}

my %sessions;

sub new {

	my $package = shift;
	my $this_session = shift;
	my $self;
	
	#you'll pay for not providing a session ID
	die "Invalid session ID in constructor" unless $this_session;
	
	SWITCH:	{

	($self = &create_new($this_session, $package)), last SWITCH unless $sessions{$this_session};
	$self = $sessions{$this_session};
	($self = &create_new($this_session, $package)), last SWITCH if ($self->{'meta'}->{'expiration_time'} < time());

	}
	
	return $sessions{$this_session};
	
	sub create_new {
	
		my $this_session = shift;
		my $package = shift;
		
		my $self = {};

		$self->{'meta'}->{'id'} = $this_session;
		$self->{'meta'}->{'lifetime'} = $LIFETIME;
		$self->{'meta'}->{'expiration_time'} = time() + $LIFETIME;

		$sessions{$this_session} = $self;
		bless($sessions{$this_session},$package);	
				
		return $self;

	}

}

sub set {

	my $self = shift;
	my $var_name = shift;
	my $ref_to_value = shift;

	touch($self);

	return 0 if (!$var_name);
	return 0 if (!ref($ref_to_value));

	$self->{'data'}->{$var_name} = $ref_to_value;

	return 1;
	
}

sub read {

	my $self = shift;
	my $var_name = shift;

	touch($self);

	return $self->{'data'}->{$var_name} if ($self->{'data'}->{$var_name});
	return undef;
}

sub delete {

	my $self = shift;
	my $var_name = shift;
	
	touch($self);
	
	delete $self->{'data'}->{$var_name};
	1;
	
}

sub abandon {

	my $self = shift;
	my $my_id = $self->{'meta'}->{'id'};
	
	delete $sessions{$my_id};
	
	return 1;
	
}

sub lifetime {

	my $self = shift;
	my $new_lifetime = shift;

	if (defined $new_lifetime) {
	
		$self->{'meta'}->{'lifetime'} = $new_lifetime;
		$self->{'meta'}->{'expiration_time'} = time() + $new_lifetime;
		
	}

	return $self->{'meta'}->{'lifetime'};
	
}

sub set_default_lifetime {

	my $self = shift;
	my $new_lifetime = shift;
	
	if (defined $new_lifetime) {
		
		$LIFETIME = $new_lifetime;
		
	}
	
	return $LIFETIME;
	
}

sub expires {
	
	my $self = shift;
	my $new_exp_time = shift;
	
	if ($new_exp_time) {
			
		$self->{'meta'}->{'expiration_time'} = $new_exp_time;
		
	}
	
	return $new_exp_time;
	
}

sub touch {

	my $self = shift;
	
	$self->{'meta'}->{'expiration_time'} = time() + $self->{'meta'}->{'lifetime'};

	return $self->{'meta'}->{'expiration_time'};

}

sub get_id {
	
	my $self = shift;
	
	return $self->{'meta'}->{'id'};
	
}

#included for future use
sub get_error_msg {

	my $self = shift;
	
	return $self->{'meta'}->{'error_msg'};

}

sub dump_to_plain_text {

	my $self = shift;
	my $s;
	foreach $key (sort(keys(% { $self->{'data'} }))) {
		
		$s = $s."$key, $self->{'data'}->{$key}\n";
	
	}

	return $s;

}

sub dump_to_html {

	my $self = shift;
	my $s;
	
	$s = $s."<table border=1><tr><td>Variable Name</td><td>Type</td><td>Scalar Value</td></tr>";
	
	foreach $key (sort(keys(% { $self->{'data'} }))) {
		
		$s = $s."<tr><td>$key</td><td>$self->{'data'}->{$key}</td>";
		
		if (ref($self->{'data'}->{$key}) eq "SCALAR") {
			
			$s = $s."<td>$ { $self->{'data'}->{$key} }</td></tr>\n";
			
		}
		
		else {
		
			$s = $s."<td>\&nbsp\;</td></tr>\n";
			
		}
	
	}

	$s = $s."</table>\n";
	
	return $s;

}

Apache::Status->menu_item(

    'Session' => 'Session Objects',
    sub {
        my($r, $q) = @_;
        my(@s) = "<TABLE border=1><TR><TD>Session ID</TD><TD>Expires</TD></TR>";
        for (keys %sessions) {
					my $expires = localtime(%sessions->{$_}->{'meta'}->{'expiration_time'});
          push @s, '<TR><TD>', $_, '</TD><TD>', $expires, "</TD></TR>\n";
        }
        push @s, '</TABLE>';
        return \@s;
   }

) if ($INC{'Apache.pm'} && Apache->module('Apache::Status'));

1;

__END__

=head1 NAME

 Apache::Session - Maintain session state across HTTP requests

=head1 SYNOPSIS

 use Apache::Session;
 my $session = Apache::Session->new($id);
 $session->set('a_hash', { 'this' => 'that' };
 my $hashref = $session->read('a_hash');

=head1 DESCRIPTION

This module provides the Apache/mod_perl user a mechanism for storing persistent 
user data in a global hash.  This package does not rely on any other non-standard
Perl modules.

This package should be considered alpha.  The interface is likely to change if I 
get any feedback at all :)  Currently, this package will not work properly on unix.
It does work on Win32 systems.  Unix operability is planned pronto.

=head1 INSTALLATION

Copy Session.pm to your perl/lib/site/Apache/ directory, or appropriate lib path.

=head1 ENVIRONMENT

Apache::Session will respect the environment variable APACHE_SESSION_LIFETIME.
This variable sets the default lifetime, in seconds, of a session object.  After
the session has been idle that many seconds, it will automatically expire.  The 
preferred way to set this default would be in your Apache http.conf:

PerlSetEnv APACHE_SESSION_LIFETIME 3600 #expire after 1 hour

If the environment variable is not set, the default is 3600 seconds.

=head1 USAGE

=head2 Creating a session object

my $session = Apache::Session->new($session_id);

where $session_id is some random variable.  IMPORTANT: The method of tracking your 
users is up to you!  You must supply Apache::Session with a valid session ID.  This 
means that you are free to use cookies, header munging, or extra-sensory perception.
The new() method behaves differently depending on its history:

CASE 1: There is no session with this session ID.  new() returns a blessed reference to
a clean session object.

CASE 2: A session already exists under that ID.  new() returns a blessed reference to the
already existing session, including all data stored in that object.

CASE 3: You didn't provide a session ID.  new() dies.

Try to avoid CASE 3.

=head2 Data Methods

=over 4
=item set(variable_name, reference_to_value)

Data is stored in a session object using the set() method.  Set() takes two arguments:
a variable name and a reference to a data structure.  The data structure can be as
complex as you like, or a simple scalar.

 $a_scalar = 'Foo';
 $session->set('a_scalar',\$a_scalar);

 %a_hash = ( 'this' => 'that' );
 $session->set('a_hash',\%a_hash);

 $session->set('anon_hash',{ 'this' => 'that' });

If the variable name is omitted, or the reference is not a reference, set() returns 0.

=item read(variable_name)

Data is read back using the read() method.  Read takes one argument, the name of the
variable to retrieve.  If that variable exists in the session object, a reference to
it is returned.  Otherwise, read() returns undef.

 $scalar_ref = $session->read('a_scalar'); #returns a reference
 print $ { $scalar_ref };                  #OK
 print $scalar_ref;                        #probably wrong
 
Note that since read() returns a reference, simply doing
 
 print $session->read('a_scalar')
 
will produce SCALAR(0xABCDEF).  Remember to dereference before use.

A neat trick arises when you return references this way: you can store data without
using the set() method.  This has its ups and downs.  For instance, you populate an array
using:

 $array_ref = $session->read('an_array');
 for($i=0 ; $i<100; $i++) {
      @ { $array_ref }->[$i] = "Foo";
 }

Because the session object maintains a reference to this array, it automatically inherits
the values you put in it.  However, you must be careful not to redefine variables on 
accident.

=item delete(variable_name)

Deletes the session object's reference to a variable.  Always returns true.

 $session->delete('a_scalar');

=back

=head2 Metadata Methods

=over 4

=item abandon()

Abandon() takes no arguments.  Abandon destroys the package's internal reference to that
session.  Abandon() always returns true.

=item expires([new_expiration_time])

Expires() takes one optional argument: the time that the session should die in seconds
since the epoch.  This method allows you to specify an exact time of expiration (noon)
instead of a relative time (one hour from now).  Expires() returns the time that the
session will die.

=item lifetime([new_lifetime])

Lifetime() takes one optional argument: the time that the session should expire in seconds 
from now.  Lifetime() returns the lifetime after making any changes you specify.

=item set_default_lifetime([default_lifetime])

Set_default_lifetime() takes one optional argument: the lifetime in seconds that new session objects
should have by default.  This is equivalent to setting the APACHE_SESSION_LIFETIME environment
variable.  Set_default_lifetime() returns the default lifetime after making any change you
specify.

=item touch()

Touch() takes no arguments.  Calling touch() gives your session a new lifetime, setting
its expiration time to now+lifetime, as set by the lifetime() function.  Calling set() or
read() also touch()es your session object, so you needn't usually worry about touch()ing
it yourself.

=item get_id()

Get_id() returns the session ID number that specifies the calling object.  Useful for 
debugging your user-tracking mechanism.

=back

=head2 Other Methods

These methods are meant to be useful for debugging your application.  Both of them
dump all of the data stored in them to a table.  The table will list all of the 
variable names stored, whether they are references to scalars, arrays, hashes, or
whatever, and it will show the value for scalar references.

=over 4

=item dump_to_plain_text()

=item dump_to_html()

Just like they sound: dump session data to text or HTML table.

=back

=head1 MISC

Apache::Session will install a menu under your Apache::Status package, if you are 
using it.  It will show each session's ID and expiration time (in plain format).

=head1 AUTHORS

Jeffrey Baker <jeff@godzilla.tamu.edu>.  Redistribute under the Perl Artistic License.
