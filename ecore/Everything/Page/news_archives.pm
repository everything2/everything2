package Everything::Page::news_archives;

use Moose;
extends 'Everything::Page';
with 'Everything::Security::NoGuest';

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP = $self->APP;
    my $DB = $self->DB;
    my $USER = $REQUEST->user;
    my $q = $REQUEST->cgi;

    my $is_admin = $APP->isAdmin($USER->NODEDATA);
    my $is_editor = $APP->isEditor($USER->NODEDATA);

    # Get the webloggables setting
    my $webloggables_node = $DB->getNode("webloggables", "setting");
    return { type => 'news_archives', error => 'Configuration not found' }
        unless $webloggables_node;

    my $webloggables = $APP->getVars($webloggables_node);

    my $view_weblog = $q->param('view_weblog') || 0;
    $view_weblog =~ s/\D//g if $view_weblog;

    # Build list of all webloggables with counts
    my @groups = ();
    foreach my $node_id (keys %$webloggables) {
        my $title = $webloggables->{$node_id};

        my $wclause = "weblog_id='$node_id' AND removedby_user=''";
        my ($count) = $DB->sqlSelect('count(*)', 'weblog', $wclause);

        push @groups, {
            node_id => int($node_id),
            title   => $title,
            count   => int($count || 0),
        };
    }

    # Sort by title
    @groups = sort { lc($a->{title}) cmp lc($b->{title}) } @groups;

    # If not viewing a specific weblog, return the list
    if (!$view_weblog) {
        return {
            type        => 'news_archives',
            groups      => \@groups,
            viewWeblog  => undef,
        };
    }

    # Check access for editor-only groups
    if (($view_weblog == 114 || $view_weblog == 923653) && !$is_editor) {
        return {
            type        => 'news_archives',
            groups      => \@groups,
            viewWeblog  => undef,
            error       => 'You do not have permission to view this group.',
        };
    }

    # Get the group being viewed
    my $group_node = $DB->getNodeById($view_weblog);
    my $group_name = $group_node ? $group_node->{title} : "Group $view_weblog";

    # Get weblog entries
    my $wclause = "weblog_id='$view_weblog' AND removedby_user=''";
    my $csr = $DB->sqlSelectMany('*', 'weblog', $wclause, 'order by tstamp desc');

    my @entries = ();
    my $skipped = 0;

    while (my $ref = $csr->fetchrow_hashref()) {
        my $N = $DB->getNodeById($ref->{to_node});
        unless ($N) {
            $skipped++;
            next;
        }

        my $linker_node = $DB->getNodeById($ref->{linkedby_user});

        push @entries, {
            node_id     => int($ref->{to_node}),
            title       => $N->{title},
            timestamp   => $ref->{tstamp},
            linker_id   => $ref->{linkedby_user} ? int($ref->{linkedby_user}) : undef,
            linker_name => $linker_node ? $linker_node->{title} : undef,
        };
    }
    $csr->finish;

    return {
        type            => 'news_archives',
        groups          => \@groups,
        viewWeblog      => int($view_weblog),
        viewGroupName   => $group_name,
        entries         => \@entries,
        skippedCount    => $skipped,
        isAdmin         => $is_admin ? \1 : \0,
    };
}

__PACKAGE__->meta->make_immutable;

1;
