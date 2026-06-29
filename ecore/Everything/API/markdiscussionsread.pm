package Everything::API::markdiscussionsread;

use Moose;
extends 'Everything::API';

# POST /api/markdiscussionsread/{ce,admin} (#4410). Replaces the render-time
# lastreaddebate writes in Everything::Page::mark_all_discussions_as_read, where
# a GET ?mark_ce_read / ?mark_admin_read marked debates read inside buildReactData.
# ce: editor or admin; admin: admin only. Each marks the CALLING user's debates.

sub routes {
    return {
        'ce'    => 'mark_ce',
        'admin' => 'mark_admin',
    };
}

sub mark_ce {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Editor or admin access required'}]
        unless ($user->is_editor || $user->is_admin);

    my $ce = $self->DB->getNode('Content Editors', 'usergroup');
    return [$self->HTTP_OK, {success => 0, error => 'Content Editors group not found'}]
        unless $ce;

    my $count = $self->_mark_debates_as_read($user->node_id, $ce->{node_id});
    return [$self->HTTP_OK, {
        success => 1,
        count   => $count,
        message => "All CE debates have been marked as read ($count debates updated).",
    }];
}

sub mark_admin {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Admin access required'}]
        unless $user->is_admin;

    my $gods = $self->DB->getNode('gods', 'usergroup');
    return [$self->HTTP_OK, {success => 0, error => 'gods group not found'}]
        unless $gods;

    my $count = $self->_mark_debates_as_read($user->node_id, $gods->{node_id});
    return [$self->HTTP_OK, {
        success => 1,
        count   => $count,
        message => "All admin debates have been marked as read ($count debates updated).",
    }];
}

# Mark every debate restricted to $group_id as read (NOW()) for $uid. Moved
# from the page controller's _mark_debates_as_read (ints only; no interpolation
# risk). Returns the number of debates touched.
sub _mark_debates_as_read {
    my ($self, $uid, $group_id) = @_;
    my $DB = $self->DB;
    my $count = 0;

    my $csr = $DB->sqlSelectMany(
        "root_debatecomment", "debatecomment",
        "restricted = $group_id", "GROUP BY root_debatecomment");

    while (my $row = $csr->fetchrow_hashref) {
        my $debate = $row->{root_debatecomment};
        my $lastread = $DB->sqlSelect("dateread", "lastreaddebate",
            "user_id = $uid AND debateroot_id = $debate");
        if ($lastread) {
            $DB->sqlUpdate("lastreaddebate", { -dateread => "NOW()" },
                "user_id = $uid AND debateroot_id = $debate");
        } else {
            $DB->sqlInsert("lastreaddebate", {
                user_id => $uid, debateroot_id => $debate, -dateread => "NOW()" });
        }
        $count++;
    }
    return $count;
}

__PACKAGE__->meta->make_immutable;

1;
