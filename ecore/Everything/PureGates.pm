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

    # Static docs / poll pages (#4520): pure gates, name == type, no payload.
    about_nobody                           => {},
    e2_acceptable_use_policy               => {},
    online_only_msg                        => {},
    ask_everything_do_i_have_the_swine_flu => {},
    everything_poll_archive                => {},
    everything_poll_directory              => {},
    everything_user_poll                   => {},

    # "Is it <holiday> yet" (#4520): all five share the IsItHoliday component, selected by occasion.
    is_it_christmas_yet       => { occasion => 'xmas' },
    is_it_halloween_yet       => { occasion => 'halloween' },
    is_it_new_year_s_day_yet  => { occasion => 'nyd' },
    is_it_new_year_s_eve_yet  => { occasion => 'nye' },
    is_it_april_fools_day_yet => { occasion => 'afd' },

    # Static config payload (#4520).
    spam_cannon => { max_recipients => 20 },

    # Content generators + permission_denied (#4522): the quote arrays / the message string moved
    # into their React components (RandomText WIT map, PermissionDenied), leaving pure { type } gates.
    fezisms_generator   => {},
    piercisms_generator => {},
    permission_denied   => {},

    # Report controllers (#4524): the params + queries moved to Everything::API::*; each Page is a
    # pure gate, React reads the filters off the URL and fetches the API.
    writeups_by_type    => {},
    nodes_of_the_year   => {},
    my_big_writeup_list => {},

    # User-activity reports (#4526): params + queries moved to Everything::API::*.
    homenode_inspector      => {},
    caja_de_arena           => {},
    everything_s_best_users => {},

    # Node-notes + editor reports (#4528).
    recent_node_notes    => {},
    node_notes_by_editor => {},
    editor_endorsements  => {},

    # Admin investigation tools (#4530).
    ip_hunter       => {},
    who_killed_what => {},
    voting_data     => {},

    # Numbered new-nodes lists -- all served by /api/newnodes, count in React (#4537).
    25                   => {},
    everything_new_nodes => {},
    e2n                  => {},
    enn                  => {},
    ekn                  => {},

    # Recommendation engines + noding speedometer (#4539).
    do_you_c_what_i_c  => {},
    the_recommender    => {},
    noding_speedometer => {},

    # Usergroup content viewers (#4541).
    usergroup_discussions     => {},
    usergroup_message_archive => {},

    # News weblogs (#4543). The News-for-Noders node is named
    # news_for_noders_stuff_that_matters but its React document type is the shorter
    # 'news_for_noders', so override the emitted type here.
    news_for_noders_stuff_that_matters => { type => 'news_for_noders' },
    news_archives                      => {},

    # Statistics + leaderboard reports (#4546): read-only aggregates moved to Everything::API::*.
    # The source nodes' types carry the access level, and since a pure gate serves the page to
    # anyone (/api/pagestate bypasses node perms), each API re-asserts it -- the API is the real
    # boundary: restricted_superdoc -> admin, oppressor_superdoc -> editor, superdoc -> public.
    everything_statistics       => {},   # restricted_superdoc -> admin
    user_statistics             => {},   # restricted_superdoc -> admin
    everything_s_richest_noders => {},   # restricted_superdoc -> admin
    everything_s_biggest_stars  => {},   # superdoc           -> public
    level_distribution          => {},   # superdoc           -> public
    everything_s_best_writeups  => {},   # oppressor_superdoc -> editor

    # Registries reports (#4548): login-required (NoGuest) superdocs; each API returns state:'guest'
    # for guests. include_empty is read off the URL in React and passed to /api/the_registries.
    the_registries          => {},
    registry_information    => {},
    recent_registry_entries => {},
);

sub registry { return \%REGISTRY; }

1;
