package Everything::Node::user;

use Moose;
extends 'Everything::Node::document';
with 'Everything::Node::helper::setting';

override 'json_display' => sub
{
  my ($self) = @_;

  my $values = super();

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

  foreach my $num("experience","GP","numwriteups","numcools","is_online","level")
  {
    $values->{$num} = int($self->$num);
  }

  foreach my $text("mission","motto","employment","specialties","leveltitle")
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
  return $self->VARS->{numwriteups} || 0;
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

sub nodelets
{
  my ($self) = @_;
  my $output = [];
  if($self->VARS->{nodelets})
  {
    foreach my $nodelet (split(",",$self->VARS->{nodelets}))
    {
      my $nodelet = $self->APP->node_by_id($nodelet);
      next unless $nodelet;
      push @$output, $nodelet;
    }

    return $output;
  }else{
    return [$self->APP->node_by_name("default nodelets","nodeletgroup")->group];
  }
}

sub is_borged
{
  my ($self) = @_;

  unless($self->VARS->{borged})
  {
    return;
  }

  my $t = time;
  my $numborged = $self->VARS->{numborged};
  $numborged ||= 1;
  $numborged *=2;

  if ($t - $self->VARS->{borged} < 300+60*$numborged) {
    return 1;
  } else {
    $self->VARS->{lastborg} = $self->VARS->{borged};
    delete $self->VARS->{borged};
    $self->DB->sqlUpdate('room', {borgd => '0'}, 'member_user='.$self->node_id);
    return 0;
  }
}

sub level
{
  my ($self) = @_;
  return $self->APP->getLevel($self->{NODEDATA});
}

sub leveltitle
{
  my ($self) = @_;
  return $self->APP->getLevelTitle($self->level);
}

sub infravision
{
  my ($self) = @_;
  return $self->VARS->{infravision};
}

sub newxp
{
  my ($self, $dontupdate) = @_;

  $self->APP->devLog("User VARS in newxp: ".$self->VARS);
  if(not defined($self->VARS->{oldexp}))
  {
    $self->VARS->{oldexp} = $self->experience;  
    return 0;
  }

  my $difference = 0;
  if($self->VARS->{oldexp} != $self->experience)
  {
    # Negative here is okay
    $difference = $self->experience - $self->VARS->{oldexp};
    unless($dontupdate)
    {
      $self->APP->devLog("Setting oldexp as ".$self->experience." (was ".$self->VARS->{oldexp}.")");
      $self->VARS->{oldexp} = $self->experience;  
    }
  }

  return $difference;
}

sub gp
{
  my ($self) = @_;
  return $self->NODEDATA->{GP} || 0;
}

sub newgp
{
  my ($self, $dontupdate) = @_;

  if(not defined($self->VARS->{oldGP}))
  {
    $self->VARS->{oldGP} = $self->gp;
    return 0;
  }

  my $difference = 0;

  if($self->VARS->{oldGP} != $self->gp)
  {
    $difference = $self->gp - $self->VARS->{oldGP};
    unless($dontupdate)
    {
      $self->VARS->{oldGP} = $self->gp;
    } 
  }

  $difference = 0 if $difference < 0;
  return $difference;
}

sub xp_to_level
{
  my ($self) = @_;

  my $LVLS = $self->APP->node_by_name('level experience','setting')->VARS || {};
  my $lvl = $self->level+1;

  my $to_lvl = 0;
  if($LVLS->{$lvl})
  {
    $to_lvl = ($LVLS->{$lvl} - $self->experience);
    $to_lvl = 0 if $to_lvl < 0;
  }

  return $to_lvl;
}

sub writeups_to_level
{
  my ($self) = @_;

  my $WRPS = $self->APP->node_by_name('level writeups','setting')->VARS || {};
  my $lvl = $self->level+1;

  my $to_lvl = 0;
  if($WRPS->{$lvl})
  {
    $to_lvl = ($$WRPS{$lvl} - $self->numwriteups);
    $to_lvl = 0 if $to_lvl < 0;
  }
  return $to_lvl;
}

sub message_ignores
{
  my ($self) = @_;

  my $csr = $self->DB->sqlSelectMany("*","messageignore","messageignore_id=".$self->node_id." ORDER BY messageignore_id");
  my $records = [];

  while(my $row = $csr->fetchrow_hashref())
  {
    my $node = $self->APP->node_by_id($row->{ignore_node});
    next unless $node;
    push @$records, $node->json_reference;
  }

  return $records;
}

sub set_message_ignore
{
  my ($self, $ignore_id, $state) = @_;

  my $ignore = $self->DB->getNodeById($ignore_id);
  return unless $ignore;

  $self->devLog("set_message_ignore: ".$self->node_id." is ".(($state)?(""):("un"))."ignoring $ignore->{title}");

  if($state)
  {
    if(my $struct = $self->is_ignoring_messages($ignore_id))
    {
      return $struct;
    }else{
      $self->DB->sqlInsert("messageignore",{"messageignore_id" => $self->node_id, "ignore_node" => $ignore->{node_id}});
      return $self->APP->node_json_reference($ignore);
    }
  }else{
    $self->DB->sqlDelete("messageignore","messageignore_id=".$self->node_id." and ignore_node=$ignore->{node_id}");
    return [$ignore->{node_id}];
  }

}

sub is_ignoring_messages
{
  my ($self, $ignore) = @_;

  my $ignorestruct = $self->DB->sqlSelectHashref("*","messageignore","messageignore_id=".$self->node_id." and ignore_node=".int($ignore));

  if($ignorestruct)
  {
    return $self->APP->node_by_id($ignorestruct->{ignore_node})->json_reference;
  }
}

sub in_room
{
  my ($self) = @_;
  return $self->NODEDATA->{in_room};
}

__PACKAGE__->meta->make_immutable;
1;
