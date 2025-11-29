package Everything::Page::e2_rot13_encoder;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ( $self, $REQUEST ) = @_;

    my $DB           = $self->DB;
    my $lastNodeText = q{};

    # If coming from a writeup, pre-load its text for encoding
    my $lastnode_id = $REQUEST->param('lastnode_id');
    if ($lastnode_id) {
        my $node = $DB->getNodeById($lastnode_id);
        if ( $node && $node->{type}{title} eq 'writeup' ) {
            $lastNodeText = $node->{doctext} || q{};
        }
    }

    return {
        type         => 'e2_rot13_encoder',
        lastNodeText => $lastNodeText
    };
}

__PACKAGE__->meta->make_immutable;

1;
