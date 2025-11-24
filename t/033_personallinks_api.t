#!/usr/bin/perl -w

use strict;
use warnings;

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitInterpolationOfLiterals ProhibitMagicNumbers)

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "/var/libraries/lib/perl5";

use Test::More;
use Everything;
use Everything::Application;
use Everything::API::personallinks;
use JSON;
use Data::Dumper;

# Suppress expected warnings throughout the test
$SIG{__WARN__} = sub {
	my $warning = shift;
	warn $warning unless $warning =~ /Could not open log/
	                  || $warning =~ /Use of uninitialized value/;
};

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Personal Links API functionality
#
# These tests verify:
# 1. GET /api/personallinks/get - Get all personal links
# 2. POST /api/personallinks/update - Update all personal links
# 3. POST /api/personallinks/add - Add current node to links
# 4. DELETE /api/personallinks/delete/:index - Delete a link by index
# 5. Authorization checks (guest users blocked)
# 6. Limit enforcement (20 items OR 1000 characters)
# 7. Input sanitization (bracket escaping)
#############################################################################

# Get a normal user for API operations
my $test_user = $DB->getNode("normaluser1", "user");
if (!$test_user) {
    $test_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "node_id > 1 LIMIT 1");
}
ok($test_user, "Got test user for tests");
diag("Test user ID: " . ($test_user ? $test_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

# Get an editor user for limit testing (optional - will skip some tests if not available)
my $editor_user;
eval {
    $editor_user = $DB->sqlSelectHashref("*", "user JOIN node ON user_id=node_id", "vars LIKE '%gods=1%' LIMIT 1");
};
# Editor user is optional - some tests will be skipped if not available
diag("Editor user available: " . ($editor_user ? "yes" : "no")) if $ENV{TEST_VERBOSE};

#############################################################################
# Helper Functions
#############################################################################

# Mock User object for testing
package MockUser {
    use Moose;
    has 'NODEDATA' => (is => 'rw', default => sub { {} });
    has 'node_id' => (is => 'rw');
    has 'title' => (is => 'rw');
    has 'VARS' => (is => 'rw', default => sub { {} });
    has 'is_guest_flag' => (is => 'rw', default => 0);
    has 'is_editor_flag' => (is => 'rw', default => 0);
    sub is_guest { return shift->is_guest_flag; }
    sub is_editor { return shift->is_editor_flag; }
    sub set_vars {
        my ($self, $vars) = @_;
        $self->VARS($vars);
        return 1;
    }
}

# Mock REQUEST object for testing
package MockRequest {
    use Moose;
    has 'user' => (is => 'rw', isa => 'MockUser');
    has '_postdata' => (is => 'rw', default => sub { {} });
    sub JSON_POSTDATA { return shift->_postdata; }
    sub is_guest { return shift->user->is_guest; }
}
package main;

#############################################################################
# Test Setup
#############################################################################

my $api = Everything::API::personallinks->new();
ok($api, "Created personallinks API instance");

#############################################################################
# Test 1: Get personal links (empty list)
#############################################################################

subtest 'Get personal links returns empty list for new user' => sub {
    plan tests => 7;

    # Create mock user with no personal links
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get personal links
    my $result = $api->get_personal_links($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    ok($result->[1], "GET returns response data");
    is(ref($result->[1]{links}), 'ARRAY', "GET returns array of links");
    is(scalar(@{$result->[1]{links}}), 0, "Empty links for new user");
    is($result->[1]{count}, 0, "Count is 0");
    is($result->[1]{item_limit}, 20, "Item limit is 20");
    is($result->[1]{char_limit}, 1000, "Character limit is 1000");
};

#############################################################################
# Test 2: Get personal links (with existing links)
#############################################################################

subtest 'Get personal links returns existing links' => sub {
    plan tests => 8;

    # Create mock user with some personal links
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {
            personal_nodelet => 'Everything<br>homenode<br>Writeups By Type',
        },
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Get personal links
    my $result = $api->get_personal_links($mock_request);
    is($result->[0], 200, "GET returns HTTP 200");
    is(scalar(@{$result->[1]{links}}), 3, "Returns 3 links");
    is($result->[1]{links}[0], 'Everything', "First link correct");
    is($result->[1]{links}[1], 'homenode', "Second link correct");
    is($result->[1]{links}[2], 'Writeups By Type', "Third link correct");
    is($result->[1]{count}, 3, "Count matches array length");
    ok($result->[1]{total_chars} > 0, "Total chars calculated");
    ok($result->[1]{total_chars} < 1000, "Under character limit");
};

#############################################################################
# Test 3: Update personal links successfully
#############################################################################

subtest 'Update personal links replaces all links' => sub {
    plan tests => 7;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {
            personal_nodelet => 'old link',
        },
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            links => ['new link 1', 'new link 2', 'new link 3'],
        },
    );

    # Update links
    my $result = $api->update_personal_links($mock_request);
    is($result->[0], 200, "UPDATE returns HTTP 200");
    is(scalar(@{$result->[1]{links}}), 3, "Returns 3 links");
    is($result->[1]{links}[0], 'new link 1', "First link updated");
    is($result->[1]{links}[1], 'new link 2', "Second link updated");
    is($result->[1]{links}[2], 'new link 3', "Third link updated");

    # Verify VARS were updated
    like($mock_user->VARS->{personal_nodelet}, qr/new link 1/, "VARS contains new links");
    unlike($mock_user->VARS->{personal_nodelet}, qr/old link/, "VARS no longer contains old link");
};

#############################################################################
# Test 4: Update sanitizes brackets
#############################################################################

subtest 'Update sanitizes brackets in link titles' => sub {
    plan tests => 3;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            links => ['[test]', 'normal link'],
        },
    );

    # Update links with brackets
    my $result = $api->update_personal_links($mock_request);
    is($result->[0], 200, "UPDATE returns HTTP 200");

    # Brackets should be escaped in storage
    like($mock_user->VARS->{personal_nodelet}, qr/\&\#91;test\&\#93;/, "Brackets escaped in VARS");
    unlike($mock_user->VARS->{personal_nodelet}, qr/\[test\]/, "Raw brackets not in VARS");
};

