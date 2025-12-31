#!/usr/bin/perl -w

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../ecore";
use lib "$FindBin::Bin/lib";
use lib "/var/libraries/lib/perl5";

use Test::More;
use JSON;
use Everything;
use Everything::Application;
use Everything::API::category;
use MockRequest;

# Initialize Everything
initEverything('development-docker');

ok($DB, "Database connection established");
ok($APP, "Application object created");

#############################################################################
# Test Category API
#
# This test verifies the category API endpoints:
# - list: Fetch categories for dropdown (lazy-load)
# - add_member: Add a node to a category
# - remove_member: Remove a node from a category
# - reorder_members: Reorder nodes within a category
# - update: Update category description
# - update_meta: Update category title/owner (editors only)
# - lookup_owner: Lookup user/usergroup for owner field (editors only)
#############################################################################

# Get test users
my $admin_user = $DB->getNode("root", "user");
my $editor_user = $DB->getNode("e2e_editor", "user") || $DB->getNode("genericdev", "user");
my $normal_user = $DB->getNode("e2e_user", "user") || $DB->getNode("normaluser1", "user");
my $guest_user_id = $Everything::CONF->guest_user;

ok($admin_user, "Got admin user");
ok($normal_user, "Got normal user");

# Create API instance
my $category_api = Everything::API::category->new();
ok($category_api, "Created category API instance");

# Get the category nodetype
my $category_type = $DB->getNode('category', 'nodetype');
ok($category_type, "Got category nodetype");

# Get the category linktype
my $category_linktype = $DB->getNode('category', 'linktype');
ok($category_linktype, "Got category linktype");

#############################################################################
# Helper Functions
#############################################################################

my @created_categories = ();
my @created_e2nodes = ();

sub create_test_category {
  my ($title, $author_id) = @_;
  $author_id //= $normal_user->{node_id};

  # Insert node
  $DB->sqlInsert('node', {
    title => $title,
    type_nodetype => $category_type->{node_id},
    author_user => $author_id,
    createtime => 'now()'
  });

  my $node_id = $DB->{dbh}->last_insert_id(undef, undef, 'node', 'node_id');

  # Insert document for category
  $DB->sqlInsert('document', {
    document_id => $node_id,
    doctext => 'Test category description'
  });

  push @created_categories, $node_id;
  return $node_id;
}

sub create_test_e2node {
  my ($title, $author_id) = @_;
  $author_id //= $normal_user->{node_id};

  my $e2node_type = $DB->getNode('e2node', 'nodetype');

  # Insert node
  $DB->sqlInsert('node', {
    title => $title,
    type_nodetype => $e2node_type->{node_id},
    author_user => $author_id,
    createtime => 'now()'
  });

  my $node_id = $DB->{dbh}->last_insert_id(undef, undef, 'node', 'node_id');

  push @created_e2nodes, $node_id;
  return $node_id;
}

sub cleanup_test_data {
  # Remove links first
  foreach my $cat_id (@created_categories) {
    $DB->sqlDelete('links', "from_node=$cat_id AND linktype=" . $category_linktype->{node_id});
    $DB->sqlDelete('document', "document_id=$cat_id");
    $DB->sqlDelete('node', "node_id=$cat_id");
  }

  foreach my $node_id (@created_e2nodes) {
    $DB->sqlDelete('node', "node_id=$node_id");
  }

  @created_categories = ();
  @created_e2nodes = ();
}

END {
  cleanup_test_data();
}

#############################################################################
# Test list_categories endpoint
#############################################################################

subtest 'list_categories - guest denied' => sub {
  my $req = MockRequest->new(
    node_id => $guest_user_id,
    is_guest_flag => 1
  );
  my $result = $category_api->list_categories($req);

  ok($result, "Got response");
  is($result->[0], 200, "HTTP 200 OK");
  is($result->[1]->{success}, 0, "Request denied for guest");
  like($result->[1]->{error}, qr/logged in/i, "Appropriate error message");
};

subtest 'list_categories - logged in user' => sub {
  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title}
  );
  my $result = $category_api->list_categories($req);

  ok($result, "Got response");
  is($result->[0], 200, "HTTP 200 OK");
  is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
  ok(exists $result->[1]->{your_categories}, "Has your_categories array");
  ok(exists $result->[1]->{public_categories}, "Has public_categories array");
  ok(exists $result->[1]->{other_categories}, "Has other_categories array");
  ok(ref($result->[1]->{your_categories}) eq 'ARRAY', "your_categories is an array");
  ok(ref($result->[1]->{public_categories}) eq 'ARRAY', "public_categories is an array");
  ok(ref($result->[1]->{other_categories}) eq 'ARRAY', "other_categories is an array");
  is($result->[1]->{is_editor}, 0, "Normal user is not an editor");
  # Normal users should have empty other_categories
  is(scalar @{$result->[1]->{other_categories}}, 0, "Normal users don't see other users' categories");
};

