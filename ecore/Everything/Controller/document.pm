package Everything::Controller::document;

use Moose;
extends 'Everything::Controller';

# Controller for document nodes (nodetype 3)
# Builds React data directly - all document nodes use this controller

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $displaytype = $REQUEST->param('displaytype') // 'display';

    # Get document data
    my $doctext = $node->doctext // '';
    my $author = $self->DB->getNodeById($node->author_user);

    # Determine if user can edit this document
    # Editors can edit any document, authors can edit their own
    my $can_edit = 0;
    if (!$user->is_guest) {
        if ($self->APP->isEditor($user->NODEDATA)) {
            $can_edit = 1;
        } elsif ($node->author_user == $user->node_id) {
            $can_edit = 1;
        }
    }

    # If displaytype is 'edit' but user can't edit, fall back to display
    if ($displaytype eq 'edit' && !$can_edit) {
        $displaytype = 'display';
    }

    # Build user data
    my $user_data = {
        node_id  => $user->node_id,
        title    => $user->title,
        is_guest => $user->is_guest ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin => $user->is_admin ? 1 : 0,
    };

    # Build contentData for React
    my $content_data = {
        type => 'document',
        displaytype => $displaytype,
        document => {
            node_id => $node->node_id,
            title => $node->title,
            doctext => $doctext,
            author => $author ? {
                node_id => $author->{node_id},
                title => $author->{title},
            } : undef,
            edittime => $node->NODEDATA->{edittime},
            createtime => $node->NODEDATA->{createtime},
        },
        can_edit => $can_edit,
        user => $user_data,
    };

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
    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout(
        '/pages/react_page',
        e2 => $e2,
        REQUEST => $REQUEST,
        node => $node
    );

    return [$self->HTTP_OK, $html];
}

sub edit {
    my ($self, $REQUEST, $node) = @_;

    # For edit mode, just set displaytype param and call display
    $REQUEST->param('displaytype', 'edit');
    return $self->display($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable();
1;
