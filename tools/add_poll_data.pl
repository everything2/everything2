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

# Get the poll node
my $poll_node = $DB->getNode("What is your favorite programming language?", "e2poll");
unless($poll_node) {
  print STDERR "ERROR: Could not find poll node\n";
  exit 1;
}

print STDERR "Found poll: $poll_node->{title} (ID: $poll_node->{node_id})\n";

# Set poll options (newline-separated in doctext)
my @poll_options = (
  "Perl",
  "JavaScript",
  "Python",
  "Ruby",
  "Go",
  "Rust"
);

$poll_node->{doctext} = join("\n", @poll_options);

# Update the e2poll table directly
$DB->sqlUpdate("e2poll", {
  question => "What is your favorite programming language?",
  poll_status => 'open',
  poll_author => $DB->getNode("normaluser1", "user")->{node_id},
  multiple => 0,
  is_dailypoll => 0,
  was_dailypoll => 0,
  e2poll_results => "0,0,0,0,0,0",
  totalvotes => 0
}, "e2poll_id=" . $poll_node->{node_id});

$DB->updateNode($poll_node, -1);

print STDERR "Updated poll with options\n";

# Initialize vote counts to 0 for each option
my @vote_counts = (0) x scalar(@poll_options);

# Have normaluser1-20 vote on the poll with various preferences
my $poll_votes = {
  # Perl fans
  1 => 0, 2 => 0, 3 => 0, 4 => 0,
  # JavaScript fans
  5 => 1, 6 => 1, 7 => 1, 8 => 1, 9 => 1,
  # Python fans
  10 => 2, 11 => 2, 12 => 2, 13 => 2, 14 => 2, 15 => 2,
  # Ruby fan
  16 => 3,
  # Go fans
  17 => 4, 18 => 4,
  # Rust fans
  19 => 5, 20 => 5,
};

my $total_votes = 0;
foreach my $user_num (sort {$a <=> $b} keys %$poll_votes) {
  my $choice = $poll_votes->{$user_num};
  my $voter = $DB->getNode("normaluser$user_num", "user");

  unless($voter) {
    print STDERR "ERROR: Could not get voter normaluser$user_num\n";
    next;
  }

  # Insert the vote
  print STDERR "Recording poll vote: normaluser$user_num voting for option $choice ($poll_options[$choice])\n";
  $DB->sqlInsert("pollvote", {
    pollvote_id => $poll_node->{node_id},
    voter_user => $voter->{node_id},
    choice => $choice,
    votetime => $APP->convertEpochToDate(time())
  });

  # Update vote count
  $vote_counts[$choice]++;
  $total_votes++;
}

# Update poll with results
$DB->sqlUpdate("e2poll", {
  e2poll_results => join(',', @vote_counts),
  totalvotes => $total_votes
}, "e2poll_id=" . $poll_node->{node_id});

print STDERR "Created poll '$poll_node->{title}' with $total_votes votes\n";
print STDERR "Results: " . join(', ', map { "$poll_options[$_]: $vote_counts[$_]" } 0..$#poll_options) . "\n";
