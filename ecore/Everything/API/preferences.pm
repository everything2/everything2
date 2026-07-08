package Everything::API::preferences;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

use Everything::Preference::List;
use Everything::Preference::String;

## no critic (ProhibitBuiltinHomonyms)

has 'allowed_preferences' => (isa => 'HashRef', is => 'ro', default => sub { {
  ## Internal state preferences (not user-facing in Settings UI)
  'vit_hidemaintenance' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'vit_hidenodeinfo' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'vit_hidenodeutil' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'vit_hidelist' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'vit_hidemisc' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'edn_hideutil' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'edn_hideedev' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'collapsedNodelets' => Everything::Preference::String->new(default_value => '', allowed_values => qr/.?/),
  'nodetrail' => Everything::Preference::String->new(default_value => '', allowed_values => qr/.?/),
  # Usergroup Writeups nodelet: which usergroup's writeups to list. A usergroup
  # title; read back via getNode($title,'usergroup') (parameterized, falls back
  # to the default group on a missing/bad title). Empty clears -> default group.
  # Replaces the retired `changeusergroup` opcode (#4312).
  'nodeletusergroup' => Everything::Preference::String->new(default_value => '', allowed_values => qr/^.{0,80}$/),

  ## Settings Tab - Look and Feel
  'userstyle' => Everything::Preference::String->new(default_value => '', allowed_values => qr/^\d*$/), # node_id or empty
  'nogradlinks' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'noquickvote' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'fxDuration' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1,100,150,300,400,600,800,1000]),
  'noreplacevotebuttons' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'votesafety' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'coolsafety' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),

  ## Settings Tab - Your Writeups
  'HideWriteupOnE2node' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'textareaSize' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1,2]),
  'nohints' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'nohintSpelling' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'nohintHTML' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hintXHTML' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hintSilly' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),

  ## Settings Tab - Other Users
  'anonymousvote' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1,2]),
  'informmsgignore' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1,2,3]),

  ## Advanced Settings Tab - Page Display
  'info_authorsince_off' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidemsgme' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidemsgyou' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidevotedata' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidehomenodeUG' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidehomenodeUC' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'showrecentwucount' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidelastnoded' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hideauthore2node' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'repThreshold' => Everything::Preference::String->new(default_value => 'none', allowed_values => qr/^(none|\d+)$/),
  'noSoftLinks' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'nosocialbookmarking' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),

  ## Advanced Settings Tab - Information
  'no_notify_kill' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'no_editnotification' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'no_coolnotification' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'no_likeitnotification' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'no_bookmarknotification' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'no_bookmarkinformer' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'anonymous_bookmark' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  # no_socialbookmarknotification / no_socialbookmarkinformer removed with the dead
  # socialBookmark notifier (#4332); see docs/user-vars-reference.md.
  'no_discussionreplynotify' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidelastseen' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),

  ## Advanced Settings Tab - Messages
  'sortmyinbox' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'getofflinemsgs' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),

  ## Advanced Settings Tab - Miscellaneous
  'noTypoCheck' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidenodeshells' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'GPoptout' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'defaultpostwriteup' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'nonodeletcollapser' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'HideNewWriteups' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'nullvote' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),

  ## SQL Prompt console (root-only) display format: 0=table, 1=variable-width, 2=textarea (#4442)
  'sqlprompt_wrap' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1,2]),

  ## Nodelet-specific preferences
  'nw_nojunk' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'num_newwus' => Everything::Preference::List->new(default_value => 15, allowed_values => [1,5,10,15,20,25,30,40]),

  ## ReadThis nodelet section visibility
  'rtn_hidecwu' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'rtn_hideedc' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'rtn_hidenws' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),

  ## Other preferences
  'tiptap_editor_raw' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),

  # everything_document_directory sort order (#4416). Was persisted by a
  # render-time `$VARS->{EDD_Sort}=` side-effect in the page controller; the
  # React sort selector now POSTs it here. \z (not $) so a trailing newline
  # can't sneak past the enum.
  'EDD_Sort' => Everything::Preference::String->new(default_value => '0', allowed_values => qr/^(0|idA|idD|nameA|nameD|authorA|authorD|createA|createD)\z/),

  # list_nodes_of_type selected-type pref (#4416). A type node_id, or empty. Was
  # persisted by a render-time setVars from ?setvars_ListNodesOfType_Type in the
  # controller AND the React was POSTing to a dead /api/preferences/update route
  # -- both replaced by this allowlisted /set key.
  'ListNodesOfType_Type' => Everything::Preference::String->new(default_value => '', allowed_values => qr/^\d*\z/),

  # style_defacer custom CSS (#4416). Was a render-time setVars from a ?vandalism
  # POST param. Length-capped at 50000 chars -- clears every existing prod value
  # (199 users, max ~32KB encoded; the decoded value the API validates is <=
  # encoded) with headroom while bounding abuse. /s so `.` spans newlines (CSS is
  # multi-line). The large-value-in-VARS-blob bloat gets real storage post-ORM (#4417).
  'customstyle' => Everything::Preference::String->new(default_value => '', allowed_values => qr/^.{0,50000}\z/s),

  ## Editor-specific preferences (Admin Settings)
  'killfloor_showlinks' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'hidenodenotes' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1])
}});

