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
use Everything::API::debatecomments;
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
# Test Debatecomments API functionality
#
# These tests verify:
# 1. POST /api/debatecomments/:id/action/reply - Reply to both debatecomment and debate nodes
# 2. PUT /api/debatecomments/:id/action/save - Edit a debatecomment or debate
# 3. DELETE /api/debatecomments/:id/action/delete - Delete a debatecomment (admin only)
# 4. Proper error handling for all endpoints
# 5. Authorization checks (usergroup membership)
# 6. Support for both 'debate' and 'debatecomment' nodetypes
#############################################################################

# Get an admin user for API operations
my $admin_user = $DB->getNode("root", "user");
ok($admin_user, "Got admin user for tests");
diag("Admin user ID: " . ($admin_user ? $admin_user->{node_id} : "NONE")) if $ENV{TEST_VERBOSE};

# Get a regular editor user (for permission tests)
my $editor_user = $DB->sqlSelectHashref("u.*, n.*", "user u JOIN node n ON u.user_id=n.node_id", "n.title != 'root' LIMIT 1");

#############################################################################
# Helper Functions
#############################################################################

sub create_mock_request {
    my ($user, $json_data, $is_guest) = @_;
    $is_guest //= 0;

    my $request = bless {
        user => bless({
            NODEDATA => $user,
            node_id => $user->{node_id},
        }, 'Everything::Node'),
        json_postdata => $json_data,
        is_guest => $is_guest,
    }, 'MockRequest';

    # Add methods to MockRequest
    no strict 'refs';
    *MockRequest::user = sub {
        my $self = shift;
        return $self->{user};
    };
    *MockRequest::is_guest = sub {
        my $self = shift;
        return $self->{is_guest};
    };
    *MockRequest::JSON_POSTDATA = sub {
        my $self = shift;
        return $self->{json_postdata};
    };

    # Add methods to the user object
    *Everything::Node::NODEDATA = sub {
        my $self = shift;
        return $self->{NODEDATA};
    };
    *Everything::Node::node_id = sub {
        my $self = shift;
        return $self->{node_id};
    };
    *Everything::Node::is_guest = sub {
        my $self = shift;
        return $self->{NODEDATA}{title} eq 'Guest User' ? 1 : 0;
    };
    *Everything::Node::is_admin = sub {
        my $self = shift;
        return $APP->isAdmin($self->{NODEDATA});
    };
    *Everything::Node::title = sub {
        my $self = shift;
        return $self->{NODEDATA}{title};
    };

    return $request;
}

sub create_test_debatecomment {
    my ($title, $restricted_group_id, $parent_id, $root_id) = @_;

    my $type = $DB->getNode('debatecomment', 'nodetype');
    return unless $type;

    $restricted_group_id //= 923653;  # Content Editors
    $parent_id //= 0;
    $root_id //= 0;

    my $node_id = $DB->insertNode($title, $type, $admin_user, {
        doctext => "Test debatecomment content",
        restricted => $restricted_group_id,
        parent_debatecomment => $parent_id,
        root_debatecomment => $root_id,
    });
    return unless $node_id;

    # If this is a root node, update root_debatecomment to self
    if ($root_id == 0) {
        $DB->sqlUpdate("debatecomment", {root_debatecomment => $node_id}, "debatecomment_id=$node_id");
    }

    return $DB->getNodeById($node_id);
}

sub create_test_debate {
    my ($title, $restricted_group_id) = @_;

    my $type = $DB->getNode('debate', 'nodetype');
    return unless $type;

    $restricted_group_id //= 114;  # gods

    my $node_id = $DB->insertNode($title, $type, $admin_user, {
        doctext => "Test debate content",
        restricted => $restricted_group_id,
        parent_debatecomment => 0,
        root_debatecomment => 0,
    });
    return unless $node_id;

    # Update root_debatecomment to self (debate is its own root)
    $DB->sqlUpdate("debatecomment", {root_debatecomment => $node_id}, "debatecomment_id=$node_id");

    return $DB->getNodeById($node_id);
}

