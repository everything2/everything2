package Everything::API::writeup_reparent;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

use Encode qw(decode_utf8);
use JSON::MaybeXS;

=head1 Everything::API::writeup_reparent

RESTful API for reparenting writeups between e2nodes (admin/editor only).

=head2 Endpoints

GET  /api/writeup_reparent - Get writeup/e2node info for reparenting
POST /api/writeup_reparent/reparent - Perform writeup reparenting operation

=cut

sub routes
{
    return {
        "/"        => "get",
        "reparent" => "post"
    };
}

sub get
{
    my ( $self, $REQUEST ) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Security: Editors and admins only
    unless ( $APP->isEditor( $USER->NODEDATA ) || $APP->isAdmin( $USER->NODEDATA ) ) {
        return [ $self->HTTP_OK, { success => 0, error => 'Access denied. Editors and admins only.' } ];
    }

    return $self->handle_get($REQUEST);
}

sub post
{
    my ( $self, $REQUEST ) = @_;

    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Security: Editors and admins only
    unless ( $APP->isEditor( $USER->NODEDATA ) || $APP->isAdmin( $USER->NODEDATA ) ) {
        return [ $self->HTTP_OK, { success => 0, error => 'Access denied. Editors and admins only.' } ];
    }

    return $self->handle_post($REQUEST);
}

=head2 handle_get

GET /api/writeup_reparent?old_e2node_id=123&old_writeup_id=456&new_e2node_id=789

Returns information about the source and destination nodes for reparenting.

=cut

sub handle_get
{
    my ( $self, $REQUEST ) = @_;

    my $DB    = $self->DB;
    my $query = $REQUEST->cgi;

    my $old_e2node_id  = $query->param('old_e2node_id');
    my $old_writeup_id = $query->param('old_writeup_id');
    my $new_e2node_id  = $query->param('new_e2node_id');

    my $result = {
        old_e2node       => undef,
        old_writeup      => undef,
        new_e2node       => undef,
        suggested_parent => undef,
        errors           => []
    };

    # Get old e2node if provided
    if ($old_e2node_id) {
        my $old_e2node = $self->getNodeByNameOrId( $old_e2node_id, 'e2node' );
        if ($old_e2node) {
            $result->{old_e2node} = $self->formatE2NodeInfo($old_e2node);
        } else {
            push @{ $result->{errors} }, 'Invalid old e2node ID or title';
        }
    }

    # Get writeup if provided
    if ($old_writeup_id) {
        my $writeup = $self->getNodeByNameOrId( $old_writeup_id, 'writeup' );
        if ($writeup) {
            $result->{old_writeup} = $self->formatWriteupInfo($writeup);

            # Try to find parent node
            my $parent_node = $DB->getNodeById( $writeup->{parent_e2node} );
            if ( $parent_node && $parent_node->{type}{title} eq 'e2node' ) {
                $result->{old_e2node} = $self->formatE2NodeInfo($parent_node);
            } else {
                # Orphaned writeup - try to guess parent
                my $suggested_parent = $self->guessParentForWriteup($writeup);
                if ($suggested_parent) {
                    $result->{suggested_parent} = $self->formatE2NodeInfo($suggested_parent);
                }
            }
        } else {
            push @{ $result->{errors} }, 'Invalid writeup ID';
        }
    }

    # Get new e2node if provided
    if ($new_e2node_id) {
        my $new_e2node = $self->getNodeByNameOrId( $new_e2node_id, 'e2node' );
        if ($new_e2node) {
            $result->{new_e2node} = $self->formatE2NodeInfo($new_e2node);
        } else {
            push @{ $result->{errors} }, 'Invalid new e2node ID or title';
        }
    }

    return [ $self->HTTP_OK, { success => 1, data => $result } ];
}

=head2 handle_post

POST /api/writeup_reparent

Body: { new_e2node_id: 123, writeup_ids: [456, 789] }

Performs the reparenting operation.

=cut

sub handle_post
{
    my ( $self, $REQUEST ) = @_;

    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # Parse JSON body - do NOT decode_utf8 before decode_json
    my $postdata = $REQUEST->POSTDATA || '{}';

    my $data;
    my $eval_success = eval { $data = decode_json($postdata); 1; };
    unless ($eval_success) {
        return [ $self->HTTP_OK, { success => 0, error => 'Invalid JSON in request body' } ];
    }

    my $new_e2node_id = $data->{new_e2node_id};
    my $writeup_ids   = $data->{writeup_ids} || [];

    unless ($new_e2node_id) {
        return [ $self->HTTP_OK, { success => 0, error => 'new_e2node_id is required' } ];
    }

    unless ( ref $writeup_ids eq 'ARRAY' && @$writeup_ids ) {
        return [ $self->HTTP_OK, { success => 0, error => 'writeup_ids array is required and must not be empty' } ];
    }

    # Get destination e2node
    my $new_e2node = $self->getNodeByNameOrId( $new_e2node_id, 'e2node' );
    unless ($new_e2node) {
        return [ $self->HTTP_OK, { success => 0, error => 'Invalid destination e2node' } ];
    }

    my @results;
    my $moved_count = 0;

    foreach my $writeup_id (@$writeup_ids) {
        my $result = $self->reparentWriteup( $writeup_id, $new_e2node, $USER->NODEDATA );
        push @results, $result;
        $moved_count++ if $result->{success};
    }

    # Note: repair_e2node could be called here to update soft links
    # but the core reparenting (nodegroup updates, parent_e2node) is sufficient

    return [
        $self->HTTP_OK,
        {
            success      => 1,
            moved_count  => $moved_count,
            results      => \@results,
            new_e2node   => $self->formatE2NodeInfo( $DB->getNodeById( $new_e2node->{node_id} ) )
        }
    ];
}

