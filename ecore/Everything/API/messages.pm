package Everything::API::messages;

use Moose;
use namespace::autoclean;
extends 'Everything::API';

## no critic (ProhibitBuiltinHomonyms)

sub routes
{ 
  return {
  ":id/action/archive" => "archive(:id)",
  ":id/action/delete" => "delete(:id)",
  ":id/action/unarchive" => "unarchive(:id)",
  "create" => "create",
  "/" => "get_all",
  "/:id" => "get_single_message(:id)"
  }
}

sub get_all
{
  my ($self, $REQUEST) = @_;

  my $limit = int($REQUEST->cgi->param("limit")) || undef;
  my $offset = int($REQUEST->cgi->param("offset")) || undef;
  my $archive = int($REQUEST->cgi->param("archive")) || 0;
  return [$self->HTTP_OK, $self->APP->get_messages($REQUEST->user->NODEDATA, $limit, $offset, $archive)];
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
          return [$self->HTTP_OK, $deliver_to_node->deliver_message({"from" => $REQUEST->user, "message" => $data->{message}})]
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

  if($self->APP->can_see_message($REQUEST->user->NODEDATA, $message))
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

around ['get_all','create'] => \&Everything::API::unauthorized_if_guest;
around ['archive','unarchive','delete','get_single_message'] => \&_message_operation_okay;

__PACKAGE__->meta->make_immutable;
1;