#############################################################################
# Test 5: Update enforces item limit
#############################################################################

subtest 'Update enforces 20 item limit' => sub {
    plan tests => 2;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );

    # Try to add 21 links
    my @too_many_links = map { "link $_" } (1..21);
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            links => \@too_many_links,
        },
    );

    # Should fail
    my $result = $api->update_personal_links($mock_request);
    is($result->[0], 400, "UPDATE returns HTTP 400 when over limit");
    like($result->[1]{error}, qr/Cannot add more links/, "Error message mentions limit");
};

#############################################################################
# Test 5a: Allow reducing links even when over limit
#############################################################################

subtest 'Update allows reducing links when over limit' => sub {
    plan tests => 6;

    # Create mock user with 25 links (over the 20 item limit)
    my @over_limit_links = map { "link $_" } (1..25);
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {
            personal_nodelet => join('<br>', @over_limit_links),
        },
        NODEDATA => $test_user,
    );

    # Reduce to 22 links (still over limit, but fewer than before)
    my @reduced_links = map { "link $_" } (1..22);
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            links => \@reduced_links,
        },
    );

    # Should succeed because we're reducing
    my $result = $api->update_personal_links($mock_request);
    is($result->[0], 200, "UPDATE returns HTTP 200 when reducing from over limit");
    is(scalar(@{$result->[1]{links}}), 22, "Returns 22 links");

    # Try to increase back to 23 (still under original 25, but more than current 22)
    my @increased_links = map { "link $_" } (1..23);
    $mock_user->{VARS}{personal_nodelet} = join('<br>', @reduced_links);
    my $mock_request2 = MockRequest->new(
        user => $mock_user,
        _postdata => {
            links => \@increased_links,
        },
    );

    # Should fail because we're increasing while over limit
    my $result2 = $api->update_personal_links($mock_request2);
    is($result2->[0], 400, "UPDATE returns HTTP 400 when increasing while over limit");
    like($result2->[1]{error}, qr/Cannot add more links/, "Error message explains can't add more");

    # Reduce to 19 links (under limit)
    my @under_limit_links = map { "link $_" } (1..19);
    $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            links => \@under_limit_links,
        },
    );

    # Should succeed
    my $result3 = $api->update_personal_links($mock_request);
    is($result3->[0], 200, "UPDATE returns HTTP 200 when reducing to under limit");
    is(scalar(@{$result3->[1]{links}}), 19, "Returns 19 links");
};

