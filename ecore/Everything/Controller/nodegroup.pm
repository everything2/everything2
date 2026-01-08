package Everything::Controller::nodegroup;

use Moose;
extends 'Everything::Controller';
with 'Everything::Controller::Role::BasicEdit';

# Controller for nodegroup nodes
# Migrated from Everything::Delegation::htmlpage::nodegroup_display_page
#
# Nodegroups are generic containers for any node type.
# Unlike usergroups, they:
# - Can contain any node type (not just users/usergroups)
# - Are only editable by admins
# - Display member type info for visual differentiation

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    # Get nodegroup data
    my $node_data = $node->NODEDATA;

    # Build enhanced group member data with type info
    my @enhanced_members;

    my $members = $node_data->{group} || [];

    foreach my $member_id (@$members) {
        my $member = $APP->node_by_id($member_id);
        next unless $member;

        my $member_data = $member->NODEDATA;
        my $type_title = $member->type->title;

        my $member_info = {
            node_id => int($member_id),
            title => $member->title,
            type => $type_title
        };

        # Add author info if available (for documents, writeups, etc.)
        if ($member_data->{author_user}) {
            my $author = $APP->node_by_id($member_data->{author_user});
            if ($author) {
                $member_info->{author} = {
                    node_id => int($author->node_id),
                    title => $author->title
                };
            }
        }

        push @enhanced_members, $member_info;
    }

    # Build user data
    my $user_data = {
        node_id  => $user->node_id,
        title    => $user->title,
        is_guest => $user->is_guest ? 1 : 0,
        is_admin => $user->is_admin ? 1 : 0
    };

    # Only admins can edit nodegroups
    my $can_edit = $user->is_admin ? 1 : 0;

    # Build contentData for React
    my $content_data = {
        type => 'nodegroup',
        nodegroup => {
            node_id => int($node->node_id),
            title => $node->title,
            doctext => $node_data->{doctext} || '',
            group => \@enhanced_members,
            member_count => scalar(@enhanced_members)
        },
        user => $user_data,
        can_edit => $can_edit
    };

    # Set node on REQUEST for buildNodeInfoStructure
    $REQUEST->node($node);

    # Build e2 data structure
    my $e2 = $APP->buildNodeInfoStructure(
        $node_data,
        $REQUEST->user->NODEDATA,
        $REQUEST->user->VARS,
        $REQUEST->cgi,
        $REQUEST
    );

    # Override contentData with our directly-built data
    $e2->{contentData} = $content_data;
    $e2->{reactPageMode} = \1;

    # Use react_page layout (includes sidebar/header/footer)
    my $html = $self->layout(
        '/pages/react_page',
        e2 => $e2,
        REQUEST => $REQUEST,
        node => $node
    );

    return [$self->HTTP_OK, $html];
}

__PACKAGE__->meta->make_immutable;
1;
