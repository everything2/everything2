package Everything::Page::clientdev_home;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::clientdev_home - E2 Client Development homepage

=head1 DESCRIPTION

Shows registered E2 clients, allows registration of new clients,
and displays clientdev usergroup weblog.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns list of registered clients and permissions.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $USER = $REQUEST->user;
    my $APP = $self->APP;
    my $NODE = $REQUEST->node;

    # Get all e2client nodes
    my @clients = $DB->getNodeWhere({}, 'e2client', 'title');
    my @client_list = ();

    foreach my $client (@clients) {
        push @client_list, {
            node_id => $client->{node_id},
            title => $client->{title},
            version => $client->{version} || ''
        };
    }

    # Check if user can create new clients
    my $can_create = $DB->isApproved($USER, $NODE);

    # Get N-Wing group info
    my $nwing = $DB->getNode('N-Wing', 'usergroup');
    my $nwing_data = {};
    if ($nwing) {
        $nwing_data = {
            node_id => $nwing->{node_id},
            title => $nwing->{title}
        };
    }

    # Check if user is in clientdev usergroup for weblog
    my $clientdev = $DB->getNode('clientdev', 'usergroup');
    my $show_weblog = 0;
    my $weblog_data = {};

    if ($clientdev && $DB->isApproved($USER, $clientdev)) {
        $show_weblog = 1;
        my $log_id = $clientdev->{node_id};

        # Check if user can remove entries (admin or usergroup owner)
        my $can_remove = 0;
        unless ($APP->isGuest($USER)) {
            $can_remove = 1 if $APP->isAdmin($USER);
            # Also check if user is usergroup owner
            my $owner_id = $APP->getParameter($log_id, 'usergroup_owner');
            $can_remove = 1 if $owner_id && $USER->{node_id} == $owner_id;
        }

        # Pagination for weblog
        my $CGI = $REQUEST->cgi;
        my $interval = 5;
        my $next_weblog = $CGI->param('nextweblog') || 0;
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

        $weblog_data = {
            entries => \@entries,
            weblog_id => int($log_id),
            can_remove => $can_remove ? 1 : 0,
            has_older => $has_older ? 1 : 0,
            has_newer => $offset > 0 ? 1 : 0,
            next_older => $end_at + $interval,
            next_newer => ($end_at > $interval) ? ($end_at - $interval) : 0,
        };
    }

    return {
        type => 'clientdev_home',
        clients => \@client_list,
        can_create => $can_create,
        nwing => $nwing_data,
        show_weblog => $show_weblog,
        weblog => $weblog_data
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
