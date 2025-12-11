package Everything::Page::create_category;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::create_category - Create a new category

=head1 DESCRIPTION

Provides a form for creating new categories. Categories can be maintained by:
- The creating user only
- Any noder (public category)
- Any usergroup the creating user is a member of

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns form data for category creation including usergroups the user belongs to.

=cut

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $APP  = $self->APP;

    # Check if user is guest
    if ( $APP->isGuest( $USER->NODEDATA ) ) {
        return {
            type      => 'create_category',
            error     => 'You must be logged in to create a category.',
            mustLogin => 1
        };
    }

    # Check if user is locked from creating categories
    my $user_id = $USER->node_id;
    my $userlock =
      $DB->sqlSelectHashref( '*', 'nodelock', "nodelock_node=$user_id" );
    if ($userlock) {
        return {
            type      => 'create_category',
            error     => 'You are forbidden from creating categories.',
            forbidden => 1
        };
    }

    # Get usergroups current user is a member of
    my $csr = $DB->sqlSelectMany(
        'ug.node_id, ug.title',
        'node ug, nodegroup ng',
        "ng.nodegroup_id = ug.node_id AND ng.node_id = $user_id",
        'ORDER BY ug.title'
    );

    my @usergroups = ();
    while ( my $row = $csr->fetchrow_hashref ) {
        push @usergroups,
          {
            node_id => $row->{node_id},
            title   => $row->{title}
          };
    }

    # Get category type ID
    my $category_type    = $DB->getType('category');
    my $category_type_id = $category_type->{node_id};

    # Get guest user ID for "Any Noder" option
    my $guest_user_id = $Everything::CONF->guest_user;

    return {
        type              => 'create_category',
        user_id           => $user_id,
        user_title        => $USER->title,
        usergroups        => \@usergroups,
        category_type_id  => $category_type_id,
        guest_user_id     => $guest_user_id,
        user_level        => $APP->getLevel( $USER->NODEDATA ),
        low_level_warning => ( $APP->getLevel( $USER->NODEDATA ) <= 1 ) ? 1 : 0
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
