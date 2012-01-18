#!/usr/bin/perl -w 

use strict;
use Everything;
use Everything::HTML;
use CGI;

mod_perlpsuedoInit "everything";


my $gu = getNode("guest user", "user");
my $XIT = getNode("XML Interfaces Ticker", "ticker");
gotoNode($$XIT{node_id}, $$gu{node_id});

#print Everything::HTML::parseCode($$wapdef{doctext});

