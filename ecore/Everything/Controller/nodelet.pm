package Everything::Controller::nodelet;

use Moose;
extends 'Everything::Controller';

# Nodelet Controller
#
# Handles display of nodelet nodes (sidebar components).
# Provides a detailed view of nodelet configuration for developers.
#
# This replaces the legacy nodelet_display_page htmlpage function
# which used insertNodelet() to render nodelet content.

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $node_data = $node->NODEDATA;

    # Nodelet nodes are only viewable by logged-in users
    # Guest users shouldn't see nodelet source/configuration
    if ($user->is_guest) {
        return [$self->HTTP_FOUND, '', {Location => '/title/Login'}];
    }

    # Get nodelet data
    my $nodelet_data = $node->json_display($user);

    # Check if this nodelet has a React component
    my $nodelet_name = $node->title;
    $nodelet_name =~ s/\s+//g;  # Remove spaces for component name
    my $react_path = $self->APP->{conf}->everything_root . "/react/components/Nodelets/$nodelet_name.js";
    my $has_react_component = -e $react_path ? 1 : 0;

    # Preview of nlcode and nltext for developers (first 500 chars)
    my $nlcode_preview = $node_data->{nlcode} ? substr($node_data->{nlcode}, 0, 500) : '';
    my $nltext_preview = $node_data->{nltext} ? substr($node_data->{nltext}, 0, 500) : '';

    # Add ellipsis if truncated
    $nlcode_preview .= '...' if length($node_data->{nlcode} || '') > 500;
    $nltext_preview .= '...' if length($node_data->{nltext} || '') > 500;

    # Build user data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0
    };

    # Build source map for nodelet
    my $source_map = {
        githubRepo => 'https://github.com/everything2/everything2',
        branch     => 'master',
        commitHash => $self->APP->{conf}->last_commit || 'master',
        components => [
            {
                type        => 'controller',
                name        => 'Everything::Controller::nodelet',
                path        => 'ecore/Everything/Controller/nodelet.pm',
                description => 'Controller for nodelet display'
            },
            {
                type        => 'react_document',
                name        => 'Nodelet',
                path        => 'react/components/Documents/Nodelet.js',
                description => 'React document component for nodelet display'
            }
        ]
    };

    # Add React nodelet component if it exists
    if ($has_react_component) {
        push @{$source_map->{components}}, {
            type        => 'react_component',
            name        => $nodelet_name,
            path        => "react/components/Nodelets/$nodelet_name.js",
            description => 'React component for sidebar rendering'
        };
    }

    # Build contentData for React
    my $content_data = {
        type    => 'nodelet',
        nodelet => {
            %$nodelet_data,
            updateinterval       => $node_data->{updateinterval} || 0,
            parent_container     => $node_data->{parent_container} || 0,
            nlcode_preview       => $nlcode_preview,
            nltext_preview       => $nltext_preview,
            has_react_component  => $has_react_component
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

# edit - redirect to basicedit for nodelet editing
# The legacy nodelet edit page is replaced by the basicedit functionality
sub edit {
    my ($self, $REQUEST, $node) = @_;

    # Redirect to basicedit displaytype
    return $self->basicedit($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable;
1;