sub cleanup_debatecomment {
    my ($node_id) = @_;
    return unless $node_id;

    # Delete from nodegroup
    $DB->sqlDelete("nodegroup", "nodegroup_id=$node_id OR node_id=$node_id");
    # Delete from debatecomment table
    $DB->sqlDelete("debatecomment", "debatecomment_id=$node_id");
    # Delete from node table
    $DB->sqlDelete("node", "node_id=$node_id");
    # Clean tomb if exists
    $DB->sqlDelete("tomb", "node_id=$node_id");
}

#############################################################################
# Test: Reply to debatecomment node
#############################################################################

subtest 'Reply to debatecomment node' => sub {
    plan tests => 5;

    # Create a root debatecomment
    my $root = create_test_debatecomment("Test Root Comment " . time(), 923653);
    ok($root, "Created root debatecomment");
    SKIP: {
        skip "Could not create root debatecomment", 4 unless $root;

        my $api = Everything::API::debatecomments->new(APP => $APP, DB => $DB, CONF => $Everything::CONF);
        my $request = create_mock_request($admin_user, {
            title => "Test Reply " . time(),
            doctext => "This is a test reply to a debatecomment",
        });

        my $result = $api->reply($request, $root->{node_id});
        ok($result, "Got reply result");
        is($result->[0], 200, "HTTP 200 status");
        is($result->[1]{success}, 1, "Reply succeeded");
        ok($result->[1]{node_id}, "Got new node_id");

        # Cleanup
        cleanup_debatecomment($result->[1]{node_id}) if $result->[1]{node_id};
        cleanup_debatecomment($root->{node_id});
    }
};

#############################################################################
# Test: Reply to debate node (extends debatecomment)
#############################################################################

subtest 'Reply to debate node' => sub {
    plan tests => 5;

    # Create a debate (which extends debatecomment)
    my $debate = create_test_debate("Test Debate " . time(), 114);
    ok($debate, "Created debate node");
    SKIP: {
        skip "Could not create debate", 4 unless $debate;

        my $api = Everything::API::debatecomments->new(APP => $APP, DB => $DB, CONF => $Everything::CONF);
        my $request = create_mock_request($admin_user, {
            title => "Test Reply to Debate " . time(),
            doctext => "This is a test reply to a debate node",
        });

        my $result = $api->reply($request, $debate->{node_id});
        ok($result, "Got reply result");
        is($result->[0], 200, "HTTP 200 status");
        is($result->[1]{success}, 1, "Reply to debate succeeded");
        ok($result->[1]{node_id}, "Got new node_id");

        # Cleanup
        cleanup_debatecomment($result->[1]{node_id}) if $result->[1]{node_id};
        cleanup_debatecomment($debate->{node_id});
    }
};

#############################################################################
# Test: Reply fails for invalid parent type
#############################################################################

subtest 'Reply fails for non-debate/debatecomment node' => sub {
    plan tests => 3;

    # Get a document node (not a debatecomment or debate)
    my $doc = $DB->getNode('Virgil', 'user');
    ok($doc, "Got non-debatecomment node");
    SKIP: {
        skip "Could not get test node", 2 unless $doc;

        my $api = Everything::API::debatecomments->new(APP => $APP, DB => $DB, CONF => $Everything::CONF);
        my $request = create_mock_request($admin_user, {
            title => "Test Invalid Reply " . time(),
            doctext => "This should fail",
        });

        my $result = $api->reply($request, $doc->{node_id});
        is($result->[0], 200, "HTTP 200 status (API returns 200 with error)");
        is($result->[1]{success}, 0, "Reply correctly failed");
    }
};

#############################################################################
# Test: Edit debatecomment
#############################################################################

subtest 'Edit debatecomment' => sub {
    plan tests => 5;

    my $comment = create_test_debatecomment("Test Edit Comment " . time(), 923653);
    ok($comment, "Created test debatecomment");
    SKIP: {
        skip "Could not create debatecomment", 4 unless $comment;

        my $api = Everything::API::debatecomments->new(APP => $APP, DB => $DB, CONF => $Everything::CONF);
        my $new_doctext = "Updated content " . time();
        my $request = create_mock_request($admin_user, {
            doctext => $new_doctext,
        });

        my $result = $api->save($request, $comment->{node_id});
        ok($result, "Got save result");
        is($result->[0], 200, "HTTP 200 status");
        is($result->[1]{success}, 1, "Save succeeded");

        # Verify the update
        my $updated = $DB->getNodeById($comment->{node_id});
        is($updated->{doctext}, $new_doctext, "Doctext was updated");

        cleanup_debatecomment($comment->{node_id});
    }
};

