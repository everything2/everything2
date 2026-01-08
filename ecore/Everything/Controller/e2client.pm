package Everything::Controller::e2client;

use Moose;
extends 'Everything::Controller';

# Controller for e2client nodes
# E2clients are API client applications registered by members of the clientdev usergroup

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    my $node_data = $node->NODEDATA;
    my $is_guest = $user->is_guest ? 1 : 0;
    my $is_admin = $user->is_admin ? 1 : 0;

    # Check if user can edit this e2client (clientdev group or admin)
    my $can_edit = $DB->canUpdateNode($user->NODEDATA, $node->NODEDATA) ? 1 : 0;

    # Get author info
    my $author = $APP->node_by_id($node_data->{author_user});
    my $author_data = $author ? {
        node_id => int($author->node_id),
        title => $author->title
    } : { node_id => 0, title => 'Unknown' };

    # Get doctext from document table
    my $doctext = $DB->sqlSelect('doctext', 'document', "document_id = " . $node->node_id) || '';

    # Build e2client data
    my $e2client_data = {
        node_id => int($node->node_id),
        title => $node->title,
        version => $node_data->{version} || '',
        homeurl => $node_data->{homeurl} || '',
        dlurl => $node_data->{dlurl} || '',
        clientstr => $node_data->{clientstr} || '',
        doctext => $doctext,
        author => $author_data,
        createtime => $node_data->{createtime} || '',
    };

    # Build contentData for React
    my $content_data = {
        type => 'e2client',
        e2client => $e2client_data,
        can_edit => $can_edit,
        is_guest => $is_guest,
        is_admin => $is_admin,
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
        $node_data,
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

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Check edit permission
    unless ($DB->canUpdateNode($user->NODEDATA, $node->NODEDATA)) {
        # Redirect to display if can't edit
        return $self->display($REQUEST, $node);
    }

    my $node_data = $node->NODEDATA;

    # Get author info
    my $author = $APP->node_by_id($node_data->{author_user});
    my $author_data = $author ? {
        node_id => int($author->node_id),
        title => $author->title
    } : { node_id => 0, title => 'Unknown' };

    # Get doctext from document table
    my $doctext = $DB->sqlSelect('doctext', 'document', "document_id = " . $node->node_id) || '';

    # Build e2client data for editing
    my $e2client_data = {
        node_id => int($node->node_id),
        title => $node->title,
        version => $node_data->{version} || '',
        homeurl => $node_data->{homeurl} || '',
        dlurl => $node_data->{dlurl} || '',
        clientstr => $node_data->{clientstr} || '',
        doctext => $doctext,
        author => $author_data,
    };

    # Build contentData for React
    my $content_data = {
        type => 'e2client_edit',
        e2client => $e2client_data,
        is_admin => $user->is_admin ? 1 : 0,
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
        $node_data,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our edit data
    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout
    my $html = $self->layout(
        '/pages/react_page',
        e2 => $e2,
        REQUEST => $REQUEST,
        node => $node
    );

    return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable;
1;