sub routes
{
  return {
  "set" => "set_preferences",
  "get" => "get_preferences",
  "notifications" => "set_notification_preferences",
  "admin" => "set_admin_preferences",
  }
}

sub set_preferences
{
  my ($self, $REQUEST) = @_;

  # NB: guest access is already blocked by the `around unauthorized_if_guest` modifier below
  # (returns 401). That base-class 401 is part of the larger response-code scrub, not this fix.

  my $data = $REQUEST->JSON_POSTDATA;

  my $valid = 1;
  if(ref $data ne "HASH" or scalar(keys %$data) == 0)
  {
    # short-term: 200-with-error until the response-code recut (filed)
    return [$self->HTTP_OK, {success => 0, error => 'No preferences provided'}];
  }

  foreach my $key (keys %$data)
  {
    if(defined($self->allowed_preferences->{$key}))
    {
      $valid = $self->allowed_preferences->{$key}->validate($data->{$key});
    }else{
      $valid = 0;
    }

    last if $valid == 0;
  }

  # NB: this is a validation failure, not an auth failure (HTTP_UNAUTHORIZED was a mislabel).
  # short-term: 200-with-error until the response-code recut (filed).
  return [$self->HTTP_OK, {success => 0, error => 'Invalid preference value'}] if $valid == 0;

  foreach my $key (keys %$data)
  {
    if($self->allowed_preferences->{$key}->should_delete($data->{$key}))
    {
      delete $REQUEST->user->VARS->{$key};
    }else{
      # Normalize List preferences to integers to ensure consistent JSON encoding
      my $value = $data->{$key};
      if (ref($self->allowed_preferences->{$key}) eq 'Everything::Preference::List') {
        $value = int($value);
      }
      $REQUEST->user->VARS->{$key} = $value;
    }
  }

  $REQUEST->user->set_vars($REQUEST->user->VARS);

  return [$self->HTTP_OK, $self->current_preferences($REQUEST)];
}

sub get_preferences
{
  my ($self, $REQUEST) = @_;

  return [$self->HTTP_OK, $self->current_preferences($REQUEST)];
}

sub current_preferences
{
  my ($self, $REQUEST) = @_;

  my $vars = $REQUEST->user->VARS;

  my $result = {};
  foreach my $key (keys %{$self->allowed_preferences})
  {
    if(defined($vars->{$key}))
    {
      if($self->allowed_preferences->{$key}->validate($vars->{$key}))
      {
        $result->{$key} = $vars->{$key};
        next;
      }
    }

    $result->{$key} = $self->allowed_preferences->{$key}->default_value;
  }
  return $result;
}

