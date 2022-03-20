#!/usr/bin/perl -w

use strict;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);

use Everything;
use Getopt::Long;

initEverything 'everything';

my $user = undef;
my $dir = undef;
GetOptions(
  "user=s" => \$user,
  "dir=s" => \$dir);

if(not defined($user) or not defined($dir))
{
  print "Need both --user and --dir\n";
  exit;
}

my $user_node = getNode($user,"user");

if(not defined($user_node))
{
  print "Could not find user: '$user'\n";
  exit;
}

if(not -d $dir)
{
  print "Directory '$dir' does not exist!\n";
  exit;
}

foreach my $type("writeup","draft")
{
  my $plural = $type.'s';
  my $outputdir = "$dir/$plural";

  `mkdir -p $outputdir`;
  my $nodetype = getType($type);
  my $csr = $DB->sqlSelectMany("node_id","node","type_nodetype=$nodetype->{node_id} and author_user=$user_node->{node_id}");

  while(my $row = $csr->fetchrow_hashref)
  {
    my $useritem = getNodeById($row->{node_id});
    my $filesystem_safe_title = $useritem->{title};

    if($type eq 'writeup')
    {
      $filesystem_safe_title = getNodeById($useritem->{parent_e2node})->{title};
    }
    $filesystem_safe_title =~ s/[\/'"\s\.:\,\?\(\)\!]/-/g;
    $filesystem_safe_title =~ s/-+$//g;
    $filesystem_safe_title .= '.txt';
    $filesystem_safe_title = lc($filesystem_safe_title);
    $filesystem_safe_title =~ s/-+/-/g;

    my $to_write_file = "$outputdir/$filesystem_safe_title";
    if(-e $to_write_file)
    {
      print "Title conflict: '$to_write_file'; creating alternate\n";
      $filesystem_safe_title =~ s/\.txt//g;
      
      my $done = 0;
      my $increment = 2;
      while(not $done)
      {
        my $proposed_file = $filesystem_safe_title."_($increment).txt";

	print "Checking $outputdir/$proposed_file\n";
	if(not -e "$outputdir/$proposed_file")
	{
          $done = 1;
	  $filesystem_safe_title = $proposed_file;
          $to_write_file = "$outputdir/$filesystem_safe_title";
        }else{
          $increment++;
	}
      }
    }
    
    if(open my $fh, ">",$to_write_file)
    {
      print "Writing: $to_write_file\n";
      print $fh "[$useritem->{title}] by [$user]\r\n";
      print $fh "Published on: ".$useritem->{publishtime}."\r\n" if $type eq 'writeup';
      print $fh "Draft\r\n" if $type eq 'draft';
      print $fh "----\r\n\r\n";
      print $fh $useritem->{doctext}; 
      close $fh;
    }

  }
}

print "Getting messages\n";
my $messages = [];

my $csr = $DB->sqlSelectMany("*","message_outbox","author_user=$user_node->{node_id}");

while(my $row = $csr->fetchrow_hashref)
{
  $row->{source} = "outbox";
  push @$messages, $row;
}

$csr = $DB->sqlSelectMany("*","message","for_user=$user_node->{node_id}");

while(my $row = $csr->fetchrow_hashref)
{
  $row->{source} = "inbox";
  push @$messages, $row;
}

$messages = [sort {$a->{tstamp} cmp $b->{tstamp}} @$messages];

print "Writing messages\n";
if(open my $message_handle, ">","$dir/messages.txt")
{
  foreach my $message (@$messages)
  {
    if($message->{author_user} == $user_node->{node_id})
    {
      print $message_handle "$message->{tstamp} ($message->{source}): $message->{msgtext}\r\n";
    }else{
      my $author = getNodeById($message->{author_user})->{title};
      print $message_handle "$message->{tstamp} ($message->{source}): $author said: $message->{msgtext}\r\n";
    }
  }
}

print "Done\n";
