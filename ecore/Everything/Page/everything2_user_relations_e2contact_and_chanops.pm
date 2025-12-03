package Everything::Page::everything2_user_relations_e2contact_and_chanops;

use Moose;
extends 'Everything::Page';

=head1 Everything::Page::everything2_user_relations__e2contact_and_chanops

React page for E2 User Relations help document.

Explains the e2contact and chanops groups and their responsibilities.

=cut

sub buildReactData
{
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;

    # Get the key user/group nodes for linking
    my $e2contact_node = $DB->getNode('e2contact', 'usergroup');
    my $chanops_node = $DB->getNode('chanops', 'usergroup');

    # Get leader nodes
    my $mauler = $DB->getNode('mauler', 'user');
    my $tem42 = $DB->getNode('Tem42', 'user');

    # Get e2contact members (if available)
    my @e2contact_members;
    if ($e2contact_node) {
        my $members = $DB->getNodeById($e2contact_node->{group}, 'nodegroup');
        if ($members && $members->{node}) {
            my @member_ids = split(',', $members->{node});
            foreach my $member_id (@member_ids) {
                my $member = $DB->getNodeById($member_id);
                push @e2contact_members, {
                    node_id => $member->{node_id},
                    title => $member->{title}
                } if $member;
            }
        }
    }

    # Get chanops members (if available)
    my @chanops_members;
    if ($chanops_node) {
        my $members = $DB->getNodeById($chanops_node->{group}, 'nodegroup');
        if ($members && $members->{node}) {
            my @member_ids = split(',', $members->{node});
            foreach my $member_id (@member_ids) {
                my $member = $DB->getNodeById($member_id);
                push @chanops_members, {
                    node_id => $member->{node_id},
                    title => $member->{title}
                } if $member;
            }
        }
    }

    return {
        type => 'user_relations',
        e2contact_node_id => $e2contact_node ? $e2contact_node->{node_id} : undef,
        chanops_node_id => $chanops_node ? $chanops_node->{node_id} : undef,
        leader => $mauler ? { node_id => $mauler->{node_id}, title => $mauler->{title} } : undef,
        director => $tem42 ? { node_id => $tem42->{node_id}, title => $tem42->{title} } : undef,
        e2contact_members => \@e2contact_members,
        chanops_members => \@chanops_members
    };
}

__PACKAGE__->meta->make_immutable;

1;
