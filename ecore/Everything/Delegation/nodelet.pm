package Everything::Delegation::nodelet;

use strict;
use warnings;

BEGIN {
  *getVars = *Everything::HTML::getVars;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
  *parseLinks = *Everything::HTML::parseLinks;
  *getRef = *Everything::HTML::getRef;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
}

sub epicenter
{
  return '';
}

sub new_writeups
{
  return '';
}

sub other_users
{
  return '';
}

sub sign_in
{
  return '';
}

sub recommended_reading
{
  return '';
}

sub vitals
{
  return '';
}

sub chatterbox
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str='';

  $str .= htmlcode("openform2","formcbox");

  # get settings here in case they are being updated. Slight kludge to remember them...
  $PAGELOAD->{chatterboxsettingswidgetlink} = htmlcode('nodeletsettingswidget','Chatterbox', 'Chatterbox settings');
  unless($$VARS{hideprivmessages})
  {

    my $messagesID = $DB->getNode('Messages', 'nodelet') -> { node_id } ;
    unless($$VARS{ nodelets } =~ /\b$messagesID\b/)
    {

      my $msgstr = htmlcode('showmessages','10');
      my $hr = "";
      $hr = '<hr width="40%">' if $msgstr;
      $str .= qq|<div id="chatterbox_messages">$msgstr</div>$hr|;
    }
  }

  $str .= qq|<div id='chatterbox_chatter'>|.htmlcode("showchatter").qq|</div><a name='chatbox'></a>|;

  unless($APP->isGuest($USER))
  {
    my $msgstr = '<input type="hidden" name="op" value="message" /><br />'."\n\t\t";
    $query->param('message','');

    #show what was said
    if(defined $query->param('sentmessage'))
    {
      my $told = $query->param('sentmessage');
      my $i=0;
      while(defined $query->param('sentmessage'.$i))
      {
        $told.="<br />\n\t\t".$query->param('sentmessage'.$i);
        ++$i;
      }
      $told=parseLinks($told,0) unless $$VARS{showRawPrivateMsg};
      $msgstr.="\n\t\t".'<p class="sentmessage">'.$told."</p>\n";
    }

    #borged or allow talk
    $msgstr .= htmlcode('borgcheck') || "";
    $msgstr .= $$VARS{borged}
    ? '<small>You\'re borged, so you can\'t talk right now.</small><br>' . $query->submit('message_send', 'erase')
    : "<input type='text' id='message' name='message' class='expandable' size='".($$NODE{title} eq "ajax chatterlight" ? "70" : "12")."' maxlength='512'>" . "\n\t\t" .
    $query->submit(-name=>'message_send', id=>'message_send', value=>'talk'). "\n\t\t";
;

    if ($APP->isSuspended($USER,"chat"))
    {
      my $canMsg = ($$VARS{borged}
                ? "chatting."
                : "public chat, but you can /msg other users.");
      $msgstr .= "<p><small>You are currently suspended from $canMsg</small></p>\n"
    }

    $msgstr.=$query->end_form;

    $msgstr .= "\n\t\t".'<div align="center"><small>'.linkNodeTitle('Chatterbox|How does this work?')." | ".linkNodeTitle('Chatterlight')."</small></div>\n" if $APP->getLevel($USER)<2;

    #Jay's topic stuff

    my $topicsetting = "";
    my $topic = '';

    unless($$VARS{hideTopic} )
    {
      $topicsetting = getVars($DB->getNode('Room Topics', 'setting'));

      if(exists($$topicsetting{$$USER{in_room}}))
      {
        $topic = $$topicsetting{$$USER{in_room}};
        utf8::decode($topic);
        $topic = "\n\t\t".'<small>'.parseLinks($topic).'</small>'; #slighly different
      }

    }

    $str.=$msgstr.$topic;
  }

  $str .= qq|<div class="nodeletfoot">|;

  if($APP->isChanop($USER))
  {
    $str .= linkNode($NODE, 'silence', {'confirmop' => 'flushcbox',
	-class=>"action ajax chatterbox:updateNodelet:Chatterbox"}).'<br>';
  }

  if($USER->{in_room})
  {
    $str .= linkNodeTitle('go outside[superdocnolinks]').'<br>';
  }
  
  $str .= $PAGELOAD->{chatterboxsettingswidgetlink}. qq|</div>|;
  return $str;
}

sub personal_links
{
  return '';
}

sub random_nodes
{
  return '';
}

sub everything_developer
{
  return '';
}

sub statistics
{
  return '';
}

sub readthis
{
  return '';
}

sub notelet
{
  return '';
}

sub recent_nodes
{
  return '';
}

sub master_control
{
  return '';
}

sub current_user_poll
{
  return '';
}

sub favorite_noders
{
  return '';
}

sub new_logs
{
  return '';
}

sub usergroup_writeups
{
  return '';
}

sub notifications
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<ul id='notifications_list'>|;
  # show settings dialog if no notifications active
  $query -> param('showwidget', 'notificationssettings') unless $$VARS{settings} || ($$NODE{title} eq 'Nodelet Settings' && $$NODE{type}{title} eq 'superdoc');
  # do this here to update settings before showing nodelet:
  my $settingslink = htmlcode('nodeletsettingswidget','Notifications', 'Notification settings');

  my $notification_list = htmlcode('notificationsJSON', 'wrap'); # 'wrap' to get markup for list
my $notify_count = 1;

  while (defined $$notification_list{$notify_count}) {
    my $notify = $$notification_list{$notify_count};
    $str .= "$$notify{value}\n";
    $notify_count++;
  }

return $str.qq'\n</ul>\n<div class="nodeletfoot">\n$settingslink\n</div>';

}

sub categories
{
  return '';
}

sub most_wanted
{
  return '';
}

sub messages
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return qq|<div id="messages_messages">|.htmlcode('testshowmessages').qq|</div>|;
}

sub neglected_drafts
{
  return '';
}

sub for_review
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my %funx = (
    startline => sub{
      $_[0] -> {type}{title} = 'draft';
      '<td>';
    },
    notes => sub{
      $_[0]{latestnote} =~ s/\[user\]//;
      my $note = $APP->encodeHTML($_[0]{latestnote}, 'adv');
      '<td align="center">'
      .($_[0]{notecount} ? linkNode($_[0], $_[0]{notecount},
      {'#' => 'nodenotes', -title => "$_[0]{notecount} notes; latest $note"})
      : '&nbsp;')
      .'</td>';
      }
  );

  my $drafts = $DB->stashData("reviewdrafts");

  return "<table><tr><th>Draft</th>".($APP->isEditor($USER)?(qq|<th align="center" title="node notes">N?</th>|):(""))."</tr>"
    .htmlcode('show content', $drafts
    , qq!<tr class="&oddrow"> startline, title, byline, "</td>",!.(($APP->isEditor($USER)?("notes"):(""))),%funx)
    .'</table>';

}

sub quick_reference
{
  return '';
}

1;
