#!/usr/bin/perl
use strict;
use warnings;

use Test::More;
use JSON;
use Encode qw(encode_utf8);

use lib '/var/libraries/lib/perl5';
use lib '/var/everything/ecore';

use Everything;
use Everything::API::documents;

# Initialize E2 system
initEverything();

my $APP = $Everything::APP;
my $DB  = $APP->{db};

# Get test users
my $admin_user   = $DB->getNode( 'root',     'user' );
my $regular_user = $DB->getNode( 'e2e_user', 'user' );
my $guest_user   = $DB->getNode( 'Guest User', 'user' );

# Get test document nodes
my $document_node = $DB->getNode( 'Front page news item 1', 'document' );
my $edevdoc_node  = $DB->getNode( 'Test Developer Documentation', 'edevdoc' );
my $oppressor_doc = $DB->getNode( 'Test Oppressor Document', 'oppressor_document' );

# Get a non-document node for negative tests
my $user_node = $DB->getNode( 'normaluser1', 'user' );

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
    sub is_guest { shift->{user}->is_guest }

    sub JSON_POSTDATA {
        my $self     = shift;
        my $postdata = $self->{postdata};
        return unless $postdata;
        return JSON::decode_json($postdata);
    }
}

# Create API instance
my $api = Everything::API::documents->new;

# Store original doctexts for cleanup
my $original_document_doctext;
my $original_edevdoc_doctext;
my $original_oppressor_doctext;

if ($document_node) {
    $original_document_doctext = $document_node->{doctext};
}
if ($edevdoc_node) {
    $original_edevdoc_doctext = $edevdoc_node->{doctext};
}
if ($oppressor_doc) {
    $original_oppressor_doctext = $oppressor_doc->{doctext};
}

# ==========================================
# Test: _is_document_type helper
# ==========================================
subtest '_is_document_type helper' => sub {
    plan tests => 4;

    SKIP: {
        skip "document node not found", 1 unless $document_node;
        ok( $api->_is_document_type($document_node), 'document type is recognized as document' );
    }

    SKIP: {
        skip "edevdoc node not found", 1 unless $edevdoc_node;
        ok( $api->_is_document_type($edevdoc_node), 'edevdoc type is recognized as document (extends document)' );
    }

    SKIP: {
        skip "oppressor_document node not found", 1 unless $oppressor_doc;
        ok( $api->_is_document_type($oppressor_doc), 'oppressor_document type is recognized as document (extends document)' );
    }

    SKIP: {
        skip "user node not found", 1 unless $user_node;
        ok( !$api->_is_document_type($user_node), 'user type is NOT recognized as document' );
    }
};

# ==========================================
# Test: Guest cannot update documents
# ==========================================
subtest 'Guest cannot update documents' => sub {
    plan tests => 2;

    SKIP: {
        skip "document node not found", 2 unless $document_node;

        my $request = MockRequest->new(
            node_id       => $guest_user->{node_id},
            title         => 'Guest User',
            is_guest_flag => 1,
            nodedata      => $guest_user,
            postdata      => encode_utf8( JSON::encode_json( { doctext => 'Guest update attempt' } ) ),
        );

        my $result = $api->update( $request, $document_node->{node_id} );

        is( $result->[0], 401, 'Returns HTTP 401 for guest' );
        ok( !$result->[1]->{success}, 'success is false for guest' );
    }
};

# ==========================================
# Test: Non-document type returns error
# ==========================================
subtest 'Non-document type returns error' => sub {
    plan tests => 3;

    SKIP: {
        skip "user node not found", 3 unless $user_node;

        my $request = MockRequest->new(
            node_id        => $admin_user->{node_id},
            title          => 'root',
            is_admin_flag  => 1,
            is_editor_flag => 1,
            nodedata       => $admin_user,
            postdata       => encode_utf8( JSON::encode_json( { doctext => 'Update attempt' } ) ),
        );

        my $result = $api->update( $request, $user_node->{node_id} );

        is( $result->[0], 200, 'Returns HTTP 200' );
        ok( !$result->[1]->{success}, 'success is false for non-document type' );
        like( $result->[1]->{error}, qr/Document not found/, 'error message indicates document not found' );
    }
};

# ==========================================
# Test: Editor can update document
# ==========================================
subtest 'Editor can update document' => sub {
    plan tests => 4;

    SKIP: {
        skip "document node not found", 4 unless $document_node;

        my $new_doctext = '<p>Updated by editor test ' . time() . '</p>';
        my $request = MockRequest->new(
            node_id        => $admin_user->{node_id},
            title          => 'root',
            is_admin_flag  => 1,
            is_editor_flag => 1,
            nodedata       => $admin_user,
            postdata       => encode_utf8( JSON::encode_json( { doctext => $new_doctext } ) ),
        );

        my $result = $api->update( $request, $document_node->{node_id} );

        is( $result->[0], 200, 'Returns HTTP 200' );
        ok( $result->[1]->{success}, 'success is true' );
        is( $result->[1]->{document}->{doctext}, $new_doctext, 'doctext was updated' );
        is( $result->[1]->{document}->{node_id}, $document_node->{node_id}, 'node_id matches' );
    }
};

