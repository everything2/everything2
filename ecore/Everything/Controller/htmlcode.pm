package Everything::Controller::htmlcode;

use Moose;
extends 'Everything::Controller';

# Htmlcode Controller
#
# Handles display of htmlcode nodes (reusable Perl code snippets).
# Provides a detailed view of htmlcode configuration for developers.
#
# This replaces the legacy htmlcode_display_page and htmlcode_edit_page
# htmlpage functions.

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $node_data = $node->NODEDATA;

    # Get htmlcode data
    my $htmlcode_data = $node->json_display($user);

    # Check if this htmlcode is delegated (code moved to codebase)
    my $is_delegated = $self->_is_delegated($node->title);

    # Preview of code for developers (first 500 chars)
    my $code_preview = $node_data->{code} ? substr($node_data->{code}, 0, 500) : '';
    $code_preview .= '...' if length($node_data->{code} || '') > 500;

    # Build user data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0
    };

    # Build source map for htmlcode
    my $source_map = {
        githubRepo => 'https://github.com/everything2/everything2',
        branch     => 'master',
        commitHash => $self->APP->{conf}->last_commit || 'master',
        components => [
            {
                type        => 'controller',
                name        => 'Everything::Controller::htmlcode',
                path        => 'ecore/Everything/Controller/htmlcode.pm',
                description => 'Controller for htmlcode display'
            },
            {
                type        => 'react_document',
                name        => 'Htmlcode',
                path        => 'react/components/Documents/Htmlcode.js',
                description => 'React document component for htmlcode display'
            }
        ]
    };

    # Add delegation module if this htmlcode is delegated
    if ($is_delegated) {
        push @{$source_map->{components}}, {
            type        => 'delegation',
            name        => 'Everything::Delegation::htmlcode',
            path        => 'ecore/Everything/Delegation/htmlcode.pm',
            description => 'Delegated htmlcode implementations'
        };
    }

    # Build contentData for React
    my $content_data = {
        type     => 'htmlcode',
        htmlcode => {
            %$htmlcode_data,
            code_preview  => $code_preview,
            is_delegated  => $is_delegated ? 1 : 0,
            type_nodetype => $node_data->{type_nodetype}
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

# Check if an htmlcode has been delegated to the codebase
sub _is_delegated {
    my ($self, $title) = @_;

    # Check if there's a matching sub in Everything::Delegation::htmlcode
    my $sub_name = $title;
    $sub_name =~ s/\s+/_/g;  # Replace spaces with underscores

    # Check if the sub exists using can()
    return Everything::Delegation::htmlcode->can($sub_name) ? 1 : 0;
}

# edit - redirect to basicedit for htmlcode editing
# The legacy htmlcode edit page is replaced by the basicedit functionality
sub edit {
    my ($self, $REQUEST, $node) = @_;

    # Redirect to basicedit displaytype
    return $self->basicedit($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable;
1;
