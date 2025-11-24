# Other Users Nodelet - Complete Specification

**Last Updated**: 2025-11-23
**Based On**: Original implementation from commit eaeb4d2a6

## Overview

The Other Users nodelet displays real-time information about users currently in the chatterbox system. It shows who is online, their status, and various social indicators.

## Original Source Code

```perl
sub other_users
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";

  $str .= htmlcode("changeroom","Other Users");

  my $wherestr = "";

  $$USER{in_room} = int($USER->{in_room});
  $USER->{in_room} = 0 unless getNodeById($USER->{in_room});
  if ($$USER{in_room}) {
    $wherestr = "room_id=$$USER{in_room} OR room_id=0";
  }

  my $UID = $$USER{node_id};
  my $isRoot = $APP->isAdmin($USER);
  my $isCE = $APP->isEditor($USER);
  my $isChanop = $APP->isChanop($USER);

  unless ($isCE || $$VARS{infravision}) {
    $wherestr.=' AND ' if $wherestr;
    $wherestr.='visible=0';
  }

  my $showActions = $$VARS{showuseractions} ? 1 : 0;

  my @doVerbs = ();
  my @doNouns = ();
  if ($showActions)
  {
    @doVerbs = ('eating', 'watching', 'stalking', 'filing',
              'noding', 'amazed by', 'tired of', 'crying for',
              'thinking of', 'fighting', 'bouncing towards',
              'fleeing from', 'diving into', 'wishing for',
              'skating towards', 'playing with',
              'upvoting', 'learning of', 'teaching',
              'getting friendly with', 'frowned upon by',
              'sleeping on', 'getting hungry for', 'touching',
              'beating up', 'spying on', 'rubbing', 'caressing',
              ''        # leave this blank one in, so the verb is
                        # sometimes omitted
    );
  @doNouns = ('a carrot', 'some money', 'EDB', 'nails', 'some feet',
              'a balloon', 'wheels', 'soy', 'a monkey', 'a smurf',
              'an onion', 'smoke', 'the birds', 'you!', 'a flashlight',
              'hash', 'your speaker', 'an idiot', 'an expert', 'an AI',
              'the human genome', 'upvotes', 'downvotes',
              'their pants', 'smelly cheese', 'a pink elephant',
              'teeth', 'a hippopotamus', 'noders', 'a scarf',
              'your ear', 'killer bees', 'an angst sandwich',
              'Butterfinger McFlurry'
    );
  }

  my $newbielook = $isRoot || $isCE;

  my $powStructLink = '<a href='.urlGen({'node'=>'E2 staff', 'nodetype'=>'superdoc'})
                    . ' style="text-decoration: none;" ';
  my $linkRoots = $powStructLink . 'title="e2gods">@</a>';
  my $linkCEs = $powStructLink . 'title="Content Editors">$</a>';

  my $linkChanops = $powStructLink.'title="chanops">+</a>';

  my $linkBorged = '<a href='.urlGen({'node'=>'E2 FAQ: Chatterbox',
                                   'nodetype'=>'superdoc'})
                 .' style="text-decoration: none;" title="borged!">&#216;</a>';

  # no ordering from databse - sorting done entirely in perl, below
  my $csr = $DB->sqlSelectMany('*', 'room', $wherestr);

  my $num = 0;
  my $sameUser;   # if the user to show is the user that is loading the page
  my $userID;     # only get member_user from hash once
  my $n;          # nick
  my $is1337 = ($userID == 220 || $userID == 322);        # nate and hemos

  # Fetch users to ignore.
  my $ignorelist = $DB->sqlSelectMany('ignore_node', 'messageignore',
                                    'messageignore_id='.$UID);
  my (%ignore, $u);
  $ignore{$u} = 1 while $u = $ignorelist->fetchrow();
  $ignorelist->finish;

  my @noderlist;
  while(my $U = $csr->fetchrow_hashref())
  {
    $num++;
    $userID = $$U{member_user};

    my $jointime = $APP->convertDateToEpoch(getNodeById($userID)->{createtime});

    my $userVars = getVars(getNodeById($userID));

    my ($lastnode,$lastnodetime, $lastnodehidden);
    my $lastnodeid =  $userVars -> {lastnoded};
    if ($lastnodeid)
    {
      $lastnode = getNodeById($lastnodeid);
      $lastnodetime = $lastnode -> {publishtime};
      $lastnodehidden = $lastnode -> {notnew};

      # Nuked writeups can mess this up, so have to check there really
      # is a lastnodetime.
      $lastnodetime = $APP->convertDateToEpoch($lastnodetime) if $lastnodetime;
    }

    #Haven't been here for a month or haven't noded?
    if( time() - $jointime  < 2592000 || !$lastnodetime ){
      $lastnodetime = 0;
    }

    my $thisChanop = $APP->isChanop($userID,"nogods");

    $sameUser = $UID==$userID;
    next if $ignore{$userID} && !$isRoot;
    $n = $$U{nick};
    my $nameLink = linkNode($userID, $n);

    if (htmlcode('isSpecialDate','halloween'))
    {
      my $bAndBrackets = 1;
      my $costume = $$userVars{costume};
      if (defined $costume and $costume ne '')
      {
        $costume = encodeHTML($$userVars{costume}, $bAndBrackets);
        $nameLink = linkNode($userID, $costume);
      }
    }
    $nameLink = '<strong>'.$nameLink.'</strong>' if $sameUser;

    my $flags='';
    if ($APP->isAdmin($userID) && !$APP->getParameter($userID,"hide_chatterbox_staff_symbol") )
    {
      $flags .= $linkRoots;
    }

    if ($newbielook)
    {
      my $getTime = $DB->sqlSelect("datediff(now(),createtime)+1 as "
                                 ."difftime","node","node_id="
                                 .$userID." having difftime<31");

      if ($getTime)
      {
        if ($getTime<=3)
        {
          $flags.='<strong class="newdays" title="very new user">'.$getTime.'</strong>';
        } else {
          $flags.='<span class="newdays" title="new user">'.$getTime.'</span>'
        }
      }
    }

    if ($APP->isEditor($userID, "nogods") && !$APP->isAdmin($userID) && !$APP->getParameter($userID,"hide_chatterbox_staff_symbol") )
    {
      $flags .= $linkCEs;
    }

    $flags .= $linkChanops if $thisChanop;

    if ($isCE || $isChanop)
    {
      $flags .= $linkBorged if $$U{borgd}; # yes, no 'e' in 'borgd'
    }
    if ($$U{visible})
    {
      $flags.='<font color="#ff0000">i</font>';
    }

    if ($$U{room_id} != 0 and $$USER{in_room} == 0)
    {
      my $rm = getNodeById($$U{room_id});
      $flags .= linkNode($rm, '~');
    }

    $flags = ' &nbsp;[' . $flags . ']' if $flags;

    my $nameLinkAppend = "";

    if ($showActions && !$sameUser && (0.02 > rand()))
    {
      $nameLinkAppend = ' <small>is ' . $doVerbs[int(rand(@doVerbs))]
                      . ' ' . $doNouns[int(rand(@doNouns))]
                      . '</small>';
    }

    # jessicaj's idea, link to a user's latest writeup
    if ($showActions && (0.02 > rand()) )
    {
      if ((time() - $lastnodetime) < 604800 # One week since noding?
        && !$lastnodehidden) {
        my $lastnodeparent = getNodeById($$lastnode{parent_e2node});
        $nameLinkAppend = '<small> has recently noded '
                        . linkNode($lastnode,$$lastnodeparent{title})
                        . ' </small>';
      }

    }

    $nameLink .= $nameLinkAppend;

    $n =~ tr/ /_/;

    my $thisnoder .= $nameLink . $flags;

    #Votes only get refreshed when user logs in
    my $activedays = $userVars -> {votesrefreshed};

    # Gotta resort the noderlist by recent writeups and XP
    push @noderlist, {
        'noder' => $thisnoder
        , 'lastNodeTime' => $lastnodetime
        , 'activeDays' => $activedays
        , 'roomId' => $$U{room_id}
     };
  }
  $csr->finish;

  return '<em>There are no noders in this room.</em>' unless $num;
  # sort by latest time of noding, tie-break by active days if
  # necessary, [alex]'s idea

  @noderlist = sort {
    ($$b{roomId} == $$USER{in_room}) <=> ($$a{roomId} == $$USER{in_room})
    || $$b{roomId} <=> $$a{roomId}
    || $$b{lastNodeTime} <=> $$a{lastNodeTime}
    || $$b{activeDays} <=> $$a{activeDays}
  } @noderlist;

  my $printRoomHeader = sub {
     my $roomId = shift;
     my $roomTitle = 'Outside';
     if ($roomId != 0)
     {
       my $room = getNodeById($roomId);
       $roomTitle = $room && $$room{type}{title} eq 'room' ?
                        $$room{title} : 'Unknown Room';
     }
     return "<div>$roomTitle:</div>\n<ul>\n";
  };

  my $lastroom = $noderlist[0]->{roomId};
  $str .= "<ul>\n";
  foreach my $noder(@noderlist)
  {
    if ($$noder{roomId} != $lastroom)
    {
      $str .= "</ul>\n";
      $str .= &$printRoomHeader($$noder{roomId});
    }

    $lastroom = $$noder{roomId};
    $str .= "<li>$$noder{noder}</li>\n";
  }

  $str .= "</ul>\n";

  my $intro = '<h4>Your fellow users ('.$num.'):</h4>';
  $intro .= '<div>in '.linkNode($$USER{in_room}). ':</div>' if $$USER{in_room};

  return $intro . $str;

}
```

