package Everything::Controller::container;

use Moose;
extends 'Everything::Controller';

# Container Controller
#
# Handles display of container nodes (layout templates).
# Provides a detailed view of container configuration for developers.
#
# This replaces the legacy container_display_page and container_edit_page
# htmlpage functions.

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $node_data = $node->NODEDATA;

    # Get container data
    my $container_data = $node->json_display($user);

    # Preview of context for developers (first 500 chars)
    my $context_preview = $node_data->{context} ? substr($node_data->{context}, 0, 500) : '';
    $context_preview .= '...' if length($node_data->{context} || '') > 500;

    # Build user data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0
    };

    # Build source map for container
    my $source_map = {
        githubRepo => 'https://github.com/everything2/everything2',
        branch     => 'master',
        commitHash => $self->APP->{conf}->last_commit || 'master',
        components => [
            {
                type        => 'controller',
                name        => 'Everything::Controller::container',
                path        => 'ecore/Everything/Controller/container.pm',
                description => 'Controller for container display'
            },
            {
                type        => 'react_document',
                name        => 'Container',
                path        => 'react/components/Documents/Container.js',
                description => 'React document component for container display'
            }
        ]
    };

    # Build contentData for React
    my $content_data = {
        type      => 'container',
        container => {
            %$container_data,
            parent_container => $node_data->{parent_container} || 0,
            context_preview  => $context_preview,
            type_nodetype    => $node_data->{type_nodetype}
        },
        user      => $user_data,
        sourceMap => $source_map
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $node_data,
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

# edit - redirect to basicedit for container editing
# The legacy container edit page is replaced by the basicedit functionality
sub edit {
    my ($self, $REQUEST, $node) = @_;

    # Redirect to basicedit displaytype
    return $self->basicedit($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable;
1;