#############################################################################
# Test: Edit debate node
#############################################################################

subtest 'Edit debate node' => sub {
    plan tests => 5;

    my $debate = create_test_debate("Test Edit Debate " . time(), 114);
    ok($debate, "Created test debate");
    SKIP: {
        skip "Could not create debate", 4 unless $debate;

        my $api = Everything::API::debatecomments->new(APP => $APP, DB => $DB, CONF => $Everything::CONF);
        my $new_doctext = "Updated debate content " . time();
        my $request = create_mock_request($admin_user, {
            doctext => $new_doctext,
        });

        my $result = $api->save($request, $debate->{node_id});
        ok($result, "Got save result");
        is($result->[0], 200, "HTTP 200 status");
        is($result->[1]{success}, 1, "Save debate succeeded");

        # Verify the update
        my $updated = $DB->getNodeById($debate->{node_id});
        is($updated->{doctext}, $new_doctext, "Debate doctext was updated");

        cleanup_debatecomment($debate->{node_id});
    }
};

#############################################################################
# Test: Guest cannot reply
#############################################################################

subtest 'Guest cannot reply' => sub {
    plan tests => 3;

    my $comment = create_test_debatecomment("Test Guest Reply " . time(), 923653);
    ok($comment, "Created test debatecomment");
    SKIP: {
        skip "Could not create debatecomment", 2 unless $comment;

        my $guest = $DB->getNode('Guest User', 'user');
        my $api = Everything::API::debatecomments->new(APP => $APP, DB => $DB, CONF => $Everything::CONF);
        my $request = create_mock_request($guest, {
            title => "Guest Reply " . time(),
            doctext => "This should fail",
        }, 1);  # is_guest = 1

        my $result = $api->reply($request, $comment->{node_id});
        is($result->[0], 401, "HTTP 401 Unauthorized for guest");
        # The response body for 401 may not include success field
        ok(!$result->[1]{success} || $result->[1]{success} == 0, "Reply correctly failed for guest");

        cleanup_debatecomment($comment->{node_id});
    }
};

#############################################################################
# Test: Delete debatecomment (admin only)
#############################################################################

subtest 'Delete debatecomment' => sub {
    plan tests => 4;

    my $comment = create_test_debatecomment("Test Delete Comment " . time(), 923653);
    ok($comment, "Created test debatecomment");
    SKIP: {
        skip "Could not create debatecomment", 3 unless $comment;

        my $api = Everything::API::debatecomments->new(APP => $APP, DB => $DB, CONF => $Everything::CONF);
        my $request = create_mock_request($admin_user, {});

        my $result = $api->delete_comment($request, $comment->{node_id});
        ok($result, "Got delete result");
        is($result->[0], 200, "HTTP 200 status");
        is($result->[1]{success}, 1, "Delete succeeded");

        # No cleanup needed - node was deleted
    }
};

#############################################################################
# Test: Delete debate node (admin only)
#############################################################################

subtest 'Delete debate node' => sub {
    plan tests => 4;

    my $debate = create_test_debate("Test Delete Debate " . time(), 114);
    ok($debate, "Created test debate");
    SKIP: {
        skip "Could not create debate", 3 unless $debate;

        my $api = Everything::API::debatecomments->new(APP => $APP, DB => $DB, CONF => $Everything::CONF);
        my $request = create_mock_request($admin_user, {});

        my $result = $api->delete_comment($request, $debate->{node_id});
        ok($result, "Got delete result");
        is($result->[0], 200, "HTTP 200 status");
        is($result->[1]{success}, 1, "Delete debate succeeded");

        # No cleanup needed - node was deleted
    }
};

done_testing();
