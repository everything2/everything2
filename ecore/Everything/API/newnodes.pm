package Everything::API::newnodes;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::newnodes - the most-recently-published writeups, N at a time

=head1 DESCRIPTION

Backs the numbered new-nodes documents (25 / Everything New Nodes / E2N / ENN / EKN). Those Pages
were byte-for-byte identical except a record count and a label; the count now lives in React config
and this single API serves them all (#4537).

  GET /api/newnodes?records=<N>

Public. C<records> is clamped to 1..1024 -- it flows into C<Application::newnodes>' C<LIMIT>, which
interpolates raw, so an unclamped user value would be an injection / runaway-query surface.
C<is_editor> is computed from the actual request user (it controls whether hidden writeups appear).

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $APP  = $self->APP;
    my $USER = $REQUEST->user;

    # int() strips anything non-numeric; clamp to a sane window (1..1024). Never
    # interpolate a user-supplied count into SQL unbounded.
    my $max_records = 1024;
    my $records = int($REQUEST->param('records') || 25);
    $records = 1            if $records < 1;
    $records = $max_records if $records > $max_records;

    my $nodes = $APP->newnodes($records, $USER->is_editor);

    my @nodelist;
    foreach my $node (@$nodes) {
        next unless $node && $node->can('parent');

        my $parent = $node->parent;
        my $author = $node->author;

        my $has_parent = $parent && ref($parent) ne 'Everything::Node::null';
        my $has_author = $author && ref($author) ne 'Everything::Node::null';

        next unless $has_author;

        # Force SCALAR context on every accessor. writeuptype() bare-`return`s
        # (an EMPTY LIST) for a writeup with no type; dropped straight into the
        # hash literal below that empty list would shift every following key/value
        # pair and scramble the whole row (surfaced on typeless test writeups
        # churned by other tests under `prove -j`) (#4537).
        my $writeuptype  = scalar $node->writeuptype;
        my $publishtime  = scalar $node->publishtime;
        my $author_name  = scalar $author->title;
        my $parent_title = $has_parent ? scalar $parent->title : scalar $node->title;

        push @nodelist, {
            node_id      => int($node->node_id),
            parent_id    => $has_parent ? int($parent->node_id) : int($node->node_id),
            parent_title => defined($parent_title) ? $parent_title : '',
            writeuptype  => defined($writeuptype) ? $writeuptype : '',
            publishtime  => defined($publishtime) ? $publishtime : '',
            author_id    => int($author->node_id),
            author_name  => defined($author_name) ? $author_name : '',
            # \1 / \0 encode as JSON true/false. A plain `?1:0` comes through the
            # API JSON path as the STRING "0", which is truthy in JS and would flip
            # every editor hide/unhide control to the wrong state (#4108 pattern).
            notnew       => $node->notnew ? \1 : \0,
        };
    }

    return [$self->HTTP_OK, {
        success  => 1,
        records  => $records,
        nodelist => \@nodelist,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
