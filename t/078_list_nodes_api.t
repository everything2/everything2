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
use Everything::API::list_nodes;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

my $api = Everything::API::list_nodes->new();
ok($api, "Created list_nodes API instance");

#############################################################################
# Test Setup: Get test users and types
#############################################################################

my $normal_user = $DB->getNode("normaluser1", "user");
ok($normal_user, "Got normal user");

my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user");

my $guest_user = $DB->getNode("guest user", "user");
ok($guest_user, "Got guest user");

# Get a type for testing (user type is common)
my $user_type = $DB->getType('user');
ok($user_type, "Got user type");
my $user_type_id = $user_type->{node_id};

#############################################################################
# Test: Basic routes check
#############################################################################

my $routes = $api->routes();
ok($routes, "Routes defined");
is($routes->{list}, 'list', "list route exists");

#############################################################################
# Test: list - normal user denied (not editor/developer)
#############################################################################

my $normal_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_editor_flag => 0,
    is_developer_flag => 0,
    nodedata => $normal_user,
    request_method => 'GET'
);

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return undef;
    };
}

my $result = $api->list($normal_request);
is($result->[0], $api->HTTP_OK, "Normal user returns HTTP 200");
is($result->[1]{success}, 0, "Normal user fails");
like($result->[1]{error}, qr/access denied/i, "Error mentions access denied");

#############################################################################
# Test: list - missing type_id
#############################################################################

my $admin_request = MockRequest->new(
    node_id => $admin_user->{node_id},
    title => $admin_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 1,
    is_editor_flag => 1,
    nodedata => $admin_user,
    request_method => 'GET'
);

{
    no warnings 'redefine';
    *MockRequest::param = sub { return undef; };  # No type_id
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Missing type_id returns HTTP 200");
is($result->[1]{success}, 0, "Missing type_id fails");
like($result->[1]{error}, qr/invalid type/i, "Error mentions invalid type");

#############################################################################
# Test: list - invalid type_id (not a number)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return 'not_a_number' if $name eq 'type_id';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Invalid type_id returns HTTP 200");
is($result->[1]{success}, 0, "Invalid type_id fails");
like($result->[1]{error}, qr/invalid type/i, "Error mentions invalid type");

#############################################################################
# Test: list - invalid type_id (zero)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return '0' if $name eq 'type_id';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Zero type_id returns HTTP 200");
is($result->[1]{success}, 0, "Zero type_id fails");

#############################################################################
# Test: list - admin success with valid type_id
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Admin list returns HTTP 200");
is($result->[1]{success}, 1, "Admin list succeeds");
ok(defined($result->[1]{nodes}), "Nodes array present");
ok(ref($result->[1]{nodes}) eq 'ARRAY', "Nodes is an array");
ok(defined($result->[1]{total}), "Total count present");
is($result->[1]{page_size}, 100, "Admin page size is 100");
is($result->[1]{type_id}, $user_type_id, "Type ID in response");
ok($result->[1]{type_name}, "Type name in response");

#############################################################################
# Test: list - editor (non-admin) has smaller page size
#############################################################################

my $editor_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 0,
    is_editor_flag => 1,
    nodedata => $normal_user,
    request_method => 'GET'
);

$result = $api->list($editor_request);
is($result->[0], $api->HTTP_OK, "Editor list returns HTTP 200");
is($result->[1]{success}, 1, "Editor list succeeds");
is($result->[1]{page_size}, 75, "Editor page size is 75");

#############################################################################
# Test: list - developer (non-editor) has smaller page size
#############################################################################

my $developer_request = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    is_guest_flag => 0,
    is_admin_flag => 0,
    is_editor_flag => 0,
    is_developer_flag => 1,
    nodedata => $normal_user,
    request_method => 'GET'
);

$result = $api->list($developer_request);
is($result->[0], $api->HTTP_OK, "Developer list returns HTTP 200");
is($result->[1]{success}, 1, "Developer list succeeds");
is($result->[1]{page_size}, 60, "Developer page size is 60");

#############################################################################
# Test: list - sort by name ascending
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return 'nameA' if $name eq 'sort1';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Sort by name returns HTTP 200");
is($result->[1]{success}, 1, "Sort by name succeeds");