# ==========================================
# Test: Editor can update edevdoc (extends document)
# ==========================================
subtest 'Editor can update edevdoc' => sub {
    plan tests => 4;

    SKIP: {
        skip "edevdoc node not found", 4 unless $edevdoc_node;

        my $new_doctext = '<p>Updated edevdoc by editor test ' . time() . '</p>';
        my $request = MockRequest->new(
            node_id        => $admin_user->{node_id},
            title          => 'root',
            is_admin_flag  => 1,
            is_editor_flag => 1,
            nodedata       => $admin_user,
            postdata       => encode_utf8( JSON::encode_json( { doctext => $new_doctext } ) ),
        );

        my $result = $api->update( $request, $edevdoc_node->{node_id} );

        is( $result->[0], 200, 'Returns HTTP 200' );
        ok( $result->[1]->{success}, 'success is true for edevdoc' );
        is( $result->[1]->{document}->{doctext}, $new_doctext, 'edevdoc doctext was updated' );
        is( $result->[1]->{document}->{node_id}, $edevdoc_node->{node_id}, 'edevdoc node_id matches' );
    }
};

# ==========================================
# Test: Editor can update oppressor_document (extends document)
# ==========================================
subtest 'Editor can update oppressor_document' => sub {
    plan tests => 4;

    SKIP: {
        skip "oppressor_document node not found", 4 unless $oppressor_doc;

        my $new_doctext = '<p>Updated oppressor_document by editor test ' . time() . '</p>';
        my $request = MockRequest->new(
            node_id        => $admin_user->{node_id},
            title          => 'root',
            is_admin_flag  => 1,
            is_editor_flag => 1,
            nodedata       => $admin_user,
            postdata       => encode_utf8( JSON::encode_json( { doctext => $new_doctext } ) ),
        );

        my $result = $api->update( $request, $oppressor_doc->{node_id} );

        is( $result->[0], 200, 'Returns HTTP 200' );
        ok( $result->[1]->{success}, 'success is true for oppressor_document' );
        is( $result->[1]->{document}->{doctext}, $new_doctext, 'oppressor_document doctext was updated' );
        is( $result->[1]->{document}->{node_id}, $oppressor_doc->{node_id}, 'oppressor_document node_id matches' );
    }
};

# ==========================================
# Test: Author can update their own document
# ==========================================
subtest 'Author can update their own document' => sub {
    plan tests => 5;

    # Create a document as admin, then change ownership to regular_user
    my $test_doc_title = 'Test Document for Author Edit ' . time();
    $DB->insertNode($test_doc_title, 'document', $admin_user, {});
    my $author_doc = $DB->getNode($test_doc_title, 'document');

    SKIP: {
        skip "could not create test document", 5 unless $author_doc;

        # Change ownership to regular_user
        $author_doc->{author_user} = $regular_user->{node_id};
        $DB->updateNode($author_doc, -1);

        my $new_doctext = '<p>Updated by author ' . time() . '</p>';
        my $request = MockRequest->new(
            node_id        => $regular_user->{node_id},
            title          => 'e2e_user',
            is_admin_flag  => 0,
            is_editor_flag => 0,
            nodedata       => $regular_user,
            postdata       => encode_utf8( JSON::encode_json( { doctext => $new_doctext } ) ),
        );

        my $result = $api->update( $request, $author_doc->{node_id} );

        is( $result->[0], 200, 'Returns HTTP 200' );
        ok( $result->[1]->{success}, 'success is true for author editing own document' );
        is( $result->[1]->{document}->{doctext}, $new_doctext, 'doctext was updated by author' );
        is( $result->[1]->{document}->{node_id}, $author_doc->{node_id}, 'node_id matches' );
        is( $result->[1]->{document}->{title}, $test_doc_title, 'title matches' );

        # Cleanup
        $DB->sqlDelete('document', "document_id = $author_doc->{node_id}");
        $DB->sqlDelete('node', "node_id = $author_doc->{node_id}");
    }
};

