#!/usr/local/bin/perl 

use Everything;
use Everything::HTML;
use Everything::XML;
use strict;
use XML::Generator;


my @types = ("writeup");
#these are the nodetypes you want it to list

my $numnodes = 12;
#number of nodes that you want to export
#NOTE: these should be put in a setting before release

initEverything 'everything';
my $XMLGEN = new XML::Generator;
my $SNODE = getNode 'system settings', 'setting';
my $SETTINGS = getVars $SNODE;


sub genTag { Everything::XML::genTag(@_); }


#first the channel tag
my $doc = ""; 

my $url = $$SETTINGS{site_url};

$url .= "/" unless $url =~ /\/$/;

$doc .= $XMLGEN->channel(
	"\n\t".genTag("title", $$SETTINGS{site_name}) .
	"\t".genTag("link", $url) .
	"\t".genTag("description", $$SETTINGS{site_description})
	)."\n";

foreach (@types) {
	$_ = getId(getType($_));
}

my $batch = $DB->sqlSelect("max(batch)", "newnodes");
my $limit = $numnodes;
my $csr = $Everything::dbh->prepare("
	SELECT * FROM newnodes
        left join node on newnodes.node_id=node.node_id
	where batch = $batch
	order by newnodes.id
	LIMIT $limit");
$csr->execute;
while (my $N = $csr->fetchrow_hashref) {
	$doc .= $XMLGEN->item(
		"\n\t".genTag("title", $$N{title}) .
		"\t".genTag("link", $url."?node_id=".$$N{node_id})
	)."\n";
}

print '<rdf:RDF 
xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns="http://my.netscape.com/rdf/simple/0.9/">';
print "\n".$doc."\n";
print '</rdf:RDF>';








