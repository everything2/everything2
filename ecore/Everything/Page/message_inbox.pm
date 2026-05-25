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
  my $query = $REQUEST->cgi;

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

  # Check for spy_user parameter (viewing another user's inbox)
  my $spy_user_name = $query->param('spy_user');
  my $viewing_bot = undef;

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
          my $bot_info = {
            node_id => $bot_user->{node_id},
            title => $bot_user->{title},
            requiredGroup => $required_group
          };
          push @accessible_bots, $bot_info;

          # If this is the spy_user, set it as viewing_bot
          if ($spy_user_name && $bot_user->{title} eq $spy_user_name) {
            $viewing_bot = $bot_info;
          }
        }
      }
    }
  }

  # Build the set of usergroups this user can reasonably filter their
  # inbox by. Union of:
  #   (a) groups they have a usergroup-addressed message FROM in their inbox
  #       (covers "used to be a member but got messages then"), and
  #   (b) groups they are currently a member of (covers groups they could
  #       reasonably receive new mail in even if they haven't yet).
  # Admins/editors naturally inherit (b) by virtue of belonging to the
  # privileged usergroups. We deliberately do NOT enumerate every usergroup
  # on the site for non-members; the filter only wants suggestions the
  # user could plausibly want to act on.
  my $usergroup_type = $DB->getType('usergroup');
  my $accessible_usergroups = [];
  if ($usergroup_type) {
    my %seen;
    my $user_id = $user->node_id;
    my $type_id = $usergroup_type->{node_id};

    # (a) groups the user has received messages from
    my $msg_csr = $DB->sqlSelectMany(
      'DISTINCT node.node_id, node.title',
      "message JOIN node ON for_usergroup = node.node_id AND node.type_nodetype=$type_id",
      "for_user=$user_id AND for_usergroup != 0"
    );
    while (my $row = $msg_csr->fetchrow_hashref) {
      next if $seen{$row->{node_id}}++;
      push @$accessible_usergroups, {
        node_id => int($row->{node_id}),
        title   => $row->{title},
      };
    }

    # (b) groups the user is currently a member of
    my $mem_csr = $DB->sqlSelectMany(
      'DISTINCT node.node_id, node.title',
      "nodegroup JOIN node ON nodegroup.nodegroup_id = node.node_id "
        . "AND node.type_nodetype=$type_id",
      "nodegroup.node_id=$user_id"
    );
    while (my $row = $mem_csr->fetchrow_hashref) {
      next if $seen{$row->{node_id}}++;
      push @$accessible_usergroups, {
        node_id => int($row->{node_id}),
        title   => $row->{title},
      };
    }

    @$accessible_usergroups
      = sort { lc( $a->{title} ) cmp lc( $b->{title} ) } @$accessible_usergroups;
  }

  # Determine which user's inbox to display (current user or bot)
  my $target_user_data = $viewing_bot ?
    $DB->getNodeById($viewing_bot->{node_id}) :
    $user->NODEDATA;

  # Sender filter — `?fromuser=alice` on this page (set by the "/msgs from me"
  # link on homenodes, #4042). Resolve username → user node here so React
  # can render a filter chip and pass the id back on subsequent API calls
  # without re-doing the lookup.
  my $fromuser_param = $query->param('fromuser');
  my $from_user = undef;
  my $from_user_id = undef;
  if ( defined $fromuser_param && length $fromuser_param ) {
    $from_user = $DB->getNode( $fromuser_param, 'user' );
    if ($from_user) {
      $from_user_id = $from_user->{node_id};
    }
  }

  # Get initial inbox messages (first page) — applies the sender filter
  # if one was supplied AND resolved to a real user.
  my $inbox_messages = $APP->get_messages($target_user_data, 25, 0, 0, undef, $from_user_id);
  my $inbox_count = $APP->get_message_count($target_user_data, 'inbox', 0, undef, $from_user_id);
  my $inbox_archived_count = $APP->get_message_count($target_user_data, 'inbox', 1, undef, $from_user_id);

  # Get initial outbox messages. Mirror the inbox-side bot-impersonation:
  # when an editor has switched to a bot's inbox via ?spy_user=<bot>, the
  # Sent tab should also show messages SENT BY that bot, not by the
  # editor. Otherwise the bot-inbox view is half-blind.
  # If ?fromuser= was supplied, treat it as the recipient filter for Sent
  # so the page lands with the same logical filter active on either tab.
  my $outbox_author = $target_user_data;
  my $outbox_messages = $APP->get_sent_messages($outbox_author, 25, 0, 0, $from_user_id, undef);
  my $outbox_count = $APP->get_message_count($outbox_author, 'outbox', 0, undef, undef, $from_user_id);
  my $outbox_archived_count = $APP->get_message_count($outbox_author, 'outbox', 1, undef, undef, $from_user_id);

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
    # Preserve the legacy key for any unmigrated callers; React now reads
    # accessibleUsergroups (broader: includes current-membership as well).
    usergroupsWithMessages => $accessible_usergroups,
    accessibleUsergroups   => $accessible_usergroups,
    currentUser => {
      node_id => $user->node_id,
      title => $user->title
    },
    viewingBot => $viewing_bot,  # Initial bot inbox to display (if spy_user param present)
    # Initial sender filter (null if no ?fromuser= or it didn't resolve)
    fromUser => $from_user ? {
      node_id => $from_user->{node_id},
      title   => $from_user->{title},
    } : undef,
  };
}

__PACKAGE__->meta->make_immutable;
1;
