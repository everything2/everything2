package Everything::API::messages;

use Moose;
use namespace::autoclean;
use JSON;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{
  return {
  ":id/action/archive" => "archive(:id)",
  ":id/action/delete" => "delete(:id)",
  ":id/action/unarchive" => "unarchive(:id)",
  ":id/action/delete_outbox" => "delete_outbox(:id)",
  "create" => "create",
  "count" => "get_count",
  "/" => "get_all",
  "/:id" => "get_single_message(:id)"
  }
}

sub get_all
{
  my ($self, $REQUEST) = @_;

  my $limit = $REQUEST->cgi->param("limit");
  $limit = defined($limit) ? int($limit) : undef;

  my $offset = $REQUEST->cgi->param("offset");
  $offset = defined($offset) ? int($offset) : undef;

  my $archive = $REQUEST->cgi->param("archive");
  $archive = defined($archive) ? int($archive) : 0;

  my $outbox = $REQUEST->cgi->param("outbox");
  $outbox = defined($outbox) ? int($outbox) : 0;

  my $for_user_id = $REQUEST->cgi->param("for_user");
  my $for_usergroup_id = $REQUEST->cgi->param("for_usergroup");

  # Determine which user's messages to fetch
  my $target_user = $REQUEST->user->NODEDATA;

  # Allow viewing bot inboxes if user has permission
  if ($for_user_id && int($for_user_id) != $REQUEST->user->node_id) {
    my $can_access = $self->_can_access_bot_inbox($REQUEST, int($for_user_id));
    unless ($can_access) {
      $self->devLog("User cannot access bot inbox for user_id=$for_user_id");
      return [$self->HTTP_FORBIDDEN, { error => 'Cannot access this inbox' }];
    }
    $target_user = $self->DB->getNodeById(int($for_user_id));
    unless ($target_user) {
      return [$self->HTTP_BAD_REQUEST, { error => 'Invalid user' }];
    }
  }

  if ($outbox) {
    # Get sent messages (outbox) - always from the actual logged in user
    return [$self->HTTP_OK, $self->APP->get_sent_messages($REQUEST->user->NODEDATA, $limit, $offset, $archive)];
  } else {
    # Get received messages (inbox) with optional usergroup filter
    return [$self->HTTP_OK, $self->APP->get_messages($target_user, $limit, $offset, $archive, $for_usergroup_id)];
  }
}

