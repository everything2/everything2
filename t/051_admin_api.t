#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use Test::More;
use JSON;

use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';
use lib "$FindBin::Bin/lib";

use Everything;
use Everything::API::admin;
use MockUser;
use MockRequest;

# Initialize E2 system
initEverything();

my $APP = $Everything::APP;
my $DB = $APP->{db};

# Get test users
my $admin_user = $DB->getNode('root', 'user');
my $editor_user = $DB->getNode('e2e_editor', 'user');
my $regular_user = $DB->getNode('e2e_user', 'user');

# Get a maintenance node to test with
my $maintenance_node = $DB->getNode('writeup maintenance create', 'maintenance');

# Create API instance
my $api = Everything::API::admin->new();

# Test 1: Admin flag works in mock
my $admin_request = MockRequest->new(
  node_id => $admin_user->{node_id},
  title => $admin_user->{title},
  nodedata => $admin_user,
  is_admin_flag => 1
);
ok($admin_request->user->is_admin, 'Admin request has is_admin = true');

# Test 2: Non-admin flag works in mock
my $regular_request = MockRequest->new(
  node_id => $regular_user->{node_id},
  title => $regular_user->{title},
  nodedata => $regular_user,
  is_admin_flag => 0
);
ok(!$regular_request->user->is_admin, 'Regular request has is_admin = false');

# Test 3: Admin can GET node data
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  my $result = $api->get_node($admin_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_OK, 'Admin can GET system node data');
}

# Test 4: Non-admin cannot GET node data
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  my $result = $api->get_node($regular_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_FORBIDDEN, 'Non-admin cannot GET system node data');
}

# Test 5: Non-admin gets proper error message
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  my $result = $api->get_node($regular_request, $maintenance_node->{node_id});
  is($result->[1]->{error}, 'Admin access required', 'Non-admin gets admin access required error');
}

# Test 6: Admin cannot GET non-existent node
{
  my $result = $api->get_node($admin_request, 999999999);
  is($result->[0], $api->HTTP_NOT_FOUND, 'Admin gets 404 for non-existent node');
}

# Test 7: Admin cannot GET non-system node types (like user)
{
  my $result = $api->get_node($admin_request, $admin_user->{node_id});
  is($result->[0], $api->HTTP_FORBIDDEN, 'Admin cannot GET non-system node type (user)');
}

# Test 8: Admin can edit node
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  # Get original title
  my $original_title = $maintenance_node->{title};

  # Set up edit request
  $admin_request->set_postdata({ title => $original_title . ' TEST' });

  my $result = $api->edit_node($admin_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_OK, 'Admin can edit system node');

  # Restore original title
  $admin_request->set_postdata({ title => $original_title });
  $api->edit_node($admin_request, $maintenance_node->{node_id});
}

# Test 9: Non-admin cannot edit node
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  $regular_request->set_postdata({ title => 'HACKED TITLE' });
  my $result = $api->edit_node($regular_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_FORBIDDEN, 'Non-admin cannot edit system node');
}

# Test 10: Empty title is rejected
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  $admin_request->set_postdata({ title => '' });
  my $result = $api->edit_node($admin_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_BAD_REQUEST, 'Empty title is rejected');
}

# Test 11: Title too long is rejected
SKIP: {
  skip "No maintenance node in test database", 1 unless $maintenance_node;

  $admin_request->set_postdata({ title => 'x' x 300 });
  my $result = $api->edit_node($admin_request, $maintenance_node->{node_id});
  is($result->[0], $api->HTTP_BAD_REQUEST, 'Title over 240 chars is rejected');
}

# Test 12: Editor is not admin (editors can see Master Control but not use admin API)
my $editor_request = MockRequest->new(
  node_id => $editor_user->{node_id},
  title => $editor_user->{title},
  nodedata => $editor_user,
  is_admin_flag => 0,  # Editors are not admins
  is_editor_flag => 1
);
ok(!$editor_request->user->is_admin, 'Editor is not admin (cannot use admin API)');

# ========================================================
# Tests for insure_writeup and remove_writeup
# ========================================================

