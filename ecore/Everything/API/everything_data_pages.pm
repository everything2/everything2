package Everything::API::everything_data_pages;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::everything_data_pages - directory of the parseable data feeds

=head1 DESCRIPTION

Lists the C<fullpage> and C<ticker> nodes -- the XML/JSON endpoints client developers can parse.
Moved out of C<Everything::Page::everything_data_pages>'s buildReactData (#4557): the Page is a pure
gate. Public (superdoc).

  GET /api/everything_data_pages

=cut

sub routes { return { "/" => "list" }; }

# Internal/deprecated pages that should not be advertised as data feeds.
my %EXCLUDED = map { $_ => 1 } (
    'chatterlight',
    'chatterlight classic',
    'Chatterlighter',
    'Ajax Update',
    'Guest Front Page',
    'inboxlight',   # deprecated -- covered by Message Inbox
);

sub _nodes_of_type {
    my ($self, $typename, $skip_excluded) = @_;
    my $DB = $self->DB;
    my $type = $DB->getType($typename);
    return [] unless $type;

    my @out;
    foreach my $node ($DB->getNodeWhere({ type_nodetype => $DB->getId($type) }, undef, 'title')) {
        next if $skip_excluded && $EXCLUDED{ $node->{title} };
        push @out, { node_id => int($node->{node_id}), title => $node->{title} };
    }
    return \@out;
}

sub list {
    my ($self, $REQUEST) = @_;

    return [$self->HTTP_OK, {
        success   => 1,
        fullpages => $self->_nodes_of_type('fullpage', 1),
        tickers   => $self->_nodes_of_type('ticker', 0),
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