#############################################################################
# Test 6: Update filters empty links
#############################################################################

subtest 'Update filters out empty and whitespace-only links' => sub {
    plan tests => 4;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            links => ['link 1', '', 'link 2', '   ', 'link 3'],
        },
    );

    # Update links
    my $result = $api->update_personal_links($mock_request);
    is($result->[0], 200, "UPDATE returns HTTP 200");
    is(scalar(@{$result->[1]{links}}), 3, "Only 3 non-empty links");
    is($result->[1]{links}[0], 'link 1', "First link correct");
    is($result->[1]{links}[2], 'link 3', "Third link correct");
};

#############################################################################
# Test 7: Add current node to links
#############################################################################

subtest 'Add current node appends to personal links' => sub {
    plan tests => 5;

    # Create mock user with existing links
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {
            personal_nodelet => 'existing link',
        },
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            title => 'New Node Title',
        },
    );

    # Add current node
    my $result = $api->add_current_node($mock_request);
    is($result->[0], 200, "ADD returns HTTP 200");
    is(scalar(@{$result->[1]{links}}), 2, "Now has 2 links");
    is($result->[1]{links}[0], 'existing link', "Old link still present");
    is($result->[1]{links}[1], 'New Node Title', "New link added");
    like($mock_user->VARS->{personal_nodelet}, qr/New Node Title/, "VARS updated with new link");
};

#############################################################################
# Test 8: Add current node respects limit
#############################################################################

subtest 'Add current node respects limit' => sub {
    plan tests => 2;

    # Create mock user at limit
    my @max_links = map { "link $_" } (1..20);
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {
            personal_nodelet => join('<br>', @max_links),
        },
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
        _postdata => {
            title => 'One Too Many',
        },
    );

    # Try to add (should fail)
    my $result = $api->add_current_node($mock_request);
    is($result->[0], 400, "ADD returns HTTP 400 when at limit");
    like($result->[1]{error}, qr/Cannot add more/, "Error message mentions limit");
};

#############################################################################
# Test 9: Delete link by index
#############################################################################

subtest 'Delete link removes link at specified index' => sub {
    plan tests => 6;

    # Create mock user with links
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {
            personal_nodelet => 'link 1<br>link 2<br>link 3',
        },
        NODEDATA => $test_user,
    );
    my $mock_request = MockRequest->new(
        user => $mock_user,
    );

    # Delete middle link (index 1)
    my $result = $api->delete_link($mock_request, 1);
    is($result->[0], 200, "DELETE returns HTTP 200");
    is(scalar(@{$result->[1]{links}}), 2, "Now has 2 links");
    is($result->[1]{links}[0], 'link 1', "First link still present");
    is($result->[1]{links}[1], 'link 3', "Third link moved to index 1");
    like($mock_user->VARS->{personal_nodelet}, qr/link 1/, "VARS contains link 1");
    unlike($mock_user->VARS->{personal_nodelet}, qr/link 2/, "VARS no longer contains link 2");
};

#############################################################################
# Test 10: Delete validates index
#############################################################################

subtest 'Delete validates index is in range' => sub {
    plan tests => 4;

    # Create mock user with 3 links
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {
            personal_nodelet => 'link 1<br>link 2<br>link 3',
        },
        NODEDATA => $test_user,
    );

    # Try to delete index 5 (out of range)
    my $mock_request1 = MockRequest->new(user => $mock_user);
    my $result1 = $api->delete_link($mock_request1, 5);
    is($result1->[0], 400, "DELETE returns HTTP 400 for out of range index");

    # Try to delete negative index
    my $mock_request2 = MockRequest->new(user => $mock_user);
    my $result2 = $api->delete_link($mock_request2, -1);
    is($result2->[0], 400, "DELETE returns HTTP 400 for negative index");

    # Try to delete invalid index (string)
    my $mock_request3 = MockRequest->new(user => $mock_user);
    my $result3 = $api->delete_link($mock_request3, 'invalid');
    is($result3->[0], 400, "DELETE returns HTTP 400 for non-numeric index");

    # Valid delete (index 0)
    my $mock_request4 = MockRequest->new(user => $mock_user);
    my $result4 = $api->delete_link($mock_request4, 0);
    is($result4->[0], 200, "DELETE returns HTTP 200 for valid index 0");
};