SKIP: {
  skip "No editor user available", 1 unless $editor_user;

  subtest 'list_categories - editor sees all categories' => sub {
    # Create a category owned by a different user
    my $other_cat_id = create_test_category("Test Other User Category " . time(), $admin_user->{node_id});

    my $req = MockRequest->new(
      node_id => $editor_user->{node_id},
      title => $editor_user->{title},
      is_editor_flag => 1
    );
    my $result = $category_api->list_categories($req);

    ok($result, "Got response");
    is($result->[0], 200, "HTTP 200 OK");
    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    is($result->[1]->{is_editor}, 1, "Editor flag is set");

    # Check that the other user's category appears in other_categories
    my $found = 0;
    foreach my $cat (@{$result->[1]->{other_categories}}) {
      if ($cat->{node_id} == $other_cat_id) {
        $found = 1;
        last;
      }
    }
    ok($found, "Editor can see other users' categories");
  };
}

subtest 'list_categories - excludes already-added categories' => sub {
  # Create a test category and e2node
  my $cat_id = create_test_category("Test Category Exclude " . time());
  my $e2node_id = create_test_e2node("Test E2Node Exclude " . time());

  # Add the e2node to the category
  $DB->sqlInsert('links', {
    from_node => $cat_id,
    to_node => $e2node_id,
    linktype => $category_linktype->{node_id},
    food => 10
  });

  # List categories for this e2node - should exclude the category
  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    query_params => { node_id => $e2node_id }
  );
  my $result = $category_api->list_categories($req);

  ok($result->[1]->{success}, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));

  # Check that the category is not in the list
  my $found = 0;
  foreach my $cat (@{$result->[1]->{your_categories}}) {
    if ($cat->{node_id} == $cat_id) {
      $found = 1;
      last;
    }
  }
  is($found, 0, "Category already containing the node is excluded");
};

#############################################################################
# Test add_member endpoint
#############################################################################

subtest 'add_member - guest denied' => sub {
  my $req = MockRequest->new(
    node_id => $guest_user_id,
    is_guest_flag => 1,
    request_method => 'POST',
    postdata => { category_id => 1, node_id => 1 }
  );
  my $result = $category_api->add_member($req);

  is($result->[1]->{success}, 0, "Request denied for guest");
};

subtest 'add_member - missing parameters' => sub {
  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    request_method => 'POST',
    postdata => { category_id => 1 }
  );
  my $result = $category_api->add_member($req);

  is($result->[1]->{success}, 0, "Request denied without node_id");
  like($result->[1]->{error}, qr/required/i, "Error mentions required field");
};

subtest 'add_member - successful add to own category' => sub {
  my $cat_id = create_test_category("Test Category Add " . time());
  my $e2node_id = create_test_e2node("Test E2Node Add " . time());

  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    request_method => 'POST',
    postdata => { category_id => $cat_id, node_id => $e2node_id }
  );
  my $result = $category_api->add_member($req);

  is($result->[1]->{success}, 1, "Successfully added to category") or diag("Error: " . ($result->[1]->{error} // 'none'));

  # Verify the link was created
  my $link = $DB->sqlSelect(
    'from_node',
    'links',
    "from_node=$cat_id AND to_node=$e2node_id AND linktype=" . $category_linktype->{node_id}
  );
  ok($link, "Link was created in database");
};

subtest 'add_member - prevent duplicate add' => sub {
  my $cat_id = create_test_category("Test Category Dup " . time());
  my $e2node_id = create_test_e2node("Test E2Node Dup " . time());

  # Add the first time
  $DB->sqlInsert('links', {
    from_node => $cat_id,
    to_node => $e2node_id,
    linktype => $category_linktype->{node_id},
    food => 10
  });

  # Try to add again
  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    request_method => 'POST',
    postdata => { category_id => $cat_id, node_id => $e2node_id }
  );
  my $result = $category_api->add_member($req);

  is($result->[1]->{success}, 0, "Duplicate add prevented");
  like($result->[1]->{error}, qr/already/i, "Error mentions already in category");
};

