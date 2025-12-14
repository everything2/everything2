package Everything::Page::usergroup_message_archive_manager;

use Moose;
extends 'Everything::Page';

=head1 NAME

Everything::Page::usergroup_message_archive_manager - Manage usergroup message archiving

=head1 DESCRIPTION

Admin tool for enabling/disabling automatic message archiving for usergroups.
Archived messages can be read at the usergroup message archive superdoc.

=cut

sub buildReactData {
    my ($self, $REQUEST) = @_;

    my $APP  = $self->APP;
    my $DB   = $self->DB;
    my $USER = $REQUEST->user;
    my $q    = $REQUEST->cgi;

    # Admin-only page
    unless ($APP->isAdmin($USER->NODEDATA)) {
        return {
            type  => 'usergroup_message_archive_manager',
            error => 'This page is restricted to administrators.'
        };
    }

    my $result = {
        type    => 'usergroup_message_archive_manager',
        node_id => $REQUEST->node->node_id
    };

    # Get usergroup message archive superdoc for linking
    my $archive_doc = $DB->getNode('usergroup message archive', 'superdoc');
    $result->{archive_node_id} = $archive_doc ? int($archive_doc->{node_id}) : undef;

    # Get all usergroups
    my $usergroup_type = $DB->getType('usergroup');
    my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=" . $usergroup_type->{node_id});

    my @usergroup_ids = ();
    while (my $ug = $csr->fetchrow_arrayref) {
        push @usergroup_ids, $ug->[0];
    }
    $csr->finish;

    # Process changes
    my @changes = ();
    my @query_params = $q->param;

    foreach my $param (@query_params) {
        next unless $param =~ /^umam_sure_id_(\d+)$/ && ($q->param($param) eq '1');
        my $ug_id = $1;
        my $action = $q->param('umam_what_id_' . $ug_id);

        next unless defined $action && length($action) && $action ne '0';

        my $ug = $DB->getNodeById($ug_id);
        next unless $ug;

        if ($action eq '1') {
            # Disable archiving
            $APP->delParameter($ug_id, $USER->NODEDATA, 'allow_message_archive');
            push @changes, {
                group_id    => int($ug_id),
                group_title => $ug->{title},
                action      => 'disabled'
            };
        } elsif ($action eq '2') {
            # Enable archiving
            $APP->setParameter($ug_id, $USER->NODEDATA, 'allow_message_archive', 1);
            push @changes, {
                group_id    => int($ug_id),
                group_title => $ug->{title},
                action      => 'enabled'
            };
        }
    }

    $result->{changes} = \@changes if @changes;

    # Build usergroup list with current status
    my @usergroups = ();
    my $num_archiving = 0;
    my $num_not_archiving = 0;

    foreach my $ug_id (@usergroup_ids) {
        my $ug = $DB->getNodeById($ug_id);
        next unless $ug;

        my $is_archiving = $APP->getParameter($ug_id, 'allow_message_archive') ? 1 : 0;

        if ($is_archiving) {
            $num_archiving++;
        } else {
            $num_not_archiving++;
        }

        push @usergroups, {
            group_id     => int($ug_id),
            group_title  => $ug->{title},
            is_archiving => $is_archiving
        };
    }

    # Sort by title
    @usergroups = sort { lc($a->{group_title}) cmp lc($b->{group_title}) } @usergroups;

    $result->{usergroups}       = \@usergroups;
    $result->{num_archiving}    = $num_archiving;
    $result->{num_not_archiving} = $num_not_archiving;

    return $result;
}

__PACKAGE__->meta->make_immutable;
1;

=head1 SEE ALSO

L<Everything::Page>

=cut
