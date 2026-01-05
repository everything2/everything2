#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use JSON;

use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';

use Everything;
use Everything::API::cool;

# Initialize E2 system
initEverything();

my $APP = $Everything::APP;
my $DB = $APP->{db};

# Get test users
my $editor_user = $DB->getNode('e2e_editor', 'user');
my $regular_user = $DB->getNode('e2e_user', 'user');
my $admin_user = $DB->getNode('root', 'user');

# Create mock request and user objects
{
  package MockUser;
  sub new {
    my ($class, %args) = @_;
    return bless {
      node_id => $args{node_id} // 0,
      title => $args{title} // 'test',
      is_admin_flag => $args{is_admin_flag} // 0,
      is_editor_flag => $args{is_editor_flag} // 0,
      is_guest_flag => $args{is_guest_flag} // 0,
      _nodedata => $args{nodedata} // {},
      _coolsleft => $args{coolsleft} // 10,
      _votesleft => $args{votesleft} // 10,
    }, $class;
  }
  sub is_admin { return shift->{is_admin_flag}; }
  sub is_editor { return shift->{is_editor_flag}; }
  sub is_guest { return shift->{is_guest_flag}; }
  sub node_id { shift->{node_id} }
  sub title { shift->{title} }
  sub NODEDATA { shift->{_nodedata} }
  sub coolsleft { return shift->{_coolsleft}; }
  sub votesleft { return shift->{_votesleft}; }
}

{
  package MockRequest;
  sub new {
    my ($class, %args) = @_;
    return bless {
      user => MockUser->new(%args),
      postdata => $args{postdata},
    }, $class;
  }
  sub user { shift->{user} }
  sub JSON_POSTDATA { shift->{postdata} }
  sub set_postdata {
    my ($self, $data) = @_;
    $self->{postdata} = $data;
  }
  sub is_guest { return shift->{user}->is_guest }
}

# Create API instance
my $api = Everything::API::cool->new();

# Create test requests
my $editor_request = MockRequest->new(
  node_id => $editor_user->{node_id},
  title => $editor_user->{title},
  nodedata => $editor_user,
  is_admin_flag => 0,
  is_editor_flag => 1,
  is_guest_flag => 0
);

my $regular_request = MockRequest->new(
  node_id => $regular_user->{node_id},
  title => $regular_user->{title},
  nodedata => $regular_user,
  is_admin_flag => 0,
  is_editor_flag => 0,
  is_guest_flag => 0
);

my $guest_request = MockRequest->new(
  node_id => 0,
  title => 'Guest User',
  nodedata => {},
  is_admin_flag => 0,
  is_editor_flag => 0,
  is_guest_flag => 1
);

# Test 1: Editor request has is_editor = true
ok($editor_request->user->is_editor, 'Editor request has is_editor = true');

# Test 2: Regular request has is_editor = false
ok(!$regular_request->user->is_editor, 'Regular request has is_editor = false');

# ========================================================
# Tests for toggle_edcool
# ========================================================