#############################################################################
# Test 11: Authorization - guest user blocked
#############################################################################

subtest 'Authorization: guest user cannot access personal links' => sub {
    plan tests => 4;

    # Create mock guest user
    my $mock_user = MockUser->new(
        node_id => 0,
        title => 'Guest User',
        is_guest_flag => 1,
        is_editor_flag => 0,
        VARS => {},
    );

    # Test GET
    my $mock_request1 = MockRequest->new(user => $mock_user);
    my $result1 = $api->get_personal_links($mock_request1);
    is($result1->[0], 401, "GET returns HTTP 401 for guest");

    # Test UPDATE
    my $mock_request2 = MockRequest->new(
        user => $mock_user,
        _postdata => { links => ['test'] },
    );
    my $result2 = $api->update_personal_links($mock_request2);
    is($result2->[0], 401, "UPDATE returns HTTP 401 for guest");

    # Test ADD
    my $mock_request3 = MockRequest->new(
        user => $mock_user,
        _postdata => { title => 'test' },
    );
    my $result3 = $api->add_current_node($mock_request3);
    is($result3->[0], 401, "ADD returns HTTP 401 for guest");

    # Test DELETE
    my $mock_request4 = MockRequest->new(user => $mock_user);
    my $result4 = $api->delete_link($mock_request4, 0);
    is($result4->[0], 401, "DELETE returns HTTP 401 for guest");
};

#############################################################################
# Test 12: Update validates request data
#############################################################################

subtest 'Update validates request data structure' => sub {
    plan tests => 3;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );

    # Test missing links field
    my $mock_request1 = MockRequest->new(
        user => $mock_user,
        _postdata => {},
    );
    my $result1 = $api->update_personal_links($mock_request1);
    is($result1->[0], 400, "Missing links field returns HTTP 400");

    # Test links is not an array
    my $mock_request2 = MockRequest->new(
        user => $mock_user,
        _postdata => { links => 'not an array' },
    );
    my $result2 = $api->update_personal_links($mock_request2);
    is($result2->[0], 400, "Non-array links returns HTTP 400");

    # Test links is a hash
    my $mock_request3 = MockRequest->new(
        user => $mock_user,
        _postdata => { links => {} },
    );
    my $result3 = $api->update_personal_links($mock_request3);
    is($result3->[0], 400, "Hash links returns HTTP 400");
};

#############################################################################
# Test 13: Add validates request data
#############################################################################

subtest 'Add current node validates request data' => sub {
    plan tests => 3;

    # Create mock user
    my $mock_user = MockUser->new(
        node_id => $test_user->{node_id},
        title => $test_user->{title},
        is_guest_flag => 0,
        is_editor_flag => 0,
        VARS => {},
        NODEDATA => $test_user,
    );

    # Test missing title field
    my $mock_request1 = MockRequest->new(
        user => $mock_user,
        _postdata => {},
    );
    my $result1 = $api->add_current_node($mock_request1);
    is($result1->[0], 400, "Missing title returns HTTP 400");

    # Test empty title
    my $mock_request2 = MockRequest->new(
        user => $mock_user,
        _postdata => { title => '' },
    );
    my $result2 = $api->add_current_node($mock_request2);
    is($result2->[0], 400, "Empty title returns HTTP 400");

    # Test undefined title
    my $mock_request3 = MockRequest->new(
        user => $mock_user,
        _postdata => { title => undef },
    );
    my $result3 = $api->add_current_node($mock_request3);
    is($result3->[0], 400, "Undefined title returns HTTP 400");
};

done_testing();
