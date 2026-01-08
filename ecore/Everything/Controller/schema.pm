package Everything::Controller::schema;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# Schema Controller
#
# Handles display of schema nodes (XML schema definitions).
# Schemas are used for XML validation and extend the ticker nodetype.
#
# Features:
# - Display schema XML content with syntax highlighting
# - Show schema metadata (author, extends)
# - BasicEdit for raw editing (gods only)

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;
    my $node_data = $node->NODEDATA;

    # Get author info
    my $author_node = $node_data->{author_user}
        ? $APP->node_by_id($node_data->{author_user})
        : undef;

    my $author = $author_node ? {
        node_id => int($author_node->node_id),
        title   => $author_node->title
    } : { node_id => 0, title => 'Unknown' };

    # Get schema_extends info if set
    my $extends_node = $node_data->{schema_extends}
        ? $APP->node_by_id($node_data->{schema_extends})
        : undef;

    my $extends = $extends_node ? {
        node_id => int($extends_node->node_id),
        title   => $extends_node->title
    } : undef;

    # Build user data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0,
        is_admin  => $user->is_admin  ? 1 : 0
    };

    # Build source map for schema
    my $source_map = {
        githubRepo => 'https://github.com/everything2/everything2',
        branch     => 'master',
        commitHash => $APP->{conf}->last_commit || 'master',
        components => [
            {
                type        => 'controller',
                name        => 'Everything::Controller::schema',
                path        => 'ecore/Everything/Controller/schema.pm',
                description => 'Controller for schema display'
            },
            {
                type        => 'react_document',
                name        => 'Schema',
                path        => 'react/components/Documents/Schema.js',
                description => 'React document component for schema display'
            }
        ]
    };

    # Build contentData for React
    my $content_data = {
        type => 'schema',
        schema => {
            node_id       => int($node->node_id),
            title         => $node->title,
            doctext       => $node_data->{doctext} || '',
            author        => $author,
            extends       => $extends,
            createtime    => $node_data->{createtime},
            type_nodetype => $node_data->{type_nodetype}
        },
        user      => $user_data,
        sourceMap => $source_map
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
