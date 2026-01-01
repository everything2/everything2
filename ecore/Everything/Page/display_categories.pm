package Everything::Page::display_categories;

use Moose;
extends 'Everything::Page';

use Readonly;
Readonly my $PAGE_SIZE => 50;

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    my $USER = $user->NODEDATA;
    my $cgi = $REQUEST->cgi;
    my $APP = $self->APP;
    my $DB = $self->DB;

    my $is_guest = $user->is_guest;
    my $user_level = $APP->getLevel($USER);
    my $can_contribute_public = ($user_level >= 1);
    my $guest_user_id = $Everything::CONF->guest_user;
    my $uid = $USER->{user_id};

    # Get query parameters
    my $page = int($cgi->param('p') || 0);
    $page = 0 if $page < 0;

    my $maintainer_name = $cgi->param('m') // '';
    $maintainer_name =~ s/^\s+|\s+$//g;

    my $order = $cgi->param('o') // '';

    # Get type IDs
    my $user_type = $DB->getType('user');
    my $usergroup_type = $DB->getType('usergroup');
    my $category_type = $DB->getType('category');

    # Resolve maintainer if specified
    my $maintainer_id = 0;
    my $maintainer_type = '';
    if (length($maintainer_name) > 0) {
        my $maintainer = $DB->getNode($maintainer_name, 'user');
        if ($maintainer && $maintainer->{node_id}) {
            $maintainer_id = $maintainer->{node_id};
            $maintainer_type = 'user';
        } else {
            $maintainer = $DB->getNode($maintainer_name, 'usergroup');
            if ($maintainer && $maintainer->{node_id}) {
                $maintainer_id = $maintainer->{node_id};
                $maintainer_type = 'usergroup';
            } else {
                # Invalid maintainer name - reset
                $maintainer_name = '';
            }
        }
    }

    # Build ORDER BY clause
    my $order_by = 'n.title, a.title';
    $order_by = 'a.title, n.title' if $order eq 'm';

    # Build WHERE clause
    my $author_restrict = '';
    $author_restrict = "AND n.author_user = $maintainer_id" if $maintainer_id > 0;

    my $start_at = $page * $PAGE_SIZE;

    # Query categories
    my $sql = qq{
        SELECT n.node_id, n.title, n.author_user,
               a.title AS maintainer,
               a.type_nodetype AS maintainer_type
        FROM node n
        JOIN node a ON n.author_user = a.node_id
        WHERE n.type_nodetype = $category_type->{node_id}
        $author_restrict
        AND n.title NOT LIKE '%\\_root'
        ORDER BY $order_by
        LIMIT $start_at, $PAGE_SIZE
    };

    my $sth = $DB->{dbh}->prepare($sql);
    $sth->execute();

    my @categories;
    while (my $row = $sth->fetchrow_hashref) {
        my $is_public = ($guest_user_id == $row->{author_user});
        my $is_usergroup = ($row->{maintainer_type} == $usergroup_type->{node_id});

        # Determine if user can contribute
        my $can_contribute = 0;
        if (!$is_guest) {
            if ($is_public && $can_contribute_public) {
                $can_contribute = 1;
            } elsif ($row->{author_user} == $uid) {
                $can_contribute = 1;
            } elsif ($is_usergroup && $APP->inUsergroup($uid, $row->{maintainer})) {
                $can_contribute = 1;
            }
        }

        push @categories, {
            node_id => int($row->{node_id}),
            title => $row->{title},
            maintainer_id => int($row->{author_user}),
            maintainer_name => $is_public ? 'Everyone' : $row->{maintainer},
            is_public => $is_public ? \1 : \0,
            is_usergroup => $is_usergroup ? \1 : \0,
            can_contribute => $can_contribute ? \1 : \0,
        };
    }

    my $has_more = (scalar(@categories) >= $PAGE_SIZE);

    return {
        displayCategories => {
            categories => \@categories,
            page => $page,
            pageSize => $PAGE_SIZE,
            hasMore => $has_more ? \1 : \0,
            maintainerName => $maintainer_name,
            sortOrder => $order,
            isGuest => $is_guest ? \1 : \0,
        }
    };
}

__PACKAGE__->meta->make_immutable;

1;