subtest 'add_member - public category accessible to any logged-in user' => sub {
  # Create a public category (owned by guest user)
  my $cat_id = create_test_category("Test Public Category " . time(), $guest_user_id);
  my $e2node_id = create_test_e2node("Test E2Node Public " . time());

  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    request_method => 'POST',
    postdata => { category_id => $cat_id, node_id => $e2node_id }
  );
  my $result = $category_api->add_member($req);

  is($result->[1]->{success}, 1, "Successfully added to public category") or diag("Error: " . ($result->[1]->{error} // 'none'));
};

#############################################################################
# Test remove_member endpoint
#############################################################################

subtest 'remove_member - successful removal by owner' => sub {
  my $cat_id = create_test_category("Test Category Remove " . time());
  my $e2node_id = create_test_e2node("Test E2Node Remove " . time());

  # Add the e2node first
  $DB->sqlInsert('links', {
    from_node => $cat_id,
    to_node => $e2node_id,
    linktype => $category_linktype->{node_id},
    food => 10
  });

  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    request_method => 'POST',
    postdata => { node_id => $cat_id, member_id => $e2node_id }
  );
  my $result = $category_api->remove_member($req);

  is($result->[1]->{success}, 1, "Successfully removed from category") or diag("Error: " . ($result->[1]->{error} // 'none'));

  # Verify the link was deleted
  my $link = $DB->sqlSelect(
    'from_node',
    'links',
    "from_node=$cat_id AND to_node=$e2node_id AND linktype=" . $category_linktype->{node_id}
  );
  ok(!$link, "Link was deleted from database");
};

#############################################################################
# Test reorder_members endpoint
#############################################################################

subtest 'reorder_members - successful reorder by owner' => sub {
  my $cat_id = create_test_category("Test Category Reorder " . time());
  my $e2node_id1 = create_test_e2node("Test E2Node Reorder1 " . time());
  my $e2node_id2 = create_test_e2node("Test E2Node Reorder2 " . time());

  # Add both e2nodes
  $DB->sqlInsert('links', {
    from_node => $cat_id,
    to_node => $e2node_id1,
    linktype => $category_linktype->{node_id},
    food => 10
  });
  $DB->sqlInsert('links', {
    from_node => $cat_id,
    to_node => $e2node_id2,
    linktype => $category_linktype->{node_id},
    food => 20
  });

  # Reorder (swap)
  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    request_method => 'POST',
    postdata => {
      node_id => $cat_id,
      member_ids => [$e2node_id2, $e2node_id1]
    }
  );
  my $result = $category_api->reorder_members($req);

  is($result->[1]->{success}, 1, "Successfully reordered") or diag("Error: " . ($result->[1]->{error} // 'none'));

  # Verify the order changed
  my $food1 = $DB->sqlSelect(
    'food',
    'links',
    "from_node=$cat_id AND to_node=$e2node_id1 AND linktype=" . $category_linktype->{node_id}
  );
  my $food2 = $DB->sqlSelect(
    'food',
    'links',
    "from_node=$cat_id AND to_node=$e2node_id2 AND linktype=" . $category_linktype->{node_id}
  );

  ok($food2 < $food1, "Order was reversed (node2 now comes first)");
};

#############################################################################
# Test update endpoint
#############################################################################

subtest 'update - update description by owner' => sub {
  my $cat_id = create_test_category("Test Category Update " . time());

  my $new_description = "Updated description " . time();
  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    request_method => 'POST',
    postdata => {
      node_id => $cat_id,
      doctext => $new_description
    }
  );
  my $result = $category_api->update_category($req);

  is($result->[1]->{success}, 1, "Successfully updated description") or diag("Error: " . ($result->[1]->{error} // 'none'));

  # Verify the description changed
  my $doctext = $DB->sqlSelect('doctext', 'document', "document_id=$cat_id");
  is($doctext, $new_description, "Description was updated in database");
};

#############################################################################
# Test lookup_owner endpoint
#############################################################################

subtest 'lookup_owner - editors only' => sub {
  my $req = MockRequest->new(
    node_id => $normal_user->{node_id},
    title => $normal_user->{title},
    query_params => { name => 'root' }
  );
  my $result = $category_api->lookup_owner($req);

  # Normal users should be denied
  is($result->[1]->{success}, 0, "Normal user denied");
  like($result->[1]->{error}, qr/editor/i, "Error mentions editors");
};

SKIP: {
  skip "No editor user available", 2 unless $editor_user;

  subtest 'lookup_owner - find user' => sub {
    my $req = MockRequest->new(
      node_id => $editor_user->{node_id},
      title => $editor_user->{title},
      is_editor_flag => 1,
      query_params => { name => 'root' }
    );
    my $result = $category_api->lookup_owner($req);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    is($result->[1]->{found}, 1, "User found");
    is($result->[1]->{title}, 'root', "Correct user returned");
    is($result->[1]->{type}, 'user', "Correct type returned");
  };

  subtest 'lookup_owner - not found' => sub {
    my $req = MockRequest->new(
      node_id => $editor_user->{node_id},
      title => $editor_user->{title},
      is_editor_flag => 1,
      query_params => { name => 'nonexistent_user_xyz_' . time() }
    );
    my $result = $category_api->lookup_owner($req);

    is($result->[1]->{success}, 1, "Request succeeded") or diag("Error: " . ($result->[1]->{error} // 'none'));
    is($result->[1]->{found}, 0, "User not found");
  };
}

done_testing();
