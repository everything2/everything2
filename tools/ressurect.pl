#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use Everything;
use Data::Dumper;

initEverything;

my $writeup = getType("writeup");
my $nuked_status = getNode("nuked","publication_status");
my $thing = getNode("thing","writeuptype");
my $draft = getType("draft");
my $webby = getNode("Webster 1913", "user");

my $csr = $DB->sqlSelectMany("*", "heaven");

$csr->execute();

my $i = 0;
my $titles = {};

my $insertstats = {};

while(my $row = $csr->fetchrow_hashref)
{
  $DB->sqlDelete("heaven", "node_id=$row->{node_id}");
  next unless($row->{type_nodetype} == $writeup->{node_id});

  my $title = $row->{title};
  $insertstats->{titleskip}++;
  next if $title =~ /^E2 Nuke Request/i;
  next if $title =~ /^Edit These E2 Titles/i;
  next if $title =~ /^Nodeshells marked for destruction/i;
  next if $title =~ /^test test test/i;
  next if $title =~ /^new writeup/i;
  next if $title =~ /^E2 Bugs/i;
  next if $title =~ /^E2 Copyright Violation/i;
  next if $title =~ /^Broken nodes/i;
  next if $title =~ /^Suggestions for E2/i;
  next if $title =~ /^E2 Mentoring Sign-Up/i;
  next if $title eq "test";
  next if $title =~ /^Everything Quest 4: Artists\/Bands\/Groups/i;
  next if $title =~ /^Everything Quest 6: E2's Scrapbook/i;
  next if $title =~ /^Everything Quest 3: The Animal Kingdom/i;
  next if $title =~ /^Everything Quest 2: Diseases/i;
  next if $title =~ /^Everything Quest 5: Recipes/i;
  $insertstats->{titleskip}--;

  #| node_id       | int(11)   | NO   | PRI | NULL                | auto_increment |
  #| type_nodetype | int(11)   | NO   | MUL | 0                   |                |
  #| title         | char(240) | YES  | MUL | NULL                |                |
  #| author_user   | int(11)   | NO   | MUL | 0                   |                |
  #| createtime    | datetime  | NO   | MUL | 0000-00-00 00:00:00 |                |
  #| hits          | int(11)   | YES  |     | 0                   |                |
  #| reputation    | int(11)   | NO   | MUL | 0                   |                |
  #| totalvotes    | int(11)   | YES  |     | NULL                |                

  #| document_id | int(11)    | NO   | PRI | NULL              | auto_increment              |
  #| doctext     | mediumtext | YES  |     | NULL              |                             |
  #| edittime    | timestamp  | NO   | MUL | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP |

  #| writeup_id         | int(11)  | NO   | PRI | 0                   |       |
  #| parent_e2node      | int(11)  | NO   | MUL | 0                   |       |
  #| wrtype_writeuptype | int(11)  | NO   | MUL | 0                   |       |
  #| notnew             | int(11)  | NO   |     | 0                   |       |
  #| cooled             | int(11)  | NO   | MUL | 0                   |       |
  #| publishtime        | datetime | NO   | MUL | 0000-00-00 00:00:00 |       |

  #| draft_id           | int(11)   | NO   | PRI | 0       |       |
  #| publication_status | int(11)   | NO   | MUL | 0       |       |
  #| collaborators      | char(255) | YES  |     | NULL    |       |

  my $nodedata; my $VAR1;
  eval("\$nodedata = $$row{data}");
  delete $$row{data};

  foreach my $key (keys %$row)
  {
    $nodedata->{$key} = $row->{$key};
  }

  my $newnode;

  foreach my $key (qw/node_id type_nodetype title author_user createtime doctext edittime parent_e2node wrtype_writeuptype notnew cooled/)
  {
    $newnode->{$key} = $nodedata->{$key};
    delete $nodedata->{$key};
  }

  $newnode->{draft_id} = $newnode->{node_id};
  delete $nodedata->{draft_id};

  $newnode->{document_id} = $newnode->{node_id};
  delete $nodedata->{document_id};

  $newnode->{writeup_id} = $newnode->{node_id};
  delete $nodedata->{writeup_id};

  $newnode->{edittime} ||= $newnode->{createtime};
  $newnode->{wrtype_writeuptype} ||= $thing->{node_id};
  $newnode->{cooled} = 0;
  $newnode->{notnew} = 0;
  $newnode->{publishtime} = 0;
  delete $nodedata->{publishtime};

  $newnode->{publication_status} = $nuked_status->{node_id};
  delete $nodedata->{publication_status};

  $newnode->{collaborators} = "";
  delete $nodedata->{collaborators};

  $newnode->{reputation} = 0;
  delete $nodedata->{reputation};

  $newnode->{hits} = 0;
  delete $nodedata->{hits};

  $newnode->{totalvotes} = 0;
  delete $nodedata->{totalvotes};

  # Trimming leftover data:
  foreach my $key (qw/core lockedby_user locktime killa_user package private datatype _memcached_version numtime editor _ORIGINAL_VALUES nodetype/)
  {
    delete $nodedata->{$key};
  }

  if(scalar(keys %$nodedata) > 0)
  {
    print "Leftover data in node_id $newnode->{node_id}: '".join(",", keys %$nodedata)."'\n";
  }

  if(not exists($newnode->{doctext}))
  {
    print "Refusing to insert non-existing doctext: $newnode->{node_id}\n";
    $insertstats->{doctext_no_exist}++;
    next;
  }

  if(not defined($newnode->{doctext}))
  {
    print "Refusing to insert undefined doctext: $newnode->{node_id}\n";
    $insertstats->{doctext_undefined}++;
    next;
  }

  if($newnode->{doctext} =~ /^\s+$/)
  {
    print "Refusing to insert blank node: $newnode->{node_id}\n";
    $insertstats->{doctext_blank}++;
    next;
  }


  if($newnode->{author_user} > 100000000)
  {
    $newnode->{author_user} -= 100000000;
  }

  my $author = getNodeById($newnode->{author_user});
  unless($author)
  {
    print "Could not find author: $newnode->{author_user}\n";
    $insertstats->{no_author}++;
    next;
  }

  $newnode->{type_nodetype} = $$draft{node_id};

  if(my $collide = getNodeById($newnode->{node_id}))
  {
    if(lc($collide->{title}) eq lc($newnode->{title}) and $collide->{author_user} == $newnode->{author_user})
    {
       print "Node_id collision, but title/author match. Skipping\n";
       $insertstats->{okay_collision}++;
       next;
    }else{
       my $existingtitle = $collide->{title};
       $existingtitle =~ s/\(\S+\)$//g;

       my $newtitle = $newnode->{title};
       $newtitle =~ s/\(\S+\)$//g;

       if($newtitle eq $existingtitle)
       {
         print "Excusable node_id collision, skipping\n";
         $insertstats->{okay_collision_typediff}++;
         next;
       }else{
         if($newnode->{author_user} == $webby->{node_id})
         {
           print "Webster collision, skipping\n";
           $insertstats->{okay_collision_webby}++;
           next;
         }else{
           if($newnode->{author_user} == $collide->{author_user} && $newnode->{createtime} eq $collide->{createtime})
           {
             print "Likely resurrection and retitle, skipping\n";
             $insertstats->{okay_collision_resurrect}++;
             next;
           }else{
             print "Bad node_id collision - $newnode->{node_id} '$collide->{title}' vs. '$newnode->{title}'\n";
             $insertstats->{bad_collision}++;
             next;
           }
         }
       }
    }
  }

  #next unless $newnode->{author_user} == 459692;
  print "Ready to insert: $newnode->{title} by $author->{title} - $newnode->{node_id}\n";


  if(my $count = $DB->sqlSelect("count(*)", "vote", "vote_id=$newnode->{node_id}"))
  {
    print "- cleaning $count votes from the vote table for node: $newnode->{node_id}\n"; 
    $DB->sqlDelete("vote","vote_id=$newnode->{node_id}");
  }

  if(my $count = $DB->sqlSelect("count(*)", "links", "to_node=$newnode->{node_id} or from_node=$newnode->{node_id}"))
  {
    print "- cleaning $count links from the link table for node: $newnode->{node_id}\n";
    $DB->sqlDelete("link","to_node=$newnode->{node_id} or from_node=$newnode->{node_id}");
  }

  if(my $count = $DB->sqlSelect("count(*)", "coolwriteups", "coolwriteups_id=$newnode->{node_id}"))
  {
    print "- cleaning $count cools from the coolwriteups table for node: $newnode->{node_id}\n";
    $DB->sqlDelete("coolwriteups", "coolwriteups_id=$newnode->{node_id}");
  }

  my $inserthash;

  foreach my $key (qw|node_id type_nodetype title author_user createtime hits reputation totalvotes|)
  {
    $inserthash->{$key} = $newnode->{$key};
  }
  $DB->sqlInsert("node", $inserthash);
  $inserthash = undef;

  foreach my $key (qw|document_id edittime doctext|)
  {
    $inserthash->{$key} = $newnode->{$key};
  }
  $DB->sqlInsert("document", $inserthash);
  $inserthash = undef;

  foreach my $key (qw|draft_id publication_status collaborators|)
  {
    $inserthash->{$key} = $newnode->{$key};
  }
  $DB->sqlInsert("draft", $inserthash);
  $inserthash = undef;

  foreach my $key (qw|writeup_id parent_e2node wrtype_writeuptype notnew cooled publishtime|)
  {
    $inserthash->{$key} = $newnode->{$key};
  }
  $DB->sqlInsert("writeup", $inserthash);
  $inserthash = undef;

}

print "Insert stats:\n";

foreach my $key (keys %$insertstats)
{
  print "- $key: $insertstats->{$key}\n";
}

