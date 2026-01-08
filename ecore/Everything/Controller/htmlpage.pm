package Everything::Controller::htmlpage;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# Htmlpage Controller
#
# Handles display of htmlpage nodes (legacy page templates).
# Most htmlpage functionality has been migrated to Everything::Page classes.
#
# This replaces the legacy htmlpage_display_page and htmlpage_edit_page
# delegation functions.

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $node_data = $node->NODEDATA;

    # Get htmlpage data
    my $htmlpage_data = $node->json_display($user);

    # Check if this htmlpage is delegated (code moved to codebase)
    my $is_delegated = $self->_is_delegated($node->title);

    # Get pagetype title
    my $pagetype_title;
    if ($node_data->{pagetype_nodetype}) {
        my $pagetype_node = $self->APP->node_by_id($node_data->{pagetype_nodetype});
        $pagetype_title = $pagetype_node ? $pagetype_node->title : undef;
    }

    # Preview of page code for developers (first 500 chars)
    my $page_preview = $node_data->{page} ? substr($node_data->{page}, 0, 500) : '';
    $page_preview .= '...' if length($node_data->{page} || '') > 500;

    # Build user data
    my $user_data = {
        node_id   => $user->node_id,
        title     => $user->title,
        is_guest  => $user->is_guest  ? 1 : 0,
        is_editor => $user->is_editor ? 1 : 0
    };

    # Build source map for htmlpage
    my $source_map = {
        githubRepo => 'https://github.com/everything2/everything2',
        branch     => 'master',
        commitHash => $self->APP->{conf}->last_commit || 'master',
        components => [
            {
                type        => 'controller',
                name        => 'Everything::Controller::htmlpage',
                path        => 'ecore/Everything/Controller/htmlpage.pm',
                description => 'Controller for htmlpage display'
            },
            {
                type        => 'react_document',
                name        => 'Htmlpage',
                path        => 'react/components/Documents/Htmlpage.js',
                description => 'React document component for htmlpage display'
            }
        ]
    };

    # Add delegation module if this htmlpage is delegated
    if ($is_delegated) {
        push @{$source_map->{components}}, {
            type        => 'delegation',
            name        => 'Everything::Delegation::htmlpage',
            path        => 'ecore/Everything/Delegation/htmlpage.pm',
            description => 'Delegated htmlpage implementations'
        };
    }

    # Build contentData for React
    my $content_data = {
        type     => 'htmlpage',
        htmlpage => {
            %$htmlpage_data,
            pagetype_nodetype => $node_data->{pagetype_nodetype} || 0,
            pagetype_title    => $pagetype_title,
            displaytype       => $node_data->{displaytype} || '',
            mimetype          => $node_data->{mimetype} || '',
            parent_container  => $node_data->{parent_container} || 0,
            page_preview      => $page_preview,
            is_delegated      => $is_delegated ? 1 : 0,
            type_nodetype     => $node_data->{type_nodetype}
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

# Check if an htmlpage has been delegated to the codebase
sub _is_delegated {
    my ($self, $title) = @_;

    # Check if there's a matching sub in Everything::Delegation::htmlpage
    my $sub_name = $title;
    $sub_name =~ s/\s+/_/g;  # Replace spaces with underscores

    # Check if the sub exists using can()
    return Everything::Delegation::htmlpage->can($sub_name) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;
1;
