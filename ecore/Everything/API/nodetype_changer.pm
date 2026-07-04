package Everything::API::nodetype_changer;

use Moose;
extends 'Everything::API';

# POST /api/nodetype_changer/lookup | /change -- admin-only (#4461, Refs #4298). Changes
# any node's nodetype. Replaces the render-time sqlUpdate in
# Everything::Page::nodetype_changer's buildReactData.
#
# Safety: the "change" endpoint refuses a target type that is permanently cached
# (usergroup/setting/datastash/room -- $Everything::CONF->permanent_cache) unless
# confirmed => 1. Enlisting a node in the permanent cache is fleet-wide (never LRU-evicted,
# version-checked at runtime, held across every worker), so a mistake there is far more
# disruptive than a normal type flip.

sub routes {
    return {
        'lookup' => 'lookup_node',
        'change' => 'change_type',
    };
}

sub lookup_node {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'This tool is restricted to administrators.'}]
        unless $user->is_admin;

    my $data    = $REQUEST->JSON_POSTDATA;
    my $node_id = $data->{node_id};
    return [$self->HTTP_OK, {success => 0, error => 'A node id is required.'}]
        unless (defined $node_id && $node_id =~ /^\d+$/);

    my $N = $self->DB->getNodeById(int($node_id));
    return [$self->HTTP_OK, {success => 0, error => "Node $node_id not found."}]
        unless $N;

    my $ct = $self->DB->getNodeById($N->{type_nodetype}, 'light');

    return [$self->HTTP_OK, {success => 1, target => {
        node_id      => int($N->{node_id}),
        title        => $N->{title},
        current_type => $ct ? $ct->{title} : 'unknown',
        type_id      => int($N->{type_nodetype}),
    }}];
}

sub change_type {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'This tool is restricted to administrators.'}]
        unless $user->is_admin;

    my $data      = $REQUEST->JSON_POSTDATA;
    my $change_id = $data->{change_id};
    my $new_type  = $data->{new_nodetype};

    return [$self->HTTP_OK, {success => 0, error => 'A node id to change is required.'}]
        unless (defined $change_id && $change_id =~ /^\d+$/);
    return [$self->HTTP_OK, {success => 0, error => 'A target nodetype is required.'}]
        unless (defined $new_type && $new_type =~ /^\d+$/);

    my $target = $self->DB->getNodeById(int($change_id));
    return [$self->HTTP_OK, {success => 0, error => "Node $change_id not found."}]
        unless $target;

    # The destination must actually be a nodetype.
    my $nodetype_type = $self->DB->getType('nodetype');
    my $tt = $self->DB->getNodeById(int($new_type), 'light');
    return [$self->HTTP_OK, {success => 0, error => 'The target nodetype is not a valid nodetype.'}]
        unless ($tt && $tt->{type_nodetype} == $nodetype_type->{node_id});

    my $type_title = $tt->{title};

    # Guard: changing INTO a permanently-cached type enlists this node in the permanent
    # cache across all workers -- require an explicit confirm.
    if (exists $Everything::CONF->permanent_cache->{$type_title} && !$data->{confirmed}) {
        return [$self->HTTP_OK, {
            success       => 0,
            needs_confirm => 1,
            type_title    => $type_title,
            warning       => "'$type_title' is a permanently-cached type. Once "
                . "'$target->{title}' is this type it can't be edited through this interface "
                . "until the servers restart -- these nodes are controlled by the deployment "
                . "system. Only do this if you know exactly what you are doing. Re-submit to "
                . "confirm.",
        }];
    }

    $self->DB->sqlUpdate('node', {type_nodetype => int($new_type)}, 'node_id=' . int($change_id));

    return [$self->HTTP_OK, {
        success => 1,
        message => "'$target->{title}' was changed to type '$type_title'.",
        target  => {
            node_id      => int($target->{node_id}),
            title        => $target->{title},
            current_type => $type_title,
            type_id      => int($new_type),
        },
    }];
}

__PACKAGE__->meta->make_immutable;

1;