# Verify nodes are sorted by name if we have multiple
if (scalar(@{$result->[1]{nodes}}) >= 2) {
    my $first_title = $result->[1]{nodes}[0]{title};
    my $second_title = $result->[1]{nodes}[1]{title};
    ok(lc($first_title) le lc($second_title), "Nodes sorted by name ascending");
} else {
    pass("Not enough nodes to verify sort order");
}

#############################################################################
# Test: list - sort by ID descending
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return 'idD' if $name eq 'sort1';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Sort by ID desc returns HTTP 200");

# Verify nodes are sorted by ID descending if we have multiple
if (scalar(@{$result->[1]{nodes}}) >= 2) {
    my $first_id = $result->[1]{nodes}[0]{node_id};
    my $second_id = $result->[1]{nodes}[1]{node_id};
    ok($first_id >= $second_id, "Nodes sorted by ID descending");
} else {
    pass("Not enough nodes to verify sort order");
}

#############################################################################
# Test: list - dual sort (sort1 and sort2)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return 'authorA' if $name eq 'sort1';
        return 'nameA' if $name eq 'sort2';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Dual sort returns HTTP 200");
is($result->[1]{success}, 1, "Dual sort succeeds");

#############################################################################
# Test: list - invalid sort option ignored
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return 'invalid_sort; DROP TABLE node;' if $name eq 'sort1';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Invalid sort returns HTTP 200");
is($result->[1]{success}, 1, "Invalid sort succeeds (ignored)");

#############################################################################
# Test: list - pagination with offset
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return 5 if $name eq 'offset';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Pagination returns HTTP 200");
is($result->[1]{offset}, 5, "Offset is 5");

#############################################################################
# Test: list - filter by author
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return $admin_user->{title} if $name eq 'filter_user';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Filter by author returns HTTP 200");
is($result->[1]{success}, 1, "Filter by author succeeds");
is($result->[1]{filter_user_name}, $admin_user->{title}, "Filter user name in response");
is($result->[1]{filter_user_not}, 0, "filter_user_not is false");

#############################################################################
# Test: list - filter by author (NOT)
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return $admin_user->{title} if $name eq 'filter_user';
        return 1 if $name eq 'filter_user_not';
        return undef;
    };
}

$result = $api->list($admin_request);
is($result->[0], $api->HTTP_OK, "Filter NOT author returns HTTP 200");
is($result->[1]{success}, 1, "Filter NOT author succeeds");
is($result->[1]{filter_user_not}, 1, "filter_user_not is true");

#############################################################################
# Test: list - node data structure
#############################################################################

{
    no warnings 'redefine';
    *MockRequest::param = sub {
        my ($self, $name) = @_;
        return $user_type_id if $name eq 'type_id';
        return undef;
    };
}

$result = $api->list($admin_request);

if (scalar(@{$result->[1]{nodes}}) > 0) {
    my $node = $result->[1]{nodes}[0];
    ok(defined($node->{node_id}), "Node has node_id");
    ok(defined($node->{title}), "Node has title");
    ok(defined($node->{author_user}), "Node has author_user");
    ok(defined($node->{author_name}), "Node has author_name");
    ok(defined($node->{createtime}), "Node has createtime");
    ok(defined($node->{can_edit}), "Node has can_edit flag");
} else {
    pass("No nodes found to check structure");
    pass("Skipping node structure checks");
    pass("Skipping node structure checks");
    pass("Skipping node structure checks");
    pass("Skipping node structure checks");
    pass("Skipping node structure checks");
}

done_testing();

=head1 NAME

t/078_list_nodes_api.t - Tests for Everything::API::list_nodes

=head1 DESCRIPTION

Tests for the list_nodes API covering:
- Normal user denied (not editor/developer)
- Missing type_id validation
- Invalid type_id validation
- Admin success with valid type_id
- Editor page size
- Developer page size
- Various sort options
- Invalid sort option protection
- Pagination with offset
- Filter by author
- Filter NOT by author
- Node data structure validation

=head1 AUTHOR

Everything2 Development Team

=cut
