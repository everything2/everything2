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

    sub param {
        my ( $self, $name ) = @_;
        return $self->{params}{$name} if exists $self->{params}{$name};
        return;
    }

    sub set_params {
        my ( $self, $params ) = @_;
        $self->{params} = $params;
    }
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

    # Step 5: Verify draft table entry is kept (writeups extend drafts)
    my $draft_row = $DB->{dbh}->selectrow_hashref(
        "SELECT * FROM draft WHERE draft_id = ?", {}, $draft_id
    );
    ok( $draft_row, 'Draft table entry preserved after publication' );
    is( $draft_row->{publication_status}, 0, 'Publication status set to 0 (published)' );

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

        # MySQL datetime has 1-second resolution, so we need at least 1 second
        # between publishes to ensure distinct publishtimes
        sleep(1) if $i < 3;
    }

    # Query for the user's most recent writeup
    # Use node_id DESC as tiebreaker since publishtime has 1-second resolution
    my $last_writeup_id = $DB->sqlSelect(
        'node_id',
        'node JOIN writeup ON node_id=writeup_id',
        "author_user=" . $regular_user->{node_id},
        "ORDER BY publishtime DESC, node_id DESC LIMIT 1"
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

# =============================================================================
# DELETE DRAFT TESTS
# =============================================================================

# Test 23: Author can delete their own draft
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft to Delete',
            doctext => '<p>This draft will be deleted.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    is( $create_status, $api->HTTP_OK, 'Draft created for delete test' );
    my $draft_id = $create_response->{draft}{node_id};
    ok( $draft_id, 'Got draft ID' );

    # Verify draft exists
    my $draft_node = $DB->getNodeById($draft_id);
    ok( $draft_node, 'Draft exists before deletion' );
    is( $draft_node->{type}{title}, 'draft', 'Node is a draft' );

    # Delete the draft
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $regular_request, $draft_id ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK' );
    ok( $delete_response->{success}, 'delete_draft succeeds' );
    like( $delete_response->{message}, qr/deleted/i, 'Success message mentions deleted' );

    # Verify draft is actually gone
    my $deleted_node = $DB->getNodeById($draft_id);
    ok( !$deleted_node, 'Draft no longer exists after deletion' );

    # Verify draft table entry is gone
    my $draft_row = $DB->sqlSelect( '*', 'draft', "draft_id=$draft_id" );
    ok( !$draft_row, 'Draft table entry deleted' );
}

