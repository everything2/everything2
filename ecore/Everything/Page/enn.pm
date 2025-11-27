package Everything::Page::enn;

use Moose;
extends 'Everything::Page';

has 'records' => ( is => 'ro', isa => 'Int', default => 300 );

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $user  = $REQUEST->user;
    my $nodes = $self->APP->newnodes( $self->records, $user->is_editor );

    # Convert blessed writeup objects to simple data structures
    my @nodelist;
    foreach my $node (@$nodes) {
        my $parent = $node->parent;
        my $author = $node->author;

        # Check if parent/author exist and are not null nodes
        my $has_parent = $parent && ref($parent) ne 'Everything::Node::null';
        my $has_author = $author && ref($author) ne 'Everything::Node::null';

        # Skip nodes with missing critical data
        next unless $has_author;

        push @nodelist,
          {
            node_id      => $node->node_id,
            parent_id    => $has_parent ? $parent->node_id : $node->node_id,
            parent_title => $has_parent ? $parent->title   : $node->title,
            writeuptype  => $node->writeuptype,
            publishtime  => $node->publishtime,
            author_id    => $author->node_id,
            author_name  => $author->title,
            notnew       => $node->notnew || 0
          };
    }

    return {
        type        => 'enn',
        nodelist    => \@nodelist,
        records     => $self->records,
        currentPage => 'ENN'
    };
}

__PACKAGE__->meta->make_immutable;

1;