sub create
{
  my ($self, $REQUEST) = @_;

  my $data = $REQUEST->JSON_POSTDATA;

  if($data->{message})
  {
    if($data->{for})
    {
      my $node = undef;
      if($node = $self->DB->getNode($data->{for}, "usergroup"))
      {
        $data->{for_id} = $node->{node_id};
        $self->devLog("Translating $data->{for} into usergroup");
      }elsif($node = $self->DB->getNode($data->{for}, "user")){
        $data->{for_id} = $node->{node_id};
        $self->devLog("Translating $data->{for} into user");
      }
    }

    if(int($data->{for_id}))
    {
      my $deliver_to_node = $self->APP->node_by_id(int($data->{for_id}));
      if($deliver_to_node)
      {
        if($deliver_to_node->can("deliver_message"))
        {
          # Determine sender - allow sending as bot if permitted
          my $sender = $REQUEST->user;
          if ($data->{send_as} && int($data->{send_as}) != $REQUEST->user->node_id) {
            my $can_send_as = $self->_can_access_bot_inbox($REQUEST, int($data->{send_as}));
            if ($can_send_as) {
              $sender = $self->APP->node_by_id(int($data->{send_as}));
              $self->devLog("Sending message as bot: " . $sender->title);
            } else {
              $self->devLog("User not authorized to send as user_id=" . $data->{send_as});
              return [$self->HTTP_FORBIDDEN, { error => 'Not authorized to send as this user' }];
            }
          }

          my $result = $deliver_to_node->deliver_message({"from" => $sender, "message" => $data->{message}});

          # Create outbox entry for sender
          # Format: you said "message" to [recipient] or [groupname] (usergroup)
          my $recipient_label = '[' . $deliver_to_node->title . ']';
          if ($deliver_to_node->type->title eq 'usergroup') {
            $recipient_label .= ' (usergroup)';
          }
          my $outbox_msg = 'you said "' . $data->{message} . '" to ' . $recipient_label;
          $self->DB->sqlInsert("message_outbox", {
            "author_user" => $sender->node_id,
            "msgtext" => $outbox_msg,
            "archive" => 0
          });

          # Transform usergroup blocking response to frontend format
          # usergroup.deliver_message returns: {successes => N, errors => N, ignores => N}
          # user.deliver_message returns: {ignores => 1} when blocked
          # Frontend expects: {errors => [...]} for array, {ignores => 1} for complete block

          my $response = {%$result};  # Copy result
          if ($result->{ignores} && $result->{ignores} > 0 && $result->{successes} && $result->{successes} > 0) {
            # Partial usergroup block - some members delivered, some blocked
            # Convert ignores count to errors array for frontend compatibility
            $response->{errors} = [];
            for (my $i = 0; $i < $result->{ignores}; $i++) {
              push @{$response->{errors}}, "User is blocking you";
            }
            delete $response->{ignores};  # Remove ignores to avoid confusion
          }

          return [$self->HTTP_OK, $response]
        }else{
          $self->devLog("Can't send message due to not having delivery_message endpoint on node type ".$deliver_to_node->type.". Returning BAD REQUEST");
          return [$self->HTTP_BAD_REQUEST];
        }
      }else{
        $self->devLog("Delivery target is not a valid node. Returning BAD REQUEST");
        return [$self->HTTP_BAD_REQUEST];
      }
    }else{
      $self->devLog("Fell through all checks and couldn't generate a sane for_id structure. Sending BAD REQUEST");
      return [$self->HTTP_BAD_REQUEST];
    }
  }else{
    $self->devLog("Can't send message due to blank message text. Sending BAD REQUEST");
    return [$self->HTTP_BAD_REQUEST];
  }
}

sub get_single_message
{
  my($self, $message) = @_;
  return $message;
}

sub archive
{
  my ($self, $message) = @_;
  return $self->APP->message_archive_set($message,1);
}

sub unarchive
{
  my ($self, $message) = @_;
  return $self->APP->message_archive_set($message,0);
}

sub delete
{
  my ($self, $message) = @_;
  return $self->APP->delete_message($message);
}

sub get_count
{
  my ($self, $REQUEST) = @_;

  my $outbox = $REQUEST->cgi->param("outbox");
  $outbox = defined($outbox) ? int($outbox) : 0;

  my $archive = $REQUEST->cgi->param("archive");
  $archive = defined($archive) ? int($archive) : 0;

  my $for_user_id = $REQUEST->cgi->param("for_user");
  my $for_usergroup_id = $REQUEST->cgi->param("for_usergroup");

  # Determine which user's messages to count
  my $target_user = $REQUEST->user->NODEDATA;

  if ($for_user_id && int($for_user_id) != $REQUEST->user->node_id) {
    my $can_access = $self->_can_access_bot_inbox($REQUEST, int($for_user_id));
    unless ($can_access) {
      return [$self->HTTP_FORBIDDEN, { error => 'Cannot access this inbox' }];
    }
    $target_user = $self->DB->getNodeById(int($for_user_id));
    unless ($target_user) {
      return [$self->HTTP_BAD_REQUEST, { error => 'Invalid user' }];
    }
  }

  my $box_type = $outbox ? 'outbox' : 'inbox';
  my $count = $self->APP->get_message_count($target_user, $box_type, $archive, $for_usergroup_id);

  return [$self->HTTP_OK, { count => $count, box => $box_type, archive => $archive }];
}

