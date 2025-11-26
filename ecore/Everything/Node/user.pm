package Everything::Node::user;

use Moose;
use Digest::MD5;

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
  return $self->NODEDATA->{experience} || 0;
}

sub GP
{
  my ($self) = @_;
  return int($self->NODEDATA->{GP} || 0);
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
  return int($self->VARS->{cools} || 0);
}

sub deliver_message
{
  my ($self, $messagedata) = @_;

  # Check if recipient is ignoring sender (unless it's a usergroup message)
  unless ($messagedata->{for_usergroup}) {
    my $ignoring = $self->DB->sqlSelect(
      'COUNT(*)',
      'messageignore',
      'messageignore_id='.$self->node_id.' AND ignore_node='.$messagedata->{from}->node_id
    );
    if ($ignoring) {
      return {"ignores" => 1};
    }
  }

  $self->DB->sqlInsert("message",{
    "author_user" => $messagedata->{from}->node_id,
    "for_user" => $self->node_id,
    "msgtext" => $messagedata->{message},
    "for_usergroup" => $messagedata->{for_usergroup} || 0,
    "archive" => 0
  });

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

sub sanctity
{
  my ($self) = @_;
  return int($self->NODEDATA->{sanctity} || 0);
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

  if($userstyle and $userstyle->type->title eq "stylesheet" and $userstyle->supported)
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
  my $nodeletids;

  # Check is_guest FIRST to ensure consistent guest experience
  # (guest_front_page sets VARS->{nodelets} which would override config)
  if($self->is_guest){
    $nodeletids = $self->CONF->guest_nodelets;
  }elsif($self->VARS->{nodelets})
  {
    $nodeletids = [split(",",$self->VARS->{nodelets})];
  }else{
    $nodeletids = $self->CONF->default_nodelets;
  }

  foreach my $n (@$nodeletids)
  {
    my $nodelet = $self->APP->node_by_id($n);
    next unless $nodelet;
    push @$output, $nodelet;
  }

  return $output;
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

  if(not defined($self->VARS->{oldexp}) or $self->VARS->{oldexp} eq "")
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

  if(not defined($self->VARS->{oldGP}) or $self->VARS->{oldGP} eq "")
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

  return $self->ignoring_messages_from(1);
}

sub ignoring_messages_from
{
  my ($self, $json) = @_;

  my $csr = $self->DB->sqlSelectMany("*","messageignore","messageignore_id=".$self->node_id." ORDER BY messageignore_id");
  my $records = [];

  while(my $row = $csr->fetchrow_hashref())
  {
    my $node = $self->APP->node_by_id($row->{ignore_node});
    next unless $node;

    if($json)
    {
      push @$records, $node->json_reference;
    } else {
      push @$records, $node;
    }
  }

  return $records;
}

sub messages_ignored_by
{
  my ($self, $json) = @_;

  my $csr = $self->DB->sqlSelectMany("*","messageignore","ignore_node=".$self->node_id." ORDER BY messageignore_id");
  my $records = [];

  while(my $row = $csr->fetchrow_hashref())
  {
    my $node = $self->APP->node_by_id($row->{messageignore_id});
    next unless $node;
    if($json)
    {
      push @$records, $node->json_reference;
    } else {
      push @$records, $node;
    }
  }

  return $records;
}

sub set_message_ignore
{
  my ($self, $ignore_id, $state) = @_;

  my $ignore = $self->DB->getNodeById($ignore_id);
  return unless $ignore;

  if($state)
  {
    if(my $struct = $self->is_ignoring_messages($ignore_id))
    {
      return $struct;
    }else{
      $self->DB->sqlInsert('messageignore',{'messageignore_id' => $self->node_id, "ignore_node" => $ignore->{node_id}});
      return $self->APP->node_json_reference($ignore);
    }
  }else{
    $self->DB->sqlDelete('messageignore','messageignore_id='.$self->node_id." and ignore_node=$ignore->{node_id}");
    return [$ignore->{node_id}];
  }

}

sub is_ignoring_messages
{
  my ($self, $ignore) = @_;

  my $ignorestruct = $self->DB->sqlSelectHashref('*','messageignore',"messageignore_id=".$self->node_id." and ignore_node=".int($ignore));

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

sub email
{
  my ($self) = @_;
  return $self->NODEDATA->{email};
}

sub has_bookmarked
{
  my ($self, $node) = @_;

  my $bookmark = $self->APP->node_by_name('bookmark','linktype');
  return $bookmark->get_link($self, $node);
}

sub request_guard_parameters
{
  my ($self, $scope) = @_;

  my $rand = rand(999999999);
  my $nonce = Digest::MD5::md5_hex($self->passwd.' ' .$self->email.$rand);

  return {$scope.'_nonce' => $nonce, $scope.'_seed' => $rand};
}

sub usergroup_memberships
{
  my ($self) = @_;
  my $groups = [];

  my $usergroup = $self->APP->node_by_name('usergroup','nodetype');

  my $csr = $self->DB->sqlSelectMany("DISTINCT(nodegroup_id)","nodegroup ng left join node n on ng.nodegroup_id=n.node_id",
    "n.type_nodetype=".$usergroup->node_id." and ng.node_id=".$self->node_id); 

  while(my $row = $csr->fetchrow_arrayref)
  {
    my $n = $self->APP->node_by_id($row->[0]);
    next unless $n;
    push @$groups, $n;
  }
  return $groups;
}

sub editable_categories
{
  my ($self) = @_;
  my $categories = [];

  my $category = $self->APP->node_by_name('category','nodetype');

  my $category_authors = [$self->node_id, $self->CONF->guest_user];  

  foreach my $ug (@{$self->usergroup_memberships})
  {
    push @$category_authors,$ug->node_id;
  }

  my $csr = $self->DB->sqlSelectMany("node_id","node",
    "author_user IN (".join(',',@$category_authors).") and type_nodetype=".
    $category->node_id);

  while(my $row = $csr->fetchrow_arrayref)
  {
    my $n = $self->APP->node_by_id($row->[0]);
    next unless $n;
    push @$categories, $n;
  }

  my $sorted_categories = [sort {$a->title cmp $b->title} @$categories];
  return $sorted_categories;
}

sub available_weblogs
{
  my ($self) = @_;

  my $available = [];  
  my $wls = $self->APP->node_by_name('webloggables' , 'setting')->VARS;
  foreach my $weblog_id (split(',' , $self->VARS->{can_weblog}))
  {
    next if $self->ui_hide_weblog_option($weblog_id);
    my $group_title = $wls->{$weblog_id} ;
    unless( $self->VARS->{ nameifyweblogs } )
    {
      my $wl = $self->APP->node_by_id($weblog_id);
      next unless $wl;
      $group_title = $wl->title;
    }
    push @$available, {"title" => $group_title, "weblog_id" => $weblog_id};
  }
  return $available;
}

sub ui_hide_weblog_option
{
  my ($self, $wid) = @_;

  return 1 if $self->VARS->{"hide_weblog_$wid"};
  return;
}

sub can_weblog
{
  my ($self) = @_;
  return if $self->is_guest;
  return 1 if $self->VARS->{can_weblog};
  return;
}

sub gravatar_img_url
{
  my ($self, $type, $size) = @_;

  my $base_url = "http://www.gravatar.com/avatar/";
  my $hash = Digest::MD5::md5_hex($self->email);

  if(not defined $type)
  {
    $type = '';
  }else{
    $type = "d=$type&";
  }

  if(not defined $size)
  {
    $size = 16;
  }

  $size = "s=$size";

  return $base_url.$hash.'?'.$type.$size;
}

sub karma
{
  my ($self) = @_;
  return $self->NODEDATA->{karma} || 0;
}

sub num_newwus
{
  my ($self) = @_;
  return $self->VARS->{num_newwus};
}

sub gp_optout
{
  my ($self) = @_;
  return $self->VARS->{GPoptout} || 0;
}

__PACKAGE__->meta->make_immutable;
1;
