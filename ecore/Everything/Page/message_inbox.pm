package Everything::Page::message_inbox;

use Moose;
extends 'Everything::Page';

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $APP = $self->APP;
  my $DB = $self->DB;
  my $user = $REQUEST->user;
  my $VARS = $REQUEST->VARS;

  # Guest users can't access message inbox
  if ($user->is_guest) {
    return {
      type => 'message_inbox',
      error => 'guest',
      message => 'You must be logged in to view your messages.'
    };
  }

  my $is_admin = $user->is_admin;
  my $is_editor = $user->is_editor;

  # Get bot inboxes configuration - maps bot username to required usergroup
  # Only editors and above can access bot inboxes
  my @accessible_bots = ();
  if ($is_admin || $is_editor) {
    my $bot_inboxes_setting = $DB->getNode('bot inboxes', 'setting');
    my $bot_config = $bot_inboxes_setting ? Everything::getVars($bot_inboxes_setting) : {};

    # Build list of bots user can access
    foreach my $bot_name (sort { lc($a) cmp lc($b) } keys %$bot_config) {
      my $required_group = $bot_config->{$bot_name};
      my $group_node = $DB->getNode($required_group, 'usergroup');

      # Admin can access all bots, editors need to be in the required group
      if ($is_admin || ($group_node && $DB->isApproved($user->NODEDATA, $group_node))) {
        my $bot_user = $DB->getNode($bot_name, 'user');
        if ($bot_user) {
          push @accessible_bots, {
            node_id => $bot_user->{node_id},
            title => $bot_user->{title},
            requiredGroup => $required_group
          };
        }
      }
    }
  }

  # Get usergroups that have messages for this user (for filtering)
  my $usergroup_type = $DB->getType('usergroup');
  my $usergroups_with_messages = [];
  if ($usergroup_type) {
    my $csr = $DB->sqlSelectMany(
      'DISTINCT node.node_id, node.title',
      'message LEFT JOIN node ON for_usergroup = node.node_id AND type_nodetype=' . $usergroup_type->{node_id},
      'for_user=' . $user->node_id . ' AND for_usergroup != 0 AND node.node_id IS NOT NULL',
      'ORDER BY node.title'
    );
    while (my $row = $csr->fetchrow_hashref) {
      push @$usergroups_with_messages, {
        node_id => $row->{node_id},
        title => $row->{title}
      };
    }
  }

  # Get initial inbox messages (first page)
  my $inbox_messages = $APP->get_messages($user->NODEDATA, 25, 0, 0);
  my $inbox_count = $APP->get_message_count($user->NODEDATA, 'inbox', 0);
  my $inbox_archived_count = $APP->get_message_count($user->NODEDATA, 'inbox', 1);

  # Get initial outbox messages (first page)
  my $outbox_messages = $APP->get_sent_messages($user->NODEDATA, 25, 0, 0);
  my $outbox_count = $APP->get_message_count($user->NODEDATA, 'outbox', 0);
  my $outbox_archived_count = $APP->get_message_count($user->NODEDATA, 'outbox', 1);

  return {
    type => 'message_inbox',
    defaultTab => 'inbox',  # Default to inbox tab
    inbox => {
      messages => $inbox_messages,
      count => $inbox_count,
      archivedCount => $inbox_archived_count
    },
    outbox => {
      messages => $outbox_messages,
      count => $outbox_count,
      archivedCount => $outbox_archived_count
    },
    pageSize => 25,
    accessibleBots => \@accessible_bots,
    usergroupsWithMessages => $usergroups_with_messages,
    currentUser => {
      node_id => $user->node_id,
      title => $user->title
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
