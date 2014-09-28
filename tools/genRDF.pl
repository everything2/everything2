#!/usr/bin/perl -w -I /var/everything/ecore

# This script at one time was used generate the RDF feed.
# It is very likely we'll use this as a starting point to do something like that again
# For now it is removed in the post-MSU world

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

sub genTag { Everything::XML::genTag(@_); }


#first the channel tag
my $doc = ""; 

my $url = $Everything::CONF->{system}->{site_url};

$url .= "/" unless $url =~ /\/$/;

$doc .= $XMLGEN->channel(
	"\n\t".genTag("title", $Everything::CONF->{system}->{site_name}) .
	"\t".genTag("link", $url) .
	"\t".genTag("description", $Everything::CONF->{system}->{site_description})
	)."\n";

foreach (@types) {
	$_ = getId(getType($_));
}

my $batch = $DB->sqlSelect("max(batch)", "newnodes") || 0;
my $limit = $numnodes;
my $csr = $DB->{dbh}->prepare("
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

