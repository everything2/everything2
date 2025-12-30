package Everything::Page::drafts;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Get the approved HTML tags from settings
    my $approved_tags = $APP->node_by_name('approved html tags', 'setting')->VARS || {};
    my @tags = sort keys %$approved_tags;

    # Open to all logged-in users
    my $can_access = $user && !$user->is_guest ? 1 : 0;

    # Check if viewing another user's drafts
    my $view_user_param = $REQUEST->param('other_user');
    my $target_user = undef;
    my $viewing_other = 0;
    my $page_title = 'Drafts';

    if ($can_access && $view_user_param) {
        # Try to find the target user
        $target_user = $DB->getNode($view_user_param, 'user');
        if ($target_user && $target_user->{node_id} != $user->node_id) {
            $viewing_other = 1;
            $page_title = "$target_user->{title}'s Drafts";
        }
    }

    # Get user's drafts if logged in (initial page load - first 20)
    my @drafts;
    my $pagination = { offset => 0, limit => 20, total => 0, has_more => 0 };

    if ($can_access) {
        my $draft_type = $DB->getType('draft');
        my $draft_type_id = $draft_type->{node_id};

        if ($viewing_other) {
            # Viewing another user's drafts - only show findable ones
            my $target_user_id = $target_user->{node_id};

            # Get all drafts for this user and filter by canSeeDraft
            my $sql = q|
                SELECT node.node_id, node.title, node.createtime,
                       draft.publication_status, draft.collaborators,
                       ps.title AS status_title,
                       document.doctext
                FROM node
                JOIN draft ON draft.draft_id = node.node_id
                JOIN document ON document.document_id = node.node_id
                LEFT JOIN node AS ps ON ps.node_id = draft.publication_status
                WHERE node.author_user = ?
                AND node.type_nodetype = ?
                ORDER BY node.createtime DESC
            |;

            my $sth = $DB->{dbh}->prepare($sql);
            $sth->execute($target_user_id, $draft_type_id);

            while (my $row = $sth->fetchrow_hashref) {
                # Build a draft hashref for canSeeDraft check
                my $draft_check = {
                    node_id => $row->{node_id},
                    author_user => $target_user_id,
                    publication_status => $row->{publication_status},
                    collaborators => $row->{collaborators}
                };

                # Only include drafts the viewer can see (with 'find' disposition)
                if ($APP->canSeeDraft($user->NODEDATA, $draft_check, 'find')) {
                    push @drafts, {
                        node_id => $row->{node_id},
                        title => $row->{title},
                        createtime => $row->{createtime},
                        status => $row->{status_title} || 'unknown',
                        doctext => $row->{doctext} || ''
                    };
                }
            }

            # Pagination for other user's visible drafts
            my $total = scalar @drafts;
            @drafts = splice(@drafts, 0, 20) if @drafts > 20;

            $pagination = {
                offset => 0,
                limit => 20,
                total => $total,
                has_more => ($total > 20) ? 1 : 0
            };
        } else {
            # Viewing own drafts - show all
            my $user_id = $user->node_id;

            # Get total count
            my $total = $DB->{dbh}->selectrow_array(
                'SELECT COUNT(*) FROM node WHERE author_user = ? AND type_nodetype = ?',
                {}, $user_id, $draft_type_id
            ) || 0;

            my $sql = q|
                SELECT node.node_id, node.title, node.createtime,
                       draft.publication_status,
                       ps.title AS status_title,
                       document.doctext
                FROM node
                JOIN draft ON draft.draft_id = node.node_id
                JOIN document ON document.document_id = node.node_id
                LEFT JOIN node AS ps ON ps.node_id = draft.publication_status
                WHERE node.author_user = ?
                AND node.type_nodetype = ?
                ORDER BY node.createtime DESC
                LIMIT 20
            |;

            my $sth = $DB->{dbh}->prepare($sql);
            $sth->execute($user_id, $draft_type_id);

            while (my $row = $sth->fetchrow_hashref) {
                push @drafts, {
                    node_id => $row->{node_id},
                    title => $row->{title},
                    createtime => $row->{createtime},
                    status => $row->{status_title} || 'unknown',
                    doctext => $row->{doctext} || ''
                };
            }

            # Set pagination metadata
            $pagination = {
                offset => 0,
                limit => 20,
                total => $total,
                has_more => (20 < $total) ? 1 : 0
            };
        }
    }

    # Get available publication statuses for the dropdown
    my @statuses;
    for my $status_name (qw(private shared findable review)) {
        my $status = $DB->getNode($status_name, 'publication_status');
        if ($status) {
            push @statuses, {
                id => $status->{node_id},
                name => $status->{title}
            };
        }
    }

    # Get user preference for raw HTML editing mode
    my $prefer_raw_html = 0;
    if ($can_access) {
        $prefer_raw_html = $user->VARS->{tiptap_editor_raw} ? 1 : 0;
    }

    return {
        type => 'drafts',
        pageTitle => $page_title,
        approvedTags => \@tags,
        canAccess => $can_access,
        username => $user ? $user->title : undef,
        drafts => \@drafts,
        pagination => $pagination,
        statuses => \@statuses,
        preferRawHtml => $prefer_raw_html,
        # When viewing another user's drafts
        viewingOther => $viewing_other ? 1 : 0,
        targetUser => $target_user ? {
            node_id => $target_user->{node_id},
            title => $target_user->{title}
        } : undef
    };
}

__PACKAGE__->meta->make_immutable;

1;
