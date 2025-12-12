#!/usr/bin/env perl
# extract-writeup-content.pl
#
# Extracts writeup content from production database for link parsing comparison tests.
# Outputs JSON blob with raw doctext that can be used to compare server-side parseLinks()
# output against client-side E2HtmlSanitizer.js output.
#
# Usage:
#   ./tools/extract-writeup-content.pl > writeup-content-dump.json
#   ./tools/extract-writeup-content.pl --limit 1000 > sample.json
#   ./tools/extract-writeup-content.pl --since "2024-01-01" > recent.json
#
# Output format:
# {
#   "extracted_at": "2025-12-11T...",
#   "count": 12345,
#   "writeups": [
#     {
#       "node_id": 123,
#       "title": "Example Writeup",
#       "doctext": "raw content with [links] and <html>",
#       "author": "username",
#       "createtime": "2020-01-01 12:00:00"
#     },
#     ...
#   ]
# }

use strict;
use warnings;
use JSON;
use Getopt::Long;
use POSIX qw(strftime);

# Add library paths
use lib '/var/everything/ecore';
use lib '/var/libraries/lib/perl5';

use Everything;
use Everything::DB;

my $limit = 0;  # 0 = no limit
my $since = '';
my $random_sample = 0;
my $include_parsed = 0;
my $help = 0;

GetOptions(
    'limit=i' => \$limit,
    'since=s' => \$since,
    'random=i' => \$random_sample,
    'include-parsed' => \$include_parsed,
    'help' => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print <<'USAGE';
Usage: extract-writeup-content.pl [OPTIONS]

Options:
  --limit N         Limit to N writeups (default: all)
  --since DATE      Only writeups created after DATE (YYYY-MM-DD)
  --random N        Random sample of N writeups
  --include-parsed  Include server-side parsed output (slower)
  --help            Show this help

Examples:
  ./tools/extract-writeup-content.pl --limit 1000 > sample.json
  ./tools/extract-writeup-content.pl --random 500 > random-sample.json
  ./tools/extract-writeup-content.pl --since "2024-01-01" > recent.json
  ./tools/extract-writeup-content.pl --include-parsed --limit 100 > with-parsed.json

USAGE
    exit 0;
}

# Initialize Everything
initEverything();
my $DB = $Everything::DB;

# Build query
my $where = "type_nodetype = (SELECT node_id FROM node WHERE title = 'writeup' AND type_nodetype = 1)";
$where .= " AND createtime >= '$since'" if $since;

my $order = $random_sample ? "ORDER BY RAND()" : "ORDER BY createtime DESC";
my $limit_clause = "";
if ($random_sample) {
    $limit_clause = "LIMIT $random_sample";
} elsif ($limit) {
    $limit_clause = "LIMIT $limit";
}

# Get writeups
my $sql = "SELECT n.node_id, n.title, n.createtime, d.doctext, u.title as author
           FROM node n
           JOIN document d ON n.node_id = d.document_id
           JOIN node u ON n.author_user = u.node_id
           WHERE $where
           $order
           $limit_clause";

my $sth = $DB->{dbh}->prepare($sql);
$sth->execute();

my @writeups;
my $count = 0;

while (my $row = $sth->fetchrow_hashref()) {
    my $writeup = {
        node_id => int($row->{node_id}),
        title => $row->{title},
        doctext => $row->{doctext} // '',
        author => $row->{author},
        createtime => $row->{createtime},
    };

    # Optionally include server-side parsed output for comparison
    if ($include_parsed && $row->{doctext}) {
        # Load the APP for parseLinks
        require Everything::Application;
        my $APP = Everything::Application->new();

        # Parse links server-side (this is what we want to match client-side)
        my $parsed = $APP->parseLinks($row->{doctext});
        $writeup->{parsed_server} = $parsed;
    }

    push @writeups, $writeup;
    $count++;

    # Progress indicator to stderr
    if ($count % 1000 == 0) {
        print STDERR "Extracted $count writeups...\n";
    }
}

$sth->finish();

# Build output
my $output = {
    extracted_at => strftime("%Y-%m-%dT%H:%M:%SZ", gmtime()),
    count => $count,
    query => {
        limit => $limit || 'none',
        since => $since || 'none',
        random_sample => $random_sample || 0,
        include_parsed => $include_parsed ? 1 : 0,
    },
    writeups => \@writeups,
};

# Output JSON
my $json = JSON->new->utf8->pretty->canonical;
print $json->encode($output);

print STDERR "Done. Extracted $count writeups.\n";
