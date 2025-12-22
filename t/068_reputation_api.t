#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::reputation;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::reputation->new();
ok($api, "Created reputation API instance");

#############################################################################
# Test Setup: Get test users and create test writeup
#############################################################################

my $author_user = $DB->getNode("normaluser1", "user");
ok($author_user, "Got author user for testing");

my $voter_user = $DB->getNode("normaluser2", "user");
ok($voter_user, "Got voter user for testing");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user for testing");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user for testing");

# Create a test e2node and writeup
my $e2node_title = "Test Reputation API Node " . time();
my $e2node_id = $DB->insertNode(
    $e2node_title,
    'e2node',
    $author_user,
    { title => $e2node_title }
);
ok($e2node_id, "Created test e2node");

my $writeup_id = $DB->insertNode(
    $e2node_title,
    'writeup',
    $author_user,
    {
        parent_e2node => $e2node_id,
        doctext => "Test writeup for reputation API testing.",
        publishtime => '2025-01-15 12:00:00'
    }
);
ok($writeup_id, "Created test writeup");

# Clean up any existing votes
$DB->sqlDelete('vote', "vote_id=$writeup_id");

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{votes}, 'votes', "votes route exists");

#############################################################################
# Test: Missing writeup_id
#############################################################################

my $request = MockRequest->new(
    node_id => $author_user->{node_id},
    title => $author_user->{title},
    is_guest_flag => 0,
    nodedata => $author_user
);

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return undef;
    };
}

my $result = $api->votes($request);
is($result->[0], $api->HTTP_OK, "Missing writeup_id returns HTTP 200");
is($result->[1]{success}, 0, "Missing writeup_id fails");
is($result->[1]{error}, 'Invalid writeup ID', "Correct error message");

#############################################################################
# Test: Invalid writeup_id (non-numeric)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $name eq 'writeup_id' ? 'abc' : undef;
    };
}

$result = $api->votes($request);
is($result->[0], $api->HTTP_OK, "Non-numeric writeup_id returns HTTP 200");
is($result->[1]{success}, 0, "Non-numeric writeup_id fails");
is($result->[1]{error}, 'Invalid writeup ID', "Correct error for non-numeric");

#############################################################################
# Test: Non-existent writeup_id
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $name eq 'writeup_id' ? 999999999 : undef;
    };
}

$result = $api->votes($request);
is($result->[0], $api->HTTP_OK, "Non-existent writeup returns HTTP 200");
is($result->[1]{success}, 0, "Non-existent writeup fails");
is($result->[1]{error}, 'Writeup not found', "Correct error for missing writeup");

#############################################################################
# Test: Node that is not a writeup (e2node)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $name eq 'writeup_id' ? $e2node_id : undef;
    };
}

$result = $api->votes($request);
is($result->[0], $api->HTTP_OK, "Non-writeup node returns HTTP 200");
is($result->[1]{success}, 0, "Non-writeup node fails");
is($result->[1]{error}, 'Node is not a writeup', "Correct error for non-writeup");

#############################################################################
# Test: Author can view their own writeup's votes
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $name eq 'writeup_id' ? $writeup_id : undef;
    };
}

$result = $api->votes($request);
is($result->[0], $api->HTTP_OK, "Author request returns HTTP 200");
is($result->[1]{success}, 1, "Author can view own writeup votes");
ok(defined($result->[1]{data}), "Data object returned");
is($result->[1]{data}{writeup_id}, $writeup_id, "Writeup ID in response");
ok(defined($result->[1]{data}{months}), "Months array returned");

#############################################################################
# Test: Guest cannot view votes (no access)
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user
);

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $name eq 'writeup_id' ? $writeup_id : undef;
    };
}

$result = $api->votes($guest_request);
is($result->[0], $api->HTTP_OK, "Guest request returns HTTP 200");
is($result->[1]{success}, 0, "Guest cannot view votes");
is($result->[1]{error}, 'Access denied', "Correct error for guest");

#############################################################################
# Test: Random user cannot view votes without voting
#############################################################################

