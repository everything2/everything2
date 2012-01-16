#!/usr/bin/perl

use lib "/var/everything/ecore";

use strict;
use Everything;
use Everything::HTML;

my $JAVASCRIPT_PATH = '/var/everything/www/js/';

initEverything "everything", 0, { servers => ["127.0.0.1:11211"] };
%Everything::HTML::HTMLVARS = %{ eval (getCode('set_htmlvars')) };

my $USER = getNode('Guest User', 'user');

$Everything::HTML::USER = $USER;
$Everything::HTML::GNODE = $USER;

mkdir $JAVASCRIPT_PATH unless -e $JAVASCRIPT_PATH;

my $jsCompiler = $DB->getNode('Javascript Compiler', 'jscript');
my $out = parseCode($$jsCompiler{doctext});
$out =~ s/^\s+//mg;

my $version = $HEADER_PARAMS{'-Last-Modified'};
$version =~ s/[ ,:]//g;
$version = substr($version, 3);             # Remove alpha day of week
$version =~ s/floating$//;                  # Remove "floating" if it's there;

my $javascriptFilepathbase = "${JAVASCRIPT_PATH}GuestJavascript.js";
my $javascriptFilepath = "${JAVASCRIPT_PATH}GuestJavascript_v$version.js";
exit 0 if -e $javascriptFilepath;

my $fh = FileHandle->new($javascriptFilepath, "w");
if (!$fh) {
  print "Failed to create $javascriptFilepath when generating Guest User Javascript. : $@\n";
} else {
  $fh->print($out);
  undef $fh;
  unlink $javascriptFilepathbase if -l $javascriptFilepathbase;
  symlink($javascriptFilepath, $javascriptFilepathbase);
}
