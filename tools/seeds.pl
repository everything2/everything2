#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;

initEverything;

if($Everything::CONF->environment ne "development")
{
	print STDERR "Not in the 'development' environment. Exiting\n";
	exit;
}

my $APP = $Everything::APP;

foreach my $user (1..30,"user with space")
{
  if($user =~ /^\d/)
  {
    # Insert a user like "normaluser1"
    $user = "normaluser$user";
  }
  print STDERR "Inserting user: $user\n";
  $DB->insertNode($user,"user",-1,{});

  my $author = getNode($user,"user");
  $author->{author_user} = $author->{node_id};
  $author->{passwd} = "blah";
  $author->{doctext} = "Homenode text for $user";
  $author->{votesleft} = 50;
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
  "normaluser1" => [
    ["Quick brown fox", "thing", "The quick brown fox jumped over the [lazy dog]"],
    ["lazy dog","idea","The lazy dog kind of just sat there while the [quick brown fox] jumped over him"],
    ["regular brown fox","person","Not very [quick], but still [admirable]. What does [he|the fox] say?"],
    ["Why are foxes lazy?","essay","<em>Are they really lazy?</em><strong>Here is my manifesto</strong>"],
    ["Dogs are a man's best friend","idea","I want to [hug all the dogs]. HUG them. [Hug them long]. [Hug them huge]"],
    ["hug all the dogs","thing","Break out the pug hugs"]],
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
      print STDERR "Inserting e2node: '$thiswriteup->[0]'\n";
      $DB->insertNode($thiswriteup->[0],"e2node",$authornode,{});
      $writeup_parent = $DB->getNode($thiswriteup->[0],"e2node");
    }
    my $writeuptype = getNode($thiswriteup->[1],"writeuptype");

    print STDERR "Inserting writeup: '$thiswriteup->[0] ($writeuptype->{title})'\n";
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

my $cools = { "normaluser1" => ["good poetry (poetry)"], "normaluser5" => ["Quick brown fox (thing)","lazy dog (idea)", "regular brown fox (person)"]};

foreach my $chinger (keys %$cools)
{
  my $chinger_node = getNode($chinger, "user");
  foreach my $writeup (@{$cools->{$chinger}})
  {
    my $writeup_node = getNode($writeup, "writeup");
    unless($writeup_node)
    {
      print STDERR "ERROR: Could not get writeup node '$writeup'"; 
      next;
    }
    $writeup_node->{cooled}++;
    updateNode($writeup_node, -1);
    $DB->sqlInsert("coolwriteups",{"coolwriteups_id" => $writeup_node->{node_id}, cooledby_user => $chinger_node->{node_id}});
  }
}

# Create a document so we can create a new item
my $frontpage_superdoc = $DB->getNode("News for Noders. Stuff that matters.", "superdoc");
print STDERR "Creating frontpage news item\n";
$DB->insertNode("Front page news item #1", "document", $DB->getNode("root","user"), {});
my $document = getNode("Front page news item #1","document");
$document->{doctext} = "This is the dawn of a new age. Of Everything. And Anything. <em>Mostly</em> [Everything]";
$DB->updateNode($document, -1);
$DB->sqlInsert("weblog",{"weblog_id" => $frontpage_superdoc->{node_id}, "to_node" => $document->{node_id} }); 

# Cast some votes so we can generate front page content

for my $writeup ("Quick brown fox (thing)","lazy dog (idea)", "regular brown fox (person)")
{
  my $writeupnode = getNode($writeup, "writeup");
  unless($writeupnode)
  {
    print STDERR "ERROR: Could not get writeupnode: '$writeup'\n";
    next;
  }
  for my $userseq (2..30)
  {
    my $weight = 1;
    if($userseq == 23)
    {
      #23 is a jerk
      $weight = -1;
    }

    my $user = getNode("normaluser$userseq","user");
    unless($user)
    {
      print STDERR "ERROR: Could not get author for vote: 'normaluser$userseq'\n";
      next;
    }
    print STDERR "Casting vote $user->{title} on '$writeupnode->{title}'\n";
    $APP->castVote($writeupnode, $user, $weight);
  }
}

