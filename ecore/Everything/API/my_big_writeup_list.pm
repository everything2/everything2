package Everything::API::my_big_writeup_list;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::my_big_writeup_list - a user's complete writeup list (with optional raw export)

=head1 DESCRIPTION

Lists all of a user's writeups (their own by default; editors/admins may look up others via
C<usersearch>), with per-writeup reputation visible to the author, editors/admins, or anyone who
voted on it. Moved out of C<Everything::Page::my_big_writeup_list>'s buildReactData (#4524): the Page
is a pure gate, React reads usersearch/orderby/raw/delimiter off the URL and calls this.

  GET /api/my_big_writeup_list?usersearch=<name>&orderby=<key>&raw=<0|1>&delimiter=<c>

Ships data + an error C<state> (guest / user_not_found / edb / webster / bad_delimiter); the copy for
each state lives in React (MyBigWriteupList). C<orderby> is whitelisted (injection-safe).

=cut

my %VALID_ORDERINGS = map { $_ => 1 } (
    'title ASC',
    'wrtype_writeuptype ASC,title ASC',
    'cooled DESC,title ASC',
    'cooled DESC,node.reputation DESC,title ASC',
    'node.reputation DESC,title ASC',
    'writeup.publishtime DESC',
    'writeup.publishtime ASC',
);

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $USER->is_guest;

    my $is_admin  = $USER->is_admin;
    my $is_editor = $USER->is_editor;

    # Own list by default; editors/admins (and anyone, historically) may look up another user.
    my $username = $REQUEST->param('usersearch');
    $username = $USER->title unless defined $username && $username ne '';
    my $target_user = $DB->getNode($username, 'user');

    return [$self->HTTP_OK, { success => 0, state => 'user_not_found', username => $username }]
        unless $target_user;
    # Bot easter-eggs the old page short-circuited (the copy lives in React, keyed on state).
    return [$self->HTTP_OK, { success => 0, state => 'edb',     username => $target_user->{title} }]
        if $target_user->{title} eq 'EDB';
    return [$self->HTTP_OK, { success => 0, state => 'webster', username => $target_user->{title} }]
        if $target_user->{title} eq 'Webster 1913';

    my $target_user_id = int($target_user->{node_id});
    my $is_me    = ($target_user_id == $USER->node_id);
    my $show_rep = $is_me || $is_admin || $is_editor;

    my $writeup_type_id = $DB->getType('writeup')->{node_id};
    my $total_count = $DB->sqlSelect(
        'COUNT(*)', 'node', "author_user=$target_user_id AND type_nodetype=$writeup_type_id"
    ) || 0;

    my $order_by  = $REQUEST->param('orderby') || 'title ASC';
    $order_by = 'title ASC' unless $VALID_ORDERINGS{$order_by};
    my $raw_mode  = $REQUEST->param('raw') ? 1 : 0;
    my $delimiter = $REQUEST->param('delimiter');
    $delimiter = '_' unless defined $delimiter && $delimiter ne '';

    my %base = (
        username    => $target_user->{title},
        user_id     => $target_user_id,
        is_me       => $is_me ? 1 : 0,
        show_rep    => $show_rep ? 1 : 0,
        total_count => int($total_count),
        order_by    => $order_by,
        raw_mode    => $raw_mode,
        delimiter   => $delimiter,
    );

    return [$self->HTTP_OK, { success => 1, %base, writeups => [] }] unless $total_count;

    if ($raw_mode && length($delimiter) != 1) {
        return [$self->HTTP_OK, { success => 0, state => 'bad_delimiter', %base, writeups => [] }];
    }

    my $cursor = $DB->sqlSelectMany(
        'node.node_id, parent_e2node, title, cooled, reputation, publishtime, totalvotes',
        'node, writeup',
        "node.author_user=$target_user_id AND node.type_nodetype=$writeup_type_id AND writeup.writeup_id=node.node_id",
        "ORDER BY $order_by"
    );

    my (@writeup_node_ids, @raw_writeups);
    while (my $row = $cursor->fetchrow_hashref) {
        push @writeup_node_ids, $row->{node_id};
        push @raw_writeups, $row;
    }

    # For a non-privileged viewer, reputation is visible per-writeup only where they voted.
    my %user_voted;
    if (!$is_me && !$is_admin && !$is_editor && @writeup_node_ids) {
        my $user_id = $USER->node_id;
        my $id_list = join(',', @writeup_node_ids);   # node_ids from the DB: all ints
        my $voted = $DB->{dbh}->selectcol_arrayref(
            "SELECT vote_id FROM vote WHERE voter_user = $user_id AND vote_id IN ($id_list)"
        );
        %user_voted = map { $_ => 1 } @{ $voted || [] };
    }

    my @writeups;
    for my $row (@raw_writeups) {
        my $voted = $user_voted{ $row->{node_id} } ? 1 : 0;
        my $data = {
            parent_e2node => $row->{parent_e2node} ? int($row->{parent_e2node}) : undef,
            title         => $row->{title},
            cooled        => int($row->{cooled} || 0),
            publishtime   => $row->{publishtime},
            voted         => $voted,
        };
        if ($show_rep || $voted) {
            my $total_votes = $row->{totalvotes} || 0;
            my $reputation  = $row->{reputation}  || 0;
            $data->{reputation}  = int($reputation);
            $data->{total_votes} = int($total_votes);
            $data->{upvotes}     = int(($total_votes + $reputation) / 2);
            $data->{downvotes}   = int(($total_votes - $reputation) / 2);
        }
        push @writeups, $data;
    }

    return [$self->HTTP_OK, { success => 1, %base, writeups => \@writeups }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
