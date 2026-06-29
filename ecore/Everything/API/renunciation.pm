package Everything::API::renunciation;

use Moose;
extends 'Everything::API';

# POST /api/renunciation/{transfer,nodes} -- admin-only (#4414). Replaces the
# render-time writeup-ownership transfer in Everything::Page::renunciation_chainsaw
# (a POST form that reparented writeups' author_user + adjusted numwriteups inside
# buildReactData). `transfer` does the bulk re-owner; `nodes` lists a user's
# writeup parent-nodes (the "generate nodelist" read).

sub routes {
    return {
        'transfer' => 'transfer_writeups',
        'nodes'    => 'list_user_nodes',
    };
}

sub transfer_writeups {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Admin access required'}]
        unless $user->is_admin;

    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $data = $REQUEST->JSON_POSTDATA;

    my $user_from = $data->{user_from};
    my $user_to   = $data->{user_to};
    my $namelist  = defined $data->{namelist} ? $data->{namelist} : '';

    return [$self->HTTP_OK, {success => 0, error => 'user_from, user_to and namelist are required'}]
        unless ($user_from && $user_to && length $namelist);

    my $from_user = $DB->getNode($user_from, 'user');
    return [$self->HTTP_OK, {success => 0, error => "No such user: \"$user_from\""}] unless $from_user;
    my $to_user = $DB->getNode($user_to, 'user');
    return [$self->HTTP_OK, {success => 0, error => "No such user: \"$user_to\""}] unless $to_user;

    my $from_id = $from_user->{node_id};
    my $to_id   = $to_user->{node_id};

    $namelist =~ s/\s*\n\s*/\n/g;
    my @names = grep { $_ } split(/\n/, $namelist);

    my (@reparented, @nonexistent, @no_writeup, @bad_owner, @bad_type);
    my $writeup_type_id = $DB->getType('writeup')->{node_id};

    foreach my $parent_title (@names) {
        my $e2node = $DB->getNode($parent_title, 'e2node');
        unless ($e2node) {
            push @nonexistent, { title => $parent_title };
            next;
        }

        my $csr = $DB->{dbh}->prepare(
            'SELECT * FROM node LEFT JOIN writeup ON node.node_id = writeup.writeup_id ' .
            'WHERE writeup.parent_e2node = ? AND node.author_user = ?'
        );
        $csr->execute($e2node->{node_id}, $from_id);

        my $found = 0;
        my $node_info = { node_id => int($e2node->{node_id}), title => $e2node->{title} };
        while (my $row = $csr->fetchrow_hashref) {
            $found = 1;
            my $writeup = $DB->getNodeById($row->{node_id});
            if ($writeup->{type_nodetype} != $writeup_type_id) {
                push @bad_type, $node_info;
            } elsif ($writeup->{author_user} != $from_id) {
                push @bad_owner, $node_info;
            } else {
                $writeup->{author_user} = $to_id;
                # Superuser write -- the endpoint is admin-gated, so the per-node
                # author permission check is redundant (and matches the
                # numwriteups updates below). The action is audited via devLog.
                $DB->updateNode($writeup, -1);
                push @reparented, $node_info;
            }
        }
        $csr->finish;
        push @no_writeup, $node_info unless $found;
    }

    # Keep both users' numwriteups in sync with the move.
    if (@reparented) {
        my $count     = scalar(@reparented);
        my $from_vars = $APP->getVars($from_user);
        my $to_vars   = $APP->getVars($to_user);
        $from_vars->{numwriteups} = int($from_vars->{numwriteups} || 0) - $count;
        $to_vars->{numwriteups}   = int($to_vars->{numwriteups}   || 0) + $count;
        Everything::setVars($from_user, $from_vars);
        Everything::setVars($to_user, $to_vars);
        $DB->updateNode($from_user, -1);
        $DB->updateNode($to_user, -1);

        $self->APP->devLog("Renunciation: " . $user->title . " transferred $count writeup(s) from "
            . $from_user->{title} . " to " . $to_user->{title});
    }

    return [$self->HTTP_OK, {
        success     => 1,
        processed   => 1,
        from_user   => { id => int($from_id), title => $from_user->{title} },
        to_user     => { id => int($to_id),   title => $to_user->{title} },
        reparented  => \@reparented,
        nonexistent => \@nonexistent,
        no_writeup  => \@no_writeup,
        bad_owner   => \@bad_owner,
        bad_type    => \@bad_type,
    }];
}

sub list_user_nodes {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    return [$self->HTTP_OK, {success => 0, error => 'Admin access required'}]
        unless $user->is_admin;

    my $DB   = $self->DB;
    my $data = $REQUEST->JSON_POSTDATA;
    my $list_for = $data->{user};
    return [$self->HTTP_OK, {success => 0, error => 'A username is required'}]
        unless ($list_for && length $list_for);

    my $list_user = $DB->getNode($list_for, 'user');
    return [$self->HTTP_OK, {success => 0, error => "No such user: \"$list_for\""}]
        unless $list_user;

    my $writeup_type = $DB->getType('writeup');
    my $csr = $DB->sqlSelectMany('node_id', 'node',
        "type_nodetype=$writeup_type->{node_id} AND author_user=$list_user->{node_id}");

    my @node_list;
    while (my $row = $csr->fetchrow_hashref) {
        my $writeup = $DB->getNodeById($row->{node_id}, 'light');
        next unless $writeup;
        my $parent = $DB->getNodeById($writeup->{parent_e2node}, 'light');
        push @node_list, { node_id => int($parent->{node_id}), title => $parent->{title} } if $parent;
    }
    $csr->finish;

    return [$self->HTTP_OK, {
        success        => 1,
        generated_list => {
            user_id    => int($list_user->{node_id}),
            user_title => $list_user->{title},
            nodes      => \@node_list,
        },
    }];
}

__PACKAGE__->meta->make_immutable;

1;
