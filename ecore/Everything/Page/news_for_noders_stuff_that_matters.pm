package Everything::Page::news_for_noders_stuff_that_matters;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::news_for_noders_stuff_that_matters - News for Noders page

=head1 DESCRIPTION

Displays news/announcements from the News usergroup weblog.
Shows the most recent 10 entries with title, author, date, and content.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns weblog entries from the News usergroup.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $query = $REQUEST->cgi;
    my $user = $REQUEST->user;

    # Get the News usergroup
    my $news_group = $DB->getNode('News', 'usergroup');
    return { type => 'news_for_noders', entries => [], error => 'News usergroup not found' }
        unless $news_group;

    my $log_id = $news_group->{node_id};

    # Check if user can remove entries (admin or usergroup owner)
    my $can_remove = 0;
    unless ($user->is_guest) {
        $can_remove = 1 if $APP->isAdmin($user->NODEDATA);
        # Also check if user is usergroup owner
        my $owner_id = $APP->getParameter($log_id, 'usergroup_owner');
        $can_remove = 1 if $owner_id && $user->node_id == $owner_id;
    }

    # Pagination
    my $interval = 10;
    my $next_weblog = $query ? ($query->param('nextweblog') // 0) : 0;
    my $end_at = $next_weblog > 0 ? int($next_weblog) : $interval;
    my $offset = ($end_at == $interval) ? 0 : ($end_at - $interval);

    # Get weblog entries
    my $csr = $DB->sqlSelectMany(
        'weblog_id, to_node, linkedby_user, linkedtime',
        'weblog',
        "weblog_id=$log_id AND removedby_user=0",
        "ORDER BY linkedtime DESC LIMIT $interval OFFSET $offset"
    );

    my @entries = ();
    while (my $row = $csr->fetchrow_hashref()) {
        my $node = $DB->getNodeById($row->{to_node});
        next unless $node;

        # Skip drafts
        next if $node->{type}{title} eq 'draft';

        # Get author info
        my $author = $DB->getNodeById($node->{author_user});
        my $author_name = $author ? $author->{title} : 'Unknown';
        my $author_id = $author ? $author->{node_id} : 0;

        # Get content - use doctext field
        my $content = $node->{doctext} // '';

        # Parse E2 links in content for display
        $content = $APP->parseLinks($content);

        push @entries, {
            node_id => int($node->{node_id}),
            title => $node->{title},
            author => $author_name,
            author_id => int($author_id),
            linkedtime => $row->{linkedtime},
            content => $content,
            type => $node->{type}{title},
        };
    }

    # Check if there are older entries
    my $has_older = $DB->sqlSelect(
        'linkedtime',
        'weblog',
        "weblog_id=$log_id AND removedby_user=0",
        "ORDER BY linkedtime DESC LIMIT 1 OFFSET $end_at"
    );

    return {
        type => 'news_for_noders',
        entries => \@entries,
        weblog_id => int($log_id),
        can_remove => $can_remove ? 1 : 0,
        has_older => $has_older ? 1 : 0,
        has_newer => $offset > 0 ? 1 : 0,
        next_older => $end_at + $interval,
        next_newer => ($end_at > $interval) ? ($end_at - $interval) : 0,
        interval => $interval,
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
