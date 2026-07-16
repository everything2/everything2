package Everything::API::usergroup_discussions;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

use Everything qw(getId getNodeById getType);

=head1 NAME

Everything::API::usergroup_discussions - the debate discussions in your usergroups

=head1 DESCRIPTION

Lists the debate threads restricted to the caller's usergroups, newest-activity first, paginated.
Moved out of C<Everything::Page::usergroup_discussions>'s buildReactData (#4541): the Page is a pure
gate, React reads show_ug/offset off the URL and calls this.

  GET /api/usergroup_discussions?show_ug=<usergroup_id>&offset=<n>

Logged-in only. Ships data + an error C<state> ('guest' / 'no_usergroups' / 'access_denied'); the
copy lives in React.

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;

    my $USER = $user->NODEDATA;
    my $uid  = getId($USER);

    # All usergroups.
    my $ug_type = int((getType('usergroup') || {})->{node_id} || 16);
    my $csr = $DB->sqlSelectMany('node_id', 'node', "type_nodetype=$ug_type ORDER BY node_id");
    my @ug_ids;
    while (my $row = $csr->fetchrow_hashref) { push @ug_ids, $row->{node_id}; }
    $csr->finish;

    # e2gods + %% are never offered.
    my %exclude = (829913 => 1, 1175790 => 1);

    # The caller's usergroups (admins in gods=114 also get Content Editors=923653).
    my @mine;
    foreach my $ug_id (@ug_ids) {
        my $ug = getNodeById($ug_id) or next;
        next unless $ug->{group};
        next unless grep { $_ == $uid } @{ $ug->{group} };
        push @mine, $ug_id unless $exclude{$ug_id};
        push @mine, 923653 if $ug_id == 114;
    }

    return [$self->HTTP_OK, { success => 0, state => 'no_usergroups' }] unless @mine;

    my @usergroups;
    foreach my $ug_id (@mine) {
        my $ug = getNodeById($ug_id) or next;
        push @usergroups, { node_id => int($ug_id), title => $ug->{title} };
    }

    my $show_ug = int($REQUEST->param('show_ug') || 0);

    if ($show_ug) {
        unless (grep { $_ == $show_ug } @mine) {
            return [$self->HTTP_OK, {
                success => 0, state => 'access_denied',
                usergroups => \@usergroups, selected_usergroup => 0 + $show_ug,
            }];
        }
    }

    # Which discussions: the selected group, or all of the caller's groups.
    my $wherestr = $show_ug
        ? "restricted=$show_ug"
        : 'restricted in (' . join(', ', map { int($_) } @mine) . ')';

    $csr = $DB->sqlSelectMany('root_debatecomment', 'debatecomment', $wherestr, 'GROUP BY root_debatecomment');
    my @nodes;
    while (my $row = $csr->fetchrow_hashref) {
        my $N = getNodeById($row->{root_debatecomment}) or next;
        my $latest_id = $DB->sqlSelect('MAX(debatecomment_id)', 'debatecomment', "root_debatecomment=$N->{node_id}");
        my $latest = getNodeById($latest_id) or next;
        push @nodes, { node => $N, latest => $latest, latesttime => $APP->convertDateToEpoch($latest->{createtime}) };
    }
    $csr->finish;

    @nodes = sort { $b->{latesttime} <=> $a->{latesttime} } @nodes;

    my $offset     = int($REQUEST->param('offset') || 0);
    my $limit      = 50;
    my $totalnodes = scalar(@nodes);
    my $nodesleft  = $totalnodes - $offset;
    my $thispage   = ($limit < $nodesleft ? $limit : $nodesleft);
    $thispage = 0 if $thispage < 0;

    my @page_nodes = $thispage > 0 ? @nodes[$offset .. $offset + $thispage - 1] : ();

    my @discussions;
    foreach my $stuff (@page_nodes) {
        my $n      = $stuff->{node};
        my $latest = $stuff->{latest};
        my $author = getNodeById($n->{author_user});
        my $ug     = getNodeById($n->{restricted});

        my $lastread = $DB->sqlSelect('dateread', 'lastreaddebate', "user_id=$uid and debateroot_id=$n->{node_id}");
        my $lastread_e = $lastread ? $APP->convertDateToEpoch($lastread) : 0;
        my $unread = ($lastread_e < $stuff->{latesttime}) ? \1 : \0;   # JSON boolean (#4108)

        my $replycount = $DB->sqlSelect('COUNT(*)', 'debatecomment', "root_debatecomment=$n->{node_id}") || 0;
        $replycount-- if $replycount > 0;   # don't count the root

        push @discussions, {
            node_id         => int($n->{node_id}),
            title           => $n->{title},
            author_id       => $author ? int($author->{node_id}) : 0,
            author_title    => $author ? $author->{title} : 'unknown',
            usergroup_id    => $ug ? int($ug->{node_id}) : 0,
            usergroup_title => $ug ? $ug->{title} : 'unknown',
            reply_count     => int($replycount),
            unread          => $unread,
            last_updated    => $latest->{createtime} || '',
        };
    }

    return [$self->HTTP_OK, {
        success            => 1,
        usergroups         => \@usergroups,
        selected_usergroup => 0 + $show_ug,   # re-numify: $show_ug was SQL-interpolated above (#4152)
        discussions        => \@discussions,
        total_discussions  => int($totalnodes),
        offset             => int($offset),
        limit              => int($limit),
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
