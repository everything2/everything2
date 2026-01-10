package Everything::Page::_unimplemented;

use Moose;
extends 'Everything::Page';

# Fallback page for nodetypes/documents that don't have a dedicated Page class.
# This renders a friendly error message directing users to report the issue.

# Store the original htmlpage info for the error message
has 'htmlpage' => (is => 'rw');

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $node = $REQUEST->node;
    my $htmlpage = $self->htmlpage || {};

    return {
        type => 'unimplemented_page',
        node => {
            node_id => $node->node_id,
            title => $node->title,
            nodeType => $node->type->title,
        },
        page => {
            node_id => $htmlpage->{node_id} // 0,
            title => $htmlpage->{title} // 'unknown',
        },
    };
}

__PACKAGE__->meta->make_immutable;
1;
