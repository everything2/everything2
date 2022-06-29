#!/usr/bin/perl -w

use strict;
use lib qw(/var/everything/ecore);
use lib qw(/var/libraries/lib/perl5);
use Test::More tests => 5;
use diagnostics;
use Everything;

initEverything 'everything';
unless($APP->inDevEnvironment())
{
	plan skip_all => "Not in the development environment";
	exit;
}

sub dummy_message
{
  my ($author,$text,$ago) = @_;

  my $timestamp = "NOW()";
  if(defined($ago))
  {
    $timestamp = "DATE_SUB(NOW(), INTERVAL $ago second)";
  }
  $DB->executeQuery("INSERT into message (author_user,msgtext,tstamp) VALUES($author->{node_id},'$text',$timestamp)");
  return $DB->sqlSelect("LAST_INSERT_ID()");
}

sub is_archived_message
{
  my ($message_id) = @_;

  my $output = $DB->sqlSelect("message_id","publicmessages","message_id=$message_id");
  if(ref $output eq "ARRAY" and not defined($output->[0]))
  {
    return 0;
  }
  return $output;
}

sub is_current_message
{
  my ($message_id) = @_;

  my $output = $DB->sqlSelect("message_id","message","message_id=$message_id");
  if(ref $output eq "ARRAY" and not defined($output->[0]))
  {
    return 0;
  }
  return $output;
}

my $long_enough = $Everything::CONF->chatterbox_cleanup_threshold+100;

$DB->executeQuery("DELETE from message where for_user=0");
$DB->executeQuery("DELETE from publicmessages");

ok(my $cme = $DB->getNode("Cool Man Eddie","user"));

my $old_message_id = dummy_message($cme, 'test', $long_enough);

$APP->chatterbox_cleanup;
ok(is_archived_message($old_message_id));
ok(!is_current_message($old_message_id));

my $new_message_id = dummy_message($cme, 'test2');

$APP->chatterbox_cleanup;
ok(!is_archived_message($new_message_id));
ok(is_current_message($new_message_id));

