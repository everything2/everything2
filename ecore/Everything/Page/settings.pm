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

  # Get available stylesheets for theme selection
  my $stylesheet_type = $DB->getType('stylesheet');
  my @available_stylesheets;
  my $current_stylesheet_title = '';

  if ($stylesheet_type) {
    # Get only "zen" stylesheets (exclude basesheet, print, etc.)
    # These are stylesheets that users can select as their theme
    my $csr = $DB->sqlSelectMany(
      'node_id, title',
      'node',
      "type_nodetype=" . $stylesheet_type->{node_id} . " AND title NOT IN ('basesheet', 'print', 'ResponsiveBase', 'Responsive2')",
      'ORDER BY title'
    );

    while (my ($id, $title) = $csr->fetchrow_array) {
      push @available_stylesheets, {
        node_id => int($id),
        title => $title
      };

      # Check if this is the user's current stylesheet
      if ($VARS->{userstyle} && int($VARS->{userstyle}) == $id) {
        $current_stylesheet_title = $title;
      }
    }
  }

  # Get default stylesheet
  my $default_style_name = $Everything::CONF->default_style || 'Kernel Blue';
  my $default_style = $DB->getNode($default_style_name, 'stylesheet');
  my $default_style_id = $default_style ? $default_style->{node_id} : 0;

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

  # Check if user is an editor (for showing Admin Settings tab)
  my $is_editor = $APP->isEditor($user->NODEDATA) ? 1 : 0;

  # Get profile data for Edit Profile tab
  my $user_node = $user->NODEDATA;
  my $user_vars = $user->VARS || {};

  # Check if user can have an image
  my $can_have_image = 0;
  my $users_with_image = $DB->getNode('users with image', 'nodegroup');
  if ($users_with_image && Everything::isApproved($user_node, $users_with_image)) {
    $can_have_image = 1;
  } elsif ($APP->getLevel($user_node) >= 1) {
    $can_have_image = 1;
  }

  # Get user bookmarks
  my @bookmarks;
  if ($user_vars->{bookmarks}) {
    my @bookmark_ids = split(/,/, $user_vars->{bookmarks});
    foreach my $bm_id (@bookmark_ids) {
      $bm_id =~ s/^\s+|\s+$//g;
      next unless $bm_id =~ /^\d+$/;
      my $bm_node = $DB->getNodeById($bm_id);
      if ($bm_node) {
        push @bookmarks, {
          node_id => int($bm_node->{node_id}),
          title => $bm_node->{title}
        };
      }
    }
  }

  my %profile_data = (
    node_id => int($user->node_id),
    title => $user->title,
    realname => $user_node->{realname} || '',
    email => $user_node->{email} || '',
    doctext => $user_node->{doctext} || '',
    imgsrc => $user_node->{imgsrc} || '',
    mission => $user_vars->{mission} || '',
    specialties => $user_vars->{specialties} || '',
    employment => $user_vars->{employment} || '',
    motto => $user_vars->{motto} || '',
  );

  my $response = {
    type => 'settings',
    settingsPreferences => \%settings_prefs,
    advancedPreferences => \%advanced_prefs,
    nodelets => \@nodelets,
    availableNodelets => \@available_nodelets,
    notificationPreferences => \@all_notifications,
    blockedUsers => \@blocked_users,
    nodeletSettings => \%nodelet_settings,
    availableStylesheets => \@available_stylesheets,
    currentStylesheet => $current_stylesheet_title,
    defaultStylesheetId => $default_style_id,
    isEditor => $is_editor,
    currentUser => {
      node_id => int($user->node_id),
      title => $user->title
    },
    # Profile tab data
    profileData => \%profile_data,
    canHaveImage => $can_have_image ? 1 : 0,
    bookmarks => \@bookmarks
  };

  # Add admin settings data for editors
  if ($is_editor) {
    # Editor-specific settings
    $response->{editorPreferences} = {
      hidenodenotes => int($VARS->{hidenodenotes} || 0)
    };

    # Macro definitions with defaults
    my %default_macros = (
      'room' => '/say /msg $1 Just so you know - you are not in the default room, where most people stay. To get back into the main room, either visit [go outside], or: go to the top of the "other users" nodelet, pick "outside" from the dropdown list, and press the "Go" button.',
      'newbie' => "/say /msg \$1 Hello, your writeups could use a little work. Read [Everything University] and [Everything FAQ] to improve your current and future writeups. \$2+\n/say /msg \$1 If you have any questions, you can send me a private message by typing this in the chatterbox: /msg \$0 (Your message here.)",
      'html' => '/say /msg $1 Your writeups could be improved by using some HTML tags, such as <p> , which starts a new paragraph. [Everything FAQ: Can I use HTML in my writeups?] lists the tags allowed here, and [E2 HTML tags] shows you how to use them.',
      'wukill' => '/say /msg $1 FYI - I removed your writeup $2+',
      'nv' => '/say /msg $1 Hey, I know that you probably didn\'t mean to, but advertising your writeups ("[nodevertising]") in the chatterbox isn\'t cool. Imagine if everyone did that - there would be no room for chatter.',
      'misc1' => "/say /msg \$0 Use this for your own custom macro. See [macro FAQ] for information about macros.\n/say /msg \$0 If you have an idea of another thing to add that would be wanted by many people, give N-Wing a /msg.",
      'misc2' => '/say /msg $0 Yup, this is an area for another custom macro.'
    );

    # Get user's current macros (or defaults if not defined)
    my @macros;
    foreach my $name (sort keys %default_macros) {
      my $var_key = 'chatmacro_' . $name;
      my $text = $VARS->{$var_key};
      my $enabled = defined $text && length($text) > 0 ? 1 : 0;

      # Use default if not defined
      $text = $default_macros{$name} unless $enabled;

      # Convert square brackets to curly for display (legacy workaround)
      $text =~ s/\[/{/g;
      $text =~ s/\]/}/g;

      push @macros, {
        name => $name,
        text => $text,
        enabled => $enabled
      };
    }

    $response->{macros} = \@macros;
    $response->{maxMacroLength} = 768;
  }

  return $response;
}

__PACKAGE__->meta->make_immutable;
1;
