#!/usr/bin/perl

use lib "/var/everything/ecore";

use strict;
use Everything;
use Everything::HTML;
use Everything::CacheStore;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday tv_interval);

my $STYLESHEET_PATH = '/var/everything/www/stylesheet/';

initEverything "everything", 0, { servers => ["127.0.0.1:11211"] };
%Everything::HTML::HTMLVARS = %{ eval (getCode('set_htmlvars')) };

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

foreach my $stylesheetNode (@stylesheets) {

	my $version = $DB->{cache}->getGlobalVersion($stylesheetNode);
	my $escapeTitle = CGI::escape($$stylesheetNode{title});
	$escapeTitle =~ s/%[0-9A-F]{2}|_//g;
	my $stylesheetFilename = "${escapeTitle}_v$version.css";
	my $stylesheetFilepath = $STYLESHEET_PATH . $stylesheetFilename;
	my $stylesheetFilepathbase = $STYLESHEET_PATH . $escapeTitle . ".css";
	next if -e $stylesheetFilepath and not $forceUpdate;

	my $fh = FileHandle->new($stylesheetFilepath, "w");
	if (!$fh) {
		print "Failed to create $stylesheetFilepath when generating stylesheet. : $@";
	} else {
		$fh->print($$stylesheetNode{doctext});
		undef $fh;
		symlink($stylesheetFilepath, $stylesheetFilepathbase);
	}
}
