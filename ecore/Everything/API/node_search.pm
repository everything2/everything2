package Everything::API::node_search;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

sub routes {
    return {
        '/' => 'search'
    };
}

sub search {
    my ($self, $REQUEST) = @_;

    my $query = $REQUEST->cgi;
    my $USER = $REQUEST->user->NODEDATA;

    # Get search parameters
    my $search_term = $query->param('q') || '';
    $search_term =~ s/^\s+|\s+$//g;

    unless ($search_term) {
        return [$self->HTTP_OK, { success => 0, error => 'Search term (q) is required' }];
    }

    # Scope determines what types to search
    my $scope = $query->param('scope') || 'users';
    my @valid_scopes = qw(users usergroups users_and_groups group_addable message_recipients);

    unless (grep { $_ eq $scope } @valid_scopes) {
        return [$self->HTTP_OK, {
            success => 0,
            error => "Invalid scope. Must be one of: " . join(', ', @valid_scopes)
        }];
    }

    # Pagination - parse early since message_recipients scope also needs it
    my $limit = int($query->param('limit') || 20);
    $limit = 20 if $limit < 1 || $limit > 100;

    # message_recipients scope has special handling
    if ($scope eq 'message_recipients') {
        return $self->_search_message_recipients($REQUEST, $search_term, $limit);
    }

    # For group_addable scope, we need the group_id to exclude current members
    my $group_id = int($query->param('group_id') || 0);
    if ($scope eq 'group_addable' && !$group_id) {
        return [$self->HTTP_OK, {
            success => 0,
            error => 'group_id parameter is required for group_addable scope'
        }];
    }

    # Determine which types to search based on scope
    my @search_types;
    if ($scope eq 'users') {
        @search_types = ('user');
    } elsif ($scope eq 'usergroups') {
        @search_types = ('usergroup');
    } elsif ($scope eq 'users_and_groups' || $scope eq 'group_addable') {
        @search_types = ('user', 'usergroup');
    }

    my @results;
    my $dbh = $self->DB->{dbh};

    foreach my $type_name (@search_types) {
        my $type = $self->DB->getType($type_name);
        next unless $type;
        my $type_id = $self->DB->getId($type);

        # Escape LIKE special characters in the search term to prevent pattern injection
        my $escaped_term = $search_term;
        $escaped_term =~ s/([%_\\])/\\$1/g;

        # Use wildcard for prefix matching
        my $search_pattern = $escaped_term . '%';

        # Build exclusion clause for group_addable
        my $exclude_clause = '';
        # Build bind params in SQL order: type_id, search_pattern, [group_id], limit
        my @bind_params = ($type_id, $search_pattern);

        if ($scope eq 'group_addable' && $group_id) {
            # Exclude nodes that are already members of the group
            $exclude_clause = qq{
                AND node.node_id NOT IN (
                    SELECT node_id FROM nodegroup WHERE nodegroup_id = ?
                )
            };
            push @bind_params, $group_id;
        }

        push @bind_params, $limit;

        # Search by title prefix (case-insensitive)
        my $sql = qq{
            SELECT node.node_id, node.title
            FROM node
            WHERE node.type_nodetype = ?
            AND node.title LIKE ?
            $exclude_clause
            ORDER BY node.title ASC
            LIMIT ?
        };

        my $sth = $dbh->prepare($sql);
        $sth->execute(@bind_params);

        while (my $row = $sth->fetchrow_hashref) {
            push @results, {
                node_id => int($row->{node_id}),
                title => $row->{title},
                type => $type_name
            };
        }
    }

    # Sort combined results by title and limit
    @results = sort { lc($a->{title}) cmp lc($b->{title}) } @results;
    @results = @results[0 .. ($limit - 1)] if @results > $limit;

    return [$self->HTTP_OK, {
        success => 1,
        results => \@results,
        count => scalar(@results),
        scope => $scope,
        search_term => $search_term
    }];
}

