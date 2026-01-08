package Everything::Controller::stylesheet;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# Stylesheet Controller
#
# Handles display and edit of stylesheet nodes (CSS stylesheets).
# Stylesheets define visual themes for Everything2.
#
# Features:
# - Display CSS content with syntax highlighting
# - Show supported status and metadata
# - GitHub source map for developers
# - BasicEdit for raw editing (gods only)

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->APP->{nodebase};
    my $node_data = $node->NODEDATA;

    # Get the CSS content from document table
    my $doctext = $node_data->{doctext} || '';

    # Get author info
    my $author_node = $node_data->{author_user}
        ? $self->APP->node_by_id($node_data->{author_user})
        : undef;

    my $author_info = $author_node ? {
        node_id => int($author_node->node_id),
        title   => $author_node->title
    } : undef;

    # Check if this stylesheet is supported (listed in settings)
    my $is_supported = $node->supported ? 1 : 0;

    # Get CSS size info
    my $css_length = length($doctext);
    my $css_lines = $doctext ? scalar(split(/\n/, $doctext)) : 0;

    # Build user data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin  ? 1 : 0
    };

    # Build source map for stylesheet
    my $source_map = {
        githubRepo => 'https://github.com/everything2/everything2',
        branch     => 'master',
        commitHash => $self->APP->{conf}->last_commit || 'master',
        components => [
            {
                type        => 'controller',
                name        => 'Everything::Controller::stylesheet',
                path        => 'ecore/Everything/Controller/stylesheet.pm',
                description => 'Controller for stylesheet display'
            },
            {
                type        => 'react_document',
                name        => 'Stylesheet',
                path        => 'react/components/Documents/Stylesheet.js',
                description => 'React document component for stylesheet display'
            },
            {
                type        => 'node_class',
                name        => 'Everything::Node::stylesheet',
                path        => 'ecore/Everything/Node/stylesheet.pm',
                description => 'Stylesheet node class'
            },
            {
                type        => 'css_file',
                name        => $node->title,
                path        => "css/" . $node->node_id . ".css",
                description => 'Rendered CSS file (via S3)',
                externalUrl => "/css/" . $node->node_id . ".css"
            }
        ]
    };

    # Build contentData for React
    my $content_data = {
        type       => 'stylesheet',
        stylesheet => {
            node_id       => int($node->node_id),
            title         => $node->title,
            doctext       => $doctext,
            createtime    => $node_data->{createtime},
            edittime      => $node_data->{edittime},
            author        => $author_info,
            is_supported  => $is_supported,
            css_length    => $css_length,
            css_lines     => $css_lines,
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

__PACKAGE__->meta->make_immutable;
1;
