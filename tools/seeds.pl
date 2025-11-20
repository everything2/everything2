#!/usr/bin/perl -w

use strict;
use utf8;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Everything::HTML;
use POSIX;

initEverything;

if($Everything::CONF->environment ne "development")
{
	print STDERR "Not in the 'development' environment. Exiting\n";
	exit;
}

$Everything::HTML::USER = getNode("root","user");
my $APP = $Everything::APP;

my $months = [qw|January February March April May June July August September October November December|];
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();

my $realyear = $year+1900;
my $rootlog = "root log: $months->[$mon] $realyear";
my $daylog = "$months->[$mon] $mday, $realyear";

foreach my $user (1..30,"user with space","genericeditor","genericdev")
{
  if($user =~ /^\d/)
  {
    # Insert a user like "normaluser1"
    $user = "normaluser$user";
  }
  print STDERR "Inserting user: $user\n";
  my $now = POSIX::strftime('%Y-%m-%d %H:%M:%S', gmtime());
  $DB->insertNode($user,"user",-1,{"lasttime" => $now});

  my $author = getNode($user,"user");
  $author->{author_user} = $author->{node_id};
  $author->{passwd} = "blah";
  $author->{doctext} = "Homenode text for $user";
  $author->{votesleft} = 50;
  $DB->updateNode($author, -1);
}

print STDERR "Promoting genericeditor to be a content editor\n";
my $ce = $DB->getNode("Content Editors","usergroup");
my $genericed = $DB->getNode("genericeditor","user");
$DB->insertIntoNodegroup($ce, $DB->getNode("root","user"), $genericed);
$DB->updateNode($ce,-1);
$genericed->{vars} ||= "";
my $genericedv = getVars($genericed);
$genericedv->{nodelets} = "1687135,262,2044453,170070,91,263,1157024,165437,1689202,1930708";
$genericedv->{settings} = '{"notifications":{"2045486":1}}';
setVars($genericed,$genericedv);
$DB->updateNode($genericed, -1);

print STDERR "Promoting genericdev to be a developer\n";
my $dev = $DB->getNode("edev","usergroup");
my $genericdev = getNode("genericdev","user");
$DB->insertIntoNodegroup($dev, $DB->getNode("root","user"),$genericdev);
$DB->updateNode($dev, -1);
my $genericdevv = getVars($genericdev);
$genericdevv->{nodelets} = "1687135,262,2044453,170070,91,263,1157024,165437,1689202,1930708,836984";
$genericdevv->{settings} = '{"notifications":{"2045486":1}}';
setVars($genericdev,$genericdevv);
$DB->updateNode($genericdev, -1);

my $types = 
{
  "e2node" => getNode("e2node","nodetype"),
  "writeup" => getNode("writeup","nodetype")
};

my $writeuptypes =
{
  "idea" => getNode("idea","writeuptype"),
};

my $datanodes = {
  "writeup" => {
    "normaluser1" => [
      ["Quick brown fox", "thing", "The quick brown fox jumped over the [lazy dog]"],
      ["lazy dog","idea","The lazy dog kind of just sat there while the [quick brown fox] jumped over him"],
      ["regular brown fox","person","Not very [quick], but still [admirable]. What does [he|the fox] say?"],
      ["Why are foxes lazy?","essay","<em>Are they really lazy?</em><strong>Here is my manifesto</strong>"],
      ["Dogs are a man's best friend","idea","I want to [hug all the dogs]. HUG them. [Hug them long]. [Hug them huge]"],
      ["hug all the dogs","thing","Break out the pug hugs"],
      ["writeup with ' single quote","thing","Sometimes you just have to be quoted"],
      ["writeup with \" double quote","thing","Sometimes you just have to be quoted twice"],
      [$daylog, "log", "Sometimes you just gotta daylog, and trigger is_log!"]],
    "normaluser2" => [
      ["tomato", "idea", "A red [vegetable]. A fruit, actually"],
      ["tomatoe", "how-to","A poorly-spelled way to say [tomato]"],
      ["swedish tomatoë", "essay","Swedish tomatoes"],
      ["potato", "essay","Boil em, mash em, put em in a [stew]."],
      ["Writeups+plusses, a lesson in love","essay","All of the love for the [plus|+] sign"]],
    "normaluser3" => [
      ["hidden writeup here", "idea","This writeup was hidden from [New Writeups]"],
      ["Writeup w/ slash", "thing", "This writeup contains a slash"],
      ["Writeups & ampersands", "thing", "This writeup contains an ampersand"],
      ["Writeup; semicolon", "essay", "Dramatic and parser-breaking"],
      ["Writeups can have questions?", "idea", "Sometimes inquisitive is good!"],
    ], 
    "user with space" => [
      ["bad poetry", "idea", "Kind of bad poetry here"],
      ["good poetry", "poetry", "Solid work here"],
      ["tomato", "definition", "What is a tomato, really?"],
      ["really bad writeup", "poetry", "This is [super bad]"]
    ],
    "genericdev" => [
      ["boring dev announcement 1", "log", "Really, pretty boring stuff"],
      ["boring dev announcement 2", "idea", "Only interesting if you're a [developer]"],
      ["interesting dev announcement", "lede", "Don't bury the lede. Understand this!"],
      ["lukewarm dev announcement", "thing", "Not bad work. Not bad at all"],
      [$rootlog, "log", "This triggers is_log!"]
    ],
    "Virgil" => [
      ["An Introduction to Everything2", "place", "Stub content for a site help doc here"],
    ]
  },
  "draft" => {
    "normaluser1" => [
      ["Really old draft, editor neglected","thing","a draft to trigger editor neglect","review"],
      ["Really old draft, user neglected","thing","a draft to trigger user neglect","review"],
      ["Really, really old draft, user neglected","thing","a draft to trigger findable change","review"],
    ],
  },
};

