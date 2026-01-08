package Everything::Controller::room;

use Moose;
extends 'Everything::Controller';

# Controller for room nodes
# Migrated from Everything::Delegation::htmlpage::room_display_page
# Edit uses standard basicedit form

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;
    my $DB = $self->DB;
    my $NODE = $node->NODEDATA;
    my $USER = $user->NODEDATA;
    my $VARS = $user->VARS;

    # Handle roomlocked parameter if provided (admin toggle)
    if (defined $REQUEST->param('roomlocked') && $APP->isAdmin($USER)) {
        $NODE->{roomlocked} = $REQUEST->param('roomlocked');
        $DB->updateNode($NODE, -1);
    }

    my $is_admin = $APP->isAdmin($USER) ? 1 : 0;
    my $is_guest = $user->is_guest ? 1 : 0;
    my $roomlocked = $NODE->{roomlocked} || 0;

    # Check if user can enter this room
    my $can_enter = 0;
    my $entered = 0;

    if (!$is_guest && $APP->canEnterRoom($NODE, $USER, $VARS)) {
        $can_enter = 1;
        # Actually enter the room
        $APP->changeRoom($USER, $NODE);
        # Update room usage date
        my (undef, undef, undef, $day, $mon, $year) = localtime();
        $NODE->{lastused_date} = join "-", ($year + 1900, ++$mon, $day);
        $DB->updateNode($NODE, -1);
        $entered = 1;
    }

    # Get doctext for room description (parse E2 links on React side)
    my $doctext = $NODE->{doctext} || '';

    # Get "go outside" superdoc for link
    my $go_outside = $DB->getNode("go outside", "superdocnolinks");
    my $go_outside_id = $go_outside ? $go_outside->{node_id} : 0;

    # Build content data for React
    my $content_data = {
        type => 'room',
        room => {
            node_id => $node->node_id,
            title => $node->title,
            doctext => $doctext,
            roomlocked => $roomlocked ? 1 : 0,
        },
        is_admin => $is_admin,
        is_guest => $is_guest,
        can_enter => $can_enter,
        entered => $entered,
        go_outside_id => $go_outside_id,
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
        $NODE,
        $USER,
        $VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData
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

sub edit {
    my ($self, $REQUEST, $node) = @_;

    # room edit uses the standard basicedit form
    return $self->basicedit($REQUEST, $node);
}

__PACKAGE__->meta->make_immutable();
1;
