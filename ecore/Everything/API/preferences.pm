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
  'settings_useTinyMCE' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
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
  'no_socialbookmarknotification' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'no_socialbookmarkinformer' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
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

  ## Nodelet-specific preferences
  'nw_nojunk' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1]),
  'num_newwus' => Everything::Preference::List->new(default_value => 15, allowed_values => [1,5,10,15,20,25,30,40]),

  ## Other preferences
  'tiptap_editor_raw' => Everything::Preference::List->new(default_value => 0, allowed_values => [0,1])
}});

sub routes
{
  return {
  "set" => "set_preferences",
  "get" => "get_preferences",
  "notifications" => "set_notification_preferences",
  }
}

sub set_preferences
{
  my ($self, $REQUEST) = @_;

  my $data = $REQUEST->JSON_POSTDATA;

  my $valid = 1;
  if(ref $data ne "HASH" or scalar(keys %$data) == 0)
  {
    return [$self->HTTP_BAD_REQUEST];
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

  return [$self->HTTP_UNAUTHORIZED] if $valid == 0;

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

  unless ($data && ref($data) eq 'HASH' && $data->{notifications}) {
    return [$self->HTTP_BAD_REQUEST, {
      success => 0,
      error => 'invalid_data',
      message => 'notifications object is required'
    }];
  }

  my $notifications = $data->{notifications};
  unless (ref($notifications) eq 'HASH') {
    return [$self->HTTP_BAD_REQUEST, {
      success => 0,
      error => 'invalid_notifications',
      message => 'notifications must be an object'
    }];
  }

  # Validate all notification IDs exist
  my $notification_type = $DB->getType('notification');
  unless ($notification_type) {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, {
      success => 0,
      error => 'notification_type_missing',
      message => 'Notification type not found'
    }];
  }

  foreach my $notif_id (keys %$notifications) {
    unless ($notif_id =~ /^\d+$/) {
      return [$self->HTTP_BAD_REQUEST, {
        success => 0,
        error => 'invalid_notification_id',
        message => "Invalid notification ID: $notif_id"
      }];
    }

    my $notif = $DB->getNodeById($notif_id);
    unless ($notif && $notif->{type_nodetype} == $notification_type->{node_id}) {
      return [$self->HTTP_BAD_REQUEST, {
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

  # Save back to VARS
  my $settings_json = JSON::encode_json($settings);
  Everything::setVars($user_node, { settings => $settings_json });

  # Update the node
  my $update_ok = eval {
    $DB->updateNode($user_node, -1);
    1;
  };

  unless ($update_ok) {
    return [$self->HTTP_INTERNAL_SERVER_ERROR, {
      success => 0,
      error => 'update_failed',
      message => 'Failed to update notification preferences'
    }];
  }

  return [$self->HTTP_OK, {
    success => 1
  }];
}

around ['set_preferences', 'set_notification_preferences'] => \&Everything::API::unauthorized_if_guest;

__PACKAGE__->meta->make_immutable;
1;