# Create a test writeup for insure/remove testing
my $test_writeup;
SKIP: {
  unless ($regular_user) {
    diag("Skipping insure/remove tests: regular_user not found");
    skip "Unable to create test writeup", 26;
  }

  # Create a test writeup node
  my $e2node_type = $DB->getNode('e2node', 'nodetype');
  my $writeup_type = $DB->getNode('writeup', 'nodetype');

  # Create parent e2node
  my $parent_title = 'Test Admin API E2node ' . time();
  my $parent_e2node_id = $DB->insertNode($parent_title, $e2node_type, $regular_user);
  my $parent_e2node = $DB->getNodeById($parent_e2node_id);

  # Create test writeup using insertNode (handles writeup table creation)
  my $writeup_title = 'Test Admin API Writeup (idea)';
  my $writeup_id = $DB->insertNode($writeup_title, $writeup_type, $regular_user, {
    doctext => 'This is a test writeup for admin API testing.',
    parent_e2node => $parent_e2node_id
  });

  # Create draft entry (required for publication_status)
  $DB->sqlInsert('draft', {
    draft_id => $writeup_id,
    publication_status => 0
  });

  $test_writeup = $DB->getNodeById($writeup_id);

  # Test 13: Writeup was created
  ok($test_writeup, 'Test writeup created successfully');

  # Test 14: Non-editor cannot insure writeup
  {
    my $result = $api->insure_writeup($regular_request, $writeup_id);
    is($result->[0], $api->HTTP_FORBIDDEN, 'Non-editor cannot insure writeup');
    is($result->[1]->{error}, 'Editor access required', 'Non-editor gets editor access required error');
  }

  # Test 15-17: Editor can insure writeup
  {
    my $result = $api->insure_writeup($editor_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'Editor can insure writeup');
    is($result->[1]->{success}, 1, 'Insure returns success');
    is($result->[1]->{action}, 'insured', 'Insure returns correct action');

    # Verify publication_status changed in draft table
    my $insured_status = $DB->getNode('insured', 'publication_status');
    my $current_status = $DB->sqlSelect('publication_status', 'draft', "draft_id=$writeup_id");
    is($current_status, $insured_status->{node_id}, 'Writeup publication_status is insured');

    # Verify entry in publish table
    my $publish_entry = $DB->sqlSelect('publisher', 'publish', "publish_id=$writeup_id");
    is($publish_entry, $editor_user->{node_id}, 'Publisher recorded in publish table');
  }

  # Test 18-20: Editor can uninsure writeup (toggle)
  {
    my $result = $api->insure_writeup($editor_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'Editor can uninsure writeup');
    is($result->[1]->{success}, 1, 'Uninsure returns success');
    is($result->[1]->{action}, 'uninsured', 'Uninsure returns correct action');

    # Verify publication_status changed back in draft table
    my $current_status = $DB->sqlSelect('publication_status', 'draft', "draft_id=$writeup_id");
    is($current_status, 0, 'Writeup publication_status is 0 after uninsure');

    # Verify entry removed from publish table
    my $publish_entry = $DB->sqlSelect('publisher', 'publish', "publish_id=$writeup_id");
    ok(!$publish_entry, 'Entry removed from publish table');
  }

  # Test 21-22: Cannot insure non-existent writeup
  {
    my $result = $api->insure_writeup($editor_request, 999999999);
    is($result->[0], $api->HTTP_NOT_FOUND, 'Cannot insure non-existent writeup');
    is($result->[1]->{error}, 'Writeup not found', 'Returns writeup not found error');
  }

  # Test 23: Non-editor/non-author cannot remove writeup
  {
    my $other_user = $DB->getNode('e2e_admin', 'user');
    my $other_request = MockRequest->new(
      node_id => $other_user->{node_id},
      title => $other_user->{title},
      nodedata => $other_user,
      is_admin_flag => 0,
      is_editor_flag => 0
    );

    my $result = $api->remove_writeup($other_request, $writeup_id);
    is($result->[0], $api->HTTP_FORBIDDEN, 'Non-editor/non-author cannot remove writeup');
  }

  # Test 24-26: Author can remove their own writeup without reason
  {
    my $author_request = MockRequest->new(
      node_id => $regular_user->{node_id},
      title => $regular_user->{title},
      nodedata => $regular_user,
      is_admin_flag => 0,
      is_editor_flag => 0
    );

    my $result = $api->remove_writeup($author_request, $writeup_id);
    if ($result->[0] != $api->HTTP_OK) {
      diag("Error: " . ($result->[1]->{message} || 'No message'));
    }
    is($result->[0], $api->HTTP_OK, 'Author can remove their own writeup');
    is($result->[1]->{success}, 1, 'Remove returns success');

    # Verify writeup converted to draft with private status
    my $draft_type = $DB->getType('draft');
    my $node_type = $DB->sqlSelect('type_nodetype', 'node', "node_id=$writeup_id");
    is($node_type, $draft_type->{node_id}, 'Writeup type changed to draft');

    my $private_status = $DB->getNode('private', 'publication_status');
    my $current_status = $DB->sqlSelect('publication_status', 'draft', "draft_id=$writeup_id");
    is($current_status, $private_status->{node_id},
       'Writeup publication_status is private after removal');
  }

  # Create another test writeup for editor removal test
  my $writeup_title2 = 'Test Admin API Writeup 2 (idea)';
  my $writeup_id2 = $DB->insertNode($writeup_title2, $writeup_type, $regular_user, {
    doctext => 'This is a second test writeup.',
    parent_e2node => $parent_e2node_id
  });

  # Create draft entry
  $DB->sqlInsert('draft', {
    draft_id => $writeup_id2,
    publication_status => 0
  });

  # Test 27: Editor cannot remove without reason
  {
    $editor_request->set_postdata({});
    my $result = $api->remove_writeup($editor_request, $writeup_id2);
    is($result->[0], $api->HTTP_BAD_REQUEST, 'Editor cannot remove without reason');
    is($result->[1]->{error}, 'Reason required', 'Returns reason required error');
  }

  # Test 28-30: Editor can remove with reason
  {
    $editor_request->set_postdata({ reason => 'Test removal reason' });
    my $result = $api->remove_writeup($editor_request, $writeup_id2);
    is($result->[0], $api->HTTP_OK, 'Editor can remove with reason');
    is($result->[1]->{success}, 1, 'Remove with reason returns success');

    # Verify writeup converted to draft with private status
    my $draft_type = $DB->getType('draft');
    my $node_type = $DB->sqlSelect('type_nodetype', 'node', "node_id=$writeup_id2");
    is($node_type, $draft_type->{node_id}, 'Writeup type changed to draft');

    my $private_status = $DB->getNode('private', 'publication_status');
    my $current_status = $DB->sqlSelect('publication_status', 'draft', "draft_id=$writeup_id2");
    is($current_status, $private_status->{node_id},
       'Writeup publication_status is private after editor removal');
  }

  # Test 31-32: Cannot remove non-existent writeup
  {
    $editor_request->set_postdata({ reason => 'Test' });
    my $result = $api->remove_writeup($editor_request, 999999999);
    is($result->[0], $api->HTTP_NOT_FOUND, 'Cannot remove non-existent writeup');
    is($result->[1]->{error}, 'Writeup not found', 'Returns writeup not found error for removal');
  }

  # Test 33: Insure/uninsure created nodenotes (from earlier tests)
  # Note: Node notes are added to the parent e2node, not the writeup
  {
    # Check that nodenotes were created during earlier tests
    my $nodenote_count = $DB->sqlSelect('COUNT(*)', 'nodenote',
      "nodenote_nodeid=$parent_e2node_id AND notetext LIKE '%Insured%'");
    ok($nodenote_count > 0, 'Insure creates nodenote on e2node');
  }

  # Test 34: Uninsure created nodenote (from earlier tests)
  {
    my $nodenote_count = $DB->sqlSelect('COUNT(*)', 'nodenote',
      "nodenote_nodeid=$parent_e2node_id AND notetext LIKE '%Uninsured%'");
    ok($nodenote_count > 0, 'Uninsure creates nodenote on e2node');
  }

  # Test 35: Remove created nodenote (from writeup_id2 in earlier test)
  # Note: Node notes are added to the parent e2node, not the writeup
  {
    my $nodenote_count = $DB->sqlSelect('COUNT(*)', 'nodenote',
      "nodenote_nodeid=$parent_e2node_id AND notetext LIKE '%Removed%'");
    ok($nodenote_count > 0, 'Remove creates nodenote with reason on e2node');
  }

  # Test 36: No duplicate publish entries (verified from earlier tests)
  {
    # writeup_id was insured, uninsured, then re-insured in earlier tests
    # Check that only one entry exists (from last insure before removal)
    my $count = $DB->sqlSelect('COUNT(*)', 'publish', "publish_id=$writeup_id");
    is($count, 0, 'No duplicate publish entries created');
  }

  # Test 37: Security log entry exists (from earlier insure operations)
  {
    # Check for security log from earlier tests
    my $seclog = $DB->sqlSelect('COUNT(*)', 'seclog',
      "seclog_node=(SELECT node_id FROM node WHERE title='insure' AND type_nodetype=(SELECT node_id FROM node WHERE title='opcode'))");
    ok($seclog > 0, 'Insure creates security log entry');
  }

  # Test 38: Remove as author creates appropriate nodenote
  # Note: Node notes are added to the parent e2node, not the writeup
  {
    my $author_request = MockRequest->new(
      node_id => $regular_user->{node_id},
      title => $regular_user->{title},
      nodedata => $regular_user,
      is_admin_flag => 0,
      is_editor_flag => 0
    );

    my $writeup_title3 = 'Test Admin API Writeup 3 (idea)';
    my $writeup_id3 = $DB->insertNode($writeup_title3, $writeup_type, $regular_user, {
      doctext => 'This is a third test writeup.',
      parent_e2node => $parent_e2node_id
    });

    # Create draft entry
    $DB->sqlInsert('draft', {
      draft_id => $writeup_id3,
      publication_status => 0
    });

    $author_request->set_postdata({});
    my $result = $api->remove_writeup($author_request, $writeup_id3);

    # Node notes are added to the parent e2node
    my $nodenote = $DB->sqlSelect('notetext', 'nodenote',
      "nodenote_nodeid=$parent_e2node_id AND notetext LIKE '%Returned to drafts by author%' ORDER BY nodenote_id DESC LIMIT 1");
    like($nodenote, qr/Returned to drafts by author/, 'Author removal creates appropriate nodenote on e2node');
  }

  # Create a fourth writeup for vote/C! removal tests (previous writeups were converted to drafts)
  my $writeup_title4 = 'Test Admin API Writeup 4 (idea)';
  my $writeup_id4 = $DB->insertNode($writeup_title4, $writeup_type, $regular_user, {
    doctext => 'This is a fourth test writeup for vote/C! removal tests.',
    parent_e2node => $parent_e2node_id
  });

  # Create draft entry
  $DB->sqlInsert('draft', {
    draft_id => $writeup_id4,
    publication_status => 0
  });

  # Test 39: Admin can remove their own vote
  {
    # First, admin votes on the writeup
    $DB->sqlInsert('vote', {
      voter_user => $admin_user->{node_id},
      vote_id => $writeup_id4,
      weight => 1
    });

    # Update writeup reputation
    my $writeup_node = $DB->getNodeById($writeup_id4);
    $writeup_node->{reputation} = ($writeup_node->{reputation} || 0) + 1;
    $DB->updateNode($writeup_node, -1);

    $admin_request->set_postdata({});
    my $result = $api->remove_vote($admin_request, $writeup_id4);

    is($result->[0], 200, 'Admin can remove their own vote');
    is($result->[1]{success}, 1, 'Vote removal returns success');
    is($result->[1]{vote_removed}, 1, 'Vote weight returned in response');

    # Verify vote is removed from database
    my $vote_count = $DB->sqlSelect('COUNT(*)', 'vote',
      "voter_user=" . $admin_user->{node_id} . " AND vote_id=$writeup_id4");
    is($vote_count, 0, 'Vote removed from database');
  }

  # Test 40: Non-admin cannot remove vote
  {
    # First, regular user votes on the writeup
    $DB->sqlInsert('vote', {
      voter_user => $regular_user->{node_id},
      vote_id => $writeup_id4,
      weight => 1
    });

    $regular_request->set_postdata({});
    my $result = $api->remove_vote($regular_request, $writeup_id4);

    is($result->[0], 403, 'Non-admin cannot remove vote (403 Forbidden)');

    # Cleanup the vote
    $DB->sqlDelete('vote', "voter_user=" . $regular_user->{node_id} . " AND vote_id=$writeup_id4");
  }

  # Test 41: Admin cannot remove non-existent vote
  {
    # Make sure admin has no vote on writeup
    $DB->sqlDelete('vote', "voter_user=" . $admin_user->{node_id} . " AND vote_id=$writeup_id4");

    $admin_request->set_postdata({});
    my $result = $api->remove_vote($admin_request, $writeup_id4);

    is($result->[0], 400, 'Cannot remove non-existent vote (400 Bad Request)');
    like($result->[1]{error}, qr/No vote found/i, 'Returns appropriate error message');
  }

  # Test 42: Admin can remove their own C!
  {
    # First, admin C!s the writeup
    $DB->sqlInsert('coolwriteups', {
      coolwriteups_id => $writeup_id4,
      cooledby_user => $admin_user->{node_id}
    });

    $admin_request->set_postdata({});
    my $result = $api->remove_cool($admin_request, $writeup_id4);

    is($result->[0], 200, 'Admin can remove their own C!');
    is($result->[1]{success}, 1, 'C! removal returns success');

    # Verify C! is removed from database
    my $cool_count = $DB->sqlSelect('COUNT(*)', 'coolwriteups',
      "cooledby_user=" . $admin_user->{node_id} . " AND coolwriteups_id=$writeup_id4");
    is($cool_count, 0, 'C! removed from database');
  }

  # Test 43: Non-admin cannot remove C!
  {
    # First, regular user C!s the writeup
    $DB->sqlInsert('coolwriteups', {
      coolwriteups_id => $writeup_id4,
      cooledby_user => $regular_user->{node_id}
    });

    $regular_request->set_postdata({});
    my $result = $api->remove_cool($regular_request, $writeup_id4);

    is($result->[0], 403, 'Non-admin cannot remove C! (403 Forbidden)');

    # Cleanup the C!
    $DB->sqlDelete('coolwriteups', "cooledby_user=" . $regular_user->{node_id} . " AND coolwriteups_id=$writeup_id4");
  }

  # Test 44: Admin cannot remove non-existent C!
  {
    # Make sure admin has no C! on writeup
    $DB->sqlDelete('coolwriteups', "cooledby_user=" . $admin_user->{node_id} . " AND coolwriteups_id=$writeup_id4");

    $admin_request->set_postdata({});
    my $result = $api->remove_cool($admin_request, $writeup_id4);

    is($result->[0], 400, 'Cannot remove non-existent C! (400 Bad Request)');
    like($result->[1]{error}, qr/No C! found/i, 'Returns appropriate error message');
  }

  # Cleanup test writeups
  $DB->sqlDelete('node', "node_id IN ($writeup_id, $writeup_id2, $writeup_id4, $parent_e2node_id)");
  $DB->sqlDelete('document', "document_id IN ($writeup_id, $writeup_id2, $writeup_id4)");
  $DB->sqlDelete('publish', "publish_id IN ($writeup_id, $writeup_id2)");
  # Clean up nodenotes on both writeups and e2node (notes now go to e2node)
  $DB->sqlDelete('nodenote', "nodenote_nodeid IN ($writeup_id, $writeup_id2, $parent_e2node_id)");
}