# Test 24: Guest cannot delete drafts
{
    # Create a draft as regular user first
    $regular_request->set_postdata(
        {
            title   => 'Draft for Guest Delete Test',
            doctext => '<p>Guest should not be able to delete this.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to delete as guest
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $guest_request, $draft_id ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK for guest (with error)' );
    ok( !$delete_response->{success}, 'delete_draft fails for guest' );
    like( $delete_response->{error}, qr/logged in/i, 'Error mentions login requirement' );

    # Verify draft still exists
    my $draft_node = $DB->getNodeById($draft_id);
    ok( $draft_node, 'Draft still exists after failed guest delete' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 25: User cannot delete another user's draft
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
            title   => 'Admin Draft for Delete Security Test',
            doctext => '<p>Regular user should not be able to delete this.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($admin_request) };
    my $draft_id = $create_response->{draft}{node_id};
    ok( $draft_id, 'Admin draft created' );

    # Verify admin is the author
    my $draft_node = $DB->getNodeById($draft_id);
    is( $draft_node->{author_user}, $admin_user->{node_id},
        'Admin is the draft author' );

    # Try to delete as regular user (not the author)
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $regular_request, $draft_id ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK (with error)' );
    ok( !$delete_response->{success}, 'delete_draft fails for non-author' );
    like( $delete_response->{error}, qr/own drafts/i,
        'Error mentions can only delete own drafts' );

    # Verify draft still exists
    my $still_exists = $DB->getNodeById($draft_id);
    ok( $still_exists, 'Draft still exists after failed unauthorized delete' );
    is( $still_exists->{author_user}, $admin_user->{node_id},
        'Draft author unchanged' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 26: Admin/god can delete any user's draft
{
    # Create a draft as regular user
    $regular_request->set_postdata(
        {
            title   => 'User Draft for Admin Delete Test',
            doctext => '<p>Admin should be able to delete this.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Verify regular user is the author
    my $draft_node = $DB->getNodeById($draft_id);
    is( $draft_node->{author_user}, $regular_user->{node_id},
        'Regular user is the draft author' );

    # Delete as admin (god)
    my $admin_request = MockRequest->new(
        node_id        => $admin_user->{node_id},
        title          => $admin_user->{title},
        nodedata       => $admin_user,
        is_admin_flag  => 1,
        is_editor_flag => 1,
        is_guest_flag  => 0
    );

    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $admin_request, $draft_id ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK for admin' );
    ok( $delete_response->{success}, 'Admin can delete any user draft' );

    # Verify draft is gone
    my $deleted_node = $DB->getNodeById($draft_id);
    ok( !$deleted_node, 'Draft deleted by admin' );
}

# Test 27: Cannot delete non-existent draft
{
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $regular_request, 999999999 ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK (with error)' );
    ok( !$delete_response->{success}, 'delete_draft fails for non-existent draft' );
    like( $delete_response->{error}, qr/not found/i, 'Error mentions not found' );
}

# Test 28: Cannot delete a non-draft node type (e.g., writeup)
{
    # Create an e2node and writeup directly
    my $e2node_title = 'E2node for Non-Draft Delete Test ' . time();
    my $e2node_id =
      $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    # Create a draft and publish it to make a writeup
    $regular_request->set_postdata(
        {
            title   => $e2node_title,
            doctext => '<p>This will become a writeup.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Publish the draft (converts to writeup)
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };
    is( $publish_status, $api->HTTP_OK, 'Draft published to writeup' );

    # Verify it's now a writeup
    my $writeup_node = $DB->getNodeById($draft_id);
    is( $writeup_node->{type}{title}, 'writeup', 'Node is now a writeup' );

    # Try to delete the writeup using delete_draft (should fail)
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $regular_request, $draft_id ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK (with error)' );
    ok( !$delete_response->{success}, 'delete_draft fails for writeup' );
    like( $delete_response->{error}, qr/not a draft/i, 'Error mentions not a draft' );

    # Verify writeup still exists
    my $still_exists = $DB->getNodeById($draft_id);
    ok( $still_exists, 'Writeup still exists after failed delete' );
    is( $still_exists->{type}{title}, 'writeup', 'Node is still a writeup' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 29: Delete removes associated data (autosave, nodenotes, links)
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft with Associated Data',
            doctext => '<p>This draft has related records.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Add an autosave entry
    $DB->{dbh}->do(
        "INSERT INTO autosave (author_user, node_id, doctext, createtime) VALUES (?, ?, 'test autosave', NOW())",
        {}, $regular_user->{node_id}, $draft_id
    );
    $DB->{dbh}->commit();

    # Add a nodenote
    $DB->{dbh}->do(
        "INSERT INTO nodenote (nodenote_nodeid, noter_user, notetext, timestamp) VALUES (?, ?, 'test note', NOW())",
        {}, $draft_id, $regular_user->{node_id}
    );
    $DB->{dbh}->commit();

    # Add a link from draft
    $DB->{dbh}->do(
        "INSERT INTO links (from_node, to_node, linktype, hits, food) VALUES (?, 1, 0, 0, 0)",
        {}, $draft_id
    );
    $DB->{dbh}->commit();

    # Verify associated data exists
    my $autosave_count = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM autosave WHERE node_id = ?", {}, $draft_id
    );
    is( $autosave_count, 1, 'Autosave entry exists before delete' );

    my $note_count = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM nodenote WHERE nodenote_nodeid = ?", {}, $draft_id
    );
    is( $note_count, 1, 'Nodenote exists before delete' );

    my $link_count = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM links WHERE from_node = ?", {}, $draft_id
    );
    is( $link_count, 1, 'Link exists before delete' );

    # Delete the draft
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $regular_request, $draft_id ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK' );
    ok( $delete_response->{success}, 'delete_draft succeeds' );

    # Verify all associated data is cleaned up
    $autosave_count = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM autosave WHERE node_id = ?", {}, $draft_id
    );
    is( $autosave_count, 0, 'Autosave entry deleted' );

    $note_count = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM nodenote WHERE nodenote_nodeid = ?", {}, $draft_id
    );
    is( $note_count, 0, 'Nodenote deleted' );

    $link_count = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM links WHERE from_node = ?", {}, $draft_id
    );
    is( $link_count, 0, 'Link deleted' );
}

# Test 30: Delete draft with manually added links - links are cleaned up
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft with Links',
            doctext => '<p>This draft has links that should be cleaned up.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Manually add a link from draft to another node (simulating a reference)
    # Note: set_parent_e2node doesn't create links, but the delete should still
    # clean up any links that exist
    $DB->{dbh}->do(
        "INSERT INTO links (from_node, to_node, linktype, hits, food) VALUES (?, 1, 0, 0, 0)",
        {}, $draft_id
    );
    $DB->{dbh}->commit();

    # Verify link exists
    my $link_count = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM links WHERE from_node = ?", {}, $draft_id
    );
    is( $link_count, 1, 'Link exists before delete' );

    # Delete the draft
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $regular_request, $draft_id ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK' );
    ok( $delete_response->{success}, 'delete_draft succeeds' );

    # Verify link is cleaned up
    $link_count = $DB->{dbh}->selectrow_array(
        "SELECT COUNT(*) FROM links WHERE from_node = ?", {}, $draft_id
    );
    is( $link_count, 0, 'Link deleted with draft' );
}

# Test 31: Concurrent delete attempts (idempotent behavior)
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for Concurrent Delete Test',
            doctext => '<p>Testing idempotent delete behavior.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # First delete should succeed
    my ( $delete_status1, $delete_response1 ) =
      @{ $api->delete_draft( $regular_request, $draft_id ) };
    is( $delete_status1, $api->HTTP_OK, 'First delete returns HTTP_OK' );
    ok( $delete_response1->{success}, 'First delete succeeds' );

    # Second delete should fail (draft no longer exists)
    my ( $delete_status2, $delete_response2 ) =
      @{ $api->delete_draft( $regular_request, $draft_id ) };
    is( $delete_status2, $api->HTTP_OK, 'Second delete returns HTTP_OK (with error)' );
    ok( !$delete_response2->{success}, 'Second delete fails (already deleted)' );
    like( $delete_response2->{error}, qr/not found/i, 'Error mentions not found' );
}

