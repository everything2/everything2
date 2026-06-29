package Everything::API::nodeforbiddance;

use Moose;
extends 'Everything::API';

# POST /api/nodeforbiddance/{forbid,unforbid} -- admin-only (#4408). Replaces the
# render-time nodelock mutations in Everything::Page::node_forbiddance, where a
# POST `forbid` and (worse) a GET `?unforbid=` link wrote nodelock inside
# buildReactData. The page node is a restricted_superdoc, but an /api/ route
# bypasses node perms, so both actions gate on is_admin here.

sub routes {
    return {
        'forbid'   => 'forbid_user',
        'unforbid' => 'unforbid_user',
    };
}

sub forbid_user {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Admin access required'}]
        unless $user->is_admin;

    my $data   = $REQUEST->JSON_POSTDATA;
    my $target = $data->{user};
    my $reason = defined $data->{reason} ? $data->{reason} : '';

    return [$self->HTTP_OK, {success => 0, error => 'A username is required'}]
        unless (defined $target && length $target);

    my $fusr = $self->DB->getNode($target, 'user');
    return [$self->HTTP_OK, {success => 0, error => "User not found: $target"}]
        unless $fusr;

    # Idempotent -- don't stack duplicate nodelock rows (the page didn't guard this).
    my $existing = $self->DB->sqlSelect('nodelock_node', 'nodelock',
        'nodelock_node=' . $fusr->{user_id});
    unless ($existing) {
        $self->DB->sqlInsert('nodelock', {
            nodelock_node   => $fusr->{user_id},
            nodelock_user   => $user->node_id,
            nodelock_reason => $reason,
        });
    }

    $self->APP->devLog(
        "Node forbiddance: " . $user->title . " forbade " . $fusr->{title});

    return [$self->HTTP_OK, {
        success => 1,
        message => 'It is done...they have been forbidden',
        user    => $fusr->{title},
    }];
}

sub unforbid_user {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Admin access required'}]
        unless $user->is_admin;

    my $data = $REQUEST->JSON_POSTDATA;
    my $uid  = $data->{user_id};
    return [$self->HTTP_OK, {success => 0, error => 'A numeric user_id is required'}]
        unless (defined $uid && $uid =~ /^\d+$/);

    $self->DB->sqlDelete('nodelock', 'nodelock_node=' . int($uid));

    $self->APP->devLog(
        "Node forbiddance: " . $user->title . " unforbade user $uid");

    return [$self->HTTP_OK, {
        success => 1,
        message => 'It is done...they are free',
    }];
}

__PACKAGE__->meta->make_immutable;

1;
