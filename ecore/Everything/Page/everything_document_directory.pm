package Everything::Page::everything_document_directory;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::everything_document_directory - Browse and filter document nodes

=head1 DESCRIPTION

Provides a directory of all document nodes with filtering and sorting options.
Different document types are shown based on user permissions.

=head1 METHODS

=head2 buildReactData($REQUEST)

Returns directory data with documents filtered by permissions, author, type, and sort order.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $DB = $self->DB;
    my $APP = $self->APP;
    my $user = $REQUEST->user;
    my $query = $REQUEST->cgi;
    my $VARS = $REQUEST->VARS;

    # Guest users must log in
    if ($user->is_guest) {
        return {
            type => 'everything_document_directory',
            error => 'guest',
            message => 'Please log in first.'
        };
    }

    my $is_admin = $user->is_admin;
    my $is_editor = $user->is_editor;
    my $is_developer = $user->is_developer;

    # Determine which node types to show based on permissions
    my @type_names = ();
    my $filtered_type = $query->param('filter_nodetype');

    if ($filtered_type) {
        # Verify user has permission to see this type
        my $can_view = 0;
        if ($filtered_type eq 'oppressor_superdoc' && $is_editor) {
            $can_view = 1;
        } elsif ($filtered_type eq 'restricted_superdoc' && $is_admin) {
            $can_view = 1;
        } elsif ($filtered_type eq 'restricted_testdoc' && $is_admin) {
            $can_view = 1;
        } elsif ($filtered_type eq 'Edevdoc' && $is_developer) {
            $can_view = 1;
        } elsif ($filtered_type =~ /^(superdoc|document|superdocnolinks)$/) {
            $can_view = 1;
        }

        if ($can_view) {
            push @type_names, $filtered_type;
        }
    } else {
        # Default types for all logged-in users
        @type_names = qw(superdoc document superdocnolinks);
        push @type_names, 'oppressor_superdoc' if $is_editor;
        push @type_names, 'restricted_superdoc' if $is_admin;
        push @type_names, 'restricted_testdoc' if $is_admin;
        push @type_names, 'Edevdoc' if $is_developer;
    }

    # Convert type names to IDs
    my @type_ids = ();
    foreach my $type_name (@type_names) {
        my $type = $DB->getType($type_name);
        push @type_ids, $type->{node_id} if $type;
    }

    # Handle filter_user parameter
    my $filter_user_param = $query->param('filter_user');
    my $filter_user_id = undef;
    my $filter_user_title = undef;

    if ($filter_user_param) {
        my $filter_user_node = $DB->getNode($filter_user_param, 'user') ||
                               $DB->getNode($filter_user_param, 'usergroup');
        if ($filter_user_node) {
            $filter_user_id = $filter_user_node->{node_id};
            $filter_user_title = $filter_user_node->{title};
        }
    }

    # Sort order is the viewer's stored EDD_Sort pref. It is NO LONGER persisted
    # here on render -- that was a side-effect in buildReactData (an in-memory
    # `$VARS->{EDD_Sort}=` write-back, #4416). The React sort selector POSTs the
    # change to /api/preferences/set, then reloads; this controller just reads it.

    # Determine sort order from VARS
    my %sort_map = (
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

    my $sort_order = $VARS->{EDD_Sort} || '0';
    my $sql_sort = $sort_map{$sort_order} || '';

    # Determine limit
    my $limit = $query->param('edd_limit') || 0;
    if ($limit !~ /^\d+$/) {
        $limit = 0;
    }

    unless ($limit) {
        # Default limits based on permissions
        $limit = 60;
        $limit += 10 if $is_developer;
        $limit += 10 if $is_editor;
        $limit += 10 if $is_admin;
    }

    # Query for documents
    my @nodes = $DB->getNodeWhere(
        { type_nodetype => \@type_ids, author_user => $filter_user_id },
        '', $sql_sort
    );

    # Build document list
    my @documents = ();
    my $shown = 0;

    foreach my $n (@nodes) {
        last if $shown >= $limit;
        $shown++;

        my $author = $DB->getNodeById($n->{author_user});

        push @documents, {
            node_id => $n->{node_id},
            title => $n->{title},
            author => $author ? $author->{title} : 'unknown',
            type => $n->{type}{title},
            createtime => $n->{createtime}
        };
    }

    # Mirror the role gating from the filter block above so the client can
    # populate the type-filter <select> with exactly the types this user is
    # allowed to choose (#4100). Single source of truth — if a type is added
    # to the filter switch above, add it here too.
    my @available_nodetypes = qw(superdoc document superdocnolinks);
    push @available_nodetypes, 'oppressor_superdoc'   if $is_editor;
    push @available_nodetypes, 'restricted_superdoc'  if $is_admin;
    push @available_nodetypes, 'restricted_testdoc'   if $is_admin;
    push @available_nodetypes, 'Edevdoc'              if $is_developer;

    return {
        type => 'everything_document_directory',
        documents => \@documents,
        total_count => scalar(@nodes),
        shown_count => $shown,
        limit => $limit,
        current_sort => $sort_order,
        filter_user => $filter_user_title,
        filter_nodetype => $filtered_type,
        available_nodetypes => \@available_nodetypes,
        permissions => {
            # is_admin / is_editor deduped to the global e2.user prop (#4390):
            # read user.admin / user.editor in React. is_developer is KEPT here
            # because PageState's user.developer is always-true (known quirk).
            is_developer => $is_developer ? 1 : 0
        }
    };
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
