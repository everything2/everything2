package Everything::Controller::nodelet::nodelet_other_users;

use Moose;
use namespace::autoclean;

extends 'Everything::Controller::nodelet';

sub nodelet
{
  my ($this, $request, $node, $properties) = @_;

  my $wherestr = "";
  
  my $user_in_room = $request->USER->{in_room} || 0;
  $user_in_room = 0 unless($request->DB->getNodeById($user_in_room));

  # TODO: When we go to objects, change the room on the user here if need be
  $request->USER->{in_room} = $user_in_room;

  if($user_in_room)
  {
    $wherestr = "room_id=$user_in_room OR room_id=0";
  }

  my $user_is_root = $request->APP->isAdmin($request->USER);
  my $user_is_editor = $request->APP->isEditor($request->USER);
  my $user_is_chanop = $request->APP->isChanop($request->USER);
  my $user_is_developer = $request->APP->isDeveloper($request->USER);

  if($user_is_editor)
  {
    $wherestr .= " AND " if $wherestr;
    $wherestr .= "visible=0";
  }

  my $room_contents = $request->DB->sqlSelectMany("*","room", $wherestr);

  my $rooms = {};

  my $userlist = [];
  while(my $U = $room_contents->fetchrow_hashref())
  {
    my $user = $this->DB->getNodeById($U->{member_user});
    next unless $user;
    my $uservars = $this->APP->getVars($user);
    my $lastnodeid = $uservars->{lastnoded};
    my $lastnode = $this->DB->getNodeById($lastnodeid);
    my $lastnodetime = $lastnode->{publishtime};
    

    my $jointime = $this->APP->convertDateToEpoch($user->{createtime});

    my $accountage = time() - $jointime;
    if($accountage < 24*60*60*30)
    {
       $U->{new_account_days} = sprintf("%d",$accountage / 24*60*60);
    }

    $U->{lastnodetime} = $lastnodetime;
    $U->{lastnode} = $lastnode;
    $U->{createtime} = $this->APP->convertDateToEpoch($user->{createtime});
    $U->{is_chanop} = $this->APP->isChanop($user, "nogods");
    $U->{is_editor} = $this->APP->isEditor($user, "nogods");
    $U->{is_admin} = $this->APP->isAdmin($user,"nogods");
    $U->{is_developer}  = $this->APP->isDeveloper($user,"nogods");

    if(!($user_is_editor || $user_is_chanop))
    {
      delete $U->{borgd};
    }

    $U->{is_me} = $user->{node_id} == $request->USER->{node_id};
    $U->{user} = $user;

    if($U->{room_id} != 0 and not exists($rooms->{$U->{room_id}}))
    {
      my $thisroom = $this->DB->getNodeById($U->{room_id});
      $rooms->{$U->{room_id}} = $thisroom->{title} || "Unknown Room";
    }

    push @$userlist, $U;
  }


  $properties->{changeroom_widget} = $this->emulate_htmlcode("changeroom",$request, "Other Users");
  $properties->{user_in_room} = $user_in_room;
  $properties->{user_is_root} = $user_is_root;
  $properties->{user_is_editor} = $user_is_editor;
  $properties->{user_is_chanop} = $user_is_chanop;
  $properties->{user_is_developer} = $user_is_developer;
  $properties->{showuseractions} = $request->VARS->{showuseractions};

  $properties->{other_users} = $userlist;
  $properties->{chatterbox_hide_symbols} = $this->APP->getParameter($request->USER,"hide_chatterbox_staff_symbol");

  $properties->{template} = "nodelet/other_users";

  $properties->{staffdoc} = $this->DB->getNode("E2 Staff","superdoc");
  $properties->{rooms} = $rooms;

  return $this->SUPER::nodelet($request,$node,$properties);
}

__PACKAGE__->meta->make_immutable;
1;