sub _search_message_recipients {
    my ($self, $REQUEST, $search_term, $limit) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $dbh = $DB->{dbh};
    my $user = $REQUEST->user;
    my $USER = $user->NODEDATA;
    my $user_id = $USER->{node_id};
    my $is_admin = $APP->isAdmin($USER);

    my @results;
    my %seen_ids;

    # Escape LIKE special characters
    my $escaped_term = $search_term;
    $escaped_term =~ s/([%_\\])/\\$1/g;
    my $search_pattern = $escaped_term . '%';

    # Get user type ID for queries
    my $user_type = $DB->getType('user');
    my $user_type_id = $DB->getId($user_type);
    my $usergroup_type = $DB->getType('usergroup');
    my $usergroup_type_id = $DB->getId($usergroup_type);

    # 1. Search users who haven't blocked the current user
    # Get list of users who have blocked the current user
    my %blockers;
    my $block_sth = $dbh->prepare(qq{
        SELECT messageignore_id FROM messageignore WHERE ignore_node = ?
    });
    $block_sth->execute($user_id);
    while (my ($blocker_id) = $block_sth->fetchrow_array) {
        $blockers{$blocker_id} = 1;
    }

    # Search users by title prefix, excluding those who blocked us
    # Also exclude users with message_forward_to set - they are mail forwarding
    # aliases and will be handled separately in step 3
    my $user_sql = qq{
        SELECT node.node_id, node.title
        FROM node
        LEFT JOIN user ON user.user_id = node.node_id
        WHERE node.type_nodetype = ?
        AND node.title LIKE ?
        AND (user.message_forward_to IS NULL OR user.message_forward_to = 0)
        ORDER BY node.title ASC
        LIMIT ?
    };

    my $user_sth = $dbh->prepare($user_sql);
    $user_sth->execute($user_type_id, $search_pattern, $limit * 2);

    while (my $row = $user_sth->fetchrow_hashref) {
        next if $blockers{$row->{node_id}};
        next if $seen_ids{$row->{node_id}};
        $seen_ids{$row->{node_id}} = 1;

        push @results, {
            node_id => int($row->{node_id}),
            title => $row->{title},
            type => 'user'
        };
    }

    # 2. Search usergroups - admins can message any group, others only groups they're in
    if ($is_admin) {
        # Admins can message any usergroup
        my $group_sql = qq{
            SELECT node.node_id, node.title
            FROM node
            WHERE node.type_nodetype = ?
            AND node.title LIKE ?
            ORDER BY node.title ASC
            LIMIT ?
        };

        my $group_sth = $dbh->prepare($group_sql);
        $group_sth->execute($usergroup_type_id, $search_pattern, $limit);

        while (my $row = $group_sth->fetchrow_hashref) {
            next if $seen_ids{$row->{node_id}};
            $seen_ids{$row->{node_id}} = 1;

            push @results, {
                node_id => int($row->{node_id}),
                title => $row->{title},
                type => 'usergroup'
            };
        }
    } else {
        # Non-admins can only message usergroups they're a member of
        # This includes direct membership and membership through subgroups
        my $member_groups_sql = qq{
            SELECT DISTINCT ng.nodegroup_id, n.title
            FROM nodegroup ng
            JOIN node n ON n.node_id = ng.nodegroup_id
            WHERE ng.node_id = ?
            AND n.type_nodetype = ?
            AND n.title LIKE ?
            ORDER BY n.title ASC
            LIMIT ?
        };

        my $member_sth = $dbh->prepare($member_groups_sql);
        $member_sth->execute($user_id, $usergroup_type_id, $search_pattern, $limit);

        while (my $row = $member_sth->fetchrow_hashref) {
            next if $seen_ids{$row->{nodegroup_id}};
            $seen_ids{$row->{nodegroup_id}} = 1;

            push @results, {
                node_id => int($row->{nodegroup_id}),
                title => $row->{title},
                type => 'usergroup'
            };
        }
    }

    # 3. Search for message forwards (aliases like c_e -> Content Editors)
    # These are users with message_forward_to set, where we match their title
    my $forward_sql = qq{
        SELECT u.user_id as alias_id, n.title as alias_title,
               u.message_forward_to as target_id,
               n2.title as target_title, n2.type_nodetype as target_type
        FROM user u
        JOIN node n ON n.node_id = u.user_id
        JOIN node n2 ON n2.node_id = u.message_forward_to
        WHERE n.title LIKE ?
        AND u.message_forward_to IS NOT NULL
        AND u.message_forward_to != 0
        ORDER BY n.title ASC
        LIMIT ?
    };

    my $forward_sth = $dbh->prepare($forward_sql);
    $forward_sth->execute($search_pattern, $limit);

    while (my $row = $forward_sth->fetchrow_hashref) {
        my $target_id = $row->{target_id};
        next if $seen_ids{$target_id};

        # Skip if target user has blocked us (for user targets)
        next if $blockers{$target_id};

        # For usergroup targets, check membership if not admin
        if ($row->{target_type} == $usergroup_type_id && !$is_admin) {
            my $is_member = $DB->sqlSelect(
                'node_id',
                'nodegroup',
                "nodegroup_id = $target_id AND node_id = $user_id"
            );
            next unless $is_member;
        }

        $seen_ids{$target_id} = 1;

        my $target_type = $row->{target_type} == $user_type_id ? 'user' : 'usergroup';

        push @results, {
            node_id => int($target_id),
            title => $row->{target_title},
            type => $target_type,
            alias => $row->{alias_title}
        };
    }

    # Sort by title and limit
    @results = sort { lc($a->{title}) cmp lc($b->{title}) } @results;
    @results = @results[0 .. ($limit - 1)] if @results > $limit;

    return [$self->HTTP_OK, {
        success => 1,
        results => \@results,
        count => scalar(@results),
        scope => 'message_recipients',
        search_term => $search_term
    }];
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

Everything::API::node_search - Unified search API for users and usergroups

=head1 DESCRIPTION

Provides a unified search endpoint for finding users and usergroups
with different scope options.

=head1 ROUTES

=head2 GET /api/node_search?q=<term>&scope=<scope>&limit=<n>

Search for nodes by title prefix.

=head3 Parameters

=over 4

=item q (required)

The search term. Matches title prefix (case-insensitive).

=item scope (optional, default: users)

What to search:

=over 4

=item users - Search only users

=item usergroups - Search only usergroups

=item users_and_groups - Search both users and usergroups

=item group_addable - Search users and usergroups that can be added to a group
(requires group_id parameter to exclude current members)

=item message_recipients - Search valid message recipients for the current user.
Returns users who haven't blocked the sender, usergroups the user can message
(admins can message any group, others only groups they're in), and expands
message forward aliases (e.g., c_e -> Content Editors).

=back

=item group_id (required for group_addable scope)

The usergroup node_id to check membership against.

=item limit (optional, default: 20, max: 100)

Maximum results to return.

=back

=head3 Response

    {
        "success": 1,
        "results": [
            { "node_id": 123, "title": "username", "type": "user" },
            { "node_id": 456, "title": "groupname", "type": "usergroup" }
        ],
        "count": 2,
        "scope": "users_and_groups",
        "search_term": "use"
    }

=head1 AUTHOR

Everything2 Development Team

=cut
