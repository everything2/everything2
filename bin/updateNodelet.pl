#!/usr/local/bin/perl 

use strict;
use Everything;
use Everything::HTML;
use Everything::CacheStore;
use POSIX qw(strftime);
initEverything "everything", 0, { servers => ["127.0.0.1:11211"] };

$Everything::HTML::CACHESTORE =  new Everything::CacheStore("cache_store:" . $CONFIG{'cachestore_dbserv'});

my $csr = $DB->sqlSelectMany('nodelet_id', 'nodelet', "updateinterval != 0");
my $USER = getNode 'guest user', 'user';

$Everything::HTML::USER = $USER;
#Everything::HTML::getTheme; 
$Everything::HTML::GNODE = $USER;

my $forceUpdate = grep { /--force/ } @ARGV;

while (my $NL = $csr->fetchrow()) {
	$NL = getNodeById($NL);

	if (!defined $$NL{updateinterval})
	{
		print "Skipping real-time nodelet $$NL{title} ($$NL{nodelet_id}).\n";
		next;
	}

	# The following logic implies an interval of -1 will always update
	my $timeToUpdate = $$NL{lastupdate} + $$NL{updateinterval};
	my $timeToUpdateStr = strftime("%a %b %e %H:%M:%S %Y", localtime($timeToUpdate));
	my $currentTime = time;


	if ($timeToUpdate <= $currentTime || $forceUpdate) {

		print "updating $$NL{title} ($$NL{nodelet_id})";
		$$NL{nltext} = Everything::HTML::parseCode($$NL{nlcode}, $NL);
		$$NL{lastupdate} = $currentTime; 
		updateNode($NL,-1);
		print "...done\n";

	} else {

		print "...not updating $$NL{title} ($$NL{nodelet_id}) until " . $timeToUpdateStr . "\n";

	}
}
$csr->finish;
