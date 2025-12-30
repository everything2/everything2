package Everything::Controller::writeup;

use Moose;
extends 'Everything::Controller';

# Controller for writeup nodes
# Builds React data directly without a Page class intermediary.
# All writeups use this single controller regardless of their title.

sub display {
    my ( $self, $REQUEST, $node ) = @_;

    my $user = $REQUEST->user;

    # Build writeup data using Node methods
    my $writeup = $node->single_writeup_display($user);

    # Build user permissions data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin  ? 1 : 0,
        can_vote  => ( !$user->is_guest && ( $user->votesleft || 0 ) > 0 ) ? 1
        : 0,
        can_cool => ( !$user->is_guest && ( $user->coolsleft || 0 ) > 0 ) ? 1
        : 0,
        coolsleft => $user->coolsleft || 0
    };

    # Get parent e2node data for:
    # 1. Editing (editors or writeup owner)
    # 2. Adding new writeups (any logged-in user who doesn't have one yet)
    my $parent_e2node_data;
    my $parent_node;
    my $is_owner = !$user->is_guest && $node->author_user == $user->node_id;
    # Provide parent data to all logged-in users so they can add writeups
    if ( !$user->is_guest ) {
        $parent_node = $node->parent;
        if ( $parent_node && !UNIVERSAL::isa($parent_node, "Everything::Node::null") ) {
            $parent_e2node_data = $parent_node->json_display($user);
        }
    }

    # Check if user has an existing draft for the parent e2node title
    my $existing_draft;
    if ( !$user->is_guest && $parent_node && !UNIVERSAL::isa($parent_node, "Everything::Node::null") ) {
        my $DB         = $self->DB;
        my $draft_type = $DB->getType('draft');
        if ($draft_type) {
            my $draft_row = $DB->{dbh}->selectrow_hashref(
                q|SELECT node.node_id, node.title, document.doctext
                  FROM node
                  JOIN document ON document.document_id = node.node_id
                  WHERE node.title = ?
                  AND node.type_nodetype = ?
                  AND node.author_user = ?
                  LIMIT 1|,
                {},
                $parent_node->title,
                $draft_type->{node_id},
                $user->node_id
            );
            if ($draft_row) {
                $existing_draft = {
                    node_id => $draft_row->{node_id},
                    title   => $draft_row->{title},
                    doctext => $draft_row->{doctext} // ''
                };
            }
        }
    }

    # Build contentData for React
    my $content_data = {
        type    => 'writeup',
        writeup => $writeup,
        user    => $user_data
    };

    # Add parent e2node if available (for E2 Node Tools modal)
    $content_data->{parent_e2node} = $parent_e2node_data if $parent_e2node_data;

    # Add existing draft if found (for continuing draft on parent e2node)
    $content_data->{existing_draft} = $existing_draft if $existing_draft;

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 =
      $self->APP->buildNodeInfoStructure( $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS, $REQUEST->cgi, $REQUEST );

    # Override contentData with our directly-built data
    $e2->{contentData}   = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout(
        '/pages/react_page',
        e2      => $e2,
        REQUEST => $REQUEST,
        node    => $node
    );
    return [ $self->HTTP_OK, $html ];
}

__PACKAGE__->meta->make_immutable();
1;
