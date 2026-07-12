package Everything::PureGates;

use strict;
use warnings;

=head1 NAME

Everything::PureGates - the pure-gate page whitelist (data only)

=head1 DESCRIPTION

Many React pages are pure gates: their server side is nothing but a static contentData payload
(C<{ type =E<gt> ... }>, plus at most static layout config) -- the React component and its API own
everything. Rather than a dedicated C<Everything::Page::*> module each, they are listed here (#4513).

Two consumers read this registry:

=over

=item * L<Everything::Controller>'s C<_build_page_table> -- slots a generic L<Everything::PureGatePage>
instance into the PAGE_TABLE for each entry, so C<page_class> resolves it (permission + display).

=item * L<Everything::Application>'s C<buildNodeInfoStructure> -- emits the payload as C<contentData>
when there is no C<Everything::Page::$name> module.

=back

This is a leaf data module with no dependencies on purpose, so both consumers (one of which is core
C<Application>) can read it without a circular use.

Keys are the normalized page name (see L<Everything::Controller/title_to_page>: lowercase, non-word
runs collapsed to single underscores). Values are the static contentData. C<buildNodeInfoStructure>
auto-adds C<type =E<gt> $page_name>, so an entry only needs C<type> when it differs from the name
(e.g. the horizontal reputation graph reuses the C<reputation_graph> component with a layout flag),
and may be C<{}> when the name IS the type.

=cut

my %REGISTRY = (
    # Content reports (#4511) -- data comes from Everything::API::content_reports.
    content_reports => { type => 'content_reports' },

    # Reputation graph pair (#4504) -- one React component, layout selects table vs chart. The
    # horizontal node reuses the reputation_graph component, so its type is overridden here.
    reputation_graph            => { type => 'reputation_graph', layout => 'vertical' },
    reputation_graph_horizontal => { type => 'reputation_graph', layout => 'horizontal' },

    # User search (#4506) -- React reads ?usersearch/orderby/page/filterhidden and calls the API.
    everything_user_search => { type => 'everything_user_search' },

    # Bestow admin-tool family (#4508/#4509) -- AdminBestowTool owns flavor text + permission tier.
    bestow_cools          => { type => 'bestow_cools' },
    bestow_easter_eggs    => { type => 'bestow_easter_eggs' },
    enrichify             => { type => 'enrichify' },
    fiery_teddy_bear_suit => { type => 'fiery_teddy_bear_suit' },
    giant_teddy_bear_suit => { type => 'giant_teddy_bear_suit' },
    superbless            => { type => 'superbless' },
    xp_superbless         => { type => 'xp_superbless' },
    the_well_of_cool      => { type => 'the_well_of_cool' },

    # JS-only toys / static pages (#4517): the whole page is a client-side widget or a static
    # document -- the server has nothing to add. The name IS the type, so the payload is empty
    # ({} -> buildNodeInfoStructure auto-adds type => the page name).
    e2_color_toy              => {},
    wharfinger_s_linebreaker  => {},
    text_formatter            => {},
    word_messer_upper         => {},
    zenmastery                => {},
    everything_quote_server   => {},
    oblique_strategies_garden => {},
    teddisms_generator        => {},
    e2_marble_shop            => {},
    e2_source_code_formatter  => {},
    between_the_cracks        => {},
    suspension_info           => {},
    e2_word_counter           => {},
);

sub registry { return \%REGISTRY; }

1;
