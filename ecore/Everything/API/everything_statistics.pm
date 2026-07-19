package Everything::API::everything_statistics;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::everything_statistics - site-wide totals (nodes, writeups, users, links)

=head1 DESCRIPTION

Admin-only site statistics. The source node is a restricted_superdoc; that gate lives here now -- a
pure gate serves the page to anyone and /api/pagestate bypasses node permissions, so the API is the
real boundary (#4546). Moved out of C<Everything::Page::everything_statistics>'s buildReactData.

  GET /api/everything_statistics

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;
    return [$self->HTTP_OK, { success => 0, state => 'permission' }]
        unless $APP->isAdmin($user->NODEDATA);

    my $total_nodes    = $DB->sqlSelect('count(*)', 'node');
    my $writeup_type_id = $DB->getType('writeup')->{node_id};
    my $total_writeups = $DB->sqlSelect('count(*)', 'node', "type_nodetype=$writeup_type_id");
    my $total_users    = $DB->sqlSelect('count(*)', 'user');
    my $total_links    = $DB->sqlSelect('count(*)', 'links');

    my $finger_node = $DB->getNode('Everything Finger', 'superdoc');
    my $news_node   = $DB->getNode('news for noders.  stuff that matters.', 'document');

    return [$self->HTTP_OK, {
        success        => 1,
        total_nodes    => int($total_nodes || 0),
        total_writeups => int($total_writeups || 0),
        total_users    => int($total_users || 0),
        total_links    => int($total_links || 0),
        finger_node_id => $finger_node ? int($finger_node->{node_id}) : undef,
        news_node_id   => $news_node   ? int($news_node->{node_id})   : undef,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
