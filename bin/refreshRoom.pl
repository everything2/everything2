#!/usr/local/bin/perl

use Everything;
use Everything::Room;
initEverything 'everything';

open (WATCHMAN, ">> /usr/local/everything/log/watchman");
my $time = 4 * 60;
my $limit = 160;


my $csr=$DB->sqlSelectMany("*", 'room');

my %ROOM;
while (my $MEMBER = $csr->fetchrow_hashref) {
   $ROOM{$$MEMBER{room_id}}{$$MEMBER{member_user}} = $MEMBER;
}
$csr->finish;


$csr=$DB->getDatabaseHandle()->prepare("	

  SELECT user_id
    FROM
    (
    SELECT user_id,experience,lasttime
      FROM user
        USE INDEX (lasttime)
      ORDER BY lasttime DESC
      LIMIT $limit
    ) recent_users
  WHERE lasttime > TIMESTAMPADD(SECOND, -$time, NOW())
  ORDER BY experience DESC");
$csr->execute or die "errr... the query";
while (my ($U) = $csr->fetchrow) {
  $U = getNodeById($U);
  $V = getVars ($U);
  my $room_id = $$U{in_room};
  my $user_id = $$U{user_id};

  if (exists ($ROOM{$room_id}{$user_id})) {
    #the user is still in the room
    delete $ROOM{$room_id}{$user_id};
  }  else {
    #the user needs to be inserted into the room table 
    Everything::Room::insertIntoRoom($room_id, $U, $V);      
    print WATCHMAN localtime(time)."\tentrance\troom $room_id\t$$U{title}\n";
  } 
}
$csr->finish;

#remove everyone who's left a room
foreach my $room_id (keys %ROOM) {
  foreach (keys %{ $ROOM{$room_id}}) {
    $DB->sqlDelete("room", "room_id=$room_id and member_user=$_");
    print WATCHMAN localtime(time)."\tdeparture\troom $room_id\t$ROOM{$room_id}{$_}{nick}\n";
  }
}

