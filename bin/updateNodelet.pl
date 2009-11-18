#!/usr/local/bin/perl 

use strict;
use Everything;
use Everything::HTML;
use Everything::CacheStore;

initEverything "everything", 0, { servers => ["127.0.0.1:11211"] };

$Everything::HTML::CACHESTORE =  new Everything::CacheStore("cache_store:" . $CONFIG{'cachestore_dbserv'});

my $csr = $DB->sqlSelectMany('nodelet_id', 'nodelet', "updateinterval != 0");
my $USER = getNode 'guest user', 'user';
$Everything::HTML::USER = $USER;
#Everything::HTML::getTheme; 
$Everything::HTML::GNODE = $USER;


while (my $NL = $csr->fetchrow()) {
	$NL = getNodeById($NL);
	print "updating $$NL{title}\n";
	$$NL{nltext} = Everything::HTML::parseCode($$NL{nlcode}, $NL);
	$$NL{lastupdate} = time; 
#	print "$$NL{nltext}\n";	
	updateNode($NL,-1);
}
$csr->finish;

