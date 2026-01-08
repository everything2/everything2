package Everything::Controller::notification;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# Controller for notification nodes
# System nodes that define notification types and their display/validation code
# Edit uses basicedit via the BasicEdit role

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $APP  = $self->APP;
    my $NODE = $node->NODEDATA;

    # Get code preview (first 2000 chars) for display code
    my $code_preview;
    if ($NODE->{code}) {
        $code_preview = length($NODE->{code}) > 2000
            ? substr($NODE->{code}, 0, 2000) . "\n... (truncated)"
            : $NODE->{code};
    }

    # Get invalid_check code preview
    my $invalid_check_preview;
    if ($NODE->{invalid_check}) {
        $invalid_check_preview = length($NODE->{invalid_check}) > 2000
            ? substr($NODE->{invalid_check}, 0, 2000) . "\n... (truncated)"
            : $NODE->{invalid_check};
    }

    # Build user data
    my $user_data = {
        node_id      => $user->node_id,
        title        => $user->title,
        is_guest     => $user->is_guest     ? 1 : 0,
        is_editor    => $user->is_editor    ? 1 : 0,
        is_developer => $user->is_developer ? 1 : 0,
        is_admin     => $user->is_admin     ? 1 : 0
    };

    # Build source map for developers
    my $source_map = {
        githubRepo => 'https://github.com/everything2/everything2',
        branch     => 'master',
        commitHash => $self->APP->{conf}->last_commit || 'master',
        components => [
            {
                type        => 'controller',
                name        => 'Everything::Controller::notification',
                path        => 'ecore/Everything/Controller/notification.pm',
                description => 'Controller for notification display'
            },
            {
                type        => 'react_document',
                name        => 'Notification',
                path        => 'react/components/Documents/Notification.js',
                description => 'React document component for notification display'
            },
            {
                type        => 'htmlcode',
                name        => 'canseeNotification',
                path        => 'nodepack/htmlcode/canseeNotification.xml',
                description => 'Security check for notification visibility'
            },
            {
                type        => 'htmlcode',
                name        => 'Notifications nodelet settings',
                path        => 'nodepack/htmlcode/Notifications%20nodelet%20settings.xml',
                description => 'User settings for notifications'
            }
        ]
    };

    # Build contentData for React
    my $content_data = {
        type         => 'notification',
        notification => {
            node_id               => $NODE->{node_id},
            title                 => $NODE->{title},
            type                  => 'notification',
            description           => $NODE->{description},
            hourLimit             => $NODE->{hourLimit},
            code_preview          => $code_preview,
            invalid_check_preview => $invalid_check_preview,
            createtime            => $NODE->{createtime}
        },
        user      => $user_data,
        sourceMap => $source_map
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $self->APP->buildNodeInfoStructure(
        $NODE,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our directly-built data
    $e2->{contentData}   = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout
    my $html = $self->layout(
        '/pages/react_page',
        e2      => $e2,
        REQUEST => $REQUEST,
        node    => $node
    );
    return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable();
1;
