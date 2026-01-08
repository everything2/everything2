package Everything::Controller::setting;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

use JSON;

# Controller for setting nodes
# Settings store key-value pairs in the vars field
# Only admins can view and edit settings

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;

    # Only gods can view setting details
    unless ($APP->isAdmin($user->NODEDATA)) {
        return $self->error_page($REQUEST, 'Access denied', 'Setting display is restricted to administrators.');
    }

    my $displaytype = $REQUEST->param('displaytype') // 'display';

    # Get vars for this setting
    my $vars = Everything::getVars($node->NODEDATA) || {};

    # Build sorted list of key-value pairs for display
    my @vars_list;
    foreach my $key (sort keys %$vars) {
        push @vars_list, {
            key => $key,
            value => $vars->{$key}
        };
    }

    # Build user data
    my $user_data = {
        node_id  => $user->node_id,
        title    => $user->title,
        is_guest => $user->is_guest ? 1 : 0,
        is_admin => $user->is_admin ? 1 : 0,
    };

    # Build contentData for React
    my $content_data = {
        type => 'setting',
        displaytype => $displaytype,
        setting => {
            node_id => $node->node_id,
            title => $node->title,
            vars => \@vars_list,
            vars_count => scalar(@vars_list),
        },
        user => $user_data,
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