## Detailed Feature Specification

### 1. Staff Badges (Sigils)

All badges link to "E2 staff" superdoc with tooltips:

| Badge | Meaning | Check | Visibility |
|-------|---------|-------|-----------|
| `@` | e2gods | `isAdmin($userID)` | Hide if user has `hide_chatterbox_staff_symbol` parameter |
| `$` | Content Editors | `isEditor($userID, "nogods") && !isAdmin($userID)` | Hide if user has `hide_chatterbox_staff_symbol` parameter |
| `+` | chanops | `isChanop($userID, "nogods")` | Always show if true |
| `Ø` (&#216;) | borged | `$U->{borgd}` | Only visible to editors/chanops |

**Important**: Editors who are also gods only show `@`, not `$`.

### 2. New User Indicators

Only visible to admins and editors (`$newbielook = $isRoot || $isCE`):

```sql
datediff(now(),createtime)+1 as difftime HAVING difftime<31
```

- **≤3 days**: `<strong class="newdays" title="very new user">N</strong>`
- **4-30 days**: `<span class="newdays" title="new user">N</span>`
- **>30 days**: No indicator

**Bug Fix (2025-11-23)**: Initial React implementation was missing the `$newbielook` check, causing new user indicators to be visible to all users. Fixed by adding `my $newbielook = $user_is_admin || $user_is_editor;` check before adding newuser flags in [Application.pm:5485](ecore/Everything/Application.pm#L5485).

### 3. Invisibility Indicators

**Database Field**: `visible` in `room` table
- `visible=0`: User is visible to all
- `visible=1`: User is invisible (only visible to privileged users)

**Query Filter**:
```perl
unless ($isCE || $$VARS{infravision}) {
  $wherestr .= 'visible=0';
}
```

**Display Indicator** (for privileged users only):
```perl
if ($$U{visible}) {
  $flags .= '<font color="#ff0000">i</font>';
}
```

Shows red 'i' when user is invisible.

**Infravision**: User VARS preference that allows seeing invisible users (like editor/chanop power but for regular users)

### 4. Room Indicators

When user is in a different room than the viewer is in room 0 (Outside):

```perl
if ($$U{room_id} != 0 and $$USER{in_room} == 0) {
  my $rm = getNodeById($$U{room_id});
  $flags .= linkNode($rm, '~');
}
```

Shows `~` link to the room the user is in.

### 5. User Actions

**VARS Preference**: `showuseractions` (NOT `hide_chatterbox_userdoing`)

**Probability**: 2% chance per user (0.02 > rand())

**Verbs** (29 options including blank):
```perl
'eating', 'watching', 'stalking', 'filing',
'noding', 'amazed by', 'tired of', 'crying for',
'thinking of', 'fighting', 'bouncing towards',
'fleeing from', 'diving into', 'wishing for',
'skating towards', 'playing with',
'upvoting', 'learning of', 'teaching',
'getting friendly with', 'frowned upon by',
'sleeping on', 'getting hungry for', 'touching',
'beating up', 'spying on', 'rubbing', 'caressing',
''  # Blank - sometimes omit verb entirely
```

**Nouns** (34 options):
```perl
'a carrot', 'some money', 'EDB', 'nails', 'some feet',
'a balloon', 'wheels', 'soy', 'a monkey', 'a smurf',
'an onion', 'smoke', 'the birds', 'you!', 'a flashlight',
'hash', 'your speaker', 'an idiot', 'an expert', 'an AI',
'the human genome', 'upvotes', 'downvotes',
'their pants', 'smelly cheese', 'a pink elephant',
'teeth', 'a hippopotamus', 'noders', 'a scarf',
'your ear', 'killer bees', 'an angst sandwich',
'Butterfinger McFlurry'
```

**Format**: `<small>is VERB NOUN</small>`

**Exclusion**: Never show for current user (`!$sameUser`)

### 6. Recent Noding Links

**VARS Preference**: `showuseractions` (same as actions)

**Probability**: 2% chance per user (0.02 > rand())

**Conditions**:
1. Must have `showuseractions` enabled
2. Less than 1 week since last node (604800 seconds)
3. Last node must not be hidden (`!$lastnodehidden`)

**Data Source**:
- User VARS: `lastnoded` (node_id)
- Node field: `publishtime`
- Node field: `notnew` (hidden flag)
- Parent: `parent_e2node`

**Calculation**:
```perl
# If user joined less than a month ago OR hasn't noded, set to 0
if (time() - $jointime < 2592000 || !$lastnodetime) {
  $lastnodetime = 0;
}
```

**Format**: `<small> has recently noded [link to writeup with parent title]</small>`

**Note**: This REPLACES user action if both would trigger (recent noding takes precedence)

### 7. Halloween Costumes

**Date Check**: `htmlcode('isSpecialDate','halloween')`

**User VARS**: `costume`

**Behavior**:
1. Check if it's Halloween using `isSpecialDate` htmlcode
2. Get user's `costume` VARS
3. If costume is defined and not empty:
   - HTML encode the costume name
   - Replace user's display name with costume in link

**Format**: Link still points to real user, but displays costume name

### 8. Current User Highlighting

**Check**: `$UID == $userID`

**Format**: `<strong>USERNAME_LINK</strong>`

Wraps the entire nameLink in strong tags.

### 9. Ignore List

**Query**:
```perl
$DB->sqlSelectMany('ignore_node', 'messageignore',
                   'messageignore_id='.$UID);
```

**Behavior**:
```perl
next if $ignore{$userID} && !$isRoot;
```

Skip ignored users UNLESS viewer is an admin (root).

### 10. Sorting Algorithm

**Order** (in priority):
1. **Current room first**: Users in viewer's room before users in other rooms
2. **Room ID descending**: Higher room IDs first
3. **Last node time descending**: Most recent noders first
4. **Active days descending**: Most active users first

```perl
@noderlist = sort {
  ($$b{roomId} == $$USER{in_room}) <=> ($$a{roomId} == $$USER{in_room})
  || $$b{roomId} <=> $$a{roomId}
  || $$b{lastNodeTime} <=> $$a{lastNodeTime}
  || $$b{activeDays} <=> $$a{activeDays}
} @noderlist;
```

**Active Days**: Uses `votesrefreshed` VARS (NOT calculated from createtime)

### 11. Multi-Room Display

**Room Headers**:
- First user's room doesn't get a header (implied to be current room)
- When room changes, close previous `</ul>` and open new section with room header
- Room header format: `<div>ROOM_TITLE:</div>\n<ul>\n`
- Room 0 displays as "Outside"
- Other rooms display node title if valid room type, otherwise "Unknown Room"

**Room Query**:
```perl
if ($$USER{in_room}) {
  $wherestr = "room_id=$$USER{in_room} OR room_id=0";
}
```

Shows users in current room AND room 0 (Outside).

### 12. Flags Formatting

**Bracket Wrapping**:
```perl
$flags = ' &nbsp;[' . $flags . ']' if $flags;
```

Only add brackets if there are any flags to show.

**Flag Order**:
1. Gods sigil (`@`)
2. New user indicator (days)
3. Editor sigil (`$`)
4. Chanop sigil (`+`)
5. Borged indicator (`Ø`)
6. Invisible indicator (red `i`)
7. Room indicator (`~`)

### 13. Output Format

**Empty State**:
```html
<em>There are no noders in this room.</em>
```

**Normal State**:
```html
<h4>Your fellow users (N):</h4>
<div>in CURRENT_ROOM:</div>  <!-- Only if in a room -->
<ul>
<li>USER_LINK [FLAGS] ACTION_OR_RECENT</li>
...
</ul>
<!-- Additional rooms with headers -->
<div>OTHER_ROOM:</div>
<ul>
<li>USER_LINK [FLAGS] ACTION_OR_RECENT</li>
...
</ul>
```

### 14. Change Room Integration

First line of output:
```perl
$str .= htmlcode("changeroom","Other Users");
```

Provides room switching interface at top of nodelet.

## Database Schema

### room table
- `member_user` - User node ID
- `room_id` - Room node ID (0 = Outside)
- `visible` - 0=visible, 1=invisible
- `borgd` - User is borged (no 'e')
- `nick` - Display nickname

### User VARS
- `infravision` - Can see invisible users
- `showuseractions` - Show random actions and recent noding
- `hide_chatterbox_staff_symbol` - Hide own staff badge
- `lastnoded` - Last writeup node_id
- `votesrefreshed` - Active days (login-based)
- `costume` - Halloween costume name

### Node fields (writeup)
- `publishtime` - When writeup was published
- `notnew` - Hidden writeup flag
- `parent_e2node` - Parent e2node

## Critical Implementation Notes

1. **Do NOT use `hide_chatterbox_userdoing`** - Correct preference is `showuseractions`
2. **Visibility is INVERTED**: visible=0 is normal, visible=1 is invisible
3. **Active days uses VARS**: `votesrefreshed`, not calculated from createtime
4. **Recent noding replaces actions**: If recent noding triggers, don't show random action
5. **Editors who are gods**: Only show `@`, not both `@` and `$`
6. **Last node time reset**: Set to 0 if user joined <1 month ago OR never noded
7. **Room display logic**: First room doesn't get header, subsequent rooms do
8. **Ignore list exception**: Admins can see users they've ignored
9. **1337 users**: Line references nate and hemos (220, 322) but variable unused
10. **Verbs include blank**: Empty string in verb array allows occasional verb omission

## Testing Checklist

- [ ] Sigils display correctly (@, $, +, Ø)
- [ ] New user indicators (≤3 days bold, 4-30 days normal)
- [ ] Invisible users show red 'i' to privileged viewers
- [ ] Infravision VARS preference works
- [ ] showuseractions VARS controls actions and recent noding
- [ ] Random actions appear ~2% of time with correct verbs/nouns
- [ ] Recent noding links appear ~2% of time for recent noders
- [ ] Halloween costumes replace names during Halloween period
- [ ] Current user appears in bold
- [ ] Ignore list hides users (except for admins)
- [ ] Sorting works correctly (room, then noding time, then active days)
- [ ] Multi-room display with correct headers
- [ ] Room indicator (~) for users in different rooms
- [ ] Flags wrapped in brackets [...]
- [ ] Empty state message when no users
- [ ] Change room interface at top

## Future Enhancements

The original code includes a reference to special handling for "1337 users" (nate and hemos) but the variable is defined but never used. This may have been removed or planned but not implemented.
