package Everything::Controller::e2node;

use Moose;
extends 'Everything::Controller';

# Controller for e2node nodes
# Builds React data directly without a Page class intermediary.
# All e2nodes use this single controller regardless of their title.

sub display {
    my ( $self, $REQUEST, $node ) = @_;

    my $user = $REQUEST->user;

    # Build e2node data using Node methods (includes all writeups, softlinks, etc.)
    my $e2node = $node->json_display($user);

    # Build user permissions data
    my $VARS = $user->VARS;
    my $user_data = {
        node_id              => $user->node_id,
        title                => $user->title,
        is_guest             => $user->is_guest ? 1 : 0,
        is_editor            => $user->is_editor ? 1 : 0,
        can_vote             => ( !$user->is_guest && ( $user->votesleft || 0 ) > 0 ) ? 1 : 0,
        can_cool             => ( !$user->is_guest && ( $user->coolsleft || 0 ) > 0 ) ? 1 : 0,
        coolsleft            => $user->coolsleft || 0,
        votesafety           => int($VARS->{votesafety} || 0),
        coolsafety           => int($VARS->{coolsafety} || 0),
        info_authorsince_off => int($VARS->{info_authorsince_off} || 0)
    };

    # Check if user has an existing draft for this e2node title
    my $existing_draft;
    if ( !$user->is_guest ) {
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
                $node->title,
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
        type   => 'e2node',
        e2node => $e2node,
        user   => $user_data
    };

    # Add existing draft if found
    $content_data->{existing_draft} = $existing_draft if $existing_draft;

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node->NODEDATA,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our directly-built data
    $e2->{contentData}   = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout( '/pages/react_page', e2 => $e2, REQUEST => $REQUEST, node => $node );
    return [ $self->HTTP_OK, $html ];
}

__PACKAGE__->meta->make_immutable();
1;
