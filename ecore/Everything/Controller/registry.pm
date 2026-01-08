package Everything::Controller::registry;

use Moose;
extends 'Everything::Controller';

with 'Everything::Controller::Role::BasicEdit';

# Controller for registry nodes
# Migrated from Everything::Delegation::htmlpage::registry_display_page
#
# Registries allow users to submit data entries (text, dates, yes/no).
# Only logged-in users can view and submit entries.
# Admins can delete any user's entry.
#
# input_style options:
# - NULL or empty: free text input
# - 'date': date picker (with optional secret year)
# - 'yes/no': yes/no dropdown

sub display {
    my ($self, $REQUEST, $node) = @_;

    my $user = $REQUEST->user;
    my $DB = $self->DB;
    my $APP = $self->APP;

    my $node_data = $node->NODEDATA;
    my $is_guest = $user->is_guest ? 1 : 0;
    my $is_admin = $user->is_admin ? 1 : 0;

    # Get author info
    my $author = $APP->node_by_id($node_data->{author_user});
    my $author_data = $author ? {
        node_id => int($author->node_id),
        title => $author->title
    } : { node_id => 0, title => 'Unknown' };

    # Build registry data
    my $registry_data = {
        node_id => int($node->node_id),
        title => $node->title,
        doctext => $node_data->{doctext} || '',
        input_style => $node_data->{input_style} || 'text',
        author => $author_data
    };

    # Initialize entries and user_entry
    my $entries = [];
    my $user_entry = undef;

    # Only fetch entries for logged-in users
    unless ($is_guest) {
        # Fetch all entries
        my $csr = $DB->sqlSelectMany(
            'r.*, n.title as username',
            'registration r JOIN node n ON r.from_user = n.node_id',
            'r.for_registry = ' . $node->node_id,
            'ORDER BY r.tstamp DESC'
        );

        if ($csr) {
            while (my $row = $csr->fetchrow_hashref()) {
                push @$entries, {
                    user_id => int($row->{from_user}),
                    username => $row->{username},
                    data => $row->{data},
                    comments => $row->{comments},
                    in_user_profile => $row->{in_user_profile} ? 1 : 0,
                    timestamp => $row->{tstamp}
                };
            }
            $csr->finish();
        }

        # Get current user's entry if exists
        my $user_row = $DB->sqlSelectHashref(
            'data, comments, in_user_profile, tstamp',
            'registration',
            'from_user = ' . $user->node_id . ' AND for_registry = ' . $node->node_id
        );

        if ($user_row) {
            $user_entry = {
                data => $user_row->{data},
                comments => $user_row->{comments},
                in_user_profile => $user_row->{in_user_profile} ? 1 : 0,
                timestamp => $user_row->{tstamp}
            };
        }
    }

    # Build contentData for React
    my $content_data = {
        type => 'registry',
        registry => $registry_data,
        entries => $entries,
        user_entry => $user_entry,
        is_guest => $is_guest,
        is_admin => $is_admin
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
