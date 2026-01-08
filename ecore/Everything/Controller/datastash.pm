package Everything::Controller::datastash;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

use JSON;
use Encode qw(encode_utf8);

# Controller for datastash nodes
# Datastash nodes store JSON data in the setting.vars field

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;

    # Only gods can view datastash details
    unless ($APP->isAdmin($user->NODEDATA)) {
        return $self->error_page($REQUEST, 'Access denied', 'datastash display is restricted to administrators.');
    }

    my $node_data = $node->NODEDATA;
    my $vars_raw = $node_data->{vars} // '';

    # Parse JSON data - encode to UTF-8 bytes first as decode_json expects bytes
    my $parsed_data;
    my $parse_error;
    if ($vars_raw && $vars_raw ne '') {
        my $success = eval {
            my $json_bytes = encode_utf8($vars_raw);
            $parsed_data = decode_json($json_bytes);
            1;
        };
        if (!$success) {
            $parse_error = $@;
        }
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
        type => 'datastash',
        datastash => {
            node_id => $node->node_id,
            title => $node->title,
            vars_raw => $vars_raw,
            vars_length => length($vars_raw),
            parsed_data => $parsed_data,
            parse_error => $parse_error,
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

__PACKAGE__->meta->make_immutable();
1;
