package Everything::Page::who_is_doing_what;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::who_is_doing_what - Admin tool to view recent node activity

=head1 DESCRIPTION

"Who is Doing What" shows administrators recently created nodes of various types
(excluding writeups, e2nodes, drafts, users, and debate comments). This helps
admins monitor system activity and see what other users/admins are creating.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns a list of recently created nodes for admin review.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $query = $REQUEST->cgi;
    my $user = $REQUEST->user;

    # Admin-only access
    unless ($APP->isAdmin($user->NODEDATA)) {
        return {
            access_denied => 1,
            username => $user->title
        };
    }

    # Get days parameter, default to 2
    my $days = $query->param('days') || 2;
    $days = int($days);
    $days = 2 if $days < 1;
    $days = 30 if $days > 30;  # Cap at 30 days

    # Get node type IDs to ignore
    my @ignore_types = qw(writeup e2node draft user debatecomment);
    my @ignore_ids = ();

    for my $type_name (@ignore_types) {
        my $type_node = $DB->getType($type_name);
        push @ignore_ids, $type_node->{node_id} if $type_node;
    }

    my $ignore_list = join(',', @ignore_ids);

    # Query for recent nodes
    my $where = "createtime >= DATE_SUB(NOW(), INTERVAL $days DAY) " .
                "AND type_nodetype NOT IN ($ignore_list)";

    my $csr = $DB->sqlSelectMany(
        "node_id, title, type_nodetype, author_user, createtime",
        "node",
        $where,
        "ORDER BY createtime DESC LIMIT 500"
    );

    my @nodes = ();

    if ($csr) {
        while (my $row = $csr->fetchrow_hashref()) {
            my $type_node = $DB->getNodeById($row->{type_nodetype});
            my $author_node = $DB->getNodeById($row->{author_user});

            push @nodes, {
                node_id => $row->{node_id},
                title => $row->{title},
                type => $type_node ? $type_node->{title} : 'unknown',
                author_id => $row->{author_user},
                author => $author_node ? $author_node->{title} : 'unknown',
                createtime => $row->{createtime}
            };
        }
    }

    return {
        nodes => \@nodes,
        days => $days,
        node_count => scalar(@nodes)
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
