package Everything::API::news_archives;

use Moose;
use namespace::autoclean;

extends 'Everything::API';

=head1 NAME

Everything::API::news_archives - browse the webloggable news archives

=head1 DESCRIPTION

Lists the webloggable groups with entry counts; when a group is selected, its weblog entries. Moved
out of C<Everything::Page::news_archives>'s buildReactData (#4543): the Page is a pure gate, React
reads view_weblog off the URL and calls this.

  GET /api/news_archives?view_weblog=<weblog_id>

Logged-in only (NoGuest). The gods / Content Editors weblogs are editor-only (C<state: 'permission'>).
view_weblog is stripped to digits before use (injection-safe).

=cut

sub routes { return { "/" => "list" }; }

sub list {
    my ($self, $REQUEST) = @_;
    my $DB   = $self->DB;
    my $APP  = $self->APP;
    my $user = $REQUEST->user;

    return [$self->HTTP_OK, { success => 0, state => 'guest' }] if $user->is_guest;
    my $is_editor = $APP->isEditor($user->NODEDATA);

    my $webloggables_node = $DB->getNode('webloggables', 'setting');
    return [$self->HTTP_OK, { success => 0, state => 'no_config' }] unless $webloggables_node;
    my $webloggables = $APP->getVars($webloggables_node);

    my $view_weblog = $REQUEST->param('view_weblog') || 0;
    $view_weblog =~ s/\D//g;
    $view_weblog = int($view_weblog || 0);

    my @groups;
    foreach my $node_id (keys %$webloggables) {
        my $wid = int($node_id);
        my ($count) = $DB->sqlSelect('count(*)', 'weblog', "weblog_id='$wid' AND removedby_user=''");
        # 0 + $wid: interpolated into SQL above (string-flagged), so re-numify or the
        # group node_id ships as a string and viewWeblog===node_id never matches (#4152).
        push @groups, { node_id => 0 + $wid, title => $webloggables->{$node_id}, count => int($count || 0) };
    }
    @groups = sort { lc($a->{title}) cmp lc($b->{title}) } @groups;

    return [$self->HTTP_OK, { success => 1, groups => \@groups, viewWeblog => undef }]
        unless $view_weblog;

    # gods (114) / Content Editors (923653) archives are editor-only.
    if (($view_weblog == 114 || $view_weblog == 923653) && !$is_editor) {
        return [$self->HTTP_OK, { success => 0, state => 'permission', groups => \@groups, viewWeblog => undef }];
    }

    my $group_node = $DB->getNodeById($view_weblog);
    my $group_name = $group_node ? $group_node->{title} : "Group $view_weblog";

    my $csr = $DB->sqlSelectMany('*', 'weblog', "weblog_id='$view_weblog' AND removedby_user=''", 'order by tstamp desc');
    my @entries;
    my $skipped = 0;
    while (my $ref = $csr->fetchrow_hashref) {
        my $N = $DB->getNodeById($ref->{to_node});
        unless ($N) { $skipped++; next; }
        my $linker = $DB->getNodeById($ref->{linkedby_user});
        push @entries, {
            node_id     => int($ref->{to_node}),
            title       => $N->{title},
            timestamp   => $ref->{tstamp},
            linker_id   => $ref->{linkedby_user} ? int($ref->{linkedby_user}) : undef,
            linker_name => $linker ? $linker->{title} : undef,
        };
    }
    $csr->finish;

    return [$self->HTTP_OK, {
        success       => 1,
        groups        => \@groups,
        viewWeblog    => int($view_weblog),
        viewGroupName => $group_name,
        entries       => \@entries,
        skippedCount  => int($skipped),
    }];
}

__PACKAGE__->meta->make_immutable(inline_constructor => 0);
1;

=head1 SEE ALSO

L<Everything::API>, L<Everything::PureGates>

=cut
