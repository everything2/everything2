#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything;

$DB->insertNode("normaluser","user",-1,{});

my $author = getNode("normaluser","user");
my $types = 
{
  "e2node" => getNode("e2node","nodetype"),
  "writeup" => getNode("writeup","nodetype")
};

my $writeuptypes =
{
  "idea" => getNode("idea","writeuptype"),
};

my $writeups = [
  ["Quick brown fox","The quick brown fox jumped over the [lazy dog]"]
];

# insertNode is: $title, $TYPE, $USER, $DATA

foreach my $thiswriteup (@$writeups)
{
  unless(my $writeup_parent = getNode($thiswriteup->[0],"e2node"))
  {
    print "Inserting e2node: '$thiswriteup->[0]'\n";
    $DB->insertNode($thiswriteup->[0],"e2node",$author,{});

    print "Inserting writeup: '$thiswriteup->[0] (idea)'\n";
    my $parent_e2node = getNode($thiswriteup->[0],"e2node");
    $DB->insertNode("$thiswriteup->[0] (idea)","writeup",$author, {});

    my $writeup = getNode("$thiswriteup->[0] (idea)","writeup");

    $writeup->{parent_e2node} = $parent_e2node->{node_id};
    $writeup->{wrtype_writeuptype} = $writeuptypes->{idea}->{node_id};
    $writeup->{doctext} = $thiswriteup->[1];
    $writeup->{notnew} = 0;
    $writeup->{cooled} = 0;
    $writeup->{document_id} = $writeup->{node_id};
    $writeup->{writeup_id} = $writeup->{writeup_id};
    $DB->updateNode($writeup, -1);
    $DB->insertIntoNodegroup($parent_e2node,-1,$writeup);
    $DB->updateNode($parent_e2node, -1);
  }
}
