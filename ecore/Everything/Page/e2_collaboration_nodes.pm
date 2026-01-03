package Everything::Page::e2_collaboration_nodes;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'e2_collaboration_nodes',
    };
}

__PACKAGE__->meta->make_immutable;

1;