# insertNode is: $title, $TYPE, $USER, $NODEDATA
foreach my $datatype (keys %$datanodes)
{
  foreach my $author (keys %{$datanodes->{$datatype}})
  {
    foreach my $thiswriteup (@{$datanodes->{$datatype}->{$author}})
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
      $DB->insertNode("$thiswriteup->[0] ($writeuptype->{title})",$datatype,$authornode, {});

      my $writeup = getNode("$thiswriteup->[0] ($writeuptype->{title})",$datatype);
      $writeup->{createtime} = $APP->convertEpochToDate(time());
      $writeup->{doctext} = $thiswriteup->[2];
      $writeup->{document_id} = $writeup->{node_id};

      if($datatype eq "writeup")
      {
        $writeup->{parent_e2node} = $parent_e2node->{node_id};
        $writeup->{wrtype_writeuptype} = $writeuptype->{node_id};
      
        $writeup->{notnew} = 0;
        if($thiswriteup->[0] =~ /hidden/i)
        {
          $writeup->{notnew} = 1;
        }

        $writeup->{cooled} = 0;
        $writeup->{writeup_id} = $writeup->{writeup_id};
        # Once we have better models, this will be a lot cleaner, but for now, faking the data is as best as we can do
        $writeup->{publishtime} = $writeup->{createtime};
        $writeup->{edittime} = $writeup->{createtime};
      }elsif($datatype eq "draft"){
        $writeup->{draft_id} = $writeup->{node_id};
        $writeup->{publication_status} = getNode($thiswriteup->[3],"publication_status")->{node_id};
      }
      $DB->updateNode($writeup, $authornode);
      if($datatype eq "writeup")
      {
        $DB->insertIntoNodegroup($parent_e2node,-1,$writeup);
        $DB->updateNode($parent_e2node, -1);
      }
    }
  }
}

# Update drafts to trigger user and editor neglect
foreach my $d("user","editor")
{
  print STDERR "Updating draft to backdate for $d neglect\n";
  my $neglect = $DB->getNode("Really old draft, $d neglected (thing)","draft");
  unless($neglect)
  {
    die "Could not get draft for neglect detection!";
  }
  $neglect->{createtime} = $APP->convertEpochToDate(time()-20*24*60*60);
  $neglect->{publishtime} = $neglect->{createtime};
  $DB->updateNode($neglect, -1);

  # Insert a nodenote where the notetext is null
  print STDERR "Putting node notes on $d neglect\n";
  $DB->sqlInsert("nodenote", {"nodenote_nodeid" => $neglect->{node_id}, "timestamp" => $APP->convertEpochToDate(time()-15*24*60*60),"notetext" => "author requested review"}); 
  if($d eq "user")
  {
    $DB->sqlInsert("nodenote",{"nodenote_nodeid" => $neglect->{node_id}, "timestamp" => $APP->convertEpochToDate(time()-10*24*60*60),"notetext" => "looks good","noter_user" => $DB->getNode("root","user")->{node_id}});
  }

}

