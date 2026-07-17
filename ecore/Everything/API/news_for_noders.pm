package Everything::API::news_for_noders;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::news_for_noders - the News usergroup weblog ("News for Noders")

=head1 DESCRIPTION

The most recent entries in the News usergroup weblog, 10 per page. Moved out of
C<Everything::Page::news_for_noders_stuff_that_matters>'s buildReactData (#4543): the Page is a pure
gate, React reads nextweblog off the URL and calls this.

  GET /api/news_for_noders?nextweblog=<n>

Public (news is visible to guests). C<can_remove> (admin or the News group's owner) is computed from
the actual request user; removal itself is DELETE /api/weblog/:weblog_id/:node_id.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    my $news_group = $DB->getNode('News', 'usergroup');
    return [$self->HTTP_OK, { success => 0, state => 'no_news_group', entries => [] }]
        unless $news_group;

    my $log_id = int($news_group->{node_id});

    # Removal is allowed for admins and the group's owner.
    my $can_remove = 0;
    unless ($user->is_guest) {
        $can_remove = 1 if $APP->isAdmin($user->NODEDATA);
        my $owner_id = $APP->getParameter($log_id, 'usergroup_owner');
        $can_remove = 1 if $owner_id && $user->node_id == $owner_id;
    }

    my $interval    = 10;
    my $next_weblog = int($REQUEST->param('nextweblog') || 0);
    my $end_at      = $next_weblog > 0 ? $next_weblog : $interval;
    my $offset      = ($end_at == $interval) ? 0 : ($end_at - $interval);
    $offset = 0 if $offset < 0;

    my $csr = $DB->sqlSelectMany(
        'weblog_id, to_node, linkedby_user, linkedtime', 'weblog',
        "weblog_id=$log_id AND removedby_user=0",
        "ORDER BY linkedtime DESC LIMIT $interval OFFSET $offset"
    );

    my @entries;
    while (my $row = $csr->fetchrow_hashref) {
        my $node = $DB->getNodeById($row->{to_node}) or next;
        next if $node->{type}{title} eq 'draft';

        my $author = $DB->getNodeById($node->{author_user});
        push @entries, {
            node_id    => int($node->{node_id}),
            title      => $node->{title},
            author     => $author ? $author->{title} : 'Unknown',
            author_id  => $author ? int($author->{node_id}) : 0,
            linkedtime => $row->{linkedtime},
            content    => $APP->parseLinks($node->{doctext} // ''),
            type       => $node->{type}{title},
        };
    }

    my $has_older = $DB->sqlSelect('linkedtime', 'weblog',
        "weblog_id=$log_id AND removedby_user=0", "ORDER BY linkedtime DESC LIMIT 1 OFFSET $end_at");

    return [$self->HTTP_OK, {
        success    => 1,
        entries    => \@entries,
        # 0 + : $log_id was interpolated into SQL above (string-flagged), so JSON
        # would otherwise ship the weblog_id as a string (#4152).
        weblog_id  => 0 + $log_id,
        # \1 / \0 -> JSON booleans; a plain ?1:0 comes through the API JSON path as a
        # string ("0"), which is truthy in JS and would flip these flags (#4108).
        can_remove => $can_remove ? \1 : \0,
        has_older  => $has_older  ? \1 : \0,
        has_newer  => $offset > 0 ? \1 : \0,
        next_older => $end_at + $interval,
        next_newer => ($end_at > $interval) ? ($end_at - $interval) : 0,
        interval   => $interval,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
