#!/usr/bin/perl

use lib "/var/everything/ecore";

use strict;
use Everything;
use Everything::HTML;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday tv_interval);

initEverything "everything";
%Everything::HTML::HTMLVARS = %{ eval (getCode('set_htmlvars')) };

my $csr;

my @title_list = grep { $_ !~ /^-/; } @ARGV;

if (@title_list) {
	my $titles = "title IN ("
		. join ', ',
			map { "'$_'" }
				@title_list;
	$titles .= ')';
	$csr = $DB->sqlSelectMany('nodelet_id', 'nodelet JOIN node ON nodelet_id = node_id', $titles);
} else {
	$csr = $DB->sqlSelectMany('nodelet_id', 'nodelet', "updateinterval != 0");
}

my $USER = getNode 'guest user', 'user';

$Everything::HTML::USER = $USER;
$Everything::HTML::GNODE = $USER;

my $forceUpdate = grep { /--force/ } @ARGV;

while (my $NL = $csr->fetchrow()) {
	$NL = getNodeById($NL);

	if (!defined $$NL{updateinterval} && !$forceUpdate)
	{
		my $title = $$NL{title} || "";
		my $nid = $$NL{nodelet_id} || "NO NODELET ID";
		print "Skipping real-time nodelet $title ($nid}).\n";
		next;
	}

	# The following logic implies an interval of -1 will always update
	my $timeToUpdate = $$NL{lastupdate} + $$NL{updateinterval};
	my $timeToUpdateStr = strftime("%a %b %e %H:%M:%S %Y", localtime($timeToUpdate));
	my $currentTime = time;


	if ($timeToUpdate <= $currentTime || $forceUpdate) {

		my $startTime = [ gettimeofday() ];
		my $startMsg = "updating $$NL{title} ($$NL{nodelet_id})";
		print $startMsg;
		Everything::printLog($startMsg);
		$$NL{nltext} = Everything::HTML::parseCode($$NL{nlcode}, $NL);
		$$NL{lastupdate} = $currentTime; 
		updateNode($NL,-1);
		my $nodeletTime = tv_interval($startTime);
		my $endMsg = "...done ($nodeletTime seconds elapsed)";
		print "$endMsg\n";
		Everything::printLog($endMsg);

	} else {

		print "...not updating $$NL{title} ($$NL{nodelet_id}) until " . $timeToUpdateStr . "\n";

	}
}
$csr->finish;
