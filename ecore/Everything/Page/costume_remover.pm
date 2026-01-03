package Everything::Page::costume_remover;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::StaffOnly';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    return {
        type => 'costume_remover',
    };
}

__PACKAGE__->meta->make_immutable;

1;
