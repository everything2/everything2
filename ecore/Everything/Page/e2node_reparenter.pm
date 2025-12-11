package Everything::Page::e2node_reparenter;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::e2node_reparenter

React page for E2Node Reparenter - allows editors/admins to repair e2node
nodegroups and move writeups between e2nodes.

This page reuses the Magical Writeup Reparenter React component by returning
type => 'magical_writeup_reparenter'.

=cut

sub buildReactData
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    # Security: Editors and admins only
    my $is_admin  = $APP->isAdmin( $USER->NODEDATA );
    my $is_editor = $APP->isEditor( $USER->NODEDATA );

    unless ( $is_admin || $is_editor ) {
        return {
            type          => 'magical_writeup_reparenter',
            access_denied => 1
        };
    }

    my $old_e2node_id  = $query->param('old_e2node_id')  || $query->param('repare');
    my $old_writeup_id = $query->param('old_writeup_id');
    my $new_e2node_id  = $query->param('new_e2node_id');

    my $result = {
        type             => 'magical_writeup_reparenter',
        old_e2node       => undef,
        old_writeup      => undef,
        new_e2node       => undef,
        suggested_parent => undef,
        errors           => [],
        is_admin         => $is_admin ? 1 : 0,
        is_editor        => $is_editor ? 1 : 0
    };

    # Get old e2node if provided
    if ( defined $old_e2node_id && $old_e2node_id ne '' ) {
        my $old_e2node = $self->getNodeByNameOrId( $old_e2node_id, 'e2node' );
        if ($old_e2node) {
            $result->{old_e2node} = $self->formatE2NodeInfo($old_e2node);
        } else {
            push @{ $result->{errors} }, 'Invalid source e2node ID or title';
        }
    }
    # Only check old_writeup_id if we don't have old_e2node_id
    elsif ( defined $old_writeup_id && $old_writeup_id ne '' ) {
        my $writeup = $self->getNodeByNameOrId( $old_writeup_id, 'writeup' );
        if ($writeup) {
            $result->{old_writeup} = $self->formatWriteupInfo($writeup);

            # Try to find parent node
            my $parent_node = $DB->getNodeById( $writeup->{parent_e2node} );
            if ( $parent_node && $parent_node->{type}{title} eq 'e2node' ) {
                $result->{old_e2node} = $self->formatE2NodeInfo($parent_node);
            } else {
                # Orphaned writeup - try to guess parent
                my $suggested = $self->guessParentForWriteup($writeup);
                if ($suggested) {
                    $result->{suggested_parent} = $self->formatE2NodeInfo($suggested);
                }
            }
        } else {
            push @{ $result->{errors} }, 'Invalid writeup ID';
        }
    }

    # Get new e2node if provided
    if ( defined $new_e2node_id && $new_e2node_id ne '' ) {
        my $new_e2node = $self->getNodeByNameOrId( $new_e2node_id, 'e2node' );
        if ($new_e2node) {
            $result->{new_e2node} = $self->formatE2NodeInfo($new_e2node);
        } else {
            push @{ $result->{errors} }, 'Invalid destination e2node ID or title';
        }
    }

    # Get Klaproth Van Lines node_id for the link
    my $kvl_node = $DB->getNode( 'Klaproth Van Lines', 'restricted_superdoc' );
    $result->{kvl_node_id} = $kvl_node ? $kvl_node->{node_id} : undef;

    return $result;
}

=head2 getNodeByNameOrId

Gets a node by ID (numeric) or title (string).

=cut

sub getNodeByNameOrId
{
    my ( $self, $node_id_or_name, $nodetype ) = @_;

    my $DB = $self->DB;

    return unless defined $node_id_or_name && $node_id_or_name ne '';

    my $target_node;

    if ( $node_id_or_name =~ m/\D/ ) {
        # Contains non-digits, treat as title
        $target_node = $DB->getNode( $node_id_or_name, $nodetype );
    } else {
        # All digits, treat as ID
        $target_node = $DB->getNodeById( $node_id_or_name, $nodetype );
        $target_node = undef unless $target_node && $target_node->{type}{title} eq $nodetype;
    }

    return $target_node;
}

=head2 guessParentForWriteup

Attempts to guess the parent e2node for an orphaned writeup.

=cut

sub guessParentForWriteup
{
    my ( $self, $writeup ) = @_;

    my $DB = $self->DB;

    my $guess_title = $writeup->{title};

    # Strip writeuptype suffix like "(idea)" from title
    $guess_title =~ s/^(.*?)(\([^\(]*)?$/$1/;
    $guess_title =~ s/\s+$//;

    return unless $guess_title;

    return $DB->getNode( $guess_title, 'e2node' );
}

=head2 formatE2NodeInfo

Formats e2node information for JSON response.

=cut

sub formatE2NodeInfo
{
    my ( $self, $e2node ) = @_;

    return unless $e2node;

    my $DB = $self->DB;

    my @writeups;
    my $group = $e2node->{group} || [];

    foreach my $writeup_id (@$group) {
        my $writeup = $DB->getNodeById($writeup_id);
        next unless $writeup && $writeup->{type}{title} eq 'writeup';

        push @writeups, $self->formatWriteupInfo($writeup);
    }

    return {
        node_id      => $e2node->{node_id},
        title        => $e2node->{title},
        writeups     => \@writeups,
        is_nodeshell => @writeups ? 0 : 1
    };
}

=head2 formatWriteupInfo

Formats writeup information for JSON response.

=cut

sub formatWriteupInfo
{
    my ( $self, $writeup ) = @_;

    return unless $writeup;

    my $DB = $self->DB;

    my $author      = $DB->getNodeById( $writeup->{author_user} );
    my $writeuptype = $DB->getNodeById( $writeup->{wrtype_writeuptype} );

    return {
        node_id       => $writeup->{node_id},
        title         => $writeup->{title},
        parent_e2node => $writeup->{parent_e2node},
        author_id     => $author ? $author->{node_id} : undef,
        author_title  => $author ? $author->{title} : 'unknown',
        writeuptype   => $writeuptype ? $writeuptype->{title} : 'unknown',
        createtime    => $writeup->{createtime}
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::Page>, L<Everything::Page::magical_writeup_reparenter>,
L<Everything::API::writeup_reparent>

=cut