# Trigger the neglecteddrafts boot back to findable
my $oldneglect = $DB->getNode("Really, really old draft, user neglected (thing)","draft");
$oldneglect->{createtime} = $APP->convertEpochToDate(time()-40*24*60*60);
$oldneglect->{publishtime} = $oldneglect->{createtime};
$DB->updateNode($oldneglect, -1);
$DB->sqlInsert("nodenote", {"nodenote_nodeid" => $oldneglect->{node_id}, "timestamp" => $APP->convertEpochToDate(time()-30*24*60*60),"notetext" => "author requested review"}); 
$DB->sqlInsert("nodenote", {"nodenote_nodeid" => $oldneglect->{node_id}, "timestamp" => $APP->convertEpochToDate(time()-29*24*60*60),"notetext" => "looks good","noter_user" => $DB->getNode("root","user")->{node_id}});



# Create a document so we can create a new item
my $frontpage_usergroup = $DB->getNode("News", "usergroup");
print STDERR "Creating frontpage news item\n";
$DB->insertNode("Front page news item 1", "document", $DB->getNode("root","user"), {});
my $document = getNode("Front page news item 1","document");
$document->{doctext} = "This is the dawn of a new age. Of Everything. And Anything. <em>Mostly</em> [Everything]";
$DB->updateNode($document, -1);
$DB->sqlInsert("weblog",{"weblog_id" => $frontpage_usergroup->{node_id}, "to_node" => $document->{node_id} }); 

print STDERR "Making some edev news items\n";
foreach my $title("boring dev announcement 2","interesting dev announcement","lukewarm dev announcement")
{
  my $n = $DB->getNode($title,"e2node");
  $DB->sqlInsert("weblog",{"weblog_id" => $dev->{node_id}, "to_node" => $n->{node_id},"linkedby_user" => $genericdev->{node_id}});
}


# Cast some votes so we can generate front page content

my $writeup_bank = {"Quick brown fox (thing)" => 1, "lazy dog (idea)" => 1, "regular brown fox (person)" => 1, "really bad writeup (poetry)" => -1};

