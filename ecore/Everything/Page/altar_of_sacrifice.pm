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
    my $NODE  = $REQUEST->node;

    my $node_id = $NODE->NODEDATA->{node_id};

    # Security: Editors only
    unless ( $APP->isEditor( $USER->NODEDATA ) ) {
        return {
            type          => 'altar_of_sacrifice',
            node_id       => $node_id,
            access_denied => 1
        };
    }

    # Get author parameter
    my $author_name = $query->param('author') || '';

    # If no author specified, show step 1
    unless ( $author_name ) {
        return {
            type    => 'altar_of_sacrifice',
            node_id => $node_id,
            step    => 'input'
        };
    }

    # Look up the author
    my $author = $DB->getNode( $author_name, 'user' );

    unless ( $author ) {
        return {
            type    => 'altar_of_sacrifice',
            node_id => $node_id,
            step    => 'input',
            error   => "$author_name is not a user."
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
            node_id     => $node_id,
            step        => 'empty',
            author_id   => $author->{node_id},
            author_name => $author->{title}
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
        node_id     => $node_id,
        step        => 'select',
        author_id   => $author->{node_id},
        author_name => $author->{title},
        writeups    => \@writeups,
        total       => $total,
        page        => $page,
        per_page    => $per_page,
        total_pages => $total_pages
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>

=cut