# ==========================================
# Test: Non-editor cannot update document they don't own
# ==========================================
subtest 'Non-editor cannot update document they do not own' => sub {
    plan tests => 3;

    SKIP: {
        skip "document node not found", 3 unless $document_node;

        my $request = MockRequest->new(
            node_id        => $regular_user->{node_id},
            title          => 'e2e_user',
            is_admin_flag  => 0,
            is_editor_flag => 0,
            nodedata       => $regular_user,
            postdata       => encode_utf8( JSON::encode_json( { doctext => 'Unauthorized update' } ) ),
        );

        my $result = $api->update( $request, $document_node->{node_id} );

        is( $result->[0], 200, 'Returns HTTP 200' );
        ok( !$result->[1]->{success}, 'success is false for non-owner' );
        like( $result->[1]->{error}, qr/Permission denied/, 'error message indicates permission denied' );
    }
};

# ==========================================
# Test: Non-editor cannot update oppressor_document even if they own it
# ==========================================
subtest 'Non-editor cannot update oppressor_document even as author' => sub {
    plan tests => 4;

    # Create an oppressor_document as admin, then change ownership to regular_user
    my $test_opp_title = 'Test Oppressor for Author ' . time();
    $DB->insertNode($test_opp_title, 'oppressor_document', $admin_user, {});
    my $author_oppressor = $DB->getNode($test_opp_title, 'oppressor_document');

    SKIP: {
        skip "could not create test oppressor_document", 4 unless $author_oppressor;

        # Change ownership to regular_user
        $author_oppressor->{author_user} = $regular_user->{node_id};
        $DB->updateNode($author_oppressor, -1);

        # Verify it's owned by regular_user
        is( $author_oppressor->{author_user}, $regular_user->{node_id}, 'oppressor_document is owned by regular_user' );

        my $request = MockRequest->new(
            node_id        => $regular_user->{node_id},
            title          => 'e2e_user',
            is_admin_flag  => 0,
            is_editor_flag => 0,
            nodedata       => $regular_user,
            postdata       => encode_utf8( JSON::encode_json( { doctext => 'Author trying to edit oppressor' } ) ),
        );

        my $result = $api->update( $request, $author_oppressor->{node_id} );

        is( $result->[0], 200, 'Returns HTTP 200' );
        ok( !$result->[1]->{success}, 'success is false - author cannot edit oppressor_document' );
        like( $result->[1]->{error}, qr/Permission denied/, 'error indicates permission denied for oppressor type' );

        # Cleanup - oppressor_document inherits from document, so delete from document table
        $DB->sqlDelete('document', "document_id = $author_oppressor->{node_id}");
        $DB->sqlDelete('node', "node_id = $author_oppressor->{node_id}");
    }
};

# ==========================================
# Test: Missing doctext returns error
# ==========================================
subtest 'Missing doctext returns error' => sub {
    plan tests => 3;

    SKIP: {
        skip "document node not found", 3 unless $document_node;

        my $request = MockRequest->new(
            node_id        => $admin_user->{node_id},
            title          => 'root',
            is_admin_flag  => 1,
            is_editor_flag => 1,
            nodedata       => $admin_user,
            postdata       => encode_utf8( JSON::encode_json( { title => 'no doctext' } ) ),
        );

        my $result = $api->update( $request, $document_node->{node_id} );

        is( $result->[0], 200, 'Returns HTTP 200' );
        ok( !$result->[1]->{success}, 'success is false when missing doctext' );
        like( $result->[1]->{error}, qr/Missing doctext/, 'error message indicates missing doctext' );
    }
};

# ==========================================
# Test: Invalid node_id returns error
# ==========================================
subtest 'Invalid node_id returns error' => sub {
    plan tests => 3;

    my $request = MockRequest->new(
        node_id        => $admin_user->{node_id},
        title          => 'root',
        is_admin_flag  => 1,
        is_editor_flag => 1,
        nodedata       => $admin_user,
        postdata       => encode_utf8( JSON::encode_json( { doctext => 'Update attempt' } ) ),
    );

    my $result = $api->update( $request, 999999999 );

    is( $result->[0], 200, 'Returns HTTP 200' );
    ok( !$result->[1]->{success}, 'success is false for invalid node_id' );
    like( $result->[1]->{error}, qr/Document not found/, 'error message indicates document not found' );
};

# ==========================================
# Cleanup: Restore original doctexts
# ==========================================
END {
    if ($document_node && defined $original_document_doctext) {
        $document_node->{doctext} = $original_document_doctext;
        $DB->updateNode($document_node, -1);
    }
    if ($edevdoc_node && defined $original_edevdoc_doctext) {
        $edevdoc_node->{doctext} = $original_edevdoc_doctext;
        $DB->updateNode($edevdoc_node, -1);
    }
    if ($oppressor_doc && defined $original_oppressor_doctext) {
        $oppressor_doc->{doctext} = $original_oppressor_doctext;
        $DB->updateNode($oppressor_doc, -1);
    }
}

done_testing();
