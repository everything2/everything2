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

  foreach my $time("lasttime","createtime")
  {
    my $t = $self->$time;
    if($t)
    {
      $values->{$time} = $self->APP->iso_date_format($t);
    }
  }

  foreach my $num("experience","GP","numwriteups","numcools")
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

sub createtime
{
  my ($self) = @_;
  return $self->NODEDATA->{createtime};
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

sub coolsleft
{
  my ($self) = @_;
  return $self->VARS->{cools} || 0;
}

__PACKAGE__->meta->make_immutable;
1;
