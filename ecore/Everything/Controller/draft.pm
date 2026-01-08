package Everything::Controller::draft;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# Controller for draft nodes
# Builds React data for draft display, similar to writeup controller.
# Replaces legacy htmlpage draft_display_page with React-based rendering.
# Edit is inline on display page; basicedit available for admins via BasicEdit role.

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Check draft visibility permissions
    unless ($APP->canSeeDraft($user->NODEDATA, $node->NODEDATA)) {
        # User cannot see this draft - redirect to search results
        my $search_node = $DB->getNodeById($self->CONF->search_results);
        return $self->CONTROLLER_TABLE->{$search_node->{type}{title}}->display($REQUEST, $APP->node_by_id($search_node->{node_id}));
    }

    # Build draft data similar to writeup display
    my $draft_data = $self->_build_draft_data($node, $user);

    # Build user permissions data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin  ? 1 : 0,
    };

    # Build contentData for React
    my $content_data = {
        type  => 'draft',
        draft => $draft_data,
        user  => $user_data
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
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
    my $html = $self->layout(
        '/pages/react_page',
        e2      => $e2,
        REQUEST => $REQUEST,
        node    => $node
    );
    return [$self->HTTP_OK, $html];
}

sub _build_draft_data {
    my ($self, $node, $user) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $nodedata = $node->NODEDATA;

    # Get publication status from NODEDATA (draft table field)
    my $pub_status_id = $nodedata->{publication_status};
    my $pub_status_node = $pub_status_id ? $DB->getNodeById($pub_status_id) : undef;
    my $publication_status = $pub_status_node ? $pub_status_node->{title} : 'unknown';

    # Get author info
    my $author_node = $DB->getNodeById($node->author_user);
    my $author = $author_node ? {
        node_id => $author_node->{node_id},
        title   => $author_node->{title}
    } : undef;

    # Check if current user is the author
    my $is_author = !$user->is_guest && $node->author_user == $user->node_id;

    # Check edit permissions
    my $can_edit = $is_author || $APP->canSeeDraft($user->NODEDATA, $nodedata, 'edit');

    # Get parent e2node if linked
    my $parent_e2node = undef;
    my $linktype = $DB->getId($DB->getNode('parent_node', 'linktype'));
    if ($linktype) {
        my $parent_id = $DB->sqlSelect('to_node', 'links',
            "from_node=" . $node->node_id . " AND linktype=$linktype");
        if ($parent_id) {
            my $parent_node = $DB->getNodeById($parent_id);
            if ($parent_node) {
                $parent_e2node = {
                    node_id => $parent_node->{node_id},
                    title   => $parent_node->{title}
                };
            }
        }
    }

    # Get collaborators from NODEDATA (draft table field)
    my $collaborators = $nodedata->{collaborators} || '';

    # Build draft data structure
    return {
        node_id            => $node->node_id,
        title              => $node->title,
        doctext            => $node->doctext || '',
        author             => $author,
        is_author          => $is_author ? 1 : 0,
        can_edit           => $can_edit ? 1 : 0,
        publication_status => $publication_status,
        collaborators      => $collaborators,
        parent_e2node      => $parent_e2node,
        createtime         => $node->createtime
    };
}

# Edit displaytype - drafts are edited inline on the display page
sub edit {
    my ($self, $REQUEST, $node) = @_;
    return $self->display($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable();
1;
