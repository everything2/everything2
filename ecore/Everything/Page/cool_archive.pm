package Everything::Page::cool_archive;

use Moose;
extends 'Everything::Page';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;

    # Get the Cool Archive Atom Feed link if it exists
    my $feed_node = $DB->getNode('Cool Archive Atom Feed', 'ticker');
    my $feed_url = $feed_node ? "/node/$feed_node->{node_id}" : undef;

    return {
        type => 'cool_archive',
        feed_url => $feed_url
    };
}

__PACKAGE__->meta->make_immutable;

1;
