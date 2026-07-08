package Everything::Roles::UsergroupArchive;

use Moose::Role;

# Shared usergroup message-archive management logic (#4479, Refs #4298). The pure-render
# Everything::Page::usergroup_message_archive_manager and the mutating
# Everything::API::usergroup_message_archive_manager both build the same status payload; the
# archive on/off writes live here so the page stays render-only.
#
# Consumers must provide DB() and APP().
requires qw(DB APP);

# The read-only status payload: every usergroup with its current archive flag, sorted by title,
# plus counts and the archive-superdoc link. Used by the page render AND returned by the API
# after applying changes.
sub usergroup_archive_payload {
    my ($self) = @_;
    my $DB  = $self->DB;
    my $APP = $self->APP;

    my $archive_doc = $DB->getNode('usergroup message archive', 'superdoc');

    my $usergroup_type = $DB->getType('usergroup');
    my $csr = $DB->sqlSelectMany('node_id', 'node', 'type_nodetype=' . $usergroup_type->{node_id});

    my @usergroups;
    my ($num_archiving, $num_not_archiving) = (0, 0);
    while (my $row = $csr->fetchrow_arrayref) {
        my $ug = $DB->getNodeById($row->[0]) or next;
        my $is_archiving = $APP->getParameter($ug->{node_id}, 'allow_message_archive') ? 1 : 0;
        $is_archiving ? $num_archiving++ : $num_not_archiving++;
        push @usergroups, {
            group_id     => int($ug->{node_id}),
            group_title  => $ug->{title},
            is_archiving => $is_archiving,
        };
    }
    $csr->finish;

    @usergroups = sort { lc($a->{group_title}) cmp lc($b->{group_title}) } @usergroups;

    return {
        archive_node_id   => $archive_doc ? int($archive_doc->{node_id}) : undef,
        usergroups        => \@usergroups,
        num_archiving     => $num_archiving,
        num_not_archiving => $num_not_archiving,
    };
}

# Apply a batch of archive on/off changes as $actor. Each change: { group_id, action } where
# action '1' = disable archiving, '2' = enable. Ignores unknown groups / no-op actions.
# Returns the list of changes actually applied (with titles), for display.
sub apply_archive_changes {
    my ($self, $actor_nodedata, $changes) = @_;
    my $DB  = $self->DB;
    my $APP = $self->APP;

    my @applied;
    foreach my $change (@{ $changes || [] }) {
        my $ug_id  = $change->{group_id};
        my $action = defined $change->{action} ? "$change->{action}" : '';
        next unless defined $ug_id && $ug_id =~ /^\d+$/;
        next unless $action eq '1' || $action eq '2';

        my $ug = $DB->getNodeById($ug_id) or next;

        if ($action eq '1') {
            $APP->delParameter($ug_id, $actor_nodedata, 'allow_message_archive');
        } else {
            $APP->setParameter($ug_id, $actor_nodedata, 'allow_message_archive', 1);
        }

        push @applied, {
            group_id    => int($ug_id),
            group_title => $ug->{title},
            action      => $action eq '1' ? 'disabled' : 'enabled',
        };
    }

    return \@applied;
}

1;
