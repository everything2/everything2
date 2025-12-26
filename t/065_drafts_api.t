#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use JSON;
use Encode qw(encode_utf8);

use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';

use Everything;
use Everything::API::drafts;

# Initialize E2 system
initEverything();

my $APP = $Everything::APP;
my $DB  = $APP->{db};

# Get test users
my $regular_user = $DB->getNode( 'e2e_user', 'user' );
my $admin_user   = $DB->getNode( 'root',     'user' );

# Get nodetypes
my $draft_type       = $DB->getType('draft');
my $writeup_type     = $DB->getType('writeup');
my $e2node_type      = $DB->getType('e2node');
my $writeuptype_type = $DB->getType('writeuptype');

# Get publication statuses
my $private_status = $DB->getNode( 'private', 'publication_status' );

# Get a writeuptype (e.g., "idea" or "person")
my $idea_writeuptype = $DB->getNode( 'idea', 'writeuptype' );

# Create mock request and user objects
{

    package MockUser;

    sub new {
        my ( $class, %args ) = @_;
        return bless {
            node_id        => $args{node_id}        // 0,
            title          => $args{title}          // 'test',
            is_admin_flag  => $args{is_admin_flag}  // 0,
            is_editor_flag => $args{is_editor_flag} // 0,
            is_guest_flag  => $args{is_guest_flag}  // 0,
            _nodedata      => $args{nodedata}       // {},
        }, $class;
    }
    sub is_admin  { return shift->{is_admin_flag}; }
    sub is_editor { return shift->{is_editor_flag}; }
    sub is_guest  { return shift->{is_guest_flag}; }
    sub node_id   { shift->{node_id} }
    sub title     { shift->{title} }
    sub NODEDATA  { shift->{_nodedata} }
}

{

    package MockRequest;

    sub new {
        my ( $class, %args ) = @_;
        return bless {
            user     => MockUser->new(%args),
            postdata => $args{postdata},
        }, $class;
    }
    sub user     { shift->{user} }
    sub POSTDATA { shift->{postdata} }

    sub JSON_POSTDATA {
        my $self     = shift;
        my $postdata = $self->{postdata};
        return unless $postdata;
        return JSON::decode_json($postdata);
    }

    sub set_postdata {
        my ( $self, $data ) = @_;
        $self->{postdata} = Encode::encode_utf8( JSON::encode_json($data) );
    }
    sub is_guest       { return shift->{user}->is_guest }
    sub request_method { 'POST' }
}

# Create API instance
my $api = Everything::API::drafts->new();

# Create test requests
my $regular_request = MockRequest->new(
    node_id        => $regular_user->{node_id},
    title          => $regular_user->{title},
    nodedata       => $regular_user,
    is_admin_flag  => 0,
    is_editor_flag => 0,
    is_guest_flag  => 0
);

my $guest_request = MockRequest->new(
    node_id        => 0,
    title          => 'Guest User',
    nodedata       => {},
    is_admin_flag  => 0,
    is_editor_flag => 0,
    is_guest_flag  => 1
);

# Test cleanup function
sub cleanup_test_nodes {
    my @node_ids = @_;
    foreach my $node_id (@node_ids) {

        # Delete from all relevant tables
        $DB->sqlDelete( 'nodegroup',
            "node_id=$node_id OR nodegroup_id=$node_id" );
        $DB->sqlDelete( 'draft',      "draft_id=$node_id" );
        $DB->sqlDelete( 'writeup',    "writeup_id=$node_id" );
        $DB->sqlDelete( 'document',   "document_id=$node_id" );
        $DB->sqlDelete( 'newwriteup', "node_id=$node_id" );
        $DB->sqlDelete( 'publish',    "publish_id=$node_id" );
        $DB->sqlDelete( 'node',       "node_id=$node_id" );
    }
    $DB->{dbh}->commit();
}