sub set_notification_preferences
{
  my ($self, $REQUEST) = @_;

  my $data = $REQUEST->JSON_POSTDATA;
  my $user = $REQUEST->user;
  my $DB = $self->DB;

  # (guest access blocked by the `around unauthorized_if_guest` modifier; see set_preferences)

  unless ($data && ref($data) eq 'HASH' && $data->{notifications}) {
    return [$self->HTTP_OK, {  # short-term: 200-with-error until the response-code recut (filed)
      success => 0,
      error => 'invalid_data',
      message => 'notifications object is required'
    }];
  }

  my $notifications = $data->{notifications};
  unless (ref($notifications) eq 'HASH') {
    return [$self->HTTP_OK, {  # short-term: 200-with-error until the response-code recut (filed)
      success => 0,
      error => 'invalid_notifications',
      message => 'notifications must be an object'
    }];
  }

  # Validate all notification IDs exist
  my $notification_type = $DB->getType('notification');
  unless ($notification_type) {
    return [$self->HTTP_OK, {  # short-term: 200-with-error until the response-code recut (filed)
      success => 0,
      error => 'notification_type_missing',
      message => 'Notification type not found'
    }];
  }

  foreach my $notif_id (keys %$notifications) {
    unless ($notif_id =~ /^\d+$/) {
      return [$self->HTTP_OK, {  # short-term: 200-with-error until the response-code recut (filed)
        success => 0,
        error => 'invalid_notification_id',
        message => "Invalid notification ID: $notif_id"
      }];
    }

    my $notif = $DB->getNodeById($notif_id);
    unless ($notif && $notif->{type_nodetype} == $notification_type->{node_id}) {
      return [$self->HTTP_OK, {  # short-term: 200-with-error until the response-code recut (filed)
        success => 0,
        error => 'notification_not_found',
        message => "Notification not found: $notif_id"
      }];
    }
  }

  # Get current settings or create new
  my $user_node = $user->NODEDATA;
  my $VARS = Everything::getVars($user_node);
  my $settings = {};

  if ($VARS->{settings}) {
    $settings = eval { JSON::decode_json($VARS->{settings}) };
    $settings = {} unless $settings;
  }

  # Update notifications in settings
  $settings->{notifications} = $notifications;

  # Save back to VARS - IMPORTANT: must pass ALL vars, not just settings,
  # because setVars() deletes any var not in the passed hash.
  # Re-read VARS fresh from database to get any changes made since we started.
  # This prevents race conditions where other preference changes would be lost.
  my $fresh_vars = Everything::getVars($user_node);
  $fresh_vars->{settings} = JSON::encode_json($settings);
  Everything::setVars($user_node, $fresh_vars);

  # Update the node
  my $update_ok = eval {
    $DB->updateNode($user_node, -1);
    1;
  };

  unless ($update_ok) {
    return [$self->HTTP_OK, {  # short-term: 200-with-error until the response-code recut (filed)
      success => 0,
      error => 'update_failed',
      message => 'Failed to update notification preferences'
    }];
  }

  return [$self->HTTP_OK, {
    success => 1
  }];
}

sub set_admin_preferences
{
  my ($self, $REQUEST) = @_;

  my $APP = $self->APP;
  my $user = $REQUEST->user;

  # Only editors can access admin settings
  unless ($APP->isEditor($user->NODEDATA)) {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Admin Settings is only available to Content Editors and gods.'
    }];
  }

  my $data = $REQUEST->JSON_POSTDATA;

  unless ($data && ref($data) eq 'HASH') {
    return [$self->HTTP_OK, {
      success => 0,
      error => 'Invalid request data'
    }];
  }

  my $VARS = $REQUEST->user->VARS;

  # Handle regular settings
  if ($data->{settings} && ref($data->{settings}) eq 'HASH') {
    my $settings = $data->{settings};
    foreach my $key (keys %$settings) {
      if (defined($self->allowed_preferences->{$key})) {
        if ($self->allowed_preferences->{$key}->validate($settings->{$key})) {
          if ($self->allowed_preferences->{$key}->should_delete($settings->{$key})) {
            delete $VARS->{$key};
          } else {
            my $value = $settings->{$key};
            if (ref($self->allowed_preferences->{$key}) eq 'Everything::Preference::List') {
              $value = int($value);
            }
            $VARS->{$key} = $value;
          }
        }
      }
    }
  }

  # Handle macros
  if ($data->{macros} && ref($data->{macros}) eq 'HASH') {
    # Define allowed macros
    my @allowed_macros = qw(room newbie html wukill nv misc1 misc2);
    my %allowed = map { $_ => 1 } @allowed_macros;
    my $max_length = 768;

    foreach my $name (keys %{$data->{macros}}) {
      next unless $allowed{$name};
      my $var_key = 'chatmacro_' . $name;

      my $value = $data->{macros}{$name};

      if (!defined $value || $value eq '') {
        # Delete the macro
        delete $VARS->{$var_key};
      } else {
        # Clean and store the macro
        $value =~ tr/\r/\n/;           # Normalize line endings
        $value =~ s/\n+/\n/gs;         # Remove multiple newlines
        $value =~ s/[^\n\x20-\x7e]//gs; # Allow only printable ASCII + newlines
        $value = substr($value, 0, $max_length);  # Enforce max length
        $value =~ s/\{/[/gs;           # Convert curly to square brackets
        $value =~ s/\}/]/gs;
        $VARS->{$var_key} = $value;
      }
    }
  }

  # Save the updated VARS
  $REQUEST->user->set_vars($VARS);

  return [$self->HTTP_OK, { success => 1 }];
}

around ['set_preferences', 'set_notification_preferences', 'set_admin_preferences'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;
