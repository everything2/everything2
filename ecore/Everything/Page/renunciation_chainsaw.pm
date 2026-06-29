package Everything::Page::renunciation_chainsaw;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::renunciation_chainsaw - Bulk transfer writeup ownership

=head1 DESCRIPTION

Admin tool for transferring ownership of multiple writeups from one user
to another. Used when a user renounces their writeups or when content
needs to be reassigned.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $q    = $REQUEST->cgi;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'renunciation_chainsaw',
            error => 'This page is restricted to administrators.'
        };
    }

    my $result = {
        type => 'renunciation_chainsaw'
    };

    # Check for pre-filled writeup
    my $wu_id = $q->param('wu_id');
    if ($wu_id && $wu_id =~ /^\d+$/) {
        my $writeup_type = $DB->getType('writeup');
        my $wu = $DB->getNodeById($wu_id);
        if ($wu && $wu->{type_nodetype} == $writeup_type->{node_id}) {
            my $author = $DB->getNodeById($wu->{author_user}, 'light');
            my $parent = $DB->getNodeById($wu->{parent_e2node}, 'light');
            $result->{prefill_user} = $author ? $author->{title} : '';
            $result->{prefill_node} = $parent ? $parent->{title} : '';
        }
    }

    # The ownership transfer and the "generate nodelist" read moved to POST
    # /api/renunciation/{transfer,nodes} (Everything::API::renunciation) so
    # rendering this page no longer reparents writeups (#4414). buildReactData is
    # pure-render: the admin gate above + the optional ?wu_id prefill below; the
    # React form drives the transfer and the node-list via the API.

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
