package Everything::API::everything_document_directory;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::everything_document_directory - browse/filter document nodes

=head1 DESCRIPTION

The document directory: a permission-scoped list of document-ish nodes, filterable by nodetype and
author and sortable by the viewer's stored preference. Moved out of
C<Everything::Page::everything_document_directory>'s buildReactData (#4557): the Page is a pure gate,
React reads the filters off the URL and calls this.

  GET /api/everything_document_directory?filter_nodetype=superdoc&filter_user=alice&edd_limit=100

Login-required (C<state: 'guest'>). Which nodetypes are visible is permission-dependent -- editors
also see oppressor_superdoc, admins restricted_superdoc/restricted_testdoc, developers Edevdoc -- and
that gating is enforced here, not just reflected in the UI: a hand-crafted C<filter_nodetype> for a
type the caller may not see is refused rather than honoured.

Sort order comes from the viewer's C<VARS.EDD_Sort> preference and is only READ here; changing it is
a POST to /api/preferences/set from React (it used to be written back as a render side-effect, #4416).

=cut

sub routes { return { "/" => "list" }; }

# EDD_Sort preference -> ORDER BY. A whitelist: the value reaches SQL, so it is never interpolated
# from the stored preference directly.
my %SORT_MAP = (
    '0'       => '',
    'idA'     => 'node_id ASC',
    'idD'     => 'node_id DESC',
    'nameA'   => 'title ASC',
    'nameD'   => 'title DESC',
    'authorA' => 'author_user ASC',
    'authorD' => 'author_user DESC',
    'createA' => 'createtime ASC',
    'createD' => 'createtime DESC',
);

# Hard ceiling on edd_limit / "show all" (each listed row is an author lookup).
my $MAX_LIMIT = 1000;

# Types every logged-in user may browse, plus the role-gated additions.
my @BASE_TYPES = qw(superdoc document superdocnolinks);

sub _visible_types {
    my ($self, $is_editor, $is_admin, $is_developer) = @_;
    my @types = @BASE_TYPES;
    push @types, 'oppressor_superdoc'  if $is_editor;
    push @types, 'restricted_superdoc' if $is_admin;
    push @types, 'restricted_testdoc'  if $is_admin;
    push @types, 'Edevdoc'             if $is_developer;
    return @types;
}

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;

    my $is_admin     = $user->is_admin     ? 1 : 0;
    my $is_editor    = $user->is_editor    ? 1 : 0;
    my $is_developer = $user->is_developer ? 1 : 0;

    my @visible = $self->_visible_types($is_editor, $is_admin, $is_developer);

    # A requested nodetype is honoured only if it is one this caller may see.
    my $filtered_type = $REQUEST->param('filter_nodetype');
    $filtered_type = '' unless defined $filtered_type;
    my @type_names;
    if (length $filtered_type) {
        @type_names = grep { $_ eq $filtered_type } @visible;
    } else {
        @type_names = @visible;
    }
    # An unpermitted/unknown filter yields no types -> an empty list, never a wider one.
    $filtered_type = '' unless @type_names;

    my @type_ids = map { $_->{node_id} }
                   grep { $_ }
                   map  { $DB->getType($_) } @type_names;

    # filter_user accepts a user or a usergroup title.
    my $filter_user_param = $REQUEST->param('filter_user');
    my ($filter_user_id, $filter_user_title);
    if (defined $filter_user_param && length $filter_user_param) {
        my $node = $DB->getNode($filter_user_param, 'user')
                || $DB->getNode($filter_user_param, 'usergroup');
        if ($node) {
            $filter_user_id    = $node->{node_id};
            $filter_user_title = $node->{title};
        }
    }

    my $sort_order = $user->VARS->{EDD_Sort} || '0';
    my $sql_sort   = $SORT_MAP{$sort_order} || '';

    # edd_limit is caller-supplied and each shown row costs a getNodeById for its author, so it is
    # digits-only AND capped -- "show all" on a big result set is otherwise an unbounded N+1.
    my $limit = $REQUEST->param('edd_limit') || 0;
    $limit = 0 unless $limit =~ /^\d+$/;
    $limit = int($limit);
    unless ($limit) {
        $limit = 60;
        $limit += 10 if $is_developer;
        $limit += 10 if $is_editor;
        $limit += 10 if $is_admin;
    }
    $limit = $MAX_LIMIT if $limit > $MAX_LIMIT;

    my @nodes = @type_ids
        ? $DB->getNodeWhere({ type_nodetype => \@type_ids, author_user => $filter_user_id }, '', $sql_sort)
        : ();

    my @documents;
    foreach my $n (@nodes) {
        last if @documents >= $limit;
        my $author = $DB->getNodeById($n->{author_user});
        push @documents, {
            node_id    => int($n->{node_id}),
            title      => $n->{title},
            author     => $author ? $author->{title} : 'unknown',
            type       => $n->{type}{title},
            createtime => $n->{createtime},
        };
    }

    return [$self->HTTP_OK, {
        success             => 1,
        documents           => \@documents,
        total_count         => scalar(@nodes),
        shown_count         => scalar(@documents),
        limit               => $limit,
        current_sort        => $sort_order,
        filter_user         => $filter_user_title,
        filter_nodetype     => $filtered_type,
        available_nodetypes => \@visible,
        # is_admin/is_editor live on the global e2.user prop (#4390); is_developer is kept because
        # PageState's user.developer is always-true (known quirk).
        is_developer        => $is_developer ? \1 : \0,
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
