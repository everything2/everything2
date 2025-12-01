package Everything::Page::e2_editor_beta;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $user = $REQUEST->user;
    my $APP = $self->APP;
    my $DB = $self->DB;

    # Get the approved HTML tags from settings
    # VARS returns a hashref where keys are tag names
    my $approved_tags = $APP->node_by_name('approved html tags', 'setting')->VARS || {};
    my @tags = sort keys %$approved_tags;

    # Open to all logged-in users
    my $can_access = $user && !$user->is_guest ? 1 : 0;

    # Get user's drafts if logged in
    my @drafts;
    if ($can_access) {
        my $user_id = $user->node_id;
        my $draft_type = $DB->getType('draft');
        my $draft_type_id = $draft_type->{node_id};

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
            LIMIT 50
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

    return {
        type => 'e2_editor_beta',
        approvedTags => \@tags,
        canAccess => $can_access,
        username => $user ? $user->title : undef,
        drafts => \@drafts,
        statuses => \@statuses
    };
}

__PACKAGE__->meta->make_immutable;

1;