my $other_request = MockRequest->new(
    node_id => $voter_user->{node_id},
    title => $voter_user->{title},
    is_guest_flag => 0,
    nodedata => $voter_user
);

$result = $api->votes($other_request);
is($result->[0], $api->HTTP_OK, "Non-voter request returns HTTP 200");
is($result->[1]{success}, 0, "Non-voter cannot view votes");
is($result->[1]{error}, 'Access denied', "Correct error for non-voter");

#############################################################################
# Test: User who voted can view votes
#############################################################################

# Cast a vote
$DB->sqlInsert('vote', {
    vote_id => $writeup_id,
    voter_user => $voter_user->{node_id},
    weight => 1,
    votetime => '2025-01-20 10:00:00'
});

$result = $api->votes($other_request);
is($result->[0], $api->HTTP_OK, "Voter request returns HTTP 200");
is($result->[1]{success}, 1, "Voter can view votes after voting");
ok(defined($result->[1]{data}{months}), "Months data returned to voter");

#############################################################################
# Test: Admin can view any writeup's votes
#############################################################################

my $admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    nodedata => $admin_user
);

$result = $api->votes($admin_request);
is($result->[0], $api->HTTP_OK, "Admin request returns HTTP 200");
is($result->[1]{success}, 1, "Admin can view any writeup votes");

#############################################################################
# Test: Vote data structure with multiple votes
#############################################################################

# Add more votes in different months
$DB->sqlInsert('vote', {
    vote_id => $writeup_id,
    voter_user => $admin_user->{node_id},
    weight => 1,
    votetime => '2025-02-15 14:00:00'
});

# Get a third user for downvote
my $third_user = $DB->getNode("normaluser3", "user");
if ($third_user) {
    $DB->sqlInsert('vote', {
        vote_id => $writeup_id,
        voter_user => $third_user->{node_id},
        weight => -1,
        votetime => '2025-02-20 16:00:00'
    });
}

$result = $api->votes($admin_request);
is($result->[0], $api->HTTP_OK, "Multi-vote request returns HTTP 200");
is($result->[1]{success}, 1, "Multi-vote request succeeds");

my $months = $result->[1]{data}{months};
ok(scalar(@$months) >= 1, "At least one month of data");

# Check month data structure
my $first_month = $months->[0];
ok(defined($first_month->{year}), "Year present in month data");
ok(defined($first_month->{month}), "Month present in month data");
ok(defined($first_month->{label}), "Label present in month data");
ok(defined($first_month->{upvotes}), "Upvotes present in month data");
ok(defined($first_month->{downvotes}), "Downvotes present in month data");
ok(defined($first_month->{reputation}), "Reputation present in month data");
ok(defined($first_month->{is_january}), "is_january flag present");

# Check that reputation = upvotes + downvotes (cumulative)
my $last_month = $months->[-1];
is($last_month->{reputation}, $last_month->{upvotes} + $last_month->{downvotes},
   "Reputation equals upvotes + downvotes");

#############################################################################
# Test: is_january flag
#############################################################################

# Check that January months are flagged correctly
foreach my $month (@$months) {
    if ($month->{month} == 1) {
        is($month->{is_january}, 1, "January month has is_january = 1");
    } else {
        is($month->{is_january}, 0, "Non-January month has is_january = 0");
    }
}

#############################################################################
# Cleanup
#############################################################################

# Delete test votes
$DB->sqlDelete('vote', "vote_id=$writeup_id");

# Delete test writeup and e2node
$DB->nukeNode($DB->getNodeById($writeup_id), $author_user);
$DB->nukeNode($DB->getNodeById($e2node_id), $author_user);

done_testing();

=head1 NAME

t/068_reputation_api.t - Tests for Everything::API::reputation

=head1 DESCRIPTION

Tests for the reputation graph API covering:
- Input validation (writeup_id)
- Permission checks (author, voter, admin, guest)
- Vote data structure
- Monthly aggregation
- Cumulative reputation calculation
- is_january flag for graph labels

=head1 AUTHOR

Everything2 Development Team

=cut
