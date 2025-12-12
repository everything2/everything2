package Everything::Page::mark_all_discussions_as_read;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::mark_all_discussions_as_read - Mark all debates as read

=head1 DESCRIPTION

Allows CE members to mark all CE debates as read, and admins to mark
admin debates as read as well.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB    = $self->DB;
    my $APP   = $self->APP;
    my $USER  = $REQUEST->user;
    my $query = $REQUEST->cgi;

    my $uid = $USER->node_id;
    my $is_admin = $APP->isAdmin($USER->NODEDATA);
    my $is_editor = $APP->isEditor($USER->NODEDATA);

    # Look up usergroup IDs by name (never hardcode node IDs)
    my $ce_node = $DB->getNode('Content Editors', 'usergroup');
    my $gods_node = $DB->getNode('gods', 'usergroup');
    my $ce_id = $ce_node ? $ce_node->{node_id} : 0;
    my $gods_id = $gods_node ? $gods_node->{node_id} : 0;

    # Check if user has any relevant access
    unless ($is_editor || $is_admin) {
        return {
            type => 'mark_all_discussions_as_read',
            error => 'You must be a Content Editor or Administrator to use this tool.'
        };
    }

    my @messages;
    my $ce_marked = 0;
    my $admin_marked = 0;

    # Handle CE debates marking
    my $mark_ce = $query->param('mark_ce_read');
    if ($mark_ce && $ce_id) {
        my $count = $self->_mark_debates_as_read($DB, $uid, $ce_id);
        $ce_marked = 1;
        push @messages, "All CE debates have been marked as read ($count debates updated).";
    }

    # Handle admin debates marking (only if admin)
    my $mark_admin = $query->param('mark_admin_read');
    if ($mark_admin && $is_admin && $gods_id) {
        my $count = $self->_mark_debates_as_read($DB, $uid, $gods_id);
        $admin_marked = 1;
        push @messages, "All admin debates have been marked as read ($count debates updated).";
    }

    # Get the node_id for the document so links can include it
    my $node_id = $REQUEST->node ? $REQUEST->node->node_id : 0;

    return {
        type => 'mark_all_discussions_as_read',
        node_id => $node_id,
        is_admin => $is_admin ? 1 : 0,
        is_editor => $is_editor ? 1 : 0,
        ce_marked => $ce_marked,
        admin_marked => $admin_marked,
        messages => \@messages
    };
}

sub _mark_debates_as_read {
    my ($self, $DB, $uid, $group_id) = @_;

    my $count = 0;

    # Get all debates for this usergroup
    my $csr = $DB->sqlSelectMany(
        "root_debatecomment",
        "debatecomment",
        "restricted = $group_id",
        "GROUP BY root_debatecomment"
    );

    while (my $row = $csr->fetchrow_hashref) {
        my $debate = $row->{root_debatecomment};

        # Check if user already has a lastreaddebate record
        my $lastread = $DB->sqlSelect(
            "dateread",
            "lastreaddebate",
            "user_id = $uid AND debateroot_id = $debate"
        );

        if ($lastread) {
            # Update existing record
            $DB->sqlUpdate(
                "lastreaddebate",
                { -dateread => "NOW()" },
                "user_id = $uid AND debateroot_id = $debate"
            );
        } else {
            # Insert new record
            $DB->sqlInsert("lastreaddebate", {
                user_id => $uid,
                debateroot_id => $debate,
                -dateread => "NOW()"
            });
        }
        $count++;
    }

    return $count;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
