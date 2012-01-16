package Everything::Room;

####################################################################
#
#	some internal functions for chatterbox and rooms
#	created so that the maintainence scripts and
#	internal chatterbox nodes can share 
#
#	Nathan Oostendorp 2000
###########################################################################

use strict;
use Everything;

sub BEGIN
{
	use Exporter ();
	use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		changeRoom
		insertIntoRoom
		canCloak
		cloak
		uncloak
	);
}

sub insertIntoRoom {
  my ($ROOM, $U, $V) = @_;

  getRef $U;
  $V ||= getVars($U);
  my $user_id=getId($U);
  my $room_id=getId($ROOM);
  $room_id = 0 unless $ROOM;
  my $vis = $$V{visible} if exists $$V{visible};
  $vis ||= 0;
  my $borgd = 0;
  $borgd = 1 if $$V{borged};

  $DB->sqlInsert("room"
    , {
            room_id => $room_id,
            member_user => $user_id,
            nick => $$U{title},
            borgd => $borgd,
            experience => $$U{experience},
            visible => $vis,
            op => isGod($U)
    }
    , {
            nick => $$U{title},
            borgd => $borgd,
            experience => $$U{experience},
            visible => $vis,
            op => isGod($U)
    }
  );

}


sub changeRoom {
  my ($USER, $ROOM) = @_;
  getRef $USER;
  my $room_id=getId($ROOM);
  $room_id=0 unless $ROOM;

  unless ($$USER{in_room} == $room_id) {
    $$USER{in_room} = $room_id;
    updateNode($USER, -1);
  }
  $DB->sqlDelete("room", "member_user=".getId($USER));
    
  insertIntoRoom($ROOM, $USER);
}

sub canCloak {
  my ($USER) = @_;
  use Everything::Experience;
  my $C = getVars(getNode('cloakers','setting'));
  return (getLevel($USER) >= 10 or isGod($USER) or exists $$C{lc($$USER{title})});
}

sub cloak {
  my ($USER, $VARS) = @_;
  my $setvarflag;
  $setvarflag = 1 unless $VARS; 
  $VARS ||= getVars $USER;
  
  $$VARS{visible}=1;
  setVars($USER, $VARS) if $setvarflag;
  $DB->sqlUpdate('room', {visible => 1}, "member_user=".getId($USER));
}

sub uncloak {
  my ($USER, $VARS) = @_;
  my $setvarflag;
  $setvarflag = 1 unless $VARS; 
  $VARS ||= getVars $USER;
  
  $$VARS{visible}=0;
  setVars($USER, $VARS) if $setvarflag;
  $DB->sqlUpdate('room', {visible => 0}, "member_user=".getId($USER));
}





1;