sub delete_outbox
{
  my ($self, $message_id) = @_;
  $self->DB->sqlDelete("message_outbox", "message_id=" . int($message_id));
  return { id => int($message_id) };
}

sub _outbox_operation_okay
{
  my ($orig, $self, $REQUEST, $id) = @_;

  if ($REQUEST->user->is_guest) {
    $self->devLog("Can't access outbox due to being Guest");
    return [$self->HTTP_FORBIDDEN];
  }

  # Verify this outbox message belongs to the user
  my $message = $self->DB->sqlSelectHashref("*", "message_outbox", "message_id=" . int($id));
  unless ($message && $message->{author_user} == $REQUEST->user->node_id) {
    $self->devLog("Can't access outbox message: not found or not owned by user");
    return [$self->HTTP_FORBIDDEN];
  }

  my $return = $self->$orig(int($id));
  if (UNIVERSAL::isa($return, "HASH")) {
    return [$self->HTTP_OK, $return];
  } else {
    return [$self->HTTP_OK, { id => $return }];
  }
}

sub _message_operation_okay
{
  my ($orig, $self, $REQUEST, $id) = @_;

  # TODO: The Moose method wrapping won't let me get away with this
  if($REQUEST->user->is_guest)
  {
    $self->devLog("Can't access path due to being Guest");
    return [$self->HTTP_FORBIDDEN];
  }

  my $message = $self->APP->get_message(int($id));
  unless($message)
  {
    $self->devLog("Can't access message due to it not being a valid message");
    return [$self->HTTP_FORBIDDEN];
  }

  # Allow access if:
  # 1. Message belongs to the logged-in user, OR
  # 2. User has permission to manage the bot inbox that owns this message
  my $can_access = $self->APP->can_see_message($REQUEST->user->NODEDATA, $message);

  # If not the user's own message, check if they can access the bot inbox
  unless ($can_access) {
    if ($message->{for_user} && $message->{for_user}->{node_id}) {
      $can_access = $self->_can_access_bot_inbox($REQUEST, $message->{for_user}->{node_id});
      if ($can_access) {
        $self->devLog("User has bot inbox access for message_id=$id, for_user=" . $message->{for_user}->{node_id});
      }
    }
  }

  if($can_access)
  {
    my $return = $self->$orig($message);
    if(UNIVERSAL::isa($return, "HASH"))
    {
      return [$self->HTTP_OK, $return];
    }else{
      return [$self->HTTP_OK, {"id" => $return}];
    }
  }else{
    return [$self->HTTP_FORBIDDEN];
  }
}

sub _can_access_bot_inbox
{
  my ($self, $REQUEST, $bot_user_id) = @_;

  # Admin can access all bot inboxes
  return 1 if $REQUEST->user->is_admin;

  # Must be at least an editor to access bot inboxes
  return 0 unless $REQUEST->user->is_editor;

  # Get bot inboxes configuration
  my $bot_setting = $self->DB->getNode('bot inboxes', 'setting');
  return 0 unless $bot_setting;

  my $bot_config = Everything::getVars($bot_setting);
  return 0 unless $bot_config;

  # Find the bot user
  my $bot_user = $self->DB->getNodeById($bot_user_id);
  return 0 unless $bot_user && $bot_user->{title};

  # Check if this is a configured bot
  my $required_group = $bot_config->{$bot_user->{title}};
  return 0 unless $required_group;

  # Check if user is in the required group
  my $group_node = $self->DB->getNode($required_group, 'usergroup');
  return 0 unless $group_node;

  return $self->DB->isApproved($REQUEST->user->NODEDATA, $group_node);
}

around ['get_all','create','get_count'] => \&Everything::API::unauthorized_if_guest;
around ['archive','unarchive','delete','get_single_message'] => \&_message_operation_okay;
around ['delete_outbox'] => \&_outbox_operation_okay;

__PACKAGE__->meta->make_immutable;
1;