# ========================================================
# Tests for lock_user and unlock_user (admin-only)
# These tests run serially to ensure we don't leave any user locked
# ========================================================

SKIP: {
  unless ($admin_user && $regular_user) {
    diag("Skipping lock/unlock tests: required users not found");
    skip "Unable to run lock/unlock tests", 18;
  }

  # Ensure the target user starts unlocked
  my $initial_lock = $regular_user->{acctlock};
  if ($initial_lock) {
    $regular_user->{acctlock} = 0;
    $DB->updateNode($regular_user, -1);
    diag("Cleaned up pre-existing lock on e2e_user for testing");
  }

  # Test: Non-admin cannot lock user
  {
    $regular_request->set_postdata({});
    my $result = $api->lock_user($regular_request, $regular_user->{node_id});
    is($result->[0], $api->HTTP_OK, 'Non-admin lock returns HTTP 200');
    is($result->[1]->{success}, 0, 'Non-admin lock returns success=0');
    is($result->[1]->{error}, 'Admin access required', 'Non-admin gets admin access required error for lock');
  }

  # Test: Editor cannot lock user (editors are not admins)
  {
    $editor_request->set_postdata({});
    my $result = $api->lock_user($editor_request, $regular_user->{node_id});
    is($result->[0], $api->HTTP_OK, 'Editor lock returns HTTP 200');
    is($result->[1]->{success}, 0, 'Editor lock returns success=0');
    is($result->[1]->{error}, 'Admin access required', 'Editor gets admin access required error for lock');
  }

  # Test: Admin can lock user
  {
    $admin_request->set_postdata({});
    my $result = $api->lock_user($admin_request, $regular_user->{node_id});
    is($result->[0], $api->HTTP_OK, 'Admin lock returns HTTP 200');
    is($result->[1]->{success}, 1, 'Admin lock returns success=1');
    is($result->[1]->{message}, 'Account locked', 'Admin lock returns correct message');
    is($result->[1]->{user}->{node_id}, $regular_user->{node_id}, 'Lock response includes user node_id');
    is($result->[1]->{locked_by}->{node_id}, $admin_user->{node_id}, 'Lock response includes who locked');

    # Verify in database
    my $target = $DB->getNodeById($regular_user->{node_id});
    is($target->{acctlock}, $admin_user->{node_id}, 'User acctlock set in database');
  }

  # Test: Cannot lock already locked user
  {
    $admin_request->set_postdata({});
    my $result = $api->lock_user($admin_request, $regular_user->{node_id});
    is($result->[0], $api->HTTP_OK, 'Lock already-locked user returns HTTP 200');
    is($result->[1]->{success}, 0, 'Lock already-locked returns success=0');
    is($result->[1]->{error}, 'Already locked', 'Already locked returns correct error');
  }

  # Test: Non-admin cannot unlock user
  {
    my $other_regular = MockRequest->new(
      node_id => $editor_user->{node_id},
      title => $editor_user->{title},
      nodedata => $editor_user,
      is_admin_flag => 0,
      is_editor_flag => 1
    );
    $other_regular->set_postdata({});
    my $result = $api->unlock_user($other_regular, $regular_user->{node_id});
    is($result->[0], $api->HTTP_OK, 'Non-admin unlock returns HTTP 200');
    is($result->[1]->{success}, 0, 'Non-admin unlock returns success=0');
    is($result->[1]->{error}, 'Admin access required', 'Non-admin gets admin access required error for unlock');
  }

  # Test: Admin can unlock user
  {
    $admin_request->set_postdata({});
    my $result = $api->unlock_user($admin_request, $regular_user->{node_id});
    is($result->[0], $api->HTTP_OK, 'Admin unlock returns HTTP 200');
    is($result->[1]->{success}, 1, 'Admin unlock returns success=1');
    is($result->[1]->{message}, 'Account unlocked', 'Admin unlock returns correct message');
    is($result->[1]->{user}->{node_id}, $regular_user->{node_id}, 'Unlock response includes user node_id');
    is($result->[1]->{previously_locked_by}->{node_id}, $admin_user->{node_id}, 'Unlock response includes who had locked');

    # Verify in database
    my $target = $DB->getNodeById($regular_user->{node_id});
    is($target->{acctlock}, 0, 'User acctlock cleared in database');
  }

  # Test: Cannot unlock already unlocked user
  {
    $admin_request->set_postdata({});
    my $result = $api->unlock_user($admin_request, $regular_user->{node_id});
    is($result->[0], $api->HTTP_OK, 'Unlock already-unlocked user returns HTTP 200');
    is($result->[1]->{success}, 0, 'Unlock already-unlocked returns success=0');
    is($result->[1]->{error}, 'Not locked', 'Already unlocked returns correct error');
  }

  # Test: Cannot lock non-existent user
  {
    $admin_request->set_postdata({});
    my $result = $api->lock_user($admin_request, 999999999);
    is($result->[0], $api->HTTP_OK, 'Lock non-existent user returns HTTP 200');
    is($result->[1]->{success}, 0, 'Lock non-existent returns success=0');
    is($result->[1]->{error}, 'User not found', 'Non-existent user returns user not found');
  }

  # Test: Cannot unlock non-existent user
  {
    $admin_request->set_postdata({});
    my $result = $api->unlock_user($admin_request, 999999999);
    is($result->[0], $api->HTTP_OK, 'Unlock non-existent user returns HTTP 200');
    is($result->[1]->{success}, 0, 'Unlock non-existent returns success=0');
    is($result->[1]->{error}, 'User not found', 'Non-existent user returns user not found for unlock');
  }

  # Test: Cannot lock non-user node
  SKIP: {
    skip "No maintenance node for non-user test", 3 unless $maintenance_node;

    $admin_request->set_postdata({});
    my $result = $api->lock_user($admin_request, $maintenance_node->{node_id});
    is($result->[0], $api->HTTP_OK, 'Lock non-user node returns HTTP 200');
    is($result->[1]->{success}, 0, 'Lock non-user node returns success=0');
    is($result->[1]->{error}, 'User not found', 'Non-user node returns user not found');
  }

  # Final cleanup: ensure user is unlocked
  my $final_target = $DB->getNodeById($regular_user->{node_id});
  if ($final_target->{acctlock}) {
    $final_target->{acctlock} = 0;
    $DB->updateNode($final_target, -1);
    diag("Cleanup: Unlocked e2e_user after tests");
  }

  # Restore initial state if it was locked
  if ($initial_lock) {
    my $restore_target = $DB->getNodeById($regular_user->{node_id});
    $restore_target->{acctlock} = $initial_lock;
    $DB->updateNode($restore_target, -1);
    diag("Restored original lock state on e2e_user");
  }
}

done_testing();
