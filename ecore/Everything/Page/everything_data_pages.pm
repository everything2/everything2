package Everything::Page::everything_data_pages;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_data_pages - Everything Data Pages Directory

=head1 DESCRIPTION

Lists available XML/JSON API endpoints (fullpage and ticker node types).
These are parseable data feeds for client developers.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns React data structure with lists of fullpage and ticker nodes.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;

    # Get fullpage nodes
    my $fullpage_type_id = $DB->getId($DB->getType('fullpage'));
    my @fullpage_nodes = $DB->getNodeWhere({ type_nodetype => $fullpage_type_id }, undef, 'title');

    # Exclude certain internal/deprecated pages
    my %excluded = map { $_ => 1 } (
        'chatterlight',
        'chatterlight classic',
        'Chatterlighter',
        'Ajax Update',
        'Guest Front Page',
        'inboxlight'  # Deprecated - functionality covered by Message Inbox
    );

    my @fullpages;
    foreach my $node (@fullpage_nodes) {
        next if $excluded{$node->{title}};
        push @fullpages, {
            node_id => $node->{node_id},
            title => $node->{title}
        };
    }

    # Get ticker nodes
    my $ticker_type_id = $DB->getId($DB->getType('ticker'));
    my @ticker_nodes = $DB->getNodeWhere({ type_nodetype => $ticker_type_id }, undef, 'title');

    my @tickers;
    foreach my $node (@ticker_nodes) {
        push @tickers, {
            node_id => $node->{node_id},
            title => $node->{title}
        };
    }

    return {
        type => 'everything_data_pages',
        fullpages => \@fullpages,
        tickers => \@tickers
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
