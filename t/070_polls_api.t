#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";
use lib "$FindBin::Bin/lib";

use Test::More;
use JSON;
use Everything;
use Everything::Application;
use Everything::API::polls;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::polls->new();
ok($api, "Created polls API instance");

#############################################################################
# Test Setup: Get test users and create test polls
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Check if e2poll type exists
my $e2poll_type = $DB->getType('e2poll');
my $can_test_polls = defined($e2poll_type);

# Create test polls if the type exists
my @test_poll_ids;

SKIP: {
    skip "e2poll type not available", 50 unless $can_test_polls;

    # Create test polls
    for my $i (1..3) {
        my $poll_id = $DB->insertNode(
            "Test Poll $i " . time(),
            'e2poll',
            $admin_user,
            {
                poll_author => $admin_user->{node_id},
                question => "Test question $i?",
                doctext => "Option A\nOption B\nOption C",
                poll_status => ($i == 1 ? 'current' : ($i == 2 ? 'new' : 'closed')),
                totalvotes => $i * 10,
                e2poll_results => join(',', ($i * 3, $i * 4, $i * 3))
            }
        );
        push @test_poll_ids, $poll_id if $poll_id;
    }

    ok(scalar(@test_poll_ids) >= 1, "Created test polls");
}

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
is($routes->{'/list'}, 'list_polls', "list_polls route exists");
is($routes->{'/set_current'}, 'set_current_poll', "set_current_poll route exists");
is($routes->{'/delete'}, 'delete_poll', "delete_poll route exists");

#############################################################################
# Test: List polls - default (active status)
#############################################################################

