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
  # React-based chatterbox - all rendering handled by React component
  return '';
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
