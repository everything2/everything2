#!/usr/bin/perl -w

use strict;
use utf8;
use lib qw(/var/libraries/lib/perl5);
use lib qw(/var/everything/ecore);
use Everything;
use Everything::HTML;
use POSIX;
use Getopt::Long;

=head1 NAME

generate-volume-writeups.pl - Generate volume test writeups for a user

=head1 SYNOPSIS

  # Generate 100 writeups for normaluser1
  ./tools/generate-volume-writeups.pl --user normaluser1 --count 100

  # Generate 200 writeups with more hidden/drafts
  ./tools/generate-volume-writeups.pl --user normaluser2 --count 200 --hidden-pct 20 --draft-pct 15

  # Clean up previously generated writeups
  ./tools/generate-volume-writeups.pl --user normaluser1 --cleanup

  # Dry run (show what would be created)
  ./tools/generate-volume-writeups.pl --user normaluser1 --count 50 --dry-run

=head1 DESCRIPTION

This utility generates test writeups with various characteristics for testing
pagination and volume displays like Everything User Search.

Features:
- Creates writeups with random writeup types
- Random hidden status (default ~5%)
- Random draft status (default ~10%)
- Has normaluser accounts vote on them randomly
- Random C!s from normaluser accounts
- Titles include a prefix to identify generated content

=head1 OPTIONS

  --user       Username to create writeups for (required)
  --count      Number of writeups to create (default: 100)
  --hidden-pct Percentage of writeups to hide (default: 5)
  --draft-pct  Percentage of writeups to leave as drafts (default: 10)
  --cleanup    Remove previously generated writeups instead of creating
  --dry-run    Show what would be done without making changes
  --help       Show this help message

=cut

my $user;
my $count = 100;
my $hidden_pct = 5;
my $draft_pct = 10;
my $days_spread = 3;
my $cleanup = 0;
my $dry_run = 0;
my $help = 0;

GetOptions(
    'user=s'        => \$user,
    'count=i'       => \$count,
    'hidden-pct=i'  => \$hidden_pct,
    'draft-pct=i'   => \$draft_pct,
    'days=i'        => \$days_spread,
    'cleanup'       => \$cleanup,
    'dry-run'       => \$dry_run,
    'help'          => \$help,
) or die "Error in command line arguments\n";

if ($help) {
    print <<'USAGE';
Usage: generate-volume-writeups.pl [OPTIONS]

Generate volume test writeups for testing pagination and search.

Options:
  --user       Username to create writeups for (required)
  --count      Number of writeups to create (default: 100)
  --hidden-pct Percentage of writeups to hide (default: 5)
  --draft-pct  Percentage of writeups to leave as drafts (default: 10)
  --days       Number of days to spread timestamps over (default: 3)
  --cleanup    Remove previously generated writeups instead of creating
  --dry-run    Show what would be done without making changes
  --help       Show this help message

Examples:
  # Generate 100 writeups for normaluser1
  ./tools/generate-volume-writeups.pl --user normaluser1 --count 100

  # Generate with more hidden writeups spread over a week
  ./tools/generate-volume-writeups.pl --user normaluser1 --count 200 --hidden-pct 15 --days 7

  # Clean up generated writeups
  ./tools/generate-volume-writeups.pl --user normaluser1 --cleanup

USAGE
    exit 0;
}

unless ($user) {
    die "Error: --user is required\n";
}

# Initialize Everything
initEverything;

if ($Everything::CONF->environment ne "development") {
    print STDERR "ERROR: Not in the 'development' environment. This tool is only for dev testing.\n";
    exit 1;
}

$Everything::HTML::USER = getNode("root", "user");
my $APP = $Everything::APP;

# Get the target user
my $author = getNode($user, "user");
unless ($author) {
    die "Error: User '$user' not found\n";
}

print STDERR "Target user: $author->{title} (node_id: $author->{node_id})\n";

# Prefix for generated writeups (so we can identify/cleanup)
my $GENERATED_PREFIX = "VolumeTest";

# Writeup types to randomly choose from
my @WRITEUP_TYPES = qw(thing idea essay person place how-to definition log poetry review lede);

# Word lists for generating random titles
my @ADJECTIVES = qw(
    ancient beautiful chaotic divine ethereal fantastic golden hidden
    infinite jovial kaleidoscopic luminous mystical nebulous obscure
    pristine quantum radiant sublime transcendent universal vibrant
    wondrous xenial youthful zealous abstract bold creative daring
    elegant fierce gentle haunting iconic jubilant keen legendary
    majestic noble opulent peculiar quaint remarkable serene timeless
);

my @NOUNS = qw(
    adventure beacon chronicle destiny eclipse frontier gateway horizon
    illusion journey kingdom labyrinth monument nexus oracle paradox
    quest remnant sanctuary threshold universe vortex wasteland xenolith
    yearning zenith algorithm boundary catalyst dimension equilibrium
    framework gradient hierarchy interface junction kernel lattice
    manifold network oscillation paradigm quantum resonance spectrum
);

