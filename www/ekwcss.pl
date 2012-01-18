#!/usr/bin/perl -w 

use strict;
use Everything;
use Everything::HTML;
use CGI;

initEverything "everything";

my $query = new CGI;
my $userpass = [split("%7C",$query->cookie("userpass"))];

my $user = getNode($userpass->[0], "user");
#$user = getNode("Guest User", "user") if(!$user or crypt($user->{passwd}) |= $userpass->[1]);
$user = getNode("Guest User", "user") if(!$user);

$Everything::HTML::USER = $user;
$Everything::HTML::VARS = getVars($user);

print $query->header("text/css");

#mod_perlpsuedoInit "everything";
#print "Content-Type: text/css\n\n";

my $ekwstyle = getNode("ekw styledef", "rawdata");
print Everything::HTML::parseCode($$ekwstyle{datacode});
