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
use Everything::API::user_search;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::user_search->new();
ok($api, "Created user_search API instance");

#############################################################################
# Test Setup: Get test users and create test writeups
#############################################################################

my $search_user = $DB->getNode("normaluser1", "user");
ok($search_user, "Got search target user");

my $viewer_user = $DB->getNode("normaluser2", "user");
ok($viewer_user, "Got viewer user");

my $editor_user = $DB->getNode("root", "user");
ok($editor_user, "Got editor/admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Create test writeups for the search user
my @test_writeup_ids;
for my $i (1..3) {
    my $e2node_title = "Test UserSearch Node $i " . time();
    my $e2node_id = $DB->insertNode(
        $e2node_title,
        'e2node',
        $search_user,
        { title => $e2node_title }
    );

    my $writeup_id = $DB->insertNode(
        $e2node_title,
        'writeup',
        $search_user,
        {
            parent_e2node => $e2node_id,
            doctext => "Test writeup $i for user_search API testing.",
            publishtime => "2025-01-" . sprintf("%02d", $i) . " 12:00:00",
            notnew => 0  # Not hidden
        }
    );
    push @test_writeup_ids, { writeup_id => $writeup_id, e2node_id => $e2node_id };
}
ok(scalar(@test_writeup_ids) == 3, "Created 3 test writeups");

# Create a CGI mock for parameters
package MockCGI;
sub new {
    my ($class, %params) = @_;
    return bless { params => \%params }, $class;
}
sub param {
    my ($self, $name) = @_;
    return $self->{params}{$name};
}

package main;

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{'/'}, 'search', "search route exists");

#############################################################################
# Test: Missing username parameter
#############################################################################

my $request = MockRequest->new(
    node_id => $viewer_user->{node_id},
    title => $viewer_user->{title},
    is_guest_flag => 0,
    nodedata => $viewer_user
);

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new();  # No username
    };
    *MockRequest::VARS = sub { return {}; };
}

my $result = $api->search($request);
is($result->[0], $api->HTTP_BAD_REQUEST, "Missing username returns 400");
like($result->[1]{error}, qr/username.*required/i, "Error mentions username required");

#############################################################################
# Test: Non-existent user
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(username => 'nonexistent_user_12345');
    };
}

$result = $api->search($request);
is($result->[0], $api->HTTP_OK, "Non-existent user returns HTTP 200");
like($result->[1]{error}, qr/not found/i, "Error mentions user not found");
is($result->[1]{username}, 'nonexistent_user_12345', "Username echoed back");
is(ref($result->[1]{writeups}), 'ARRAY', "Empty writeups array returned");
is(scalar(@{$result->[1]{writeups}}), 0, "Zero writeups for non-existent user");

#############################################################################
# Test: Valid user search - basic response
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(username => $search_user->{title});
    };
}

$result = $api->search($request);
is($result->[0], $api->HTTP_OK, "Valid user search returns HTTP 200");
is($result->[1]{username}, $search_user->{title}, "Username in response");
is($result->[1]{user_id}, $search_user->{node_id}, "User ID in response");
ok(defined($result->[1]{writeups}), "Writeups array present");
ok(defined($result->[1]{total}), "Total count present");
ok(defined($result->[1]{page}), "Page number present");
ok(defined($result->[1]{per_page}), "Per page present");
ok(defined($result->[1]{total_pages}), "Total pages present");
ok(defined($result->[1]{orderby}), "Order by present");
ok(defined($result->[1]{can_see_rep}), "can_see_rep flag present");
ok(defined($result->[1]{is_self}), "is_self flag present");
ok(defined($result->[1]{is_editor}), "is_editor flag present");

#############################################################################
# Test: Writeup data structure
#############################################################################

ok($result->[1]{total} >= 3, "At least 3 writeups found");

my $first_writeup = $result->[1]{writeups}[0];
ok(defined($first_writeup->{node_id}), "Writeup has node_id");
ok(defined($first_writeup->{title}), "Writeup has title");
ok(defined($first_writeup->{parent_id}), "Writeup has parent_id");
ok(defined($first_writeup->{parent_title}), "Writeup has parent_title");
ok(defined($first_writeup->{writeup_type}), "Writeup has writeup_type");
ok(defined($first_writeup->{cools}), "Writeup has cools");
ok(defined($first_writeup->{publishtime}), "Writeup has publishtime");
ok(defined($first_writeup->{hits}), "Writeup has hits");

#############################################################################
# Test: Self vs other visibility
#############################################################################

# Viewing another user's writeups
is($result->[1]{is_self}, 0, "is_self is 0 when viewing another user");
is($result->[1]{can_see_rep}, 0, "can_see_rep is 0 for non-self non-editor");

# Viewer cannot see reputation
ok(!defined($first_writeup->{reputation}) || !$result->[1]{can_see_rep},
   "Reputation not visible to other users");

# Self viewing own writeups
my $self_request = MockRequest->new(
    node_id => $search_user->{node_id},
    title => $search_user->{title},
    is_guest_flag => 0,
    nodedata => $search_user
);

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(username => $search_user->{title});
    };
}

$result = $api->search($self_request);
is($result->[0], $api->HTTP_OK, "Self search returns HTTP 200");
is($result->[1]{is_self}, 1, "is_self is 1 when viewing own writeups");
is($result->[1]{can_see_rep}, 1, "can_see_rep is 1 for self");

