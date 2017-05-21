package Everything::Node::user;

use Moose;
extends 'Everything::Node::document';

has 'VARS' => ('is' => 'ro', 'isa' => 'HashRef', 'lazy' => 1, 'builder' => '_build_VARS');

sub _build_VARS
{
  my ($self) = @_;

  return Everything::getVars($self->NODEDATA); 
}

override 'json_display' => sub
{
  my ($self) = @_;

  my $values = super();
  my $level = $self->APP->getLevel($self->NODEDATA) || 0;
  $values->{level} = int($level);
  $values->{leveltitle} = $self->APP->getLevelTitle($level);


  my $bookmarks = $self->APP->get_bookmarks($self->NODEDATA) || [];
  if(scalar @$bookmarks)
  {
    $values->{bookmarks} = $bookmarks;
  }

  foreach my $time("lasttime")
  {
    my $t = $self->$time;
    if($t)
    {
      $values->{$time} = $self->APP->iso_date_format($t);
    }
  }

  foreach my $num("experience","GP","numwriteups","numcools","is_online")
  {
    $values->{$num} = int($self->$num);
  }

  foreach my $text("mission","motto","employment","specialties")
  {
    my $t = $self->$text;
    if($t)
    {
      $values->{$text} = $t;
    }
  }

  if(my $fwd = $self->message_forward_to)
  {
    $values->{message_forward_to} = $fwd->json_reference;
  }

  return $values;
};

sub numwriteups
{
  my ($self) = @_;
  return $self->VARS->{numwriteups};
}

sub lasttime
{
  my ($self) = @_;
  return $self->NODEDATA->{lasttime};
}

sub experience
{
  my ($self) = @_;
  return $self->NODEDATA->{experience};
}

sub GP
{
  my ($self) = @_;
  return $self->NODEDATA->{GP};
}

sub mission
{
  my ($self) = @_;
  return $self->VARS->{mission};
}

sub motto
{
  my ($self) = @_;
  return $self->VARS->{motto};
}

sub employment
{
  my ($self) = @_;
  return $self->VARS->{employment};
}

sub specialties
{
  my ($self) = @_;
  return $self->VARS->{specialties};
}

sub numcools
{
  my ($self) = @_;
  my $numcools = $self->DB->sqlSelect("count(*) as numcools","coolwriteups","cooledby_user=".$self->NODEDATA->{node_id});
  return $numcools;
}

sub is_guest
{
  my ($self) = @_;
  return $self->APP->isGuest($self->NODEDATA) || 0;
}

sub is_editor
{
  my ($self) = @_;
  return $self->APP->isEditor($self->NODEDATA) || 0;
}

sub is_admin
{
  my ($self) = @_;
  return $self->APP->isAdmin($self->NODEDATA) || 0;
}

sub is_chanop
{
  my ($self) = @_;
  return $self->APP->isChanop($self->NODEDATA) || 0;
}

sub is_clientdev
{
  my ($self) = @_;
  return $self->APP->isClientDeveloper($self->NODEDATA, "nogods") || 0;
}

sub is_developer
{
  my ($self) = @_;
  return $self->APP->isDeveloper($self->NODEDATA, "nogods") || 0;
}

sub votesleft
{
  my ($self) = @_;
  return $self->NODEDATA->{votesleft};
}

sub message_forward_to
{
  my ($self) = @_;

  return unless $self->NODEDATA->{message_forward_to};
  return $self->APP->node_by_id($self->NODEDATA->{message_forward_to});
}

sub coolsleft
{
  my ($self) = @_;
  return $self->VARS->{cools} || 0;
}

sub deliver_message
{
  my ($self, $messagedata) = @_;

  $self->DB->sqlInsert("message",{"author_user" => $messagedata->{from}->node_id,"for_user" => $self->node_id,"msgtext" => $messagedata->{message}});

  return {"successes" => 1};
}

sub is_online
{
  my ($self) = @_;
  
  my $count = $self->DB->sqlSelect("count(*)","room","member_user=".$self->node_id);
  return $count;
}

sub get_online_messages_always
{
  my ($self) = @_;
  return $self->VARS->{getofflinemsgs};
}

sub locked
{
  my ($self) = @_;
  return $self->NODEDATA->{acctlock};
}

sub salt
{
  my ($self) = @_;
  return $self->NODEDATA->{salt};
}

sub passwd
{
  my ($self) = @_;
  return $self->NODEDATA->{passwd};
}

sub style
{
  my ($self) = @_;

  my $userstyle = $self->VARS->{userstyle};
  my $default = $self->APP->node_by_name($self->CONF->default_style,"stylesheet");

  unless($userstyle)
  {
    return $default;
  }

  $userstyle = $self->APP->node_by_id($userstyle);

  if($userstyle and $userstyle->type->title eq "stylesheet")
  {
    return $userstyle;
  }

  return $default;
}

sub customstyle
{
  my ($self) = @_;

  return ($self->VARS->{customstyle})?($self->VARS->{customstyle}):(undef);
}

__PACKAGE__->meta->make_immutable;
1;
