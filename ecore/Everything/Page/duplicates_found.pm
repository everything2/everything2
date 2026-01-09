package Everything::Page::duplicates_found;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::duplicates_found - Duplicates Found page

=head1 DESCRIPTION

Displayed when multiple nodes match a search query. Shows a table of matching
nodes with their types and authors.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data about duplicate nodes found, or redirects if only one match.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user->NODEDATA;
    my $NODE = $REQUEST->node;
    my $query = $REQUEST->cgi;

    my $search_term = $query->param('node') || '';
    my $lastnode_id = $query->param('lastnode_id') || 0;
    my $current_user_id = $USER->{node_id};

    my @matches = ();
    my $one_visible_match = undef;

    # Iterate over the group to find readable matches
    foreach my $node_id (@{$NODE->NODEDATA->{group} || []}) {
        my $N = $DB->getNodeById($node_id, 'light');
        next unless $DB->canReadNode($USER, $N);

        # Skip drafts unless user can see them
        if ($N->{type}{title} eq 'draft' && !$APP->canSeeDraft($USER, $N, 'find')) {
            next;
        }

        # Track if we have exactly one visible match
        if (!@matches) {
            $one_visible_match = $N;
        } else {
            $one_visible_match = undef;
        }

        my $author_name = '';
        if ($N->{author_user}) {
            my $author = $DB->getNodeById($N->{author_user});
            $author_name = $author ? $author->{title} : '';
        }

        push @matches, {
            node_id => $N->{node_id},
            title => $N->{title},
            type => $N->{type}{title},
            author_user => $N->{author_user} || 0,
            author_name => $author_name,
            createtime => $N->{createtime},
            is_current_user => ($N->{author_user} && $N->{author_user} == $current_user_id) ? 1 : 0
        };
    }

    # If no matches, redirect to nothing_found
    if (!@matches) {
        return {
            type => 'duplicates_found',
            redirect_to_nothing_found => 1
        };
    }

    # If exactly one match, set up a redirect
    if ($one_visible_match) {
        return {
            type => 'duplicates_found',
            redirect_to_node => $one_visible_match->{node_id}
        };
    }

    return {
        type => 'duplicates_found',
        search_term => $search_term,
        matches => \@matches,
        lastnode_id => $lastnode_id
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