=head2 reparentWriteup

Reparents a single writeup to a new e2node.

=cut

sub reparentWriteup
{
    my ( $self, $writeup_id, $new_e2node, $USER ) = @_;

    my $DB  = $self->DB;
    my $APP = $self->APP;

    # Get writeup
    my $writeup = $DB->getNodeById( $writeup_id, 'writeup' );
    unless ( $writeup && $writeup->{type}{title} eq 'writeup' ) {
        return { success => 0, writeup_id => $writeup_id, error => 'Invalid writeup ID' };
    }

    # Get old e2node (may not exist if orphaned)
    my $old_e2node;
    if ( $writeup->{parent_e2node} ) {
        $old_e2node = $DB->getNodeById( $writeup->{parent_e2node} );
        $old_e2node = undef unless ( $old_e2node && $old_e2node->{type}{title} eq 'e2node' );
    }

    # Check if already in destination nodegroup
    my $newgroup           = $new_e2node->{group} || [];
    my $already_in_group   = scalar grep { $_ == $writeup_id } @$newgroup;
    my $old_title          = $writeup->{title};
    my $old_parent_node_id = $writeup->{parent_e2node};

    # Remove from old nodegroup if moving between different e2nodes
    if ( $old_e2node && $new_e2node->{node_id} != $old_e2node->{node_id} ) {
        $DB->removeFromNodegroup( $old_e2node, $writeup, -1 );
    }

    # Get or validate writeuptype
    my $writeuptype = $DB->getNodeById( $writeup->{wrtype_writeuptype} );
    unless ( $writeuptype && $writeuptype->{type}{title} eq 'writeuptype' ) {
        $writeuptype = $DB->getNode( 'idea', 'writeuptype' );
    }

    # Update writeup
    $writeup->{wrtype_writeuptype} = $writeuptype->{node_id};
    $writeup->{title}              = $new_e2node->{title} . " ($writeuptype->{title})";
    $writeup->{parent_e2node}      = $new_e2node->{node_id};

    # Add to new nodegroup
    unless ($already_in_group) {
        $DB->insertIntoNodegroup( $new_e2node, -1, $writeup );
    }

    # Update writeup in database
    $DB->updateNode( $writeup, -1 );

    # Get author for logging and notification
    my $author = $DB->getNodeById( $writeup->{author_user} );
    my $author_title = $author ? $author->{title} : 'unknown user';

    # Security log
    my $log_message =
          "Reparented writeup: '$old_title' by $author_title -> '"
        . $writeup->{title} . "'"
        . ( $old_e2node ? " (from e2node $old_e2node->{node_id})" : " (from orphaned state)" );

    $APP->securityLog( $new_e2node, $USER, $log_message );

    # Send notification to author
    if ( $author && $author->{node_id} != $USER->{node_id} ) {
        $DB->sqlInsert(
            'message',
            {
                msgtext => "I moved your writeup \"$old_title\" to \"$new_e2node->{title}\"",
                author_user => $USER->{node_id},
                for_user    => $author->{node_id}
            }
        );
    }


    return {
        success               => 1,
        writeup_id            => $writeup_id,
        old_title             => $old_title,
        new_title             => $writeup->{title},
        old_parent_node_id    => $old_parent_node_id,
        new_parent_node_id    => $new_e2node->{node_id},
        author_id             => $author ? $author->{node_id} : undef,
        author_title          => $author_title,
        already_in_nodegroup  => $already_in_group ? 1 : 0,
        writeuptype           => $writeuptype->{title}
    };
}

=head2 getNodeByNameOrId

Gets a node by ID (numeric) or title (string).

=cut

sub getNodeByNameOrId
{
    my ( $self, $node_id_or_name, $nodetype ) = @_;

    my $DB = $self->DB;

    return unless defined $node_id_or_name;

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

Attempts to guess the parent e2node for an orphaned writeup by stripping
the writeuptype suffix from the title.

=cut

sub guessParentForWriteup
{
    my ( $self, $writeup ) = @_;

    my $DB = $self->DB;

    my $guess_title = $writeup->{title};

    # Strip writeuptype suffix like "(idea)" from title
    # Be tolerant of writeups where it gets cut off
    $guess_title =~ s/^(.*?)(\([^\(]*)?$/$1/;
    $guess_title =~ s/\s+$//;    # Trim trailing whitespace

    return unless $guess_title;

    my $potential_parent = $DB->getNode( $guess_title, 'e2node' );
    return $potential_parent;
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
        node_id  => $e2node->{node_id},
        title    => $e2node->{title},
        writeups => \@writeups,
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

    my $author = $DB->getNodeById( $writeup->{author_user} );
    my $writeuptype = $DB->getNodeById( $writeup->{wrtype_writeuptype} );

    return {
        node_id         => $writeup->{node_id},
        title           => $writeup->{title},
        parent_e2node   => $writeup->{parent_e2node},
        author_id       => $author ? $author->{node_id} : undef,
        author_title    => $author ? $author->{title} : 'unknown',
        writeuptype     => $writeuptype ? $writeuptype->{title} : 'unknown',
        createtime      => $writeup->{createtime}
    };
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SEE ALSO

L<Everything::API>

=cut