# Get normaluser accounts for voting/cooling
sub get_normalusers {
    my @users;
    for my $i (1..30) {
        my $u = getNode("normaluser$i", "user");
        push @users, $u if $u;
    }
    return @users;
}

# Generate a random title
sub generate_title {
    my ($index) = @_;
    my $adj = $ADJECTIVES[int(rand(@ADJECTIVES))];
    my $noun = $NOUNS[int(rand(@NOUNS))];
    return "$GENERATED_PREFIX: $adj $noun $index";
}

# Cleanup mode
if ($cleanup) {
    print STDERR "Cleaning up generated writeups for $user...\n";

    # Find all writeups with our prefix
    my $writeup_type = $DB->getType('writeup');
    my $draft_type = $DB->getType('draft');

    my $sql = qq|
        SELECT node.node_id, node.title, node.type_nodetype
        FROM node
        WHERE node.author_user = ?
        AND node.title LIKE ?
        AND node.type_nodetype IN (?, ?)
    |;

    my $sth = $DB->{dbh}->prepare($sql);
    $sth->execute($author->{node_id}, "$GENERATED_PREFIX:%", $writeup_type->{node_id}, $draft_type->{node_id});

    my @to_delete;
    while (my $row = $sth->fetchrow_hashref) {
        push @to_delete, $row;
    }

    if (@to_delete == 0) {
        print STDERR "No generated writeups found for $user\n";
        exit 0;
    }

    print STDERR "Found " . scalar(@to_delete) . " generated writeups to clean up\n";

    if ($dry_run) {
        print STDERR "[DRY RUN] Would delete:\n";
        for my $w (@to_delete) {
            print STDERR "  - $w->{title} (node_id: $w->{node_id})\n";
        }
        exit 0;
    }

    for my $w (@to_delete) {
        print STDERR "Deleting: $w->{title}\n";

        # Delete votes
        $DB->{dbh}->do("DELETE FROM vote WHERE vote_id = ?", {}, $w->{node_id});

        # Delete cools
        $DB->{dbh}->do("DELETE FROM coolwriteups WHERE coolwriteups_id = ?", {}, $w->{node_id});

        # Delete from nodegroup (e2node membership)
        $DB->{dbh}->do("DELETE FROM nodegroup WHERE node_id = ?", {}, $w->{node_id});

        # Delete the writeup/draft node
        my $node = $DB->getNodeById($w->{node_id});
        if ($node) {
            $DB->nukeNode($node, -1);
        }
    }

    # Clean up orphaned e2nodes with our prefix
    my $e2node_type = $DB->getType('e2node');
    my $e2node_sql = qq|
        SELECT node.node_id, node.title
        FROM node
        WHERE node.title LIKE ?
        AND node.type_nodetype = ?
    |;
    my $e2node_sth = $DB->{dbh}->prepare($e2node_sql);
    $e2node_sth->execute("$GENERATED_PREFIX:%", $e2node_type->{node_id});

    while (my $row = $e2node_sth->fetchrow_hashref) {
        # Check if e2node has any children left
        my $children = $DB->sqlSelect('COUNT(*)', 'nodegroup', "nodegroup_id = $row->{node_id}");
        if (!$children || $children == 0) {
            print STDERR "Deleting orphaned e2node: $row->{title}\n";
            my $node = $DB->getNodeById($row->{node_id});
            $DB->nukeNode($node, -1) if $node;
        }
    }

    print STDERR "Cleanup complete!\n";
    exit 0;
}

# Creation mode
print STDERR "Generating $count writeups for $user\n";
print STDERR "  Hidden: ~$hidden_pct%\n";
print STDERR "  Drafts: ~$draft_pct%\n";
print STDERR "  Spread over: $days_spread days\n";

if ($dry_run) {
    print STDERR "[DRY RUN] Would create $count writeups\n";
    exit 0;
}

my @normalusers = get_normalusers();
print STDERR "Found " . scalar(@normalusers) . " normaluser accounts for voting/cooling\n";

my $writeup_type_node = $DB->getType('writeup');
my $draft_type_node = $DB->getType('draft');

my @created_writeups;
my $drafts_created = 0;
my $hidden_created = 0;

