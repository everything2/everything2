package Everything::Page::node_heaven_title_search;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::node_heaven_title_search

React page for Node Heaven Title Search - search for deleted writeups by title.

Admin-only tool for searching the Node Heaven database by title pattern.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Only admins can access this tool
    unless ( $APP->isAdmin( $USER->NODEDATA ) ) {
        return {
            type  => 'node_heaven_title_search',
            error => 'Access denied. This tool is restricted to administrators.'
        };
    }

    my $search_title = $query->param('heaventitle') || '';
    $search_title =~ s/".*//;  # Strip anything after a quote
    $search_title =~ s/^\s+|\s+$//g;

    my @results    = ();
    my $total_count = 0;
    my $self_kill_count = 0;

    if ($search_title) {
        # Query heaven table for matching titles
        # Pattern: "title (" matches writeup format "Node Title (by username)"
        my $sql_pattern = $search_title . ' (%';

        my $csr = $DB->sqlSelectMany(
            '*',
            'heaven',
            'title like ' . $DB->quote($sql_pattern),
            'ORDER BY createtime DESC'
        );

        while ( my $row = $csr->fetchrow_hashref ) {
            $total_count++;

            # Get author user node
            my $author = $DB->getNodeById( $row->{author_user}, 'light' );
            my $author_title = $author ? $author->{title} : 'Unknown';

            # Get killa user node
            my $killa = undef;
            my $killa_title = undef;
            if ( $row->{killa_user} && $row->{killa_user} != -1 ) {
                $killa = $DB->getNodeById( $row->{killa_user}, 'light' );
                $killa_title = $killa ? $killa->{title} : 'Unknown';

                # Count self-kills
                if ( $row->{killa_user} == $USER->node_id ) {
                    $self_kill_count++;
                }
            }

            push @results, {
                node_id       => $row->{node_id},
                title         => $row->{title},
                createtime    => $row->{createtime},
                reputation    => $row->{reputation},
                author_user   => $row->{author_user},
                author_title  => $author_title,
                killa_user    => $row->{killa_user},
                killa_title   => $killa_title
            };
        }
    }

    # Get Node Heaven Visitation node_id for linking
    my $visit_node = $DB->getNode( 'Node Heaven Visitation', 'superdoc' );
    my $visit_node_id = $visit_node ? $visit_node->{node_id} : 0;

    return {
        type            => 'node_heaven_title_search',
        search_title    => $search_title,
        results         => \@results,
        total_count     => $total_count,
        self_kill_count => $self_kill_count,
        visit_node_id   => $visit_node_id
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
