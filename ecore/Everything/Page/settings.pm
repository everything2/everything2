package Everything::Page::settings;

use Moose;
extends 'Everything::Page';

## no critic (RegularExpressions RequireExtendedFormatting RequireLineBoundaryMatching RequireDotMatchAnything)
## no critic (ValuesAndExpressions ProhibitMagicNumbers)

=head1 NAME

Everything::Page::settings - Unified Settings page

=head1 DESCRIPTION

Modern unified settings interface combining:
- Display preferences (visibility toggles, new writeups count)
- Nodelet order management (drag-and-drop)
- Advanced settings (future expansion)

=cut

sub buildReactData
{
  my ($self, $REQUEST) = @_;

  my $APP = $self->APP;
  my $DB = $self->DB;
  my $user = $REQUEST->user;
  my $VARS = $REQUEST->VARS;

  # Guest users can't access settings
  if ($user->is_guest) {
    return {
      type => 'settings',
      error => 'guest',
      message => 'You must be logged in to view settings.'
    };
  }

  # Get all user-facing preferences for Tab 1 (Settings)
  # Note: Force numeric context with int() to ensure JavaScript gets numbers, not strings
  my %settings_prefs;

  ## Look and Feel
  $settings_prefs{userstyle} = $VARS->{userstyle} || '';
  $settings_prefs{nogradlinks} = int($VARS->{nogradlinks} || 0);
  $settings_prefs{noquickvote} = int($VARS->{noquickvote} || 0);
  $settings_prefs{fxDuration} = int($VARS->{fxDuration} || 0);
  $settings_prefs{noreplacevotebuttons} = int($VARS->{noreplacevotebuttons} || 0);
  $settings_prefs{votesafety} = int($VARS->{votesafety} || 0);
  $settings_prefs{coolsafety} = int($VARS->{coolsafety} || 0);

  ## Your Writeups - Editing
  $settings_prefs{HideWriteupOnE2node} = int($VARS->{HideWriteupOnE2node} || 0);
  $settings_prefs{settings_useTinyMCE} = int($VARS->{settings_useTinyMCE} || 0);
  $settings_prefs{textareaSize} = int($VARS->{textareaSize} || 0);

  ## Your Writeups - Hints
  $settings_prefs{nohints} = int($VARS->{nohints} || 0);
  $settings_prefs{nohintSpelling} = int($VARS->{nohintSpelling} || 0);
  $settings_prefs{nohintHTML} = int($VARS->{nohintHTML} || 0);
  $settings_prefs{hintXHTML} = int($VARS->{hintXHTML} || 0);
  $settings_prefs{hintSilly} = int($VARS->{hintSilly} || 0);

  ## Other Users
  $settings_prefs{anonymousvote} = int($VARS->{anonymousvote} || 0);
  $settings_prefs{informmsgignore} = int($VARS->{informmsgignore} || 0);

  # Get all Advanced Settings preferences (Tab 2)
  my %advanced_prefs;

  ## Page Display
  $advanced_prefs{info_authorsince_off} = int($VARS->{info_authorsince_off} || 0);
  $advanced_prefs{hidemsgme} = int($VARS->{hidemsgme} || 0);
  $advanced_prefs{hidemsgyou} = int($VARS->{hidemsgyou} || 0);
  $advanced_prefs{hidevotedata} = int($VARS->{hidevotedata} || 0);
  $advanced_prefs{hidehomenodeUG} = int($VARS->{hidehomenodeUG} || 0);
  $advanced_prefs{hidehomenodeUC} = int($VARS->{hidehomenodeUC} || 0);
  $advanced_prefs{showrecentwucount} = int($VARS->{showrecentwucount} || 0);
  $advanced_prefs{hidelastnoded} = int($VARS->{hidelastnoded} || 0);
  $advanced_prefs{hideauthore2node} = int($VARS->{hideauthore2node} || 0);
  $advanced_prefs{repThreshold} = $VARS->{repThreshold} || 'none';
  $advanced_prefs{noSoftLinks} = int($VARS->{noSoftLinks} || 0);
  $advanced_prefs{nosocialbookmarking} = int($VARS->{nosocialbookmarking} || 0);

  ## Information
  $advanced_prefs{no_notify_kill} = int($VARS->{no_notify_kill} || 0);
  $advanced_prefs{no_editnotification} = int($VARS->{no_editnotification} || 0);
  $advanced_prefs{no_coolnotification} = int($VARS->{no_coolnotification} || 0);
  $advanced_prefs{no_likeitnotification} = int($VARS->{no_likeitnotification} || 0);
  $advanced_prefs{no_bookmarknotification} = int($VARS->{no_bookmarknotification} || 0);
  $advanced_prefs{no_bookmarkinformer} = int($VARS->{no_bookmarkinformer} || 0);
  $advanced_prefs{anonymous_bookmark} = int($VARS->{anonymous_bookmark} || 0);
  $advanced_prefs{no_socialbookmarknotification} = int($VARS->{no_socialbookmarknotification} || 0);
  $advanced_prefs{no_socialbookmarkinformer} = int($VARS->{no_socialbookmarkinformer} || 0);
  $advanced_prefs{no_discussionreplynotify} = int($VARS->{no_discussionreplynotify} || 0);
  $advanced_prefs{hidelastseen} = int($VARS->{hidelastseen} || 0);

  ## Messages
  $advanced_prefs{sortmyinbox} = int($VARS->{sortmyinbox} || 0);
  $advanced_prefs{getofflinemsgs} = int($VARS->{getofflinemsgs} || 0);

  ## Miscellaneous
  $advanced_prefs{noTypoCheck} = int($VARS->{noTypoCheck} || 0);
  $advanced_prefs{hidenodeshells} = int($VARS->{hidenodeshells} || 0);
  $advanced_prefs{GPoptout} = int($VARS->{GPoptout} || 0);
  $advanced_prefs{defaultpostwriteup} = int($VARS->{defaultpostwriteup} || 0);
  $advanced_prefs{nonodeletcollapser} = int($VARS->{nonodeletcollapser} || 0);
  $advanced_prefs{HideNewWriteups} = int($VARS->{HideNewWriteups} || 0);
  $advanced_prefs{nullvote} = int($VARS->{nullvote} || 0);

  # Get notification preferences from settings JSON
  my %notification_prefs;
  if ($VARS->{settings}) {
    my $settings_json = eval { JSON::decode_json($VARS->{settings}) };
    if ($settings_json && $settings_json->{notifications}) {
      %notification_prefs = %{$settings_json->{notifications}};
    }
  }

  # Get nodelet order
  my $nodelet_order = $VARS->{nodelets} || '';
  my @nodelet_ids = split(/,/, $nodelet_order);

  my @nodelets;
  foreach my $node_id (@nodelet_ids) {
    $node_id =~ s/^\s+|\s+$//g;  # trim whitespace
    next unless $node_id =~ /^\d+$/;  # skip non-numeric

    my $nodelet = $DB->getNodeById($node_id);
    if ($nodelet) {
      push @nodelets, {
        node_id => int($nodelet->{node_id}),
        title => $nodelet->{title}
      };
    }
  }

  # Get available nodelets for adding
  my $nodelet_type = $DB->getType('nodelet');
  my @available_nodelets;

  if ($nodelet_type) {
    my $csr = $DB->sqlSelectMany(
      'node_id, title',
      'node',
      'type_nodetype=' . $nodelet_type->{node_id},
      'ORDER BY title'
    );

    while (my ($id, $title) = $csr->fetchrow_array) {
      push @available_nodelets, {
        node_id => int($id),
        title => $title
      };
    }
  }

  # Get all notification types for configuration
  my $notification_type = $DB->getType('notification');
  my @all_notifications;
  if ($notification_type) {
    my $csr = $DB->sqlSelectMany(
      'node_id, title',
      'node',
      'type_nodetype=' . $notification_type->{node_id},
      'ORDER BY title'
    );
    while (my ($id, $title) = $csr->fetchrow_array) {
      push @all_notifications, {
        node_id => int($id),
        title => $title,
        enabled => $notification_prefs{$id} ? 1 : 0
      };
    }
  }

  # Get blocked users using unified user interactions (both unfavorite + message blocking)
  my @blocked_users;

  # Get unfavorite users (writeup hiding)
  my %unfavorite_map;
  if($VARS->{unfavoriteusers})
  {
    my @unfavorites = split(/,/, $VARS->{unfavoriteusers});
    foreach my $uid (@unfavorites)
    {
      $uid =~ s/^\s+|\s+$//g;
      $unfavorite_map{$uid} = 1 if $uid =~ /^\d+$/;
    }
  }

  # Get message blocks
  my %message_block_map;
  my $csr = $DB->sqlSelectMany("ignore_node","messageignore","messageignore_id=".$user->node_id);
  while(my ($blocked_id) = $csr->fetchrow_array)
  {
    $message_block_map{$blocked_id} = 1;
  }

  # Combine both lists
  my %all_users = (%unfavorite_map, %message_block_map);

  foreach my $uid (keys %all_users)
  {
    my $blocked_user = $DB->getNodeById($uid);
    next unless $blocked_user;

    push @blocked_users, {
      node_id => int($blocked_user->{node_id}),
      title => $blocked_user->{title},
      type => $blocked_user->{type}{title},
      hide_writeups => $unfavorite_map{$uid} ? 1 : 0,
      block_messages => $message_block_map{$uid} ? 1 : 0
    };
  }

  # Get nodelet-specific settings for active nodelets
  my %nodelet_settings;
  foreach my $nodelet (@nodelets) {
    my $title = $nodelet->{title};

    # New Writeups nodelet settings
    if ($title eq 'New Writeups') {
      $nodelet_settings{$nodelet->{node_id}} = {
        num_newwus => int($VARS->{num_newwus} || 15),
        nw_nojunk => int($VARS->{nw_nojunk} || 0)
      };
    }
  }

  return {
    type => 'settings',
    settingsPreferences => \%settings_prefs,
    advancedPreferences => \%advanced_prefs,
    nodelets => \@nodelets,
    availableNodelets => \@available_nodelets,
    notificationPreferences => \@all_notifications,
    blockedUsers => \@blocked_users,
    nodeletSettings => \%nodelet_settings,
    currentUser => {
      node_id => $user->node_id,
      title => $user->title
    }
  };
}

__PACKAGE__->meta->make_immutable;
1;