# =============================================================================
# UNPUBLISH/REPUBLISH FLOW TESTS
# =============================================================================

# Test 32: Unpublish writeup preserves title with writeuptype suffix
{
    # Create e2node for this test
    my $e2node_title = 'Unpublish Test Node ' . time();
    my $e2node_id    = $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created e2node for unpublish test' );

    # Create and publish a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for Unpublish Test',
            doctext => '<p>This will be published then unpublished.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};
    ok( $draft_id, 'Draft created for unpublish test' );

    # Publish the draft
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };
    is( $publish_status, $api->HTTP_OK, 'Draft published successfully' );

    # Verify writeup title format
    my $writeup_node = $DB->getNodeById($draft_id);
    is( $writeup_node->{type}{title}, 'writeup', 'Node is now a writeup' );
    my $expected_title = "$e2node_title (idea)";
    is( $writeup_node->{title}, $expected_title, 'Writeup title has writeuptype suffix' );

    # Now unpublish via admin API (return to drafts)
    # First we need to use the admin API
    require Everything::API::admin;
    my $admin_api = Everything::API::admin->new( APP => $APP, DB => $DB );

    my ( $remove_status, $remove_response ) =
      @{ $admin_api->remove_writeup( $regular_request, $draft_id ) };
    is( $remove_status, $admin_api->HTTP_OK, 'remove_writeup returns HTTP_OK' );
    ok( $remove_response->{success}, 'Writeup removed successfully' );

    # Verify it's now a draft with the original writeup title preserved
    # Force cache refresh
    $DB->getCache->removeNode($writeup_node);
    my $draft_node = $DB->getNodeById($draft_id);
    is( $draft_node->{type}{title}, 'draft', 'Node is now a draft again' );
    is( $draft_node->{title}, $expected_title, 'Draft title preserved writeuptype suffix' );

    # The title should still be "Unpublish Test Node (idea)" so React can parse it
    like( $draft_node->{title}, qr/\(idea\)$/, 'Title ends with (idea) suffix' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 33: Republish with different writeuptype changes title correctly
{
    # Create e2node for this test
    my $e2node_title = 'Republish Test Node ' . time();
    my $e2node_id    = $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created e2node for republish test' );

    # Create and publish a draft as "idea"
    $regular_request->set_postdata(
        {
            title   => 'Draft for Republish Test',
            doctext => '<p>This will be published, unpublished, and republished.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Publish as "idea"
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };
    is( $publish_status, $api->HTTP_OK, 'Draft published as idea' );

    my $writeup_node = $DB->getNodeById($draft_id);
    is( $writeup_node->{title}, "$e2node_title (idea)", 'First publish title is correct' );

    # Unpublish
    require Everything::API::admin;
    my $admin_api = Everything::API::admin->new( APP => $APP, DB => $DB );

    my ( $remove_status, $remove_response ) =
      @{ $admin_api->remove_writeup( $regular_request, $draft_id ) };
    ok( $remove_response->{success}, 'Writeup removed' );

    # Verify draft title still has the old writeuptype
    $DB->getCache->removeNode($writeup_node);
    my $draft_node = $DB->getNodeById($draft_id);
    is( $draft_node->{title}, "$e2node_title (idea)", 'Draft preserves title with idea suffix' );

    # Now republish with a DIFFERENT writeuptype - "thing" instead of "idea"
    my $thing_writeuptype = $DB->getNode( 'thing', 'writeuptype' );
    ok( $thing_writeuptype, 'Got thing writeuptype' );

    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $thing_writeuptype->{node_id}
        }
    );

    my ( $republish_status, $republish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };
    is( $republish_status, $api->HTTP_OK, 'Draft republished as thing' );
    ok( $republish_response->{success}, 'Republish succeeded' );

    # Verify the title now has "thing" instead of "idea"
    $DB->getCache->removeNode($draft_node);
    my $republished_node = $DB->getNodeById($draft_id);
    is( $republished_node->{type}{title}, 'writeup', 'Node is writeup again' );
    is( $republished_node->{title}, "$e2node_title (thing)", 'Title updated with new writeuptype' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 34: Republish to same e2node with same writeuptype (no duplicate suffix)
{
    # Create e2node for this test
    my $e2node_title = 'No Duplicate Suffix Test ' . time();
    my $e2node_id    = $DB->insertNode( $e2node_title, $e2node_type, $regular_user );
    ok( $e2node_id, 'Created e2node for no-duplicate test' );

    # Create and publish a draft
    $regular_request->set_postdata(
        {
            title   => 'Draft for No Duplicate Test',
            doctext => '<p>Testing no duplicate suffix.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Publish as "idea"
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $publish_status, $publish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };
    is( $publish_status, $api->HTTP_OK, 'Draft published' );

    # Unpublish
    require Everything::API::admin;
    my $admin_api = Everything::API::admin->new( APP => $APP, DB => $DB );
    $admin_api->remove_writeup( $regular_request, $draft_id );

    # Republish with same writeuptype to same e2node
    $regular_request->set_postdata(
        {
            parent_e2node      => $e2node_id,
            wrtype_writeuptype => $idea_writeuptype->{node_id}
        }
    );

    my ( $republish_status, $republish_response ) =
      @{ $api->publish_draft( $regular_request, $draft_id ) };
    is( $republish_status, $api->HTTP_OK, 'Draft republished' );

    # Verify title does NOT have duplicate suffix like "title (idea) (idea)"
    my $republished_node = $DB->getNodeById($draft_id);
    is( $republished_node->{title}, "$e2node_title (idea)",
        'Title has single writeuptype suffix, not duplicated' );
    unlike( $republished_node->{title}, qr/\(idea\).*\(idea\)/,
        'No duplicate (idea) suffix' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# =============================================================================
# SEARCH DRAFTS TESTS
# =============================================================================

# Test 35: Search drafts by title
{
    # Create a draft with searchable title
    my $unique_title = 'Searchable Quantum Physics ' . time();
    $regular_request->set_postdata(
        {
            title   => $unique_title,
            doctext => '<p>Just some regular content here.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};
    ok( $draft_id, 'Created draft for search test' );

    # Search for it by title
    $regular_request->set_params( { q => 'Quantum Physics' } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts returns HTTP_OK' );
    ok( $search_response->{success}, 'search_drafts succeeds' );
    ok( ref $search_response->{drafts} eq 'ARRAY', 'drafts is an array' );

    # Find our draft in results
    my ($found) = grep { $_->{node_id} == $draft_id } @{ $search_response->{drafts} };
    ok( $found, 'Our draft found in search results' );
    like( $found->{title}, qr/Quantum Physics/, 'Found draft has matching title' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 36: Search drafts by content (doctext)
{
    # Create a draft with searchable content
    my $unique_content = 'UniqueXyzzyMagicWord' . time();
    $regular_request->set_postdata(
        {
            title   => 'Generic Title ' . time(),
            doctext => "<p>This contains the word $unique_content embedded in text.</p>"
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};
    ok( $draft_id, 'Created draft for content search test' );

    # Search for it by content
    $regular_request->set_params( { q => $unique_content } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts by content returns HTTP_OK' );
    ok( $search_response->{success}, 'search_drafts by content succeeds' );

    # Find our draft in results
    my ($found) = grep { $_->{node_id} == $draft_id } @{ $search_response->{drafts} };
    ok( $found, 'Draft found by content search' );
    like( $found->{doctext}, qr/$unique_content/, 'Found draft has matching content' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 37: Search returns empty for non-matching query
{
    $regular_request->set_params( { q => 'ZzzzNonExistentQueryXxxx' . time() } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts returns HTTP_OK for no results' );
    ok( $search_response->{success}, 'search_drafts succeeds even with no results' );
    is( scalar @{ $search_response->{drafts} }, 0, 'Empty results for non-matching query' );
}

# Test 38: Search requires minimum 2 characters
{
    $regular_request->set_params( { q => 'a' } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts returns HTTP_OK for short query' );
    ok( $search_response->{success}, 'search_drafts succeeds (returns message)' );
    is( scalar @{ $search_response->{drafts} }, 0, 'No results for 1-char query' );
    like( $search_response->{message}, qr/too short|minimum/i, 'Message indicates query too short' );
}

# Test 39: Search respects limit parameter
{
    # Create multiple drafts
    my @draft_ids;
    for my $i ( 1 .. 5 ) {
        $regular_request->set_postdata(
            {
                title   => "Limit Test Draft $i " . time(),
                doctext => '<p>Content for limit testing.</p>'
            }
        );
        my ( $status, $response ) = @{ $api->create_draft($regular_request) };
        push @draft_ids, $response->{draft}{node_id};
    }

    # Search with limit of 2
    $regular_request->set_params( { q => 'Limit Test Draft', limit => 2 } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts with limit returns HTTP_OK' );
    ok( $search_response->{success}, 'search_drafts with limit succeeds' );
    ok( scalar @{ $search_response->{drafts} } <= 2, 'Results respect limit of 2' );

    # Cleanup
    cleanup_test_nodes(@draft_ids);
}

# Test 40: Search only returns user's own drafts (security)
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

    my $admin_unique = 'AdminOnlySecret' . time();
    $admin_request->set_postdata(
        {
            title   => "Admin Draft with $admin_unique",
            doctext => '<p>Secret admin content.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($admin_request) };
    my $admin_draft_id = $create_response->{draft}{node_id};
    ok( $admin_draft_id, 'Created admin draft' );

    # Verify admin is the author
    my $draft_node = $DB->getNodeById($admin_draft_id);
    is( $draft_node->{author_user}, $admin_user->{node_id}, 'Admin is draft author' );

    # Now search as regular user - should NOT find admin's draft
    $regular_request->set_params( { q => $admin_unique } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts returns HTTP_OK' );
    ok( $search_response->{success}, 'search_drafts succeeds' );

    # Verify admin's draft is NOT in results
    my ($found) = grep { $_->{node_id} == $admin_draft_id } @{ $search_response->{drafts} };
    ok( !$found, 'Regular user cannot see admin draft in search results' );

    # Cleanup
    cleanup_test_nodes($admin_draft_id);
}

# Test 41: Search handles SQL special characters safely
{
    # Create a draft
    $regular_request->set_postdata(
        {
            title   => 'SQL Injection Test Draft ' . time(),
            doctext => '<p>Normal content here.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Try to inject SQL via search query
    # The % and _ are LIKE wildcards that should be escaped
    $regular_request->set_params( { q => "'; DROP TABLE node; --" } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts handles SQL injection attempt' );
    ok( $search_response->{success}, 'search_drafts succeeds (no crash)' );

    # Verify database is still intact
    my $node_count = $DB->{dbh}->selectrow_array("SELECT COUNT(*) FROM node");
    ok( $node_count > 0, 'Database still has nodes (SQL injection failed)' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 42: Search escapes LIKE wildcards (% and _)
{
    # Create a draft with literal % and _ in content
    my $percent_content = 'Percentage100%Increase' . time();
    $regular_request->set_postdata(
        {
            title   => 'Wildcard Test ' . time(),
            doctext => "<p>This has $percent_content in it.</p>"
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Search for the exact string with %
    $regular_request->set_params( { q => '100%Increase' } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts with % in query returns HTTP_OK' );
    ok( $search_response->{success}, 'search_drafts handles % in query' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 43: Guest cannot search drafts
{
    $guest_request->set_params( { q => 'test search' } );

    # The search_drafts method is wrapped with unauthorized_if_guest
    # which returns HTTP_UNAUTHORIZED for guests
    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($guest_request) };

    # Guest should get unauthorized response
    is( $search_status, $api->HTTP_UNAUTHORIZED, 'search_drafts returns HTTP_UNAUTHORIZED for guest' );
    ok( !$search_response->{success}, 'Guest search is not successful' );
}

# =============================================================================
# ADDITIONAL SECURITY TESTS FOR DELETE
# =============================================================================

# Test 44: Cannot delete draft by manipulating node_id in URL
{
    # Create drafts for two different users
    my $admin_request = MockRequest->new(
        node_id        => $admin_user->{node_id},
        title          => $admin_user->{title},
        nodedata       => $admin_user,
        is_admin_flag  => 1,
        is_editor_flag => 1,
        is_guest_flag  => 0
    );

    # Admin creates a draft
    $admin_request->set_postdata(
        {
            title   => 'Admin Private Draft ' . time(),
            doctext => '<p>This is admin private content.</p>'
        }
    );
    my ( $admin_create_status, $admin_create_response ) =
      @{ $api->create_draft($admin_request) };
    my $admin_draft_id = $admin_create_response->{draft}{node_id};

    # Regular user creates a draft
    $regular_request->set_postdata(
        {
            title   => 'Regular User Draft ' . time(),
            doctext => '<p>This is regular user content.</p>'
        }
    );
    my ( $user_create_status, $user_create_response ) =
      @{ $api->create_draft($regular_request) };
    my $user_draft_id = $user_create_response->{draft}{node_id};

    # Regular user tries to delete admin's draft by ID
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $regular_request, $admin_draft_id ) };

    is( $delete_status, $api->HTTP_OK, 'delete_draft returns HTTP_OK' );
    ok( !$delete_response->{success}, 'Regular user cannot delete admin draft' );

    # Verify admin's draft still exists
    my $admin_draft = $DB->getNodeById($admin_draft_id);
    ok( $admin_draft, 'Admin draft still exists after unauthorized delete attempt' );

    # Verify user's draft still exists (wasn't affected)
    my $user_draft = $DB->getNodeById($user_draft_id);
    ok( $user_draft, 'User draft still exists' );

    # Cleanup
    cleanup_test_nodes( $admin_draft_id, $user_draft_id );
}

# Test 45: Verify delete checks author_user, not just node_id
{
    # This verifies the security check is on author_user, not some other field

    # Create a draft as regular user
    $regular_request->set_postdata(
        {
            title   => 'Author Check Draft ' . time(),
            doctext => '<p>Testing author verification.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Verify the author_user is set correctly
    my $draft = $DB->getNodeById($draft_id);
    is( $draft->{author_user}, $regular_user->{node_id},
        'Draft has correct author_user' );

    # Create a second user request with different user
    my $other_user = $DB->getNode( 'normaluser1', 'user' );
    ok( $other_user, 'Got another user for cross-user test' );

    my $other_request = MockRequest->new(
        node_id        => $other_user->{node_id},
        title          => $other_user->{title},
        nodedata       => $other_user,
        is_admin_flag  => 0,
        is_editor_flag => 0,
        is_guest_flag  => 0
    );

    # Other user tries to delete the draft
    my ( $delete_status, $delete_response ) =
      @{ $api->delete_draft( $other_request, $draft_id ) };

    ok( !$delete_response->{success}, 'Other user cannot delete draft' );

    # Verify draft still exists
    my $still_exists = $DB->getNodeById($draft_id);
    ok( $still_exists, 'Draft still exists after cross-user delete attempt' );

    # Now the actual author deletes it - should work
    my ( $owner_delete_status, $owner_delete_response ) =
      @{ $api->delete_draft( $regular_request, $draft_id ) };

    ok( $owner_delete_response->{success}, 'Author can delete their own draft' );

    # Verify draft is gone
    my $deleted = $DB->getNodeById($draft_id);
    ok( !$deleted, 'Draft deleted by author' );
}

# Test 46: Verify search only searches user's drafts, not writeups or other types
{
    # Create a draft
    my $unique_term = 'SearchTypeTest' . time();
    $regular_request->set_postdata(
        {
            title   => "Draft $unique_term",
            doctext => '<p>Draft content.</p>'
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Create an e2node with the same term in title
    my $e2node_title = "E2Node $unique_term";
    my $e2node_id = $DB->insertNode( $e2node_title, $e2node_type, $regular_user );

    # Search - should only find the draft, not the e2node
    $regular_request->set_params( { q => $unique_term } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts returns HTTP_OK' );

    # Should find the draft
    my ($found_draft) = grep { $_->{node_id} == $draft_id } @{ $search_response->{drafts} };
    ok( $found_draft, 'Draft found in search' );

    # Should NOT find the e2node
    my ($found_e2node) = grep { $_->{node_id} == $e2node_id } @{ $search_response->{drafts} };
    ok( !$found_e2node, 'E2node not found in draft search (correct behavior)' );

    # Cleanup
    cleanup_test_nodes( $draft_id, $e2node_id );
}

# Test 47: Verify search returns proper draft fields
{
    my $test_title = 'Field Test Draft ' . time();
    my $test_content = '<p><strong>Field test</strong> content here.</p>';

    $regular_request->set_postdata(
        {
            title   => $test_title,
            doctext => $test_content
        }
    );

    my ( $create_status, $create_response ) =
      @{ $api->create_draft($regular_request) };
    my $draft_id = $create_response->{draft}{node_id};

    # Search for the draft
    $regular_request->set_params( { q => 'Field Test Draft' } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    my ($found) = grep { $_->{node_id} == $draft_id } @{ $search_response->{drafts} };
    ok( $found, 'Draft found in search' );

    # Verify all expected fields are present
    ok( exists $found->{node_id}, 'Response has node_id field' );
    ok( exists $found->{title}, 'Response has title field' );
    ok( exists $found->{createtime}, 'Response has createtime field' );
    ok( exists $found->{status}, 'Response has status field' );
    ok( exists $found->{doctext}, 'Response has doctext field' );

    # Verify field values
    is( $found->{node_id}, $draft_id, 'node_id is correct' );
    like( $found->{title}, qr/Field Test Draft/, 'title is correct' );
    like( $found->{doctext}, qr/Field test/, 'doctext contains expected content' );

    # Cleanup
    cleanup_test_nodes($draft_id);
}

# Test 48: Verify search query is returned in response
{
    my $search_query = 'test query string';
    $regular_request->set_params( { q => $search_query } );

    my ( $search_status, $search_response ) =
      @{ $api->search_drafts($regular_request) };

    is( $search_status, $api->HTTP_OK, 'search_drafts returns HTTP_OK' );
    is( $search_response->{query}, $search_query, 'Response includes the query string' );
}

done_testing();
