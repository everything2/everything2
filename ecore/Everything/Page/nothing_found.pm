package Everything::Page::nothing_found;

use Moose;
use Readonly;
use List::Util qw(shuffle);
use Encode qw(decode_utf8 is_utf8);
extends 'Everything::Page';

=head1 NAME

Everything::Page::nothing_found - Nothing Found page

=head1 DESCRIPTION

Displayed when a node search returns no results. Shows appropriate message based
on context (nuke operation, URL, search) and provides forms for searching again
or creating new content.

For guest users, shows a selection of recent "best entries" (from coolnodes) to
encourage exploration.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns data for the Nothing Found page, including search term and user permissions.

=cut

Readonly my $EXCERPT_LENGTH => 400;
Readonly my $BEST_ENTRIES_COUNT => 20;

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $USER = $REQUEST->user;
    my $query = $REQUEST->cgi;

    my $node_param = $query->param('node') || '';
    my $op = $query->param('op') || '';
    my $node_id = $query->param('node_id') || '';
    my $lastnode_id = $query->param('lastnode_id') || 0;

    # Searching for CJK (e.g. ?node=美国国家安全局) was rendering on the page
    # as Latin-1 mojibake (ç¾Žå›½…) because the CGI -utf8 pragma in
    # Everything::Request doesn't reliably flag the param as UTF-8 here, so
    # downstream JSON encoding emitted each byte as a separate codepoint and
    # the browser then UTF-8-encoded those codepoints — classic double-
    # encoding. Force a one-time UTF-8 decode when the value still looks like
    # raw bytes. is_utf8 guards against double-decoding when the pragma did
    # work (the byte path produces the visible mojibake; the unicode path
    # produces correct output).
    if (!is_utf8($node_param)) {
        my $decoded = eval { decode_utf8($node_param, Encode::FB_CROAK) };
        $node_param = $decoded if defined $decoded && !$@;
    }

    # Check if this was a successful nuke operation
    my $was_nuke = 0;
    if ($op eq 'nuke' && $node_id && $node_id !~ /\D/) {
        $was_nuke = 1;
    }

    # Check if the search term is a URL
    my $is_url = 0;
    my $external_link = '';
    if ($node_param =~ /^https?:\/\//) {
        $is_url = 1;
        # For security, escape quotes and commas
        my $escaped_url = $node_param;
        $escaped_url =~ s/'/&#39;/g;
        $escaped_url =~ s/,/&#44;/g;
        $external_link = $escaped_url;
    }

    # Check for tin-opener access (gods only, for viewing censored drafts)
    my $is_admin = $APP->isAdmin($USER);
    my $show_tin_opener = 0;
    my $tin_opener_message = '';
    my $tinopener_active = $query->param('tinopener') || 0;

    if ($is_admin && $query->param('type') eq 'writeup' && $query->param('author')) {
        $show_tin_opener = 1;
        if ($tinopener_active) {
            my $author = $DB->getNode(scalar($query->param('author')), 'user');
            if (!$author) {
                $tin_opener_message = 'User does not exist.';
            } elsif ($author->{acctlock}) {
                $tin_opener_message = $APP->linkNode($author) . "'s account is locked. The tin-opener doesn't work on locked users.";
            } else {
                $tin_opener_message = 'No draft here.';
            }
        }
    }

    # Check if e2node with this title already exists
    my $existing_e2node = undef;
    my $search_title = $node_param;
    $search_title =~ s/^\s*https?:\/\///;  # Strip URL prefix
    if ($search_title) {
        my $n = $DB->getNode($search_title, 'e2node');
        if ($n) {
            $existing_e2node = {
                node_id => $n->{node_id},
                title => $n->{title}
            };
        }
    }

    my $is_guest = $USER->is_guest;

    # For guest users, fetch best recent entries to show
    my @best_entries;
    if ($is_guest && !$was_nuke) {
        my $best_recent = $DB->stashData("bestrecentnodes");
        if ($best_recent && ref($best_recent) eq 'ARRAY' && @$best_recent) {
            # Shuffle and take 20 entries
            my @shuffled = shuffle(@$best_recent);
            my @selected = splice(@shuffled, 0, $BEST_ENTRIES_COUNT);

            foreach my $entry (@selected) {
                push @best_entries, {
                    node_id => $entry->{parent_e2node},
                    writeup_id => $entry->{writeup_id},
                    title => $entry->{parent_title},
                    author => {
                        node_id => $entry->{author_user},
                        title => $entry->{author_name}
                    },
                    excerpt => $entry->{snippet}
                };
            }
        }
    }

    return {
        type => 'nothing_found',
        was_nuke => $was_nuke ? \1 : \0,
        search_term => $node_param,
        is_url => $is_url ? \1 : \0,
        external_link => $external_link,
        show_tin_opener => $show_tin_opener ? \1 : \0,
        tinopener_active => $tinopener_active ? \1 : \0,
        tin_opener_message => $tin_opener_message,
        existing_e2node => $existing_e2node,
        lastnode_id => $lastnode_id,
        best_entries => \@best_entries
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