SKIP: {
    skip "e2poll type not available", 40 unless $can_test_polls;

    my $request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    {
        no warnings 'redefine';
        *MockRequest::param = sub {
            my ($self, $name) = @_;
            return undef;  # Use defaults
        };
    }

    my $result = $api->list_polls($request);
    is($result->[0], $api->HTTP_OK, "List polls returns HTTP 200");
    is($result->[1]{success}, 1, "List polls succeeds");
    ok(defined($result->[1]{polls}), "Polls array present");
    ok(defined($result->[1]{has_more}), "has_more flag present");
    ok(defined($result->[1]{total}), "Total count present");
    ok(defined($result->[1]{startat}), "startat present");
    ok(defined($result->[1]{limit}), "limit present");

    #############################################################################
    # Test: Poll data structure
    #############################################################################

    if (scalar(@{$result->[1]{polls}}) > 0) {
        my $poll = $result->[1]{polls}[0];
        ok(defined($poll->{poll_id}), "Poll has poll_id");
        ok(defined($poll->{title}), "Poll has title");
        ok(defined($poll->{question}), "Poll has question");
        ok(defined($poll->{poll_author}), "Poll has poll_author");
        ok(defined($poll->{poll_author}{node_id}), "Poll author has node_id");
        ok(defined($poll->{poll_author}{title}), "Poll author has title");
        ok(defined($poll->{poll_status}), "Poll has poll_status");
        ok(defined($poll->{totalvotes}), "Poll has totalvotes");
        ok(ref($poll->{options}) eq 'ARRAY', "Poll has options array");
        ok(ref($poll->{results}) eq 'ARRAY', "Poll has results array");
    }

    #############################################################################
    # Test: Filter by status - new
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::param = sub {
            my ($self, $name) = @_;
            my %params = (status => 'new');
            return $params{$name};
        };
    }

    $result = $api->list_polls($request);
    is($result->[0], $api->HTTP_OK, "Filter by 'new' returns HTTP 200");
    foreach my $poll (@{$result->[1]{polls}}) {
        is($poll->{poll_status}, 'new', "Poll status is 'new'");
    }

    #############################################################################
    # Test: Filter by status - current
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::param = sub {
            my ($self, $name) = @_;
            my %params = (status => 'current');
            return $params{$name};
        };
    }

    $result = $api->list_polls($request);
    is($result->[0], $api->HTTP_OK, "Filter by 'current' returns HTTP 200");
    foreach my $poll (@{$result->[1]{polls}}) {
        is($poll->{poll_status}, 'current', "Poll status is 'current'");
    }

    #############################################################################
    # Test: Filter by status - closed
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::param = sub {
            my ($self, $name) = @_;
            my %params = (status => 'closed');
            return $params{$name};
        };
    }

    $result = $api->list_polls($request);
    is($result->[0], $api->HTTP_OK, "Filter by 'closed' returns HTTP 200");
    foreach my $poll (@{$result->[1]{polls}}) {
        is($poll->{poll_status}, 'closed', "Poll status is 'closed'");
    }

    #############################################################################
    # Test: Pagination
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::param = sub {
            my ($self, $name) = @_;
            my %params = (startat => 0, limit => 2);
            return $params{$name};
        };
    }

    $result = $api->list_polls($request);
    is($result->[0], $api->HTTP_OK, "Pagination returns HTTP 200");
    ok(scalar(@{$result->[1]{polls}}) <= 2, "At most 2 polls returned");
    is($result->[1]{limit}, 2, "Limit is 2");

    #############################################################################
    # Test: Guest user can list polls
    #############################################################################

    my $guest_request = MockRequest->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        nodedata => $guest_user
    );

    {
        no warnings 'redefine';
        *MockRequest::param = sub { return undef; };
    }

    $result = $api->list_polls($guest_request);
    is($result->[0], $api->HTTP_OK, "Guest can list polls");
    is($result->[1]{success}, 1, "Guest list succeeds");

    # Guest should not see user_vote populated (unless they voted, which they can't)
    if (scalar(@{$result->[1]{polls}}) > 0) {
        my $poll = $result->[1]{polls}[0];
        ok(!defined($poll->{user_vote}) || $poll->{user_vote} eq '',
           "Guest has no user_vote");
    }

    #############################################################################
    # Test: set_current_poll - non-admin denied
    #############################################################################

    my $normal_request = MockRequest->new(
        node_id => $normal_user->{node_id},
        title => $normal_user->{title},
        is_guest_flag => 0,
        nodedata => $normal_user
    );

    {
        no warnings 'redefine';
        *MockRequest::POSTDATA = sub {
            return JSON::encode_json({ poll_id => $test_poll_ids[0] });
        };
    }

    $result = $api->set_current_poll($normal_request);
    is($result->[0], $api->HTTP_OK, "Non-admin set_current returns HTTP 200");
    is($result->[1]{success}, 0, "Non-admin set_current fails");
    like($result->[1]{error}, qr/admin/i, "Error mentions admin required");

    #############################################################################
    # Test: set_current_poll - admin success
    #############################################################################

    SKIP: {
        skip "No test polls created", 4 unless scalar(@test_poll_ids) >= 2;

        my $admin_request = MockRequest->new(
            node_id => $admin_user->{node_id},
            title => $admin_user->{title},
            is_guest_flag => 0,
            is_admin_flag => 1,
            nodedata => $admin_user
        );

        # Set the second poll (which was 'new') as current
        {
            no warnings 'redefine';
            *MockRequest::POSTDATA = sub {
                return JSON::encode_json({ poll_id => $test_poll_ids[1] });
            };
        }

        $result = $api->set_current_poll($admin_request);
        is($result->[0], $api->HTTP_OK, "Admin set_current returns HTTP 200");
        is($result->[1]{success}, 1, "Admin set_current succeeds");
        is($result->[1]{poll_id}, $test_poll_ids[1], "Correct poll_id returned");

        # Verify the poll is now current (query DB directly to avoid cache)
        my $poll_status = $DB->sqlSelect('poll_status', 'e2poll',
            "e2poll_id=" . $test_poll_ids[1]);
        is($poll_status, 'current', "Poll status is now 'current'");
    }

    #############################################################################
    # Test: set_current_poll - invalid JSON
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::POSTDATA = sub { return "not valid json"; };
    }

    my $admin_request = MockRequest->new(
        node_id => $admin_user->{node_id},
        title => $admin_user->{title},
        is_guest_flag => 0,
        is_admin_flag => 1,
        nodedata => $admin_user
    );

    $result = $api->set_current_poll($admin_request);
    is($result->[0], $api->HTTP_OK, "Invalid JSON returns HTTP 200");
    is($result->[1]{success}, 0, "Invalid JSON fails");
    like($result->[1]{error}, qr/invalid json/i, "Error mentions invalid JSON");

    #############################################################################
    # Test: set_current_poll - missing poll_id
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::POSTDATA = sub {
            return JSON::encode_json({});  # No poll_id
        };
    }

    $result = $api->set_current_poll($admin_request);
    is($result->[0], $api->HTTP_OK, "Missing poll_id returns HTTP 200");
    is($result->[1]{success}, 0, "Missing poll_id fails");
    like($result->[1]{error}, qr/poll_id/i, "Error mentions poll_id required");

    #############################################################################
    # Test: set_current_poll - non-existent poll
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::POSTDATA = sub {
            return JSON::encode_json({ poll_id => 999999999 });
        };
    }

    $result = $api->set_current_poll($admin_request);
    is($result->[0], $api->HTTP_OK, "Non-existent poll returns HTTP 200");
    is($result->[1]{success}, 0, "Non-existent poll fails");
    like($result->[1]{error}, qr/not found/i, "Error mentions poll not found");

    #############################################################################
    # Test: delete_poll - non-admin denied
    #############################################################################

    {
        no warnings 'redefine';
        *MockRequest::POSTDATA = sub {
            return JSON::encode_json({ poll_id => $test_poll_ids[0] });
        };
    }

    $result = $api->delete_poll($normal_request);
    is($result->[0], $api->HTTP_OK, "Non-admin delete returns HTTP 200");
    is($result->[1]{success}, 0, "Non-admin delete fails");
    like($result->[1]{error}, qr/admin/i, "Error mentions admin required");

    #############################################################################
    # Test: delete_poll - admin success
    #############################################################################

    SKIP: {
        skip "No test polls to delete", 3 unless scalar(@test_poll_ids) >= 1;

        # Delete the last test poll
        my $poll_to_delete = pop @test_poll_ids;

        {
            no warnings 'redefine';
            *MockRequest::POSTDATA = sub {
                return JSON::encode_json({ poll_id => $poll_to_delete });
            };
        }

        $result = $api->delete_poll($admin_request);
        is($result->[0], $api->HTTP_OK, "Admin delete returns HTTP 200");
        is($result->[1]{success}, 1, "Admin delete succeeds");

        # Verify poll is deleted
        my $deleted_poll = $DB->getNodeById($poll_to_delete);
        ok(!$deleted_poll, "Poll was deleted from database");
    }
}

#############################################################################
# Cleanup
#############################################################################

foreach my $poll_id (@test_poll_ids) {
    my $poll = $DB->getNodeById($poll_id);
    if ($poll) {
        $DB->sqlDelete('pollvote', "pollvote_id=$poll_id");
        $DB->nukeNode($poll, -1);
    }
}

done_testing();

=head1 NAME

t/070_polls_api.t - Tests for Everything::API::polls

=head1 DESCRIPTION

Tests for the polls API covering:
- List polls with status filter (active, new, current, closed)
- Pagination
- Poll data structure
- Guest user access
- set_current_poll permission checks
- set_current_poll validation (JSON, poll_id)
- delete_poll permission checks
- delete_poll functionality

=head1 AUTHOR

Everything2 Development Team

=cut