# Self can see reputation and vote spread
$first_writeup = $result->[1]{writeups}[0];
ok(defined($first_writeup->{reputation}), "Self can see reputation");
ok(defined($first_writeup->{upvotes}), "Self can see upvotes");
ok(defined($first_writeup->{downvotes}), "Self can see downvotes");
ok(defined($first_writeup->{hidden}), "Self can see hidden status");

#############################################################################
# Test: Editor visibility
#############################################################################

my $editor_request = MockRequest->new(
    node_id => $editor_user->{node_id},
    title => $editor_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    is_editor_flag => 1,
    nodedata => $editor_user
);

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(username => $search_user->{title});
    };
}

$result = $api->search($editor_request);
is($result->[0], $api->HTTP_OK, "Editor search returns HTTP 200");
is($result->[1]{is_editor}, 1, "is_editor is 1 for editors");
is($result->[1]{can_see_rep}, 1, "can_see_rep is 1 for editors");

$first_writeup = $result->[1]{writeups}[0];
ok(defined($first_writeup->{reputation}), "Editor can see reputation");
ok(defined($first_writeup->{hidden}), "Editor can see hidden status");
ok(defined($first_writeup->{has_note}), "Editor can see has_note flag");

#############################################################################
# Test: Guest user search
#############################################################################

my $guest_request = MockRequest->new(
    node_id => 0,
    title => 'Guest User',
    is_guest_flag => 1,
    nodedata => $guest_user
);

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(username => $search_user->{title});
    };
}

$result = $api->search($guest_request);
is($result->[0], $api->HTTP_OK, "Guest search returns HTTP 200");
is($result->[1]{is_self}, 0, "Guest is_self is 0");
is($result->[1]{can_see_rep}, 0, "Guest cannot see reputation");

# Guest should not see vote information
$first_writeup = $result->[1]{writeups}[0];
ok(!defined($first_writeup->{user_vote}), "Guest does not see user_vote");

#############################################################################
# Test: Pagination
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(
            username => $search_user->{title},
            page => 1,
            per_page => 2
        );
    };
}

$result = $api->search($request);
is($result->[0], $api->HTTP_OK, "Paginated search returns HTTP 200");
is($result->[1]{page}, 1, "Page is 1");
is($result->[1]{per_page}, 2, "Per page is 2");
ok(scalar(@{$result->[1]{writeups}}) <= 2, "At most 2 writeups returned");
ok($result->[1]{total_pages} >= 1, "Total pages calculated");

# Test page 2
{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(
            username => $search_user->{title},
            page => 2,
            per_page => 2
        );
    };
}

my $page2_result = $api->search($request);
is($page2_result->[1]{page}, 2, "Page 2 request works");

#############################################################################
# Test: Sort order - publishtime desc (default)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(
            username => $search_user->{title},
            orderby => 'publishtime_desc'
        );
    };
}

$result = $api->search($request);
is($result->[1]{orderby}, 'publishtime_desc', "Order by publishtime_desc");

# Check that writeups are ordered by publishtime descending
if (scalar(@{$result->[1]{writeups}}) >= 2) {
    my $first_time = $result->[1]{writeups}[0]{publishtime};
    my $second_time = $result->[1]{writeups}[1]{publishtime};
    ok($first_time ge $second_time, "First writeup has later publishtime");
}

#############################################################################
# Test: Sort order - title ascending
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(
            username => $search_user->{title},
            orderby => 'title_asc'
        );
    };
}

$result = $api->search($request);
is($result->[1]{orderby}, 'title_asc', "Order by title_asc");

#############################################################################
# Test: Invalid sort order falls back to default
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(
            username => $search_user->{title},
            orderby => 'invalid_order'
        );
    };
}

$result = $api->search($request);
# Should still work - uses default order
is($result->[0], $api->HTTP_OK, "Invalid orderby still returns HTTP 200");

#############################################################################
# Test: Per page limits
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(
            username => $search_user->{title},
            per_page => 200  # Should be capped at 100
        );
    };
}

$result = $api->search($request);
ok($result->[1]{per_page} <= 100, "Per page capped at maximum");

{
    no warnings 'redefine';
    *MockRequest::cgi = sub {
        return MockCGI->new(
            username => $search_user->{title},
            per_page => 0  # Should be set to default
        );
    };
}

$result = $api->search($request);
ok($result->[1]{per_page} >= 1, "Per page has minimum value");

#############################################################################
# Cleanup
#############################################################################

foreach my $test_data (@test_writeup_ids) {
    my $writeup = $DB->getNodeById($test_data->{writeup_id});
    my $e2node = $DB->getNodeById($test_data->{e2node_id});
    $DB->nukeNode($writeup, $search_user) if $writeup;
    $DB->nukeNode($e2node, $search_user) if $e2node;
}

done_testing();

=head1 NAME

t/069_user_search_api.t - Tests for Everything::API::user_search

=head1 DESCRIPTION

Tests for the user search API covering:
- Input validation (username required)
- Non-existent user handling
- Basic response structure
- Writeup data fields
- Self vs other visibility (reputation, vote spread)
- Editor visibility (has_note, hidden)
- Guest user restrictions
- Pagination
- Sort ordering
- Per page limits

=head1 AUTHOR

Everything2 Development Team

=cut