for my $i (1..$count) {
    my $title = generate_title($i);
    my $writeup_type = $WRITEUP_TYPES[int(rand(@WRITEUP_TYPES))];
    my $is_draft = (rand(100) < $draft_pct);
    my $is_hidden = (!$is_draft && rand(100) < $hidden_pct);

    my $full_title = "$title ($writeup_type)";
    my $node_type = $is_draft ? 'draft' : 'writeup';

    # Check if already exists
    my $existing = getNode($full_title, $node_type);
    if ($existing) {
        print STDERR "[$i/$count] Already exists: $full_title\n";
        push @created_writeups, $existing;
        next;
    }

    # Create e2node parent (if writeup, not draft)
    my $parent_e2node;
    unless ($is_draft) {
        $parent_e2node = getNode($title, "e2node");
        unless ($parent_e2node) {
            $DB->insertNode($title, "e2node", $author, {});
            $parent_e2node = $DB->getNode($title, "e2node");
        }
    }

    # Get writeup type node
    my $wrtype = getNode($writeup_type, "writeuptype");
    unless ($wrtype) {
        print STDERR "WARNING: Unknown writeuptype '$writeup_type', using 'thing'\n";
        $wrtype = getNode("thing", "writeuptype");
    }

    # Create the writeup/draft
    $DB->insertNode($full_title, $node_type, $author, {});
    my $writeup = getNode($full_title, $node_type);

    unless ($writeup) {
        print STDERR "ERROR: Failed to create $full_title\n";
        next;
    }

    # Generate some lorem ipsum-ish content
    my $doctext = generate_content($title, $writeup_type);

    # Spread timestamps over the configured number of days
    my $seconds_spread = $days_spread * 24 * 60 * 60;
    $writeup->{createtime} = $APP->convertEpochToDate(time() - int(rand($seconds_spread)));
    $writeup->{doctext} = $doctext;
    $writeup->{document_id} = $writeup->{node_id};

    if ($is_draft) {
        $writeup->{draft_id} = $writeup->{node_id};
        my $pub_status = getNode("findable", "publication_status");
        $writeup->{publication_status} = $pub_status->{node_id} if $pub_status;
        $drafts_created++;
    } else {
        $writeup->{parent_e2node} = $parent_e2node->{node_id};
        $writeup->{wrtype_writeuptype} = $wrtype->{node_id};
        $writeup->{writeup_id} = $writeup->{node_id};
        $writeup->{publishtime} = $writeup->{createtime};
        $writeup->{edittime} = $writeup->{createtime};
        $writeup->{cooled} = 0;

        if ($is_hidden) {
            $writeup->{notnew} = 1;
            $hidden_created++;
        } else {
            $writeup->{notnew} = 0;
        }
    }

    $DB->updateNode($writeup, $author);

    # Add to e2node nodegroup (if writeup)
    if (!$is_draft && $parent_e2node) {
        my $already_in_group = $DB->sqlSelect('COUNT(*)', 'nodegroup',
            "nodegroup_id=$parent_e2node->{node_id} AND node_id=$writeup->{node_id}");
        if (!$already_in_group) {
            $DB->insertIntoNodegroup($parent_e2node, -1, $writeup);
            $DB->updateNode($parent_e2node, -1);
        }
    }

    push @created_writeups, $writeup unless $is_draft;

    my $status = $is_draft ? "[DRAFT]" : ($is_hidden ? "[HIDDEN]" : "");
    print STDERR "[$i/$count] Created: $full_title $status\n";
}

print STDERR "\nCreated $count writeups ($drafts_created drafts, $hidden_created hidden)\n";

# Now add votes and cools
if (@created_writeups && @normalusers) {
    print STDERR "\nAdding votes and cools...\n";

    my $votes_cast = 0;
    my $cools_given = 0;

    for my $writeup (@created_writeups) {
        # Get the writeup's actual author for integrity checks
        my $writeup_author_id = $writeup->{author_user};

        # Each normaluser has a 30% chance to vote on this writeup
        for my $voter (@normalusers) {
            # Users cannot vote on their own writeups
            next if $voter->{node_id} == $writeup_author_id;

            if (rand(100) < 30) {
                # Check if already voted
                my $existing_vote = $DB->sqlSelect('COUNT(*)', 'vote',
                    "vote_id=$writeup->{node_id} AND voter_user=$voter->{node_id}");

                unless ($existing_vote) {
                    # 80% upvote, 20% downvote
                    my $weight = (rand(100) < 80) ? 1 : -1;
                    $APP->castVote($writeup, $voter, $weight);
                    $votes_cast++;
                }
            }
        }

        # 15% chance of getting a C! from a random normaluser
        if (rand(100) < 15) {
            my $cooler = $normalusers[int(rand(@normalusers))];
            # Users cannot C! their own writeups
            next if $cooler->{node_id} == $writeup_author_id;

            my $existing_cool = $DB->sqlSelect('COUNT(*)', 'coolwriteups',
                "coolwriteups_id=$writeup->{node_id} AND cooledby_user=$cooler->{node_id}");

            unless ($existing_cool) {
                $writeup->{cooled}++;
                $DB->updateNode($writeup, -1);
                $DB->sqlInsert("coolwriteups", {
                    "coolwriteups_id" => $writeup->{node_id},
                    "cooledby_user" => $cooler->{node_id}
                });
                $cools_given++;
            }
        }
    }

    print STDERR "Cast $votes_cast votes and $cools_given C!s\n";
}

print STDERR "\nDone!\n";

# Generate some content for a writeup
sub generate_content {
    my ($title, $type) = @_;

    my @paragraphs = (
        "This is a [test writeup] about $title.",
        "The nature of $title is [complex] and [multifaceted].",
        "When considering $title, one must think about the [implications].",
        "Many have written about [similar topics], but $title deserves special attention.",
        "In conclusion, $title represents an important aspect of [Everything2].",
    );

    my $num_paragraphs = 2 + int(rand(4));
    my @selected;
    for (1..$num_paragraphs) {
        push @selected, $paragraphs[int(rand(@paragraphs))];
    }

    return "<p>" . join("</p>\n<p>", @selected) . "</p>";
}
