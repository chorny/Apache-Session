######################################################################
#
# Consult the documentation before trying to run this file.
# You need to set the environment variable SESSION_FILE_DIRECTORY
# This file also assumes PerlSendHeader Off
#
######################################################################

use strict;
use Apache;
use Apache::Constants;
use Apache::Session::File;

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

my $link = $session->rewrite();

print<<__EOS__;

Hello<br>
Session ID number is: $session->{'_ID'}<br>
The Session ID is embedded in the URL<br>
<br>
Your input to the form was: $input<br>
Your name is $session->{'name'}<br>

<form action="$link" method="post">
  Type in your name here:
  <input name="input">
  <input type="submit" value="Go!">
</form>
__EOS__

print "<hr>These are the contents of the session hash:\n";
print $session->dump_to_html();

$session->store(); # You should store() regardless of autocommit