for my $writeup (keys %$writeup_bank)
{
  my $writeupnode = getNode($writeup, "writeup");
  unless($writeupnode)
  {
    print STDERR "ERROR: Could not get writeupnode: '$writeup'\n";
    next;
  }
  for my $userseq (2..30)
  {
    my $weight = $writeup_bank->{$writeup};
    if($userseq == 23)
    {
      #23 is a jerk
      $weight = -1*$weight;
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

# Inserting an editor cool
my $coollink = $DB->getNode("coollink","linktype");
my $to_cool = ["Quick brown fox","tomato"];

foreach my $n (@$to_cool)
{
  my $coolnode = $DB->getNode($n, "e2node");
  print STDERR "Using editor cool from $genericed->{title} on $coolnode->{title}\n";
  $DB->sqlInsert("links",{"from_node" => $coolnode->{node_id}, "to_node" => $genericed->{node_id}, "linktype" => $coollink->{node_id}});
}


my $thing_writeuptype = $DB->getNode("thing","writeuptype");
my $normaluser1 = $DB->getNode("normaluser1","user");
my $root = $DB->getNode("root","user");

## Insert a node_forward
# Work around maintenance weirdness
print STDERR "Inserting a node_foward";
$Everything::HTML::query = new CGI;
my $potato = $DB->getNode("potato", "e2node");
my $nf = $DB->insertNode("Goto potato", "node_forward", $root, {});
$nf = $DB->getNode("Goto potato", "node_forward");
$nf->{doctext} = $potato->{node_id};
$DB->updateNode($nf, -1);
print STDERR "Inserted node_forward '$nf->{title}' to point to '$potato->{title}' ($potato->{node_id})\n";

$Everything::HTML::query = undef;


## Create a writeup with a broken writeuptype
print STDERR "Inserting a node with a broken writeuptype\n";
my $broken_type_e2node = $DB->insertNode("writeup with a broken type", "e2node", $root);
$broken_type_e2node = $DB->getNodeById($broken_type_e2node);

my $broken_type_writeup = $DB->getNodeById($DB->insertNode("writeup with a broken type (thing)", "writeup", $normaluser1));
$broken_type_writeup->{parent_e2node} = $broken_type_e2node->{node_id};
$broken_type_writeup->{wrtype_writeuptype} = 9999;
$broken_type_writeup->{publishtime} = $broken_type_writeup->{createtime};

$DB->updateNode($broken_type_writeup, -1);
$DB->insertIntoNodegroup($broken_type_e2node,-1,$broken_type_writeup);
print STDERR "Inserted writeup with broken type: '$broken_type_writeup->{title}' ($broken_type_writeup->{node_id})\n";

my $no_parent_writeup = $DB->getNodeById($DB->insertNode("writeup with no parent (thing)", "writeup", $normaluser1));
$no_parent_writeup->{doctext} = "This writeup is an [orphan]";
$no_parent_writeup->{wrtype_writeuptype} = $thing_writeuptype->{node_id};
$no_parent_writeup->{publishtime} = $no_parent_writeup->{createtime};
$DB->updateNode($no_parent_writeup, -1);
print STDERR "Inserted writeup with no parent: '$no_parent_writeup->{title}'\n";

my $broken_nodegroup_e2node = $DB->getNodeById($DB->insertNode("writeup with a broken nodegroup", "e2node", $root));
my $broken_nodegroup_writeup = $DB->getNodeById($DB->insertNode("writeup with a broken nodegroup (thing)", "writeup", $normaluser1));
$broken_nodegroup_writeup->{doctext} = "This is a node that doesn't have the proper [group membership] in [nodegroup], but it has an e2node parent";
$broken_nodegroup_writeup->{parent_e2node} = $broken_nodegroup_e2node->{node_id};
$broken_nodegroup_writeup->{wrtype_writeuptype} = $thing_writeuptype->{node_id};
$broken_nodegroup_writeup->{publishtime} = $broken_nodegroup_writeup->{createtime};
print STDERR "Inserted writeup with no nodegroup registration: '$broken_nodegroup_writeup->{title}'\n";

my $no_author_e2node = $DB->getNodeById($DB->insertNode("writeup with no owner","e2node",$root));
my $no_author_writeup = $DB->getNodeById($DB->insertNode("writeup with no owner (thing)", "writeup", $normaluser1));
$no_author_writeup->{author_user} = 0;
$no_author_writeup->{parent_e2node} = $no_author_e2node->{node_id};
$no_author_writeup->{wrtype_writeuptype} = $thing_writeuptype->{node_id};
$no_author_writeup->{doctext} = "This writeup has no author to test broken node handling!";
$no_author_writeup->{publishtime} = $no_author_writeup->{createtime};
$DB->insertIntoNodegroup($no_author_e2node, -1, $no_author_writeup);
$DB->updateNode($no_author_writeup, -1);
print STDERR "Inserted writeup with no author: '$no_author_writeup->{title}'\n";

my $bad_cool_e2node = $DB->getNodeById($DB->insertNode("writeup with bad cool info", "e2node", $root));
my $bad_cool_writeup = $DB->getNodeById($DB->insertNode("writeup with bad cool info (thing)", "writeup", $normaluser1));
$bad_cool_writeup->{parent_e2node} = $bad_cool_e2node->{node_id};
$bad_cool_writeup->{wrtype_writeuptype} = $thing_writeuptype->{node_id};
$bad_cool_writeup->{doctext} = "This writeup was [Cool Archive|cooled] by a [ghost]";
$bad_cool_writeup->{cooled} = 1;
$bad_cool_writeup->{publishtime} = $bad_cool_writeup->{createtime};
$DB->insertIntoNodegroup($bad_cool_e2node, -1, $bad_cool_writeup);
$DB->updateNode($bad_cool_writeup, -1);
$DB->sqlInsert("coolwriteups",{"coolwriteups_id" => $bad_cool_writeup->{node_id}, cooledby_user => 9999});
print STDERR "Inserted writeup with bad cooler: '$bad_cool_writeup->{title}'\n";

my $cools = { "normaluser1" => ["good poetry (poetry)", "swedish tomatoë (essay)"], "normaluser5" => ["Quick brown fox (thing)","lazy dog (idea)", "regular brown fox (person)", "writeup with a broken type (thing)","writeup with no parent (thing)", "writeup with a broken nodegroup (thing)", "writeup with no owner (thing)"]};

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

# Create ip_to_uint function that is needed for IP Hunter
$DB->{dbh}->do("CREATE DEFINER=`everyuser`@`%` FUNCTION `ip_to_uint`(ipin VARCHAR(255)) RETURNS int unsigned     DETERMINISTIC BEGIN     RETURN (CAST(SUBSTRING_INDEX(ipin,'.',1) AS UNSIGNED) * 256 * 256 * 256)      + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',2),'.',-1) AS UNSIGNED) * 256 * 256)      + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',3),'.',-1) AS UNSIGNED) * 256)      + (CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(ipin,'.',4),'.',-1)  AS UNSIGNED))      ;   END");
print STDERR "Created ip_to_uint function\n";
