#!/usr/bin/perl

use lib "/var/everything/ecore";

use strict;
use Everything;
use Everything::HTML;
require CGI;

my $STYLESHEET_PATH = '/var/everything/www/stylesheet/';

initEverything "everything", 0, { servers => ["127.0.0.1:11211"] };
%Everything::HTML::HTMLVARS = %{ eval (getCode('set_htmlvars')) };
$Everything::HTML::USER = getNode('Guest User', 'user');
$query = new CGI();

mkdir $STYLESHEET_PATH unless -e $STYLESHEET_PATH;

my $forceUpdate = grep { /--force/ } @ARGV;
my @title_list = grep { $_ !~ /^-/; } @ARGV;
my $titleRestrict = '';


if (@title_list) {
	$titleRestrict = "title IN ("
		. join ', ',
			map { $DB->quote($_) }
				@title_list;
	$titleRestrict .= ')';
}

my @stylesheets = $DB->getNodeWhere($titleRestrict, 'stylesheet');
my %displaytypes = (
	'basesheet'		=>		'view',
	'print'			=>		'view',
);

foreach my $stylesheetNode (@stylesheets) {

	foreach my $autofix (qw/0 1/) {

			my $autofixFilename = $autofix ? "_autofix" : "";
			my $version = $DB->{cache}->getGlobalVersion($stylesheetNode);
			my $escapeTitle = CGI::escape($$stylesheetNode{title});
			$escapeTitle =~ s/%[0-9A-F]{2}|_//g;
			my $stylesheetFilename = "${escapeTitle}_v${version}${autofixFilename}.css";
			my $stylesheetFilepath = $STYLESHEET_PATH . $stylesheetFilename;
			my $stylesheetFilepathbase = $STYLESHEET_PATH . $escapeTitle . "$autofixFilename.css";
			next if -e $stylesheetFilepath and not $forceUpdate;

			my $displaytype = 'serve';
			$displaytype = $displaytypes{$escapeTitle} if exists $displaytypes{$escapeTitle};
			
			my $outputter = getPage($stylesheetNode, $displaytype);
			$Everything::HTML::GNODE = $stylesheetNode;
			if ($autofix) {
				$query->param('autofix', 1);
			} else {
				$query->delete('autofix');
			}
			my $out = parseCode($$outputter{page}, $stylesheetNode);
			my $fh = FileHandle->new($stylesheetFilepath, "w");
			if (!$fh) {
				print "Failed to create $stylesheetFilepath when generating stylesheet. : $@\n";
			} else {
				$fh->print($out);
				undef $fh;
				unlink $stylesheetFilepathbase if -l $stylesheetFilepathbase;
				symlink($stylesheetFilepath, $stylesheetFilepathbase);
			}

	}

}