# Create a test writeup for editor cool testing
my $test_writeup;
SKIP: {
  unless ($regular_user) {
    diag("Skipping edcool tests: regular_user not found");
    skip "Unable to create test writeup", 15;
  }

  # Create a test writeup node
  my $e2node_type = $DB->getNode('e2node', 'nodetype');
  my $writeup_type = $DB->getNode('writeup', 'nodetype');

  # Create parent e2node
  my $parent_title = 'Test Cool API E2node ' . time();
  my $parent_e2node_id = $DB->insertNode($parent_title, $e2node_type, $regular_user);

  # Create test writeup
  my $writeup_title = 'Test Cool API Writeup (idea)';
  my $writeup_id = $DB->insertNode($writeup_title, $writeup_type, $regular_user, {
    doctext => 'This is a test writeup for cool API testing.',
    parent_e2node => $parent_e2node_id
  });

  $test_writeup = $DB->getNodeById($writeup_id);

  # Test 3: Writeup was created
  ok($test_writeup, 'Test writeup created successfully');

  # Get linktype nodes
  my $coollink_type = $DB->getNode('coollink', 'linktype');
  my $bookmark_type = $DB->getNode('bookmark', 'linktype');

  # Test 4: Non-editor cannot add editor cool
  {
    my $result = $api->toggle_edcool($regular_request, $parent_e2node_id);
    is($result->[0], $api->HTTP_OK, 'Non-editor cannot add editor cool');
    is($result->[1]->{success}, 0, 'Non-editor cool returns success: 0');
    like($result->[1]->{error}, qr/Editor access required/i, 'Returns editor access required error');
  }

  # Test 5-7: Editor can add editor cool
  {
    my $result = $api->toggle_edcool($editor_request, $parent_e2node_id);
    is($result->[0], $api->HTTP_OK, 'Editor can add editor cool');
    is($result->[1]->{success}, 1, 'Editor cool add returns success');
    is($result->[1]->{edcooled}, 1, 'Editor cool status is 1');

    # Verify link was created from e2node to coolnodes
    my $link = $DB->sqlSelectHashref('*', 'links',
      "from_node=$parent_e2node_id AND linktype=" . $coollink_type->{node_id});
    ok($link, 'Editor cool link created in database');
  }

  # Test 8-10: Editor can remove editor cool (toggle)
  {
    my $result = $api->toggle_edcool($editor_request, $parent_e2node_id);
    is($result->[0], $api->HTTP_OK, 'Editor can remove editor cool');
    is($result->[1]->{success}, 1, 'Editor cool remove returns success');
    is($result->[1]->{edcooled}, 0, 'Editor cool status is 0');

    # Verify link was removed
    my $link = $DB->sqlSelectHashref('*', 'links',
      "from_node=$parent_e2node_id AND linktype=" . $coollink_type->{node_id});
    ok(!$link, 'Editor cool link removed from database');
  }

  # Test 11-12: Cannot editor cool non-existent node
  {
    my $result = $api->toggle_edcool($editor_request, 999999999);
    is($result->[0], $api->HTTP_OK, 'Cannot editor cool non-existent node');
    is($result->[1]->{success}, 0, 'Non-existent node returns success: 0');
    like($result->[1]->{error}, qr/Node not found/i, 'Returns node not found error');
  }

  # ========================================================
  # Tests for toggle_bookmark
  # ========================================================

  # The writeup nodetype has disable_bookmark set globally, so we need to clear it for these tests
  my $writeup_type_node = $DB->getNode('writeup', 'nodetype');
  my $original_bookmark_setting = $DB->getNodeParam($writeup_type_node, 'disable_bookmark');
  $DB->deleteNodeParam($writeup_type_node, 'disable_bookmark');

  # Test 13-14: Guest cannot bookmark
  {
    my $result = $api->toggle_bookmark($guest_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'Guest cannot bookmark writeup');
    is($result->[1]->{success}, 0, 'Guest bookmark returns success: 0');
    like($result->[1]->{error}, qr/Login required/i, 'Returns login required error');
  }

  # Test 15-17: Regular user can bookmark writeup
  {
    my $result = $api->toggle_bookmark($regular_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'Regular user can bookmark writeup');
    is($result->[1]->{success}, 1, 'Bookmark add returns success');
    is($result->[1]->{bookmarked}, 1, 'Bookmark status is 1');

    # Verify link was created from user to writeup
    my $link = $DB->sqlSelectHashref('*', 'links',
      "from_node=" . $regular_user->{node_id} .
      " AND to_node=$writeup_id AND linktype=" . $bookmark_type->{node_id});
    ok($link, 'Bookmark link created in database');
  }

  # Test 18-20: Regular user can remove bookmark (toggle)
  {
    my $result = $api->toggle_bookmark($regular_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'Regular user can remove bookmark');
    is($result->[1]->{success}, 1, 'Bookmark remove returns success');
    is($result->[1]->{bookmarked}, 0, 'Bookmark status is 0');

    # Verify link was removed
    my $link = $DB->sqlSelectHashref('*', 'links',
      "from_node=" . $regular_user->{node_id} .
      " AND to_node=$writeup_id AND linktype=" . $bookmark_type->{node_id});
    ok(!$link, 'Bookmark link removed from database');
  }

  # Test 21-22: Cannot bookmark non-existent node
  {
    my $result = $api->toggle_bookmark($regular_request, 999999999);
    is($result->[0], $api->HTTP_OK, 'Cannot bookmark non-existent node');
    is($result->[1]->{success}, 0, 'Non-existent node bookmark returns success: 0');
    like($result->[1]->{error}, qr/Node not found/i, 'Returns node not found error for bookmark');
  }

  # Test 23: Editor can also bookmark writeups
  {
    my $result = $api->toggle_bookmark($editor_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'Editor can bookmark writeup');
    is($result->[1]->{bookmarked}, 1, 'Editor bookmark status is 1');

    # Cleanup
    $DB->sqlDelete('links',
      "from_node=" . $editor_user->{node_id} .
      " AND to_node=$writeup_id AND linktype=" . $bookmark_type->{node_id});
  }

  # Test 24-25: Cannot bookmark when node has disable_bookmark parameter
  {
    # Set disable_bookmark parameter on the writeup
    $DB->setNodeParam($DB->getNode($writeup_id), 'disable_bookmark', 1);

    my $result = $api->toggle_bookmark($regular_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'Bookmark API returns 200 when disable_bookmark is set');
    is($result->[1]->{success}, 0, 'Bookmark with disable_bookmark returns success: 0');
    like($result->[1]->{error}, qr/Cannot bookmark/i, 'Bookmark returns error when disable_bookmark is set');

    # Clear the parameter
    $DB->deleteNodeParam($DB->getNode($writeup_id), 'disable_bookmark');
  }

  # Test 26-27: Cannot editor cool when node has disable_cool parameter
  {
    # Set disable_cool parameter on the parent e2node
    $DB->setNodeParam($DB->getNode($parent_e2node_id), 'disable_cool', 1);

    my $result = $api->toggle_edcool($editor_request, $parent_e2node_id);
    is($result->[0], $api->HTTP_OK, 'Editor cool API returns 200 when disable_cool is set');
    is($result->[1]->{success}, 0, 'Editor cool with disable_cool returns success: 0');
    like($result->[1]->{error}, qr/Cannot cool/i, 'Editor cool returns error when disable_cool is set');

    # Clear the parameter
    $DB->deleteNodeParam($DB->getNode($parent_e2node_id), 'disable_cool');
  }

  # Test 28-31: Cool Man Eddie message sent when awarding C!
  {
    # Create a second writeup for C! testing (we need a fresh writeup to avoid "already cooled" error)
    my $cool_writeup_title = 'Test Cool Message Writeup (idea)';
    my $cool_writeup_id = $DB->insertNode($cool_writeup_title, $writeup_type, $regular_user, {
      doctext => 'This is a test writeup for C! Eddie message testing.',
      parent_e2node => $parent_e2node_id
    });

    # Create a request for a user with C!s available
    my $cooler_request = MockRequest->new(
      node_id => $editor_user->{node_id},
      title => $editor_user->{title},
      nodedata => $editor_user,
      is_admin_flag => 0,
      is_editor_flag => 1,
      is_guest_flag => 0
    );

    # Award the C!
    my $result = $api->award_cool($cooler_request, $cool_writeup_id);
    is($result->[0], $api->HTTP_OK, 'C! award succeeds');

    # Check if Cool Man Eddie sent a message to the writeup author
    my $eddie = $DB->getNode('Cool Man Eddie', 'user');
    ok($eddie, 'Cool Man Eddie user exists');

    if ($eddie) {
      my $message = $DB->sqlSelectHashref('*', 'message',
        "author_user=" . $eddie->{node_id} . " AND for_user=" . $regular_user->{node_id} .
        " ORDER BY message_id DESC LIMIT 1");
      ok($message, 'Eddie message was created for C!');
      like($message->{msgtext}, qr/cooled/i, 'Message mentions cooling') if $message;

      # Cleanup Eddie message
      $DB->sqlDelete('message', "message_id=" . $message->{message_id}) if $message;
    }

    # Cleanup cool writeup
    $DB->sqlDelete('node', "node_id=$cool_writeup_id");
    $DB->sqlDelete('document', "document_id=$cool_writeup_id");
    $DB->sqlDelete('coolwriteups', "coolwriteups_id=$cool_writeup_id");
  }

  # Test 32-35: Cool Man Eddie message sent when bookmarking
  {
    # First, let's bookmark a writeup to trigger the Eddie message
    my $result = $api->toggle_bookmark($regular_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'Bookmark succeeds');

    # Check if Cool Man Eddie sent a message
    my $eddie = $DB->getNode('Cool Man Eddie', 'user');
    ok($eddie, 'Cool Man Eddie user exists');

    if ($eddie) {
      my $message = $DB->sqlSelectHashref('*', 'message',
        "author_user=" . $eddie->{node_id} . " AND for_user=" . $regular_user->{node_id} .
        " ORDER BY message_id DESC LIMIT 1");
      ok($message, 'Eddie message was created for bookmark');
      like($message->{msgtext}, qr/bookmarked/i, 'Message mentions bookmarking') if $message;

      # Cleanup Eddie message
      $DB->sqlDelete('message', "message_id=" . $message->{message_id}) if $message;
    }

    # Unbookmark for cleanup
    $DB->sqlDelete('links',
      "from_node=" . $regular_user->{node_id} .
      " AND to_node=$writeup_id AND linktype=" . $bookmark_type->{node_id});
  }

  # Test 36-37: User with no C!s remaining gets proper error
  {
    # Create a user with 0 cools
    my $no_cools_request = MockRequest->new(
      node_id => $editor_user->{node_id},
      title => $editor_user->{title},
      nodedata => $editor_user,
      is_admin_flag => 0,
      is_editor_flag => 1,
      is_guest_flag => 0,
      coolsleft => 0
    );

    my $result = $api->award_cool($no_cools_request, $writeup_id);
    is($result->[0], $api->HTTP_OK, 'No cools API returns HTTP 200');
    is($result->[1]->{success}, 0, 'No cools returns success: 0');
    like($result->[1]->{error}, qr/no C!s remaining/i, 'No cools error message is correct');
  }

  # Test 38-41: C!s are decremented after awarding one (integration test with real DB)
  {
    # Create a fresh writeup for this test
    my $decrement_test_title = 'Test Cool Decrement Writeup (idea)';
    my $decrement_writeup_id = $DB->insertNode($decrement_test_title, $writeup_type, $regular_user, {
      doctext => 'This is a test writeup for C! decrement testing.',
      parent_e2node => $parent_e2node_id
    });

    # Set up the editor user with a known number of C!s
    my $editor_vars = $APP->getVars($editor_user);
    my $original_cools = $editor_vars->{cools} || 0;
    $editor_vars->{cools} = 5;  # Set to known value
    Everything::setVars($editor_user, $editor_vars);

    # Create a real request using the actual editor user data
    # We need to create a proper MockUser that returns the real NODEDATA
    my $real_editor_request = MockRequest->new(
      node_id => $editor_user->{node_id},
      title => $editor_user->{title},
      nodedata => $editor_user,
      is_admin_flag => 0,
      is_editor_flag => 1,
      is_guest_flag => 0,
      coolsleft => 5
    );

    # Award the C!
    my $result = $api->award_cool($real_editor_request, $decrement_writeup_id);
    is($result->[0], $api->HTTP_OK, 'C! decrement test: API returns HTTP 200');
    is($result->[1]->{success}, 1, 'C! decrement test: C! awarded successfully');

    # Check the returned cools_remaining
    is($result->[1]->{cools_remaining}, 4, 'C! decrement test: cools_remaining is decremented in response');

    # Verify the actual database was updated
    my $updated_vars = $APP->getVars($editor_user);
    is($updated_vars->{cools}, 4, 'C! decrement test: cools in database was decremented from 5 to 4');

    # Cleanup
    $editor_vars->{cools} = $original_cools;  # Restore original cools
    Everything::setVars($editor_user, $editor_vars);
    $DB->sqlDelete('coolwriteups', "coolwriteups_id=$decrement_writeup_id");
    $DB->sqlDelete('node', "node_id=$decrement_writeup_id");
    $DB->sqlDelete('document', "document_id=$decrement_writeup_id");
  }

  # Restore original bookmark setting on writeup nodetype
  if ($original_bookmark_setting) {
    $DB->setNodeParam($writeup_type_node, 'disable_bookmark', $original_bookmark_setting);
  }

  # Cleanup test writeup and e2node
  $DB->sqlDelete('node', "node_id IN ($writeup_id, $parent_e2node_id)");
  $DB->sqlDelete('document', "document_id=$writeup_id");
  $DB->sqlDelete('links', "from_node=$parent_e2node_id OR to_node=$writeup_id");
}

done_testing();
