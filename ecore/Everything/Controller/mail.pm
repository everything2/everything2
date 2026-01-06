package Everything::Controller::mail;

use Moose;
extends 'Everything::Controller';

# Controller for mail nodes
# Migrated from Everything::Delegation::htmlpage::mail_display_page
# Edit uses standard basicedit form (inherited from base Controller)

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;

    # Get mail-specific data
    my $from_address = $node->NODEDATA->{from_address} // '';
    my $doctext = $node->doctext // '';

    # Get recipient (author_user is the "To" field for mail)
    my $recipient_id = $node->author_user;
    my $recipient = $recipient_id ? $self->DB->getNodeById($recipient_id) : undef;

    # Determine if user can edit this mail
    my $can_edit = 0;
    if (!$user->is_guest && $self->APP->isAdmin($user->NODEDATA)) {
        $can_edit = 1;
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
        type => 'mail',
        mail => {
            node_id => $node->node_id,
            title => $node->title,
            doctext => $doctext,
            from_address => $from_address,
            recipient => $recipient ? {
                node_id => int($recipient->{node_id}),
                title => $recipient->{title},
            } : undef,
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

    # Mail edit uses the standard basicedit form (gods-only)
    return $self->basicedit($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable();
1;
