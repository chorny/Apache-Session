use strict;
use Apache;
use Apache::Constants;
use Apache::Session;
use Apache::Session::File;
use CGI;

my $r = Apache->request();

$r->status(OK);
$r->content_type("text/html");
$r->send_http_header;

my $session_id = $r->path_info();
$session_id =~ s/^\///;

my $opts = { autocommit => 1, lifetime => 600 };

my $session = Apache::Session::File->open($session_id, $opts)||
              Apache::Session::File->new($opts);

die "No session" unless $session;

my $input = CGI::param('input');
$session->{'name'} = $input if $input;
print<<__EOS__;

Hello<br>
Session ID number is: $session->{'_ID'}<br>
You wrote $input<br>
Your name is $session->{'name'}<br>

<form action="http://localhost/test.perl/$session->{'_ID'}" method="post">
  Type in your name here:
  <input name="input">
  <input type="submit" value="Go!">
</form>
__EOS__

print "<hr>Session contents:\n";
print $session->dump_to_html();

$session->unlock();