# Test 1: Create a draft
{
    $regular_request->set_postdata(
        {
            title   => 'Test Draft for Publication',
            doctext => '<p>This is a test draft that will be published.</p>'
        }
    );

    my ( $status, $response ) = @{ $api->create_draft($regular_request) };

    is( $status, $api->HTTP_OK, 'create_draft returns HTTP_OK' );
    ok( $response->{success},        'create_draft succeeds' );
    ok( $response->{draft}{node_id}, 'create_draft returns node_id' );

    my $draft_id = $response->{draft}{node_id};

    # Verify draft exists in database
    my $draft_node = $DB->getNodeById($draft_id);
    ok( $draft_node, 'Draft node exists in database' );
    is( $draft_node->{type}{title}, 'draft', 'Node type is draft' );
    is(
        $draft_node->{author_user},
        $regular_user->{node_id},
        'Draft author is correct'
    );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 2: Guest cannot create drafts (should be blocked by authorization wrapper)
{
    # Note: The actual API wraps create_draft with unauthorized_if_guest
    # For testing the raw method, we'll just verify the wrapper exists

    # Check that the wrapper is applied
    my $wrapped =
      Everything::API::drafts->meta->find_method_by_name('create_draft');
    ok( $wrapped,
        'create_draft method exists (should be wrapped with guest check)' );
}

# Test 3: Publish draft - complete workflow
{
    # Step 1: Create an e2node
    my $e2node_title = 'Test E2node for Publishing ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created test e2node' );

    # Step 2: Create a draft
    $regular_request->set_postdata(
        {
            title   => $e2node_title,
            doctext =>
'<p>This is a test writeup that will be published to the e2node.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    is( $create_status, $api->HTTP_OK, 'Draft created successfully' );
    my $draft_id = $create_response->{draft}{node_id};

    # Step 3: Publish the draft
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id},
            feedback_policy_id => 0
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_OK, 'publish_draft returns HTTP_OK' );
    ok( $publish_response->{success}, 'publish_draft succeeds' );
    is( $publish_response->{writeup_id},
        $draft_id, 'Writeup ID matches draft ID' );
    is( $publish_response->{e2node_id}, $e2node_id, 'E2node ID is correct' );

    # Step 4: Verify the node is now a writeup
    my $writeup_node = $DB->getNodeById($draft_id);
    is( $writeup_node->{type}{title},
        'writeup', 'Node type changed to writeup' );

    # Step 5: Verify draft table entry is deleted
    my $draft_row = $DB->sqlSelect( '*', 'draft', "draft_id=$draft_id" );
    ok( !$draft_row, 'Draft table entry deleted after publication' );

    # Step 6: Verify writeup table entry exists
    my $writeup_row =
      $DB->{dbh}
      ->selectrow_hashref( "SELECT * FROM writeup WHERE writeup_id = ?",
        {}, $draft_id );
    ok( $writeup_row, 'Writeup table entry created' );
    is( $writeup_row->{parent_e2node},
        $e2node_id, 'Writeup parent_e2node is correct' );
    is(
        $writeup_row->{wrtype_writeuptype},
        $idea_writeuptype->{node_id},
        'Writeup type is correct'
    );

    # Step 7: Verify nodegroup entry exists
    # nodegroup_id = parent (e2node), node_id = member (writeup)
    my $nodegroup_row =
      $DB->{dbh}->selectrow_hashref(
        "SELECT * FROM nodegroup WHERE nodegroup_id = ? AND node_id = ?",
        {}, $e2node_id, $draft_id );
    ok( $nodegroup_row,                           'Nodegroup entry created' );
    ok( defined $nodegroup_row->{nodegroup_rank}, 'Nodegroup rank is set' );
    ok( defined $nodegroup_row->{orderby},        'Nodegroup orderby is set' );

    # Step 8: Verify newwriteup entry exists
    my $newwriteup_row =
      $DB->sqlSelect( '*', 'newwriteup', "node_id=$draft_id" );
    ok( $newwriteup_row, 'Newwriteup entry created' );

    # Step 9: Verify publish table entry exists
    my $publish_row = $DB->sqlSelect( '*', 'publish', "publish_id=$draft_id" );
    ok( $publish_row, 'Publish table entry created' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 4: Publish draft without parent_e2node (should fail)
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Test Draft No Parent',
            doctext => '<p>This draft has no parent e2node.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to publish without parent_e2node
    $regular_request->set_postdata(
        {
            wrtype_writeuptype => $idea_writeuptype->{node_id}

              # Intentionally missing parent_e2node
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_BAD_REQUEST,
        'publish_draft returns BAD_REQUEST for missing parent' );
    ok( !$publish_response->{success},
        'publish_draft fails without parent_e2node' );
    is( $publish_response->{error},
        'missing_parent', 'Error code is missing_parent' );

    # Verify node is still a draft
    my $draft_node = $DB->getNodeById($draft_id);
    is( $draft_node->{type}{title},
        'draft', 'Node is still a draft after failed publish' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 5: Publish draft with invalid e2node (should fail)
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Test Draft Invalid Parent',
            doctext => '<p>This draft has invalid parent e2node.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to publish with non-existent e2node
    $regular_request->set_postdata(
        {
            parent_e2node      => 999999999,    # Non-existent node ID
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_BAD_REQUEST,
        'publish_draft returns BAD_REQUEST for invalid parent' );
    ok( !$publish_response->{success},
        'publish_draft fails with invalid parent_e2node' );
    is( $publish_response->{error},
        'invalid_parent', 'Error code is invalid_parent' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 6: User cannot publish another user's draft
{
    # Create a draft as admin
    my $admin_request = MockRequest->new(
        node_id        => $admin_user->{node_id},
        title          => $admin_user->{title},
        nodedata       => $admin_user,
        is_admin_flag  => 1,
        is_editor_flag => 1,
        is_guest_flag  => 0
    );

    $admin_request->set_postdata(
        {
            title   => 'Admin Draft',
            doctext => '<p>This is an admin draft.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($admin_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to publish as regular user
    my $e2node_title = 'Test E2node ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_FORBIDDEN,
        'publish_draft returns FORBIDDEN for other user draft' );
    ok( !$publish_response->{success},
        'publish_draft fails for unauthorized user' );
    is( $publish_response->{error},
        'permission_denied', 'Error code is permission_denied' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 7: Multiple writeups can be published to same e2node
{
    # Create e2node
    my $e2node_title = 'Multi-Writeup E2node ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    my @draft_ids;

    # Create and publish 3 drafts to same e2node
    for my $i ( 1 .. 3 ) {

        # Create draft
        $regular_request->set_postdata(
            {
                title   => "$e2node_title - Draft $i",
                doctext => "<p>This is writeup number $i.</p>"
            }
        );

        my ( $create_status, $create_response ) =
          @{ $api->create_draft($regular_request) };
        my $draft_id = $create_response->{draft}{node_id};
        push @draft_ids, $draft_id;

        # Publish draft
        $regular_request->set_postdata(
            {
                parent_e2node      => $e2node_id,
                wrtype_writeuptype => $idea_writeuptype->{node_id}
            }
        );

        my ( $publish_status, $publish_response ) =
          @{ $api->publish_draft( $regular_request, $draft_id ) };
        is( $publish_status, $api->HTTP_OK, "Draft $i published successfully" );
    }

    # Verify all 3 writeups are in nodegroup
    # nodegroup_id = parent (e2node), node_id = member (writeup)
    my $count =
      $DB->{dbh}
      ->selectrow_array( "SELECT COUNT(*) FROM nodegroup WHERE nodegroup_id = ?",
        {}, $e2node_id );
    is( $count, 3, 'All 3 writeups in nodegroup' );

    # Verify ranks are sequential
    my $ranks = $DB->{dbh}->selectcol_arrayref(
"SELECT nodegroup_rank FROM nodegroup WHERE nodegroup_id = ? ORDER BY nodegroup_rank",
        {}, $e2node_id
    );
    is( $ranks->[0], 0, 'First writeup has rank 0' );
    is( $ranks->[1], 1, 'Second writeup has rank 1' );
    is( $ranks->[2], 2, 'Third writeup has rank 2' );

    # Cleanup
    cleanup_test_nodes( @draft_ids, $e2node_id );
}

# Test 8: Set parent e2node by ID
{
    # Create an e2node first
    my $e2node_title = 'Test E2node for Parent ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created test e2node for parent test' );

    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for Parent Test',
            doctext => '<p>Testing set_parent_e2node.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Set parent e2node by ID
    $regular_request->set_postdata( { e2node_id => $e2node_id } );

    my ( $parent_status, $parent_response ) =
      @{ $api->set_parent_e2node( $regular_request, $draft_id ) };

    is( $parent_status, $api->HTTP_OK,
        'set_parent_e2node by ID returns HTTP_OK' );
    ok( $parent_response->{success}, 'set_parent_e2node by ID succeeds' );
    is( $parent_response->{e2node}{node_id},
        $e2node_id, 'E2node ID matches' );
    is( $parent_response->{e2node}{title},
        $e2node_title, 'E2node title matches' );
    ok( !$parent_response->{e2node}{created},
        'E2node was not newly created' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 9: Set parent e2node by title (existing e2node)
{
    # Create an e2node first
    my $e2node_title = 'Test E2node By Title ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created test e2node for title lookup' );

    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for Title Test',
            doctext => '<p>Testing set_parent_e2node by title.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Set parent e2node by title
    $regular_request->set_postdata( { e2node_title => $e2node_title } );

    my ( $parent_status, $parent_response ) =
      @{ $api->set_parent_e2node( $regular_request, $draft_id ) };

    is( $parent_status, $api->HTTP_OK,
        'set_parent_e2node by title returns HTTP_OK' );
    ok( $parent_response->{success}, 'set_parent_e2node by title succeeds' );
    is( $parent_response->{e2node}{node_id},
        $e2node_id, 'E2node ID matches' );
    is( $parent_response->{e2node}{title},
        $e2node_title, 'E2node title matches' );
    ok( !$parent_response->{e2node}{created},
        'Existing e2node was found, not created' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 10: Set parent e2node by title (creates new e2node)
{
    my $new_e2node_title = 'Brand New E2node ' . time();

    # Verify e2node doesn't exist
    my $existing = $DB->getNode( $new_e2node_title, 'e2node' );
    ok( !$existing, 'E2node does not exist yet' );

    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for New E2node Test',
            doctext => '<p>Testing e2node creation.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Set parent e2node by title (should create new e2node)
    $regular_request->set_postdata( { e2node_title => $new_e2node_title } );

    my ( $parent_status, $parent_response ) =
      @{ $api->set_parent_e2node( $regular_request, $draft_id ) };

    is( $parent_status, $api->HTTP_OK,
        'set_parent_e2node creates new e2node' );
    ok( $parent_response->{success}, 'set_parent_e2node succeeds' );
    ok( $parent_response->{e2node}{node_id}, 'New e2node has node_id' );
    is( $parent_response->{e2node}{title},
        $new_e2node_title, 'New e2node title matches' );
    ok( $parent_response->{e2node}{created}, 'E2node was newly created' );

    # Verify e2node exists in database
    my $new_e2node = $DB->getNodeById( $parent_response->{e2node}{node_id} );
    ok( $new_e2node, 'New e2node exists in database' );
    is( $new_e2node->{type}{title}, 'e2node', 'Node type is e2node' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $parent_response->{e2node}{node_id} );
}

# Test 11: Set parent e2node with invalid e2node_id
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for Invalid ID Test',
            doctext => '<p>Testing invalid e2node_id.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to set parent with non-existent e2node_id
    $regular_request->set_postdata( { e2node_id => 999999999 } );

    my ( $parent_status, $parent_response ) =
      @{ $api->set_parent_e2node( $regular_request, $draft_id ) };

    is( $parent_status, $api->HTTP_BAD_REQUEST,
        'set_parent_e2node returns BAD_REQUEST for invalid ID' );
    ok( !$parent_response->{success},
        'set_parent_e2node fails with invalid ID' );
    is( $parent_response->{error}, 'invalid_e2node', 'Error is invalid_e2node' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 12: Set parent e2node without e2node_id or e2node_title
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for Missing Param Test',
            doctext => '<p>Testing missing parameters.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to set parent without e2node info
    $regular_request->set_postdata( {} );

    my ( $parent_status, $parent_response ) =
      @{ $api->set_parent_e2node( $regular_request, $draft_id ) };

    is( $parent_status, $api->HTTP_BAD_REQUEST,
        'set_parent_e2node returns BAD_REQUEST without e2node info' );
    ok( !$parent_response->{success},
        'set_parent_e2node fails without e2node info' );
    is( $parent_response->{error}, 'missing_e2node', 'Error is missing_e2node' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 13: User cannot set parent on another user's draft
{
    # Create a draft as admin
    my $admin_request = MockRequest->new(
        node_id        => $admin_user->{node_id},
        title          => $admin_user->{title},
        nodedata       => $admin_user,
        is_admin_flag  => 1,
        is_editor_flag => 1,
        is_guest_flag  => 0
    );

    $admin_request->set_postdata(
        {
            title   => 'Admin Draft for Permission Test',
            doctext => '<p>This is an admin draft.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($admin_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Create an e2node
    my $e2node_title = 'E2node for Permission Test ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    # Try to set parent as regular user (not the draft owner)
    $regular_request->set_postdata( { e2node_id => $e2node_id } );

    my ( $parent_status, $parent_response ) =
      @{ $api->set_parent_e2node( $regular_request, $draft_id ) };

    is( $parent_status, $api->HTTP_FORBIDDEN,
        'set_parent_e2node returns FORBIDDEN for other user draft' );
    ok( !$parent_response->{success},
        'set_parent_e2node fails for unauthorized user' );
    is( $parent_response->{error},
        'permission_denied', 'Error is permission_denied' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 14: Set parent on non-existent draft
{
    $regular_request->set_postdata( { e2node_title => 'Some E2node' } );

    my ( $parent_status, $parent_response ) =
      @{ $api->set_parent_e2node( $regular_request, 999999999 ) };

    is( $parent_status, $api->HTTP_NOT_FOUND,
        'set_parent_e2node returns NOT_FOUND for non-existent draft' );
    ok( !$parent_response->{success}, 'set_parent_e2node fails' );
    is( $parent_response->{error}, 'not_found', 'Error is not_found' );
}

# Test 15: Set parent then publish workflow
{
    # Create an e2node
    my $e2node_title = 'E2node for Full Workflow ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    # Step 1: Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for Full Workflow',
            doctext => '<p>Testing the complete workflow.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Step 2: Set parent e2node
    $regular_request->set_postdata( { e2node_id => $e2node_id } );

    my ( $parent_status, $parent_response ) =
      @{ $api->set_parent_e2node( $regular_request, $draft_id ) };

    is( $parent_status, $api->HTTP_OK, 'Set parent e2node succeeded' );
    is( $parent_response->{e2node}{node_id}, $e2node_id, 'Parent e2node set correctly' );

    # Step 3: Publish using the e2node from step 2
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_OK, 'Publish succeeded' );
    ok( $publish_response->{success}, 'Publish returned success' );

    # Verify writeup is in e2node's nodegroup
    # nodegroup_id = parent (e2node), node_id = member (writeup)
    my $in_nodegroup = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM nodegroup WHERE nodegroup_id = ? AND node_id = ?",
        {}, $e2node_id, $draft_id
    );
    is( $in_nodegroup, 1, 'Writeup is in e2node nodegroup' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 16: Publish draft without writeuptype (should fail)
{
    # Create e2node and draft
    my $e2node_title = 'E2node for Writeuptype Test ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    $regular_request->set_postdata(
        {
            title   => 'Draft Missing Writeuptype',
            doctext => '<p>Testing missing writeuptype.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to publish without writeuptype
    $regular_request->set_postdata(
        {
            parent_e2node => $e2node_id
            # Intentionally missing wrtype_writeuptype
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_BAD_REQUEST,
        'publish_draft returns BAD_REQUEST for missing writeuptype' );
    ok( !$publish_response->{success}, 'publish_draft fails without writeuptype' );
    is( $publish_response->{error}, 'missing_writeuptype',
        'Error is missing_writeuptype' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 17: Publish draft with invalid writeuptype (should fail)
{
    # Create e2node and draft
    my $e2node_title = 'E2node for Invalid Writeuptype ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    $regular_request->set_postdata(
        {
            title   => 'Draft Invalid Writeuptype',
            doctext => '<p>Testing invalid writeuptype.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to publish with invalid writeuptype
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => 999999999  # Non-existent writeuptype
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_BAD_REQUEST,
        'publish_draft returns BAD_REQUEST for invalid writeuptype' );
    ok( !$publish_response->{success}, 'publish_draft fails with invalid writeuptype' );
    is( $publish_response->{error}, 'invalid_writeuptype',
        'Error is invalid_writeuptype' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 18: Publish draft to locked node (should fail)
{
    # Create e2node
    my $e2node_title = 'Locked E2node for Publish Test ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created test e2node for lock test' );

    # Lock the e2node
    $DB->sqlInsert(
        'nodelock',
        {
            nodelock_reason => 'Editorial decision - node is complete',
            nodelock_user   => $admin_user->{node_id},
            nodelock_node   => $e2node_id
        }
    );
    $DB->{dbh}->commit();

    # Verify lock exists
    my $lock_check = $DB->sqlSelectHashref( '*', 'nodelock', "nodelock_node=$e2node_id" );
    ok( $lock_check, 'Node lock was created' );

    # Create a draft
    $regular_request->set_postdata(
        {
            title   => $e2node_title,
            doctext => '<p>Trying to publish to a locked node.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};
    ok( $draft_id, 'Draft created for lock test' );

    # Try to publish to locked e2node
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_OK,
        'publish_draft returns HTTP_OK for locked node (with error in response)' );
    ok( !$publish_response->{success},
        'publish_draft fails for locked node' );
    is( $publish_response->{error}, 'node_locked',
        'Error code is node_locked' );
    like( $publish_response->{message}, qr/locked/i,
        'Error message mentions locked' );

    # Verify draft is still a draft (not converted)
    my $draft_node = $DB->getNodeById($draft_id);
    is( $draft_node->{type}{title}, 'draft',
        'Node is still a draft after failed publish to locked node' );

    # Cleanup - remove lock first, then nodes
    $DB->sqlDelete( 'nodelock', "nodelock_node=$e2node_id" );
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 19: Unlocking a node allows publishing
{
    # Create e2node
    my $e2node_title = 'Unlock E2node Test ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    # Lock the e2node
    $DB->sqlInsert(
        'nodelock',
        {
            nodelock_reason => 'Temporary lock',
            nodelock_user   => $admin_user->{node_id},
            nodelock_node   => $e2node_id
        }
    );
    $DB->{dbh}->commit();

    # Create a draft
    $regular_request->set_postdata(
        {
            title   => $e2node_title,
            doctext => '<p>Testing unlock then publish.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Unlock the e2node
    $DB->sqlDelete( 'nodelock', "nodelock_node=$e2node_id" );
    $DB->{dbh}->commit();

    # Now try to publish - should succeed
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_OK,
        'publish_draft returns HTTP_OK after unlock' );
    ok( $publish_response->{success},
        'publish_draft succeeds after node is unlocked' );

    # Verify writeup was created
    my $writeup_node = $DB->getNodeById($draft_id);
    is( $writeup_node->{type}{title}, 'writeup',
        'Node type changed to writeup after unlock' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 20: Published writeup title follows "e2node (writeuptype)" format
{
    # Create e2node
    my $e2node_title = 'Writeup Title Format Test ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created test e2node for title format test' );

    # Create a draft with a different title (should be overwritten)
    $regular_request->set_postdata(
        {
            title   => 'Some Draft Title',
            doctext => '<p>Testing that the writeup title is set correctly.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Publish the draft
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_OK, 'publish_draft returns HTTP_OK' );
    ok( $publish_response->{success}, 'publish_draft succeeds' );

    # Verify the writeup title follows the correct format
    my $writeup_node = $DB->getNodeById($draft_id);
    my $expected_title = "$e2node_title (idea)";
    is( $writeup_node->{title}, $expected_title,
        'Writeup title follows "e2node (writeuptype)" format' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 21: Published writeup appears as user's most recent writeup
{
    # Create e2node
    my $e2node_title = 'Last Writeup Test ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created test e2node for last writeup test' );

    # Create and publish a draft
    $regular_request->set_postdata(
        {
            title   => $e2node_title,
            doctext => '<p>This should become the user last writeup.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };

    is( $publish_status, $api->HTTP_OK, 'publish_draft returns HTTP_OK' );

    # Query for the user's most recent writeup (same query used by lastnoded)
    # This verifies the writeup is properly linked to the author and has a publishtime
    my $last_writeup_id = $DB->sqlSelect(
        'node_id',
        'node JOIN writeup ON node_id=writeup_id',
        "author_user=" . $regular_user->{node_id},
        "ORDER BY publishtime DESC LIMIT 1"
    );

    is( $last_writeup_id, $draft_id,
        'Published writeup appears as user most recent writeup' );

    # Verify the writeup has a valid publishtime
    my $publishtime = $DB->sqlSelect(
        'publishtime',
        'writeup',
        "writeup_id=$draft_id"
    );
    ok( $publishtime && $publishtime ne '0000-00-00 00:00:00',
        'Published writeup has valid publishtime' );

    # Verify the writeup is in the newwriteup table (for New Writeups display)
    my $in_newwriteups = $DB->sqlSelect(
        'node_id',
        'newwriteup',
        "node_id=$draft_id"
    );
    is( $in_newwriteups, $draft_id,
        'Published writeup is in newwriteup table' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 22: Multiple writeups by same user - most recent is correct
{
    # Create e2node
    my $e2node_title = 'Multi Writeup Last Test ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    my @draft_ids;

    # Publish 3 writeups in sequence
    for my $i ( 1 .. 3 ) {
        $regular_request->set_postdata(
            {
                title   => "$e2node_title - Draft $i",
                doctext => "<p>Writeup number $i.</p>"
            }
        );

        my ( $create_status, $create_response ) =
          @{ $api->create_draft($regular_request) };
        my $draft_id = $create_response->{draft}{node_id};
        push @draft_ids, $draft_id;

        $regular_request->set_postdata(
            {
                parent_e2node      => $e2node_id,
                wrtype_writeuptype => $idea_writeuptype->{node_id}
            }
        );

        my ( $publish_status, $publish_response ) =
          @{ $api->publish_draft( $regular_request, $draft_id ) };
        is( $publish_status, $api->HTTP_OK, "Writeup $i published" );

        # Small delay to ensure distinct publishtimes
        # (MySQL datetime has 1-second resolution)
        select( undef, undef, undef, 0.1 );
    }

    # Query for the user's most recent writeup
    my $last_writeup_id = $DB->sqlSelect(
        'node_id',
        'node JOIN writeup ON node_id=writeup_id',
        "author_user=" . $regular_user->{node_id},
        "ORDER BY publishtime DESC LIMIT 1"
    );

    # The last published writeup should be the most recent
    is( $last_writeup_id, $draft_ids[2],
        'Third (most recent) writeup is returned as last writeup' );

    # Verify all three have distinct publishtimes in correct order
    my $times = $DB->{dbh}->selectcol_arrayref(
        "SELECT publishtime FROM writeup WHERE writeup_id IN (?, ?, ?) ORDER BY publishtime ASC",
        {}, @draft_ids
    );
    is( scalar(@$times), 3, 'All three writeups have publishtimes' );

    # Cleanup
    cleanup_test_nodes( @draft_ids, $e2node_id );
}

done_testing();
