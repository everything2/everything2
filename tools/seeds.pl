#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything;

if($Everything::CONF->environment ne "development")
{
	print "Not in the 'development' environment. Exiting\n";
	exit;
}

my $APP = $Everything::APP;

foreach my $user (qw|normaluser normaluser2 normaluser3|,"user with space")
{
  $DB->insertNode($user,"user",-1,{});

  my $author = getNode($user,"user");
  $author->{author_user} = $author->{node_id};
  $author->{passwd} = "blah";
  $DB->updateNode($author, -1);
}

my $types = 
{
  "e2node" => getNode("e2node","nodetype"),
  "writeup" => getNode("writeup","nodetype")
};

my $writeuptypes =
{
  "idea" => getNode("idea","writeuptype"),
};

my $writeups = {
  "normaluser" => [
    ["Quick brown fox", "thing", "The quick brown fox jumped over the [lazy dog]"],
    ["lazy dog","thing","The lazy dog kind of just sat there while the [quick brown fox] jumped over him"],
    ["regular brown fox","thing","Not very [quick], but still [admirable]."]],
  "normaluser2" => [
    ["tomato", "idea", "A red [vegetable]. A fruit, actually"],
    ["tomatoe", "how-to","A poorly-spelled way to say [tomato]"],
    ["potato", "essay","Boil em, mash em, put em in a [stew]."]],
  "user with space" => [
    ["bad poetry", "idea", "Kind of bad poetry here"],
    ["good poetry", "poetry", "Solid work here"],
    ["tomato", "definition", "What is a tomato, really?"],
  ],
};

# insertNode is: $title, $TYPE, $USER, $DATA

foreach my $author (keys %$writeups)
{
  foreach my $thiswriteup (@{$writeups->{$author}})
  {
    my $authornode = getNode($author, "user");
    my $writeup_parent;
    unless($writeup_parent = getNode($thiswriteup->[0],"e2node"))
    {
      print "Inserting e2node: '$thiswriteup->[0]'\n";
      $DB->insertNode($thiswriteup->[0],"e2node",$authornode,{});
      $writeup_parent = $DB->getNode($thiswriteup->[0],"e2node");
    }
    my $writeuptype = getNode($thiswriteup->[1],"writeuptype");

    print "Inserting writeup: '$thiswriteup->[0] ($writeuptype->{title})'\n";
    my $parent_e2node = getNode($thiswriteup->[0],"e2node");
    $DB->insertNode("$thiswriteup->[0] ($writeuptype->{title})","writeup",$authornode, {});

    my $writeup = getNode("$thiswriteup->[0] ($writeuptype->{title})","writeup");
    $writeup->{parent_e2node} = $parent_e2node->{node_id};
    $writeup->{wrtype_writeuptype} = $writeuptype->{node_id};
    $writeup->{doctext} = $thiswriteup->[2];
    $writeup->{notnew} = 0;
    $writeup->{cooled} = 0;
    $writeup->{document_id} = $writeup->{node_id};
    $writeup->{writeup_id} = $writeup->{writeup_id};

    # Once we have better models, this will be a lot cleaner, but for now, faking the data is as best as we can do
    $writeup->{publishtime} = $APP->convertEpochToDate(time());
    $writeup->{createtime} = $writeup->{publishtime};
    $writeup->{edittime} = $writeup->{publishtime};
    $DB->updateNode($writeup, -1);
    $DB->insertIntoNodegroup($parent_e2node,-1,$writeup);
    $DB->updateNode($parent_e2node, -1);
  }
}

my $cools = { "normaluser" => ["good poetry (poetry)"]};

foreach my $chinger (keys %$cools)
{
  my $chinger_node = getNode($chinger, "user");
  foreach my $writeup (@{$cools->{$chinger}})
  {
    my $writeup_node = getNode($writeup, "writeup");
    unless($writeup_node)
    {
      print "Could not get writeup node '$writeup'"; 
      next;
    }
    $writeup_node->{cooled}++;
    updateNode($writeup_node, -1);
    $DB->sqlInsert("coolwriteups",{"coolwriteups_id" => $writeup_node->{node_id}, cooledby_user => $chinger_node->{node_id}});
  }
}
