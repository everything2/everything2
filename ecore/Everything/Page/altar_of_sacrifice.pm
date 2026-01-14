package Everything::Page::altar_of_sacrifice;

use Moose;
extends 'Everything::Page';

use Everything qw(getNode getNodeById getId getType);

=head1 Everything::Page::altar_of_sacrifice

React page for Altar of Sacrifice - admin tool to remove writeups from a user.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Security: Editors only
    unless ( $APP->isEditor( $USER->NODEDATA ) ) {
        return {
            type          => 'altar_of_sacrifice',
            access_denied => 1,
            # node_id removed - use e2.node_id from global state
        };
    }

    # Get author parameter
    my $author_name = $query->param('author') || '';

    # If no author specified, show step 1
    unless ( $author_name ) {
        return {
            type => 'altar_of_sacrifice',
            step => 'input',
            # node_id removed - use e2.node_id from global state
        };
    }

    # Look up the author
    my $author = $DB->getNode( $author_name, 'user' );

    unless ( $author ) {
        return {
            type  => 'altar_of_sacrifice',
            step  => 'input',
            error => "$author_name is not a user.",
            # node_id removed - use e2.node_id from global state
        };
    }

    # Get pagination params
    my $page = int( $query->param('page') || 1 );
    my $per_page = 100;
    my $offset = ( $page - 1 ) * $per_page;

    # Get writeup type
    my $wuType = $DB->getType('writeup');

    # Count total writeups
    my $total = $DB->sqlSelect(
        'COUNT(*)',
        'node',
        "type_nodetype=$wuType->{node_id} AND author_user=$author->{node_id}"
    );

    # No writeups found
    unless ( $total ) {
        return {
            type        => 'altar_of_sacrifice',
            step        => 'empty',
            author_id   => $author->{node_id},
            author_name => $author->{title},
            # node_id removed - use e2.node_id from global state
        };
    }

    # Get writeups for this page
    my $csr = $DB->sqlSelectMany(
        'node_id, title',
        'node',
        "type_nodetype=$wuType->{node_id} AND author_user=$author->{node_id}",
        "ORDER BY title LIMIT $offset, $per_page"
    );

    my @writeups = ();
    while ( my $row = $csr->fetchrow_hashref ) {
        push @writeups, {
            node_id => $row->{node_id},
            title   => $row->{title}
        };
    }
    $csr->finish;

    # Calculate pagination
    my $total_pages = int( ( $total + $per_page - 1 ) / $per_page );

    return {
        type        => 'altar_of_sacrifice',
        step        => 'select',
        author_id   => $author->{node_id},
        author_name => $author->{title},
        writeups    => \@writeups,
        total       => $total,
        page        => $page,
        per_page    => $per_page,
        total_pages => $total_pages,
        # node_id removed - use e2.node_id from global state
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
