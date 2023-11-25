package Everything::Delegation::document;

use strict;
use warnings;

# Used by advanced_settings
use DateTime;

BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getVars = *Everything::HTML::getVars;
  *getId = *Everything::HTML::getId;
  *urlGen = *Everything::HTML::urlGen;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
  *parseCode = *Everything::HTML::parseCode;
  *parseLinks = *Everything::HTML::parseLinks;
  *isNodetype = *Everything::HTML::isNodetype;
  *getRef = *Everything::HTML::getRef;
  *insertNodelet = *Everything::HTML::insertNodelet;
  *getType = *Everything::HTML::getType;
  *updateNode = *Everything::HTML::updateNode;
  *setVars = *Everything::HTML::setVars;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *canReadNode = *Everything::HTML::canReadNode;
  *encodeHTML = *Everything::HTML::encodeHTML;
}

# Used by e2_sperm_counter
use POSIX qw(ceil);

# Used by your_gravatar
use Digest::MD5;

sub admin_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '<p>You need to sign in or '
	.linkNode(getNode('Sign up','superdoc'), 'register').' to use this page.</p>' if $APP->isGuest($USER);

  $PAGELOAD->{pageheader} = '<!-- at end -->'.htmlcode('settingsDocs');

  my $str = htmlcode('openform', -id => 'pagebody');

  #editor options
  if($APP->isEditor($USER))
  {
    return unless $APP->isEditor($USER);
    my $nl = "<br />\n";
    $str .= "<p><strong>Editor Stuff</strong>\n";
    $str .= $nl . htmlcode('varcheckbox','killfloor_showlinks,Add HTML in the killing floor display for easy copy & paste');

    $str .= $nl . htmlcode('varcheckbox','hidenodenotes,Hide Node Notes');

    $str .= '</p>';

    my $f = $query->param('sexisgood'); #end of form indicator
    my $l=768; #max length of each macro

    #key is allowed macro, value is the default
    #note: things like $1 are NOT supposed to be interpolated - that is done when the macro is executed
    my %allowedMacros = (
      'room' => '/say /msg $1 Just so you know - you are not in the default room, where most people stay. To get back into the main room, either visit {go outside}, or: go to the top of the "other users" nodelet, pick "outside" from the dropdown list, and press the "Go" button.',
      'newbie' => '/say /msg $1 Hello, your writeups could use a little work. Read [Everything University] and [Everything FAQ] to improve your current and future writeups. $2+'."\n".'/say /msg $1 If you have any questions, you can send me a private message by typing this in the chatterbox: /msg $0 (Your message here.)',
      'html' => '/say /msg $1 Your writeups could be improved by using some HTML tags, such as &lt;p&gt; , which starts a new paragraph. [Everything FAQ: Can I use HTML in my writeups?] lists the tags allowed here, and [E2 HTML tags] shows you how to use them.',
      'wukill' => '/say /msg $1 FYI - I removed your writeup $2+',
      'nv' => '/say /msg $1 Hey, I know that you probably didn\'t mean to, but advertising your writeups ("[nodevertising]") in the chatterbox isn\'t cool. Imagine if everyone did that - there would be no room for chatter.',
      'misc1' => '/say /msg $0 Use this for your own custom macro. See [macro FAQ] for information about macros.'."\n".'/say /msg $0 If you have an idea of another thing to add that would be wanted by many people, give N-Wing a /msg.',
      'misc2' => '/say /msg $0 Yup, this is an area for another custom macro.'
    );

    my @ks = sort(keys(%allowedMacros));

    foreach my $k (@ks)
    {
      my $v = undef;
      if( (defined $query->param('usemacro_'.$k)) && ($v=$query->param('usemacro_'.$k) eq '1') )
      {
	#possibly add macro
	if( (defined $query->param('macrotext_'.$k)) && ($v=$query->param('macrotext_'.$k)) )
        {
          $v =~ tr/\r/\n/; $v =~ s/\n+/\n/gs; #line endings are a pain
          $v =~ s/[^\n\x20-\x7e]//gs; #could probably also allow \x80-\xfe
          $v = substr($v,0,$l);
          $v =~ s/\{/[/gs; $v =~ s/\}/]/gs; #hack - it seems you can't use square brackets in a superdoc :(
          $$VARS{'chatmacro_'.$k} = $v;
	}
      } elsif($f) {
        #delete unwanted macro (but only if no form submit problems)
        delete $$VARS{'chatmacro_'.$k};
      }
    }

    $str .= '<p><strong>Macros</strong></p>'."\n".'<table cellspacing="1" cellpadding="2" border="1"><tr><th>Use?</th><th>Name</th><th>Text</th></tr>'."\n";

    foreach my $k (@ks)
    {
	my $v = $$VARS{'chatmacro_'.$k};
	my $z = ($v && length($v)>0) ? 1 : 0;
	unless($z) { $v = $allowedMacros{$k}; }
	$v =~ s/\[/{/gs; $v =~ s/\]/}/gs; #square-link-in-superdoc workaround :(
	$str .= '<tr><td>' .
	$query->checkbox('usemacro_'.$k, $z, '1', '')
	. '</td><td><code>' . $k . '</code></td><td>' .
	$query->textarea(-name=>'macrotext_'.$k, -default=>$v, -rows=>6, -columns=>65, -override=>1)
	. "</td></tr>\n";
    }

    $str .= "</table>\n".'If you will use a macro, make sure the "Use" column is checked. If you won\'t use it, uncheck it, and it will be deleted. The text in the "macro" area of a "non-use" macro is the default text, although you can change it (but be sure to check the "use" checkbox if you want to keep it). Each macro must currently begin with <code>/say</code> (which indicates that you\'re saying something). Note: each macro is limited to '.$l.' characters. Sorry, until a better solution is found, instead of square brackets, &#91; and &#93;, you\'ll have to use curly brackets, { and } instead. <tt>:(</tt> There is more information about macros at [macro FAQ].</p>';

  }

  $str .= htmlcode("closeform");
  return $str;
}

sub advanced_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '<p>You need to sign in or '
	.linkNode(getNode('Sign up','superdoc'), 'register')
	.' to use this page.</p>' if ($APP->isGuest($USER));

  if (defined $query->param('sexisgood'))
  {
    $$VARS{'preference_last_update_time'} = DateTime->now()->epoch()-60;
  }

  $PAGELOAD->{pageheader} = '<!-- put at end -->'.htmlcode('settingsDocs');
  my $str = htmlcode('openform', -id=>'pagebody');
  $str .= qq|<h2>Page display</h2>|;

  my @headeroptions = ( 'audio', 'length' , 'hits' , 'dtcreate' ) ;
  my @footeroptions = ( 'kill' , 'sendmsg' , 'addto' , 'social' ) ;

  my $legacycheck = '^$|c:type,c:(author|pseudoanon)(,\w:' . join( ')?(,\w:' , @headeroptions ) . ',?)?' ;
  my $legacyhead = '';
  $legacyhead = '<p>'.$query->checkbox(-name=>'replaceoldheader',
    -label=>'Overwrite all existing header settings. (Changing settings here will not overwrite any custom formatting you already have in place unless you check this.)')."</p>\n" 
    unless $$VARS{ wuhead } =~ /^$legacycheck$/ || $query -> param( 'replaceoldheader' ) ;

  $legacycheck = '^$|(l:kill)?,?c:vote,c:cfull(,\w:' . join( ')?(,\w:' , @footeroptions ) . ',?)?' ;
  my $legacyfoot = '';
  $legacyfoot = '<p>'.$query->checkbox(-name=>'replaceoldfooter',
    -label=>'Overwrite all existing footer settings. (Changing settings here will not overwrite any custom formatting you already have in place unless you check this.)')."</p>\n"
    unless $$VARS{ wufoot } =~ /^$legacycheck$/ || $query -> param( 'replaceoldfooter' );

  if(defined($query->param('change_stuff')))
  {
    $$VARS{ wuhead } = 'c:type,c:author,c:audio,c:length,c:hits,r:dtcreate' unless $legacyhead ;
    $$VARS{ wuhead } =~ s/,$// ;

    foreach my $headeroption ( @headeroptions )
    {
      if($query->param('wuhead_'.$headeroption))
      {
        $$VARS{ wuhead } .= ",c:$headeroption," unless $$VARS{ wuhead } =~ /\w:$headeroption/ ;
      } else {
        $$VARS{ wuhead } =~ s/,?\w:$headeroption//g ;
      }
    }

    $$VARS{ wufoot }='l:kill,c:vote,c:cfull,c:sendmsg,c:addto,r:social' unless $legacyfoot ;
    $$VARS{ wufoot } =~ s/,$// ;
    foreach my $footeroption ( @footeroptions )
    {
      if($query->param('wufoot_'.$footeroption))
      {
        $$VARS{ wufoot } .= ",c:$footeroption" unless $$VARS{ wufoot } =~ /\w:$footeroption/ ;
      } else {
        $$VARS{ wufoot } =~ s/,?\w:$footeroption//g ;
      }
    }

    if ( $query -> param( 'nokillpopup' ) )
    {
      $$VARS{ nokillpopup } = 4 ;
    } else {
      delete $$VARS{ nokillpopup }
    }
  }

  $str .= "<fieldset><legend>Writeup Headers</legend>\n";
  $str .= htmlcode('varcheckboxinverse', 'info_authorsince_off','Show how long ago the author was here');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wuhead_audio',
    -checked=>( ($$VARS{'wuhead'}=~'audio') ? 1 : 0 ) ,
    -label=>'Show links to any audio files');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wuhead_length',
    -checked=>( ($$VARS{'wuhead'}=~'length') ? 1 : 0 ) ,
    -label=>'Show approximate word count of writeup');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wuhead_hits',
    -checked=>( ($$VARS{'wuhead'}=~'hits' || $$VARS{'wuhead'} eq '' ) ? 1 : 0 ) ,
    -label=>'Show a hit counter for each writeup');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wuhead_dtcreate',
    -checked=>( ($$VARS{'wuhead'}=~'dtcreate' || $$VARS{'wuhead'} eq '' ) ? 1 : 0 ) ,
    -label=>'Show time of creation');
  $str .= "<br>\n";

  $str .= "$legacyhead</fieldset>";

  $str .= "<fieldset><legend>Writeup Footers</legend>\n";

  if ($$USER{title} =~ /^(?:mauler|riverrun|Wiccanpiper|DonJaime)$/ and $DB->isGod($USER))
  {
    # only gods can disable pop-up: they get the missing tools in Master Control
    # as of 2011-07-15 only three gods are using it. Let's lose it gradually...
    $str .= $query->checkbox(-name=>'nokillpopup',
      -checked=>( $$VARS{ nokillpopup } == 4 ) ,
      -label=> 'Admin tools always visible, no pop-up' )
      .'<br>';
  }

  $str .= $query->checkbox(-name=>'wufoot_sendmsg',
    -checked=>( ($$VARS{'wufoot'}=~'sendmsg' || $$VARS{'wufoot'} eq '' ) ? 1 : 0 ) ,
    -label=>'Show a box to send messages to the author');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wufoot_addto',
   -checked=>( ($$VARS{'wufoot'}=~'addto' || $$VARS{'wufoot'} eq '' ) ? 1 : 0 ) ,
   -label=>'Show a tool to add the writeup to your bookmarks, a usergroup page or a category');
  $str .= "<br>\n";

  $str .= $query->checkbox(-name=>'wufoot_social',
    -checked=>( ($$VARS{'wufoot'}=~'social' || $$VARS{'wufoot'} eq '' ) ? 1 : 0 ) ,
    -label=>'Show social bookmarking buttons');
  $str .= "<br>\n";

  if($$VARS{nosocialbookmarking})
  {
    $str .= "<small>To see social bookmarking buttons on other people's writeups you must enable them for yours<br>\n";

    $str .= htmlcode('varcheckboxinverse','nosocialbookmarking','Enable social bookmarking buttons on my writeups')."</small><br>\n"
  }

  $str .= "$legacyfoot</fieldset>";

  $str .= $query->hidden(-name=>'change_stuff');

  $str .= qq|<p><small><strong>[Old Writeup Settings]</strong> provides more control over writeup headers and footers, but the interface is rather complicated.</small></p>|;
  $str .= qq|<fieldset><legend>Homenodes</legend>|;

  $str .= htmlcode("varcheckbox","hidemsgme","I am anti-social.");
  $str .= qq|(So don't display the user /msg box in users' homenodes.)|;
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","hidemsgyou",'No one talks to me either, so on homenodes, hide the "/msgs from me" link to [Message Inbox]');
  $str .= qq|<br>|;
  
  $str .= htmlcode("varcheckbox","hidevotedata","Not only that, but I'm careless with my votes and C!s (so don't show them on my homenode)");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","hidehomenodeUG","I'm a loner, Dottie, a rebel. (Don't list my usergroups on my homenode.)");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","hidehomenodeUC","I'm a secret librarian. (Don't list my categories on my homenode.)");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","showrecentwucount","Let the world know, I'm a fervent noder, and I love it! (show recent writeup count in homenode.)");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","hidelastnoded","Link to user's most recently created writeup on their homenode");
  $str .= qq|<br>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Other display options</legend>|;
  $str .= htmlcode("varcheckboxinverse","hideauthore2node","Show who created a writeup page title (a.k.a. e2node)");
  $str .= qq|<br>|;

  $$VARS{ repThreshold } ||= '0' if exists( $$VARS{ repThreshold } ) ; # ecore stores 0 as ''
  if ( $query -> param( 'sexisgood' ) )
  {
    $query -> param( 'activateThreshold' , 1 ) if $query->param('repThreshold') ne '' and $$VARS{repThreshold} eq 'none' ;
    unless ( $query -> param( 'activateThreshold' ) )
    {
      $$VARS{repThreshold} = 'none';
    } else {
      $$VARS{repThreshold} = $query->param('repThreshold');
      unless ( $$VARS{repThreshold} =~ /\d+|none/ )
      {
        delete $$VARS{repThreshold};
      } else {
        $$VARS{repThreshold} = int $$VARS{repThreshold};
	if ( $query->param('repThreshold') > 50 )
        {
          $query->param( 'repThreshold' , 50 );
          $str.="<small>Maximum threshold is 50.</small><br>";
        }
      }
    }
  }

  $query -> param( 'repThreshold' , '' ) if $$VARS{repThreshold} eq 'none';

  $str .= $query -> checkbox( -name=>'activateThreshold' , -value => 1 ,
    -checked=>( $$VARS{repThreshold} eq 'none' ? 0 : 1 ) , -force => 1 ,
    -label=>'Hide low-reputation writeups in New Writeups and e2nodes.' ) ;

  $str .= ' <label>Reputation threshold: ';
  $str .= $query-> textfield( 'repThreshold' , $$VARS{repThreshold} , 3 , 3 );
  $str .= "</label> (default is ".$Everything::CONF->writeuplowrepthreshold.")";

  $str .= qq|<br>|;
  $str .= htmlcode("varcheckbox","noSoftLinks","Hide softlinks");
  $str .= qq|<br>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<h2>Information</h2>|;
  $str .= qq|<fieldset><legend>Writeup maintenance</legend>|;

  $str .= htmlcode("varcheckboxinverse","no_notify_kill","Tell me when my writeups are deleted");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_editnotification","Tell me when my writeups get edited by [e2 staff|an editor or administrator]");
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Writeup response</legend>|;

  $str .= htmlcode("varcheckboxinverse","no_coolnotification",'Tell me when my writeups get [C!]ed ("cooled")');
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_likeitnotification","Tell me when Guest Users like my writeups");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_bookmarknotification","Tell me when my writeups get bookmarked on E2");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_bookmarkinformer","Tell others when I bookmark a writeup on E2");
  $str .= htmlcode("varcheckbox","anonymous_bookmark","but do it anonymously");
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Social bookmarking</legend>|;

  $str .= htmlcode("varcheckboxinverse","nosocialbookmarking","Allow others to see social bookmarking buttons on my writeups");
  $str .= qq|<small>Unchecking this will also hide the social bookmarking buttons on other people's writeups.</small><br>|;

  $str .= htmlcode("varcheckboxinverse","no_socialbookmarknotification","Tell me when my writeups get bookmarked on a social bookmarking site");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckboxinverse","no_socialbookmarkinformer","Tell others when I bookmark a writeup on a social bookmarking site");
  $str .= qq|</p></fieldset>|;

  $str .= qq|<fieldset><legend>Other information</legend>|;

  $str .= htmlcode("varcheckboxinverse","no_discussionreplynotify","Tell me when someone replies to my usergroup discussion posts");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","hidelastseen","Don't tell anyone when I was last here");
  $str .= qq|<br>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<h2>Messages</h2>|;
  $str .= qq|<fieldset><legend>Message Inbox</legend>|;

  $str .= htmlcode("varcheckbox","sortmyinbox","Sort my messages in message inbox");
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","mitextarea","Larger text box in Message Inbox");
  $str .= qq|<br></fieldset>|;

  $str .= qq|<fieldset><legend>Usergroup messages</legend>|;
  $str .= htmlcode("varcheckbox","getofflinemsgs","Get online-only messages, even while offline.");
  $str .= '([online only /msg|explanation])';
  $str .= qq|</fieldset>|;

  $str .= qq|<h2>Miscellaneous</h2>|;
  $str .= qq|<fieldset><legend>Chatterbox</legend>|;

  $str .= htmlcode("varcheckboxinverse","noTypoCheck","Check for chatterbox command typos");
  $str .= qq|&ndash; /mgs etc.(when enabled, some messages that aren't typos may be flagged as such, although this will protect you against most real typos)<br>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Nodeshells</legend>|;

  $str .= htmlcode("varcheckbox","hidenodeshells","Hide nodeshells in search results and softlink tables");
  $str .= qq|<br><small>A nodeshell is a page on Everything2 with a title but no content</small>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>GP system</legend>|;
  $str .= htmlcode("varcheckbox","GPoptout","Opt me out of the GP System.");
  $str .= qq|<br>|;
  $str .= qq|<small>[GP] is a points reward system. You get points for doing good stuff and can use them to buy fun stuff.</small>|;
  $str .= qq|</fieldset>|;

  $str .= qq|<fieldset><legend>Little-needed</legend>|;

  $str .= htmlcode("varcheckbox","defaultpostwriteup","Publish immediately by default.");
  $str .= qq|<br>|;

  $str .= qq|<small>(Some older users may appreciate having 'publish immediately' initially selected instead 'post as draft'.)</small><br>|;

  $str .= htmlcode("varcheckbox","noquickvote","Disable quick functions (a.k.a. AJAX).");
  $str .= qq|<br>|;

  $str .= qq|<small>(Voting, cooling, chatting, etc will all require complete pageloads. You probably don't want this.)</small><br>|;

  $str .= htmlcode("varcheckbox","nonodeletcollapser","Disable nodelet collapser");
  $str .= qq|<br>|;
  $str .= qq|<small>(clicking on a nodelet title will not hide its content).</small><br>|;

  $str .= htmlcode("varcheckbox","HideNewWriteups","Hide your new writeups by default");
  $str .= qq|<br>|;
  $str .= "<small>(note: some writeups, such as [Everything Daylogs|day log]s and maintenance-related writeups,always default to a hidden creation)</small><br>";

  $str .= htmlcode("varcheckbox","nullvote","Show null vote button");
  $str .= qq|<br><small>Some old browsers needed at least one radio-button to be selected</small></fieldset>|;

  $str .= qq|<h2>Unsupported options</h2>|;
  $str .= qq|<fieldset><legend>Experimental/In development</legend>|;
  $str .= qq|<p><small>The time zone and other settings here do not currently affect the display of all times on the site.</small><br>|;

  $str .= htmlcode("varcheckbox","localTimeUse","Use my time zone offset");

  #daylight saving time messes things up; cheap way is to have a separate checkbox for daylight saving time
  my %specialNames = (
    '-12:00'=>'International date line West',
    '-11:00'=>'Samoa',
    '-10:00'=>'Hawaii',
    '-9:00'=>'Alaska',
    '-8:00'=>'Pacific (Los Angeles/Vancouver)/Baja California',
    '-7:00'=>'Mountain (Calgary/Denver/Salt Lake City)/Chihuahua/La Paz',
    '-6:00'=>'Central (Winnipeg/Chicago/New Orleans)/Central America',
    '-5:00'=>'Eastern (New York City/Atlanta/Miami)/Bogota/Lima/Quito',
    '-4:30'=>'Caracas',
    '-4:00'=>'Atlantic (Halifax)/Asuncion/Santiago/Georgetown/San Juan',
    '-3:30'=>'Newfoundland',
    '-3:00'=>'Greenland/Rio de Janeiro/Brasilia/Buenos Aires/Montevideo',
    '-1:00'=>'Azores/Cabo Verde',
    '0:00'=>'UTC server time (Lisbon/London/Dublin/Reykjavik/Monrovia)',
    '1:00'=>'Central Europe (Madrid/Amsterdam/Paris/Berlin/Prague)',
    '2:00'=>'Eastern Europe/Jerusalem/Istanbul/Cairo/Cape Town',
    '3:00'=>'Moscow/Baghdad/Nairobi',
    '3:30'=>'Tehran',
    '4:00'=>'Caucasus (Tblisi/Yerevan/Baku)/Abu Dhabi/Port Louis',
    '4:30'=>'Kabul',
    '5:00'=>'Ekaterinburg/Islamabad/Tashkent',
    '5:30'=>'Chennai/Kolkata/Mumbai/Sri Jayawardenepura',
    '6:00'=>'Astana/Dhaka/Novosibirsk',
    '6:30'=>'Yangoon (Rangoon)',
    '7:00'=>'Bangkok/Hanoi/Jakarta/Krasnoyarsk',
    '8:00'=>'Beijing/Hong Kong/Singapore/Urumqi/Irkutsk/Perth/Ulaanbataar',
    '9:00'=>'Tokyo/Seoul/Yakutsk',
    '9:30'=>'Adelaide/Darwin',
    '10:00'=>'Guam/Sydney/Melbourne/Brisbane/Vladivostok',
    '11:00'=>'Magadan/Solomon Islands/New Caledonia',
    '12:00'=>'Auckland/Wellington/Fiji',
    '13:00'=>'Nuku\'alofa',
  );

  my $params='';
  my $t= -43200; # 12 * 3600: time() uses seconds
  my $minutes = '00';
  my $plus ;
  for(my $hours=-12;$hours<=13;++$hours)
  {
    my $n = ( $hours % 12 ? 2 : ( $hours ? 1 : 3 ) );
    $plus = '-' unless $hours ;
    for (my $i=$n; $i ; $i--)
    {
      my $zone = "$hours:$minutes" ;
      $params .= ",$t,$plus$zone".($specialNames{$zone} ? " - $specialNames{$zone}" :'');
      $minutes = $minutes eq '00' ? '30' : '00' ;
      $t += 1800 ;
      $plus = '+' unless $hours ;
    }
  }
  $params =~ s/\b(\d):/0$1:/g ;
  #Y2k bug:
  #	60*60*24*365*100=3153600000=100 years ago, 365 days/year
  #	60*60*24*25=2160000=25 extra leap days; adjustment to 26: Feb 29, 2004
  #week in future:
  #	60*60*24*7=604800=week

  $params=',-3155760000,Y2k bug'.$params.',604800,I live for the future';

  $str .= htmlcode('varsComboBox', 'localTimeOffset,0'.$params);
  $str .= qq|<br>|;

  $str .= htmlcode("varcheckbox","localTimeDST","I am currently in daylight saving time");
  $str .= qq|(so add an an hour to my normal offset)<br>|;

  $str .= htmlcode("varcheckbox","localTime12hr","I am from a backwards country that uses a 12 hour clock");
  $str .= qq|(show AM/PM instead of 24-hour format)|;

  $str .= qq|</p></fieldset>|;

  $str .= htmlcode("closeform");
  return $str;
}

sub alphabetizer
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>Go ahead -- one entry per line:</p>|;
  $str .= htmlcode("openform");

  $str .= qq|<p><!-- N-Wing added options 2005-12-12 -->|;

  $str .= qq|separator: |;
  $str .= htmlcode("varsComboBox","alphabetizer_sep",0,0,"none (default)",1,"<br>",2,"<li> (use in UL or OL)");
  $str .= qq|<br />|;

  $str .= qq|sort: |;
  $str .= htmlcode("varcheckbox","alphabetizer_sortorder","reverse");
  $str .= htmlcode("varcheckboxinverse","alphabetizer_case","ignore case (default yes)");
  $str .= qq|<br />|;

  $str .= htmlcode("varcheckbox","alphabetizer_format","make everything an E2 link");

  $str .= qq|</p><p>|;

  $str .= $query->textarea('alpha', '', 20,60);
  $str .= qq|</p>|;

  $str .= htmlcode("closeform");

  my $list = $query->param('alpha');
  return $str unless $list;

  my $outputstr = '';
  my $leOpen = '';
  my $leClose = '';
  my $s = $VARS->{'alphabetizer_sep'};
  if($s==1)
  {
    $leClose = '&lt;br&gt;'
  } elsif($s==2) {
    $leOpen = '&lt;li&gt;';
    $leClose = '&lt;/li&gt;';
  } else {
    #no formatting
  }

  my @entries = split "\n", $list;

  foreach(@entries)
  {
    s/^\s*(.*?)\s*$/$1/;

    # Put articles at the end so they don't screw up
    # the sort.
    $_ =~ s/^(An?) (.*)$/$2, $1/i;
    $_ =~ s/^(The) (.*)$/$2, $1/i;
  }

  if($VARS->{'alphabetizer_case'})
  {
    @entries = sort @entries;
  } else {
    @entries = sort {lc($a) cmp lc($b)} @entries;
  }

  @entries = reverse @entries if $VARS->{'alphabetizer_sortorder'};

  foreach(@entries)
  {
    next unless length($_);
    $_ =~ s/^(.*), (An?)/$2 $1/i;
    $_ =~ s/^(.*), (The)/$2 $1/i;

    if($VARS->{'alphabetizer_format'})
    {
      #put brackets around the string.
      $_ = '['.$_.']';
    }
  }

  foreach (@entries)
  {
    next unless length($_);

    $outputstr .= $leOpen . encodeHTML($_,1) . $leClose . "\n";
  }

  return qq|$str<pre>$outputstr</pre></p>|;
}

sub ask_everything__do_i_have_the_swine_flu_
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>You walk up to the Everything Oracle, insert your coin, and ask the question that's most on your mind: DO I HAVE [SWINE FLU]???</p>|;
  $str .= qq|<br>The answer instantly flashes on the screen:<br><br><p align=center>|;

  my @flu = (
    "No.",
    "Yes.",
    "Maybe.",
    "I'm afraid that is classified information.",
    "Does your mother know you're here?",
    "Who wants to know?",
    "No.",
    "Please try again.",
    "I could tell you but then I'd have to kill you. If the Swine Flu doesn't do it first.",
    "No. You're probably Jewish and not allowed to have Swine Flu.",
    "You... INSERT ANOTHER COIN",
    "No. But for aboot tree-fiddy I get you some.",
    "Would you rather have the answer that's behind door number three?",
    "Not yet",
    "No. You don't deserve it.",
    "Yes. You've earned it.",
    "Hast thou eaten of the tree, whereof I commanded thee that thou shouldest not eat? Damn right you have the Swine Flu!",
    "I'm sorry, Dave. I cannot allow this.",
    "Yes. You got it from kissing Al Gore.",
    "Yes. You got it from kissing Janet Reno.",
    "Yes. A tall, dark stranger gave it to you.",
    "Yes. It's part of an evil plot by the E2 gods.",
    "No.",
    "Why does it always have to be about you?",
    "No. Nice shoes!",
    "Yes. And the horse you rode in on",
    "No. You have Avian Flu. Get a clue and know the difference!",
    "No. Your biology is too alien to be infected.",
    "No. You may be a swine but you're not that kind of swine.",
    "No. Just no.",
    "No. Have you made your will yet?",
    "No. But, if you ask nicely, you can have mine.",
    "What, you didn't get yours yet? Here, have some.",
    "You sick puppy, you...",
    "Who's asking? Oh, it's you, ignorant as usual.",
    "I'm not sure. Let's play doctor and find out.",
    "What do you mean, SWINE FLU? Omigod, you were with that floozy again!! What did you catch this time? That's it! I'm taking the kids and am going to my mother's!",
    "Yes. No. Yes. No. Oh, whatever.",
    "Yes. YES. <b>OH GOD YES!</b>",
    "Maybe. What's in it for me?",
    "I know but I'm not telling.",
    "ACCESS DENIED",
    "Do I look like a doctor?",
    "My sources say no",
    "Outlook not so good",
    "Signs point to yes",
    "I see dead people.",
    "Wouldn't you like to know?",
    "No. Swine Flu is not an STD.",
    "No. I'd do something about that rash, though.",
    "No. You're not smart enough to get it.",
    "No.",
    "Yes. Now go away.",
    "42",
    "YES. OH YES! Thank you so much for asking!",
    "Whaddaya mean, do you have Swine Flu? If you don't know, who does?",
    "What do I care if you have Swine Flu?",
    "GUARDS!!!",
    "No.",
    "Yes. No. What was the question again?",
    "No. Can I have your stuff when you die?",
    "GET AWAY FROM ME!!!"
  );

  $str .= "<b><font size='+1'>".$flu[int(rand(@flu))]."</font></b>";
  $str .= qq|</p>|;
  return $str;
}

sub available_rooms
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @stuff = ("Yeah, yeah, get a room...", "I'll take door number three...", "Hey, that's a llama back there!", "Three doors, down, on your right, just past [Political Asylum]", "They can't ALL be locked!?", "Why be so stuffed up in a room? [Go outside]!");

  my $str ="<p align=\"center\">".($stuff[rand(@stuff)])."</p><br><br>"."<p align=\"right\">..or you could ".linkNode(getNode("go outside", "superdocnolinks"))."</p><br><br>";

  my $csr = $DB->sqlSelectMany("node_id, title", "node", "type_nodetype=".getId(getType("room")));

  my $rooms = {};

  while(my $ROW = $csr->fetchrow_hashref())
  {
    $$rooms{lc($$ROW{title})} = $$ROW{node_id};
  }

  $str.="<ul>";

  foreach(sort(keys %$rooms))
  {
    $str.="<li>".linkNode(getNodeById($$rooms{$_}));
  }

  $str.="</ul>";
  return $str;
}

sub bad_spellings_listing
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>If you have the option enabled to show <strong>common bad spellings</strong> in your writeups, common bad spellings will be flagged and displayed you are looking at your writeup by itself (as opposed to the e2node, which may contain other noders' writeups).</p>|;
  $str .= qq|<p>This option can be toggled at [Settings[Superdoc]] in the Writeup Hints section. You currently have it |;
  $str .= $VARS->{nohintSpelling} ? 'disabled, which is not recommended' : 'enabled, the recommended setting';
  $str .= qq|</p><p>|;

  my $spellInfo = getNode('bad spellings en-US','setting');
  return $str.'<strong>Error</strong>: unable to get spelling setting.' unless defined $spellInfo;

  my $isRoot = $APP->isAdmin($USER);
  my $isCE = $APP->isEditor($USER);
  if($isRoot)
  {
    $str .= '<p>(Site administrators can edit this setting at '.linkNode($spellInfo,0,{lastnode_id=>0}).'.)</p><p>
';
  }

  $spellInfo = getVars($spellInfo);
  return $str.'<strong>Error</strong>: unable to get spelling information.' unless defined $spellInfo;

  #table header
  $str .= qq|Spelling errors and corrections:<table border="1" cellpadding="2" cellspacing="0"><tr><th>invalid</th><th>correction</th></tr>|;

  #table body - wrong spellings to correct spellings
  my $s="";
  my $numShown = 0;
  foreach(sort(keys(%$spellInfo)))
  {
    next if substr($_,0,1) eq '_';
    next if $_ eq 'nwing';
    ++$numShown;
    $s = $_;
    $s =~ tr/_/ /;
    $str .= '<tr><td>'.$s.'</td><td>'.$$spellInfo{$_}.'</td></tr>';
  }

  #table footer
  $str .= '</table>';

  $str .= '('.$numShown.' entries';
  $str .= ' shown, '.scalar(keys(%$spellInfo)).' total' if $isCE;
  $str .= ')';

  $str .= qq|</p>|;
  return $str;
}

sub bestow_easter_eggs
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  return 'Who do you think you are? The Easter Bunny?' unless $APP->isAdmin($USER);

  my @params = $query->param;
  my $str = '';

  my (@users, @thenodes);
  foreach (@params)
  {
    if(/^eggUser(\d+)$/)
    {
      $users[$1] = $query->param($_);
    }
  }

  for(my $count=0; $count < @users; $count++)
  {
    next unless $users[$count];

    my ($U) = getNode ($users[$count], 'user');
    if (not $U)
    {
      $str.="couldn't find user $users[$count]<br />";
      next;
    }

    # Send an automated notification.
    my $failMessage = htmlcode('sendPrivateMessage',{
      'recipient_id'=>getId($U),
      'message'=>'Far out! Somebody has given you an [easter egg].',
      'author'=>'Cool Man Eddie',
      });

    $str .= "User $$U{title} was given one easter egg";
  
    my $v = getVars($U);
    if (!exists($$v{easter_eggs}))
    {
      $$v{easter_eggs} = 1;
    } else {
      $$v{easter_eggs} += 1;
    }
   
    setVars($U, $v);
    $str .= "<br />\n";
  }

  # Build the table rows for inputting user names
  my $count = 5;
  $str.=htmlcode('openform');
  $str.='<table border="1">';
  $str.="\t<tr><th>Egg these users</th></tr> ";

  for (my $i = 0; $i < $count; $i++)
  {
    $query->param("eggUser$i", '');
    $str.="\n\t<tr><td>";
    $str.=$query->textfield("eggUser$i", '', 40, 80);
    $str.="</td>";
  }

  $str.='</table>';

  $str.=htmlcode('closeform');

  if ($query->param("Give yourself an egg you greedy bastard"))
  {
    if (!exists($$VARS{easter_eggs}))
    {
      $$VARS{easter_eggs} = 1;
    } else {
      $$VARS{easter_eggs} += 1;
    }
  }

  $str.=htmlcode('openform');
  $str.=$query->submit('Give yourself an egg you greedy bastard');
  $str.=$query->end_form;

  return $str;
}

sub between_the_cracks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $isGuest = $APP->isGuest($USER);
  return "<p>Undifferentiated from the masses of the streets, you fall between the cracks yourself.</p>" if $isGuest;

  my $rowCtr = 0;

  my ($title, $queryText, $rows);
  my $count = 1000;
  my $maxVotes = int($query->param("mv"));
  my ($minRep, $repRestriction, $repStr) = (undef, '', '');
  my $resultCtr = 50;

  if ($maxVotes <= 0)
  {
    $maxVotes = 5;
  }

  if (defined $query->param("mr") && $query->param("mr") ne "")
  {
    $minRep = int($query->param("mr"));
    if ($minRep > 5 || abs($minRep) > ($maxVotes - 2))
    {
      $minRep = undef;
    }
  
    if (defined $minRep)
    {
      $repRestriction = "AND reputation >= $minRep";
      $repStr = " and a reputation of $minRep or greater";
    }
  }

  my $str = qq|<p>These nodes have fallen between the cracks, and seem to have gone unnoticed. This page lists <em>up to</em> $resultCtr writeups that you haven't voted on that have fewer than $maxVotes total vote(s)$repStr on E2. Since they have been neglected until now, why don\'t you visit them and click that vote button?</p>|;
  $str .= qq|<form method="get"><div>|;
  $str .= qq|<input type="hidden" name="node_id" value="|.getId($NODE).qq|" />|;
  $str .= qq|<b>Display writeups with |;

  my @mvChoices = ();

  for(my $i=1;$i<=10;$i++)
  {
    push @mvChoices, $i
  }

  $str .= $query->popup_menu('mv', \@mvChoices, $maxVotes);
  $str .= ' (or fewer) votes and ';

  my %mrLabels = ();
  my @mrValues = ();

  for(my $i=-3;$i<=3;$i++)
  {
    $mrLabels{$i} = $i;
    push @mrValues, $i;
  }

  $mrLabels{''} = 'no restriction';
  push @mrValues, '';

  $str .= $query->popup_menu(-name => 'mr',
    -labels => \%mrLabels,
    -default => $minRep,
    -values => \@mrValues);

  $str .= ' (or greater) rep.';

  $str .= qq|</b><input type="submit" value="Go" /></div></form>|;
  $str .= qq|<table width="100%"><tr><th>#</th><th>Writeup</th><th>Author</th>|;
  $str .= qq|<th>Total Votes</th><th>Create Time</th></tr>|;

  $queryText = qq|SELECT title, author_user, createtime, writeup_id, totalvotes
    FROM writeup
    JOIN node
      ON writeup.writeup_id = node.node_id
    LEFT OUTER JOIN vote
      ON vote.vote_id = node.node_id AND vote.voter_user = $$USER{user_id}
    WHERE
      node.totalvotes <= $maxVotes
      $repRestriction
      AND node.author_user <> $$USER{user_id}
      AND vote.voter_user IS NULL
      AND wrtype_writeuptype <> 177599
    ORDER BY writeup.writeup_id
    LIMIT $count|;

  $rows = $DB->{dbh}->prepare($queryText);
  $rows->execute() or return $rows->errstr;

  while(my $wu = $rows->fetchrow_hashref)
  {
    $title = $$wu{title};
    if($title =~ /^(.*?) \([\w-]+\)$/) { $title = $1; }
    $title =~ s/\s/_/g;

    if ( !$APP->isUnvotable($$wu{writeup_id}) )
    {
      $rowCtr++;
      if ($rowCtr % 2 == 0)
      {
        $str .= '<tr class="evenrow">';
      }else{
        $str .= '<tr class="oddrow">';
      }
      $str .= '<td style="text-align:center;padding:0 5px">'.$rowCtr.'</td>
         <td>'.linkNode($$wu{writeup_id}, '', {lastnode_id=>0}).'</td>
         <td>'.linkNode($$wu{author_user}, '', {lastnode_id=>0}).'</td>
         <td style="text-align:center">'.$$wu{totalvotes}.'</td>
         <td style="text-align:right">'.$$wu{createtime}.'</td>
         </tr>';
    }
    last if ($rowCtr >= $resultCtr);
  }

  if ($rowCtr == 0)
  {
    $str .= '<tr><td colspan="3"><em>You have voted on all '.$count.' writeups with the lowest number of votes.</em></td></tr>';
  }

  $str .= '</table><p style="text-align:right">Bugs to [in10se]</p>';

  return $str;
}

sub blind_voting_booth
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $poweruser = $APP->isEditor($USER);

  my $wu = undef;
  my $hasvoted = 0;

  my $str = 'Welcome to the blind voting booth.  You can give anonymous feedback without knowing who wrote a writeup here, if you so choose.<br><br>';


  if(!($query->param('op') eq 'vote'))
  {
    return qq|You're done for today| if($$USER{votesleft} == 0);

    my $wucount = 0;
    while(!$wu && $wucount < 30)
    {
 
      my $limit = $DB->sqlSelect("max(writeup_id)", "writeup");
      my $min = $DB->sqlSelect("min(writeup_id)", "writeup");
      my $rnd = int(rand($limit-$min));

      $rnd+= $min;

      my $maybewu = $DB->sqlSelect("writeup_id", "writeup", "writeup_id=$rnd");

  
      if($maybewu)
      {
        my $tempref = getNodeById($maybewu);

        if($$tempref{wrtype_writeuptype} != 177599  && $$tempref{author_user} != $$USER{user_id})
        {
          $wu = $maybewu if(!$APP->hasVoted($tempref, $USER));
        }
      }

      $wucount++;
    }

  } else {
    my $wutemp = getNodeById($query->param('votedon'));

    return linkNode($NODE, 'Try Again') unless($wutemp);
    return linkNode($NODE, 'Try Again') if(!$APP->hasVoted($wutemp, $USER));

    $wu = $query->param('votedon');
    $hasvoted = 1;

  }

  my $rndnode = getNodeById($wu);
  my $nodeauthor = getNodeById($$rndnode{author_user});

  $str.=htmlcode('votehead');
  $str.='(<b>'.$$rndnode{title}.'</b>) by ';
  if($hasvoted == 1)
  {
    $str.=linkNode(getNode($$nodeauthor{title}, 'user'), $$nodeauthor{title}).' - ('.linkNode(getNodeById($$rndnode{parent_e2node}), 'full node').')';
  } else {
    $str.='? - ('.linkNode(getNodeById($$rndnode{parent_e2node}), 'full node').')';
  }
  
  $str.='<br>';

  if($hasvoted == 0)
  {
    $str.='<input type="hidden" name="votedon" value="'.$$rndnode{node_id}.'"><input type="radio" name="vote__'.$$rndnode{node_id}.'" value="1"> +<input type="radio" name="vote__'.$$rndnode{node_id}.'" value="-1"> - '.linkNode($NODE, 'pass on this writeup', {garbage=>int(rand(100000))});
  } else {
    $str.='Reputation: '.$$rndnode{reputation};
  }

  $str.='<br><hr><br>';
  $str.=$$rndnode{doctext};

  if($hasvoted == 0)
  {
    $str.='<table border="0" width="100%"><tr><td align="left"><INPUT TYPE="submit" NAME="sexisgreat" VALUE="vote!"></td>';
    if($poweruser)
    {
      $str.= '<td align="right"><INPUT TYPE="submit" NAME="node" VALUE="the killing floor II"></td>';
    }
    
    $str.='</tr></table></form>';
  }

  $str.= '<br><br><hr><br>'.linkNode($NODE, 'Another writeup, please') if($hasvoted && $$USER{votesleft} != 0);

  return $str;
}

sub bounty_hunters_wanted
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<style type="text/css"> .mytable th, .mytable td {border: 1px solid silver;padding: 3px;}</style>|;

  $str .= qq|<p align=center><b>[Everything's Most Wanted] is now automated</b></p>|;

  $str .= "<p>Okay, so [mauler|I] just finished fully automating the [Everything's Most Wanted] feature so that noders can manage bounties they have posted by themselves without having to go through the tedious process of messaging an admin several times. Hopefully this feature should be a lot more useful now. [Everything's Most Wanted|Check it out!]</p>";

  $str .= "<p>The five most recently requested nodes are automatically listed below. If you fill one of these, please message the requesting noder to claim your prize. Please see [Everything's Most Wanted|the main list] for full details on conditions and rewards.</p>";

  $str .= qq|<p>&nbsp;</p>|;

  $str .= qq|<table>|;

  $str.="<p><table class='mytable' align=center><tr><th>Requesting Sheriff</th><th>Outlaw Nodeshell</th><th>GP Reward (if any)</th></tr>";

  my $REQ = getVars(getNode('bounty order','setting'));
  my $OUT = getVars(getNode('outlaws', 'setting'));
  my $REW = getVars(getNode('bounties', 'setting'));
  my $HIGH = getVars(getNode('bounty number', 'setting'));
  my $MAX = 5;

  my $bountyTot = $$HIGH{1};
  my $numberShown = 0;
  my $outlawStr = "";
  my $requester = undef;
  my $reward = undef;

  for(my $i = $bountyTot; $numberShown < $MAX; $i--)
  {

    if (exists $$REQ{$i})
    {
      $numberShown++;
      $requester = $$REQ{$i};
      $outlawStr = $$OUT{$requester};
      $reward = $$REW{$requester};
      $str.="<tr><TD>[$requester]</TD><TD>$outlawStr</TD><TD>$reward</TD></tr>";
    }
  }

  $str .= "</table><p align=center>([Everything's Most Wanted|see full list])</p><p>&nbsp;</p>";

  return $str;
}

sub buffalo_generator
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @verbNouns=('Buffalo', 'buffalo', 'police', 'bream', 'perch', 'char', 'people', 'dice', 'cod', 'smelt', 'pants');
  my @intermediatePunctuation=(',', ';', ',', ':', '...');
  my @finalPunctuation=('.', '!', '?');

  my $str='';
  my $sentence='';

  @verbNouns=('buffalo') if ($query->param('onlybuffalo'));

  while (1)
  {
    $sentence='';
    while (1)
    {
      $sentence.=$verbNouns[int(rand(@verbNouns))];
      last if(rand(1)<0.1);
      $sentence.=$intermediatePunctuation[int(rand(@intermediatePunctuation))] if (rand(1)<0.25);
      $sentence.=" ";
    }
    $sentence=ucfirst($sentence);
    $sentence.=$finalPunctuation[int(rand(@finalPunctuation))].' ';
    $str.=$sentence;
    last if(rand(1)<0.4);
  }

  $str.="<ul>\n\t<li>".linkNode($NODE, "MOAR", {moar => 'more'})."</li>\n";
  $str.="\n\t<li>".linkNode($NODE, "Only buffalo", {onlybuffalo => 'true'})."</li>\n";
  $str.="\n\t<li>".linkNodeTitle("Buffalo Haiku Generator|In haiku form")."</li>\n";
  $str.="\n\t<li>".linkNodeTitle("Buffalo buffalo Buffalo buffalo buffalo buffalo Buffalo buffalo|...what?")."</li></ul>\n";

  return $str;

}

sub buffalo_haiku_generator
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @verbNouns=('Buffalo', 'buffalo', 'police', 'people', 'bream', 'perch', 'char', 'dice', 'cod', 'smelt', 'pants');
  my @wordLength=(3,3,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1);
  my @intermediatePunctuation=(',', ';', ',', ':', '...');
  my @finalPunctuation=('.', '!', '?');
  my @lineLength=(5,7,5); 
  my $str='';
  my $sentence='';

  @verbNouns=('buffalo') if ($query->param('onlybuffalo'));

  $sentence='<p style="text-align:center">';
  for (my $i=0; $i<3; $i++)
  {
    my $syllables=0;
    while ($syllables<$lineLength[$i])
    {
      my $wordNumber=(rand(@verbNouns));
      if ($syllables+$wordLength[$wordNumber]>$lineLength[$i])
      {
        $wordNumber=(4+rand(@verbNouns-4)); # Pick a one-syllable word.
      }
      $syllables+=$wordLength[$wordNumber];
      $sentence.=$verbNouns[$wordNumber];
      $sentence.=$intermediatePunctuation[int(rand(@intermediatePunctuation))] if (rand(1)<0.1);
      $sentence.=" ";
    }
    $sentence.="<br />";    
  }
  $sentence=ucfirst($sentence);
  $str.=$sentence."</p>";


  $str.="<ul>\n\t<li>".linkNode($NODE, "Furthermore!", {moar => 'further'})."</li>\n";
  $str.="\t<li>".linkNodeTitle("Buffalo Generator|More buffalo, less haiku")."</li>\n";
  $str.="\t<li>".linkNodeTitle("Buffalo buffalo Buffalo buffalo buffalo buffalo Buffalo buffalo")."</li></ul>\n";

  return $str;
}

sub chatterlighter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $nlid = getNode( 'Notifications' , 'nodelet' ) -> { node_id } ;
  $PAGELOAD->{ pagenodelets } = "$nlid," if $$VARS{ nodelets } =~ /\b$nlid\b/ ;
  $PAGELOAD->{ pagenodelets } .= getNode( 'New Writeups' , 'nodelet' ) -> { node_id } ;

  my $str = insertNodelet( getNode( 'Chatterbox', 'nodelet' ) );
  $str .= qq|<span class="instant ajax chatterlight_rooms:updateNodelet:Other+Users"></span>|;
  $str .= qq|<div id="chatterlight_rooms">|;
  $str .= qq|<p><span title="What chatroom you are in">Now talking in: |;
  $str .= linkNode($$USER{in_room}) || "outside";
  $str .= qq|</span> |;
  $str .= htmlcode("changeroom");
  $str .= qq|</div>|;

  return $str;
}

sub clientdev_home
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $str = qq|<h2>Registered Clients</h2>|;
  $str .= qq|<p>|;
  $str .= "(See [clientdev: Registering a client|here] for more information as to what this is about)<br />";
  $str .= qq|<table border="1" cellpadding="1" cellspacing="0">|;
  $str .= qq|<tr><th>title</th><th>version</th></tr>|;

  my @clientdoc = $DB->getNodeWhere ({}, 'e2client', 'title');
  my $v = undef;

  foreach (@clientdoc)
  {
    $v = $_->{'version'};
    $str .=
    '<tr><td>' . linkNode($_) . '</td><td>' .((defined $v) && length($v) ? encodeHTML($v,1) : ''). '<td></tr>';
  }

  $str .= '</table>';

  if($DB->isApproved($USER, $NODE))
  {
    $str.=htmlcode('openform');
    $str.="<input type=\"hidden\" name=\"op\" value=\"new\">\n";
    $str.="<input type=\"hidden\" name=\"type\" value=\"e2client\">\n";
    $str.="<input type=\"hidden\" name=\"displaytype\" value=\"edit\">\n";
    $str.='<h2>Register your client:</h2>';
    $str.=$query->textfield('node', '', 25);
    $str.=htmlcode('closeform');
  }

  $str .= qq|</p>|;

  $str .= qq|<p>Things to (eventually) come:</p>|;
  $str .= qq|<ol><li>make debates work for general groups</li>|;
  $str .= qq|<li>list of people, their programming language, the platform, and the project</li>|;
  $str .= qq|</ol>|;

  $str .= qq|<p>|;
  $str .= htmlcode("linkGroupMessages","N-Wing");
  $str .= qq|</p>|;

  $str .= qq|<p><hr /></p>|;

  my $cd = getNode("clientdev","usergroup");
  if($DB->isApproved($USER, $cd))
  {
    $str .= "<p>\n".htmlcode('weblog',"5,$cd->{node_id}")."\n<p>";
  }

  return $str;
}

sub confirm_password
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $token = $query->param('token');
  my $action = $query->param('action');
  my $expiry = $query->param('expiry');
  my $username = $query->param('user');

  unless($token and $action and $username)
  {
    return qq|<p>To use this page, please click on or copy and paste the link from the email we sent you. </p>|.
      qq|<p>If we didn't send you an email, you don't need this page.</p>|;
  }
  
  return '<p>Invalid action.</p>' unless($action eq 'activate' || $action eq 'reset');

  my $user = getNode($username, 'user');

  if ($expiry && time() > $expiry)
  {
    # make sure unactivated account is gone in case they want to recreate it
    $DB->nukeNode($user, -1, 'no tombstone') if $action eq 'activate'
      && $user && !$user -> {lasttime} && $expiry =~ /$$user{passwd}/;

    return $query->p('This link has expired. But you can '
      .linkNode(getNode($action eq 'reset' ? 'Reset password' : 'Sign up', 'superdoc')
      , 'get a new one').'.');
  }

  return $query->p(
    'The account you are trying to activate does not exist. But you can '
    .linkNode(getNode('Sign up', 'superdoc') , 'create a new one').'.') unless $user;

  return "<p>We're sorry, but we don't accept new users from the IP address you
    used to create this account. Please get in touch with us if you think this
    is a mistake.</p>" if $action eq 'activate' && $user -> {acctlock};

  my $prompt = '';

  if ($query -> param('op') ne 'login')
  {
    # check for locked-user infection...
    my $newVars = getVars($user);
    if ($$newVars{infected})
    {
      # new user infects current user
      $$VARS{infected} = 1 unless $APP -> isGuest($USER);

    }elsif(htmlcode('checkInfected')){
      # current user infects new user
      $$newVars{infected} = 1;
      setVars($user, $newVars);
    }

    $action = 'validate' if $$newVars{infected};

    $prompt = "Please log in with your username and password to $action your account";

  }elsif($USER -> {title} ne $username || $$USER{salt} eq $query -> param('oldsalt')){
    $prompt = 'Password or link invalid. Please try again';
  }

  $query -> delete('passwd');

  return htmlcode('openform')
    .$query->fieldset({style => 'width: 25em; max-width: 100%; margin: 3em auto 0'},
      $query->legend('Log in')
      .$query -> p($prompt.':')
      .$query -> p({style => 'text-align: right'},
        $query -> label('Username:'
        .$query -> textfield(
          -name => 'user'
          , readonly => 'readonly'
          , size => 30
          , maxlength => 240))
          .'<br>'
        .$query -> label('Password:'
        .$query -> password_field('passwd', '', 30, 240))
        .'<br>'
        .$query->checkbox("expires", "", "+10y", 'stay logged in')
        .'<br>'
        .$query -> submit('sockItToMe', $action)
      )
    )
    .$query -> hidden('token')
    .$query -> hidden('action')
    .$query -> hidden('expiry')
    .$query -> hidden('oldsalt', $$USER{salt})
    .$query -> hidden(-name => 'op', value => 'login', force => '1')
    .'</form>' if $prompt;

  return "<p>Password updated. You are logged in.</p>" if $action eq 'reset';

  # send welcome message
  htmlcode('sendPrivateMessage', {
    'author_id' => getId(getNode('Virgil','user')),
    'recipient_id' => $USER -> {node_id},
    'message' => "Welcome to E2! We hope you're enjoying the site. If you haven't already done so,
    We recommend reading both [E2 Quick Start] and [Links on Everything2] before you start writing anything. If you have any questions or need help, feel free to ask any editor (editors have a \$ next to their names in the Other Users list)" });

  return "<p>Your account has been activated and you have been logged in.</p>
    <p>Perhaps you'd like to edit " .linkNode($USER, 'your profile')
    .", or check out the logged-in users' <a href='/'>front page</a>,
    or maybe just read <a href='/?op=randomnode'>something at random</a>.";

}

sub cool_archive
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>Welcome to the Cool Archive page -- where you can see the entire|;
  $str .= qq|library of especially worthwhile content in the mess of Everything history.  Enjoy.|;
  $str .= qq|<small>(|;
  $str .= linkNode(getNode('Cool Archive Atom Feed','ticker'),'feed',{lastnode_id=>0});
  $str .= qq|)</small></p>|;

  $str .= qq|<p><strong>NB</strong>: sorting by something other than most recently or oldest C!ed requires entering a user.</p>|;

  $str .= htmlcode("openform");

  my $isEDev = $APP->isDeveloper($USER);
  my $orderby = $query->param('orderby');
  $orderby = "" if not defined($orderby);

  my $useraction = $query->param('useraction');
  $useraction ||= '';


  my %orderhash = (
    'tstamp DESC' => 'Most Recently Cooled',   # coolwriteups
    'tstamp ASC' => 'Oldest Cooled',           # coolwriteups
    'title ASC' => 'Title(needs user)',        # node
    'title DESC' => 'Title (Reverse)' ,        # node
    'reputation DESC, title ASC' => 'Highest Reputation', # writeup
    'reputation ASC, title ASC' => 'Lowest Reputation',   # writeup
    'cooled DESC, title ASC' => 'Most Cooled',            # writeups
  );

  my $offset = $query->param('place');
  $offset ||= 0;

  $orderby = '' unless exists $orderhash{$orderby};

  $orderby ||= 'tstamp DESC';

  my @ordervals = keys %orderhash;

  $str.='Order by: '.$query->popup_menu('orderby', \@ordervals, $orderby, \%orderhash);
  $str.= ' and ';
  my @actions = ('cooled', 'written');
  $str.=$query->popup_menu('useraction', \@actions);
  $str.=' by user: ';
  $str.= $query->textfield('cooluser', '', 15,30);


  $str.=htmlcode('closeform');

  my $user = $APP->htmlScreen(scalar $query->param('cooluser'));

  # Select 51 rows so that we know, if 51 come back, we can provide a "next" link
  #  even though we always display 50 at most
  my $pageSize = 50;
  my $limit    = $pageSize + 1;

  my ($csr, $wherestr, $coolQuery) = (undef, undef, undef);

  if($user)
  {
    my $U = getNode($user, 'user');
    return $str . "<br />Sorry, no '$user' is found on the system!" unless $U;

    if ($useraction eq 'cooled')
    {
      $coolQuery = qq|
        select node.*, writeup.*, cw.*
        from 
         (select * from coolwriteups where cooledby_user = ? ) cw
        inner join node
          on node.node_id = cw.coolwriteups_id
        inner join writeup
          on writeup.writeup_id = node.node_id
        order by $orderby
        limit ?
        offset ?|;

      $csr = $DB->{dbh}->prepare($coolQuery);
      $csr->execute(getId($U), $limit, $offset);

    } elsif ($useraction eq 'written') {

      $coolQuery = qq|
        select nd.*, writeup.*, coolwriteups.*
        from 
        (select * from node where author_user = ? ) nd 
        inner join coolwriteups
        on coolwriteups.coolwriteups_id = nd.node_id
        inner join writeup
        on writeup.writeup_id = nd.node_id
        where writeup.cooled != 0
        order by $orderby
        limit ?
        offset ?|;

        $csr = $DB->{dbh}->prepare($coolQuery);
        $csr->execute(getId($U), $limit, $offset);

    }

  } elsif($orderby =~ /^(title|reputation|cooled) (ASC|DESC)/) {

    return $str . '<br>To sort by title, reputation, or number of C!s, a user name must be supplied.';

  } else {

    # Ordered by tstamp
    # We can do sorting and limiting in sub-query because it contains our sort field

    # We use "bigLimit" instead of the default limit because it's possible for
    #  a bunch of cools to point to writeups which no longer exist.  This is our hacky way
    #  of making sure paging still works ($limit or more results are necessary to trigger
    #  the "next" link) without doing a huge join
    my $bigLimit = 10 * $limit;

    $coolQuery = qq|
      select node.*, writeup.*, cw.*
      from 
      (select * from coolwriteups order by $orderby limit ? offset ? ) cw
      inner join writeup
        on writeup.writeup_id = cw.coolwriteups_id
      inner join node
        on node.node_id = cw.coolwriteups_id|;

    $csr = $DB->{dbh}->prepare($coolQuery);
    $csr->execute($bigLimit, $offset);

  }
 
  return encodeHTML($coolQuery) unless $csr;

  $str.='<table width="100%" cellpadding="0" cellspacing="0">';
  $str.='<tr>';
  $str.='<th>Writeup</th><th>Written by</th><th>Cooled By</th></tr>';

  my $count = 0;

  my $rownum = 1;
  while(my $row = $csr->fetchrow_hashref)
  {
    $str .= $APP->cool_archive_row($row, ($rownum % 2));
    $rownum++;
  }

  $csr->finish;

  $str.='<tr><td>';
  $str.=linkNode($NODE, "<--last $pageSize", {orderby => $orderby, 
    cooluser => $user, 
    useraction => $useraction, 
    place => $offset - $pageSize})
  if $offset >= $pageSize;

  $str.='</td><td colspan="2" align="right">';
  $str.=linkNode($NODE, "next $pageSize-->", {orderby => $orderby,
    cooluser => $user, 
    useraction => $useraction, 
    place => $offset + $pageSize})
  if $count > $pageSize;

  $str.='</td></tr>';
  $str.='</table>';
  return $str;

}

sub create_a_registry
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  
  my $str = qq|<p>Registries are places where people can share snippets of information about themselves, like their [email address] or [favourite vegetables].</p>|;

  $str .= qq|<p>Before you create any new registries, you should have a look at [the registries] we already have.</p>|;

  $str .= htmlcode("openform");

  if($query->param('sexisgood'))
  {
    return $str;
  }

  if($APP->getLevel($USER) < 8)
  {
    return "You would need to be [The Everything2 Voting/Experience System|level 8] to create a registry." unless $APP->getLevel($USER);

  }

  my $labels = ['key','value'];
  my $rows = [
    {'key'=>'Title','value'=>
     '<input type="text" name="node" size="40" maxlength="255">
      <input type="hidden" name="op" value="new">
      <input type="hidden" name="type" value="registry">
      <input type="hidden" name="displaytype" value="display">'
    },
    {'key'=>'Description', 'value'=>
     '<textarea name="registry_doctext" rows="7" cols="50"></textarea>'
    },
    {'key'=>'Answer style', 'value'=>
     $query->popup_menu(-name=>'registry_input_style', -values=>['text','yes/no','date'])
    },
    {'key'=>' ','value'=>
     '<input type="submit" name="sexisgood" value="create">'}
  ];
  $str .= $APP->buildTable($labels,$rows,'nolabels');
  $str .= qq|</form>|;
  return $str;
}

sub create_category
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p><b><big>[Everything2 Help] &gt; [Everything2 Categories]</big></b></p>|;

  $str .= "<p>A [category] is a way to group a list of related nodes. You can create a category that only you can edit, a category that anyone can edit, or a category that can be maintained by any [Everything2 Usergroups|usergroup] you are a member of.</p>";

  $str .= qq|<p>The scope of categories is limitless. Some examples might include:</p>|;

  $str .= qq|<ul>|;
  $str .= qq|<li>$USER->{title}'s Favorite Movies</li>|;
  $str .= qq|<li>The Definitive Guide To Star Trek</li>|;
  $str .= qq|<li>Everything2 Memes</li>|;
  $str .= qq|<li>Funny Node Titles</li>|;
  $str .= qq|<li>The Best Books of All Time</li>|;
  $str .= qq|<li>Albums $USER->{title} Owns</li>|;
  $str .= qq|<li>Writeups About Love</li>|;
  $str .= qq|<li>Angsty Poetry</li>|;
  $str .= qq|<li>Human Diseases</li>|;
  $str .= qq|<li>... the list could go on and on</li>|;
  $str .= qq|</ul>|;

  $str .= "<p>Before you create your own category you might want to visit the [Display Categories|category display page] to see if you can contribute to an existing category.</p>";

  my $guestUser = $Everything::CONF->guest_user;
  #
  # Filter people out who can't create categories
  #
  if ( $APP->isGuest($USER) )
  {
    $str .= "You must be [login|logged in] to create a category.";
    return $str;
  }

  if ( $APP->getLevel($USER) <= 1 )
  {
     $str.='Note that until you are at least Level 2, you can only add your own writeups to categories.';
  }

  # this check may or may not be needed/wanted
  my $userlock = $DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$$USER{user_id}");
  if ($userlock)
  {
    return 'You are forbidden from creating categories.';
  }

  #
  # Output Form
  #

  $str .= $query->start_form;
  $query->param("node", "");
  $str .= '<p><b>Category Name:</b><br />';
  $str .= $query->textfield(-name => "node",
    -default => "",
    -size => 50,
    -maxlength => 255);
  $str .= '</p><p><b>Maintainer:</b><br />';

  # Get usergroups current user is a member of
  my $sql = "SELECT DISTINCT ug.node_id,ug.title 
    FROM node ug,nodegroup ng 
    WHERE ng.nodegroup_id=ug.node_id AND ng.node_id=$$USER{user_id} ORDER BY ug.title";
  my $ds = $DB->{dbh}->prepare($sql);
  $ds->execute() or return $ds->errstr;
  my $catType = getId(getType('category'));
  my @vals = ();
  my %txts = ();

  # current user
  $txts{$$USER{user_id}} = "Me ($$USER{title})";
  push @vals, $$USER{user_id};
  # guest user will be used for "Any Noder"
  $txts{$guestUser} = "Any Noder";
  push @vals, $guestUser;
  while(my $ug = $ds->fetchrow_hashref)
  { 
    $txts{$$ug{node_id}} = $$ug{title} . " (usergroup)";
     push @vals, $$ug{node_id};
  }

  $str .= $query->popup_menu("maintainer", \@vals, "", \%txts );

  my @customDimensions = htmlcode('customtextarea');

  # clear op which is set to "" on page load
  # also clear 'type' which may have been set to navigate to this page
  $query->delete('op', 'type');

  $str .= '</p>'
    . '<fieldset><legend>Category Description</legend>'
    . $query->textarea(
      -name => "category_doctext"
      , -id => "category_doctext"
      , -class => "formattable"
      , @customDimensions
    )
    . '</fieldset>'
    . $query->hidden(-name => "op", -value => "new")
    . $query->hidden(-name => "type", -value => $catType);

  $str .= $query->submit("createit", "Create It!");
  $str .= $query->end_form;

  return $str;
}

sub create_room
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $isChanop = $APP->isChanop($USER);

  if ($APP->getLevel($USER) < $Everything::CONF->create_room_level
    and not $DB->isGod($USER)
    and not $isChanop)
  {
    return "<I>Too young, my friend.</I>";
  }

  my $str = "";

  if ($APP->isSuspended($USER, 'room'))
  {
    return '<h2 class="warning">You\'ve been suspended from creating new rooms!</h2>';
  }

  $query->delete('op', 'type', 'node');
  $str.=$query->start_form;
  $str.=$query->hidden(-name => 'op', -value => 'new');
  $str.=$query->hidden(-name => 'type', -value => 'room');
  $str.='Room name: ';
  $str.=$query->textfield(-name => 'node', -size => 28, -maxlenght => 80);
  $str.="<P>And a few words of description: "
    .$query->textarea("room_doctext", "", 5, 60, "", "wrap=virtual");
  $str.=$query->submit("enter");
  $str.=$query->end_form;

  return $str;
}

sub database_lag_o_meter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>|;

  my %stats = ();
  my %vars = ();

  my $csr = $DB->{dbh}->prepare('show status');
  $csr->execute;

  while (my ($key, $val) = $csr->fetchrow)
  {
    $stats{$key} = $val;
  }

  $csr->finish;
  $csr = $DB->{dbh}->prepare('show variables');
  $csr->execute;
  while (my ($key, $val) = $csr->fetchrow)
  {
    $vars{$key} = $val;
  }

  $csr->finish;

  $stats{smq} = sprintf("%.2f", 1000000*$stats{Slow_queries}/$stats{Queries});
  my $time = $stats{Uptime};
  my ($d,$h,$m,$s) = (0, 0, 0, 0);

  $d += int($time / (60*60*24));
  $time -= $d * (60*60*24);
  $h += int($time / (60*60));
  $time -= $h * (60*60);
  $m += int($time / (60));
  $time -= $m * (60);
  $s += int($time);

  my $uptime = sprintf("%d+%02d:%02d:%02d", $d, $h, $m, $s);

  $str .= "Uptime: $uptime<br>Queries: ". $APP->commifyNumber($stats{Queries});
  $str .= "<br>Slow (>$vars{long_query_time} sec): ";
  $str .= $APP->commifyNumber($stats{Slow_queries});
  $str .= qq|<br>Slow/Million: $stats{smq}<br>|;

  $str .= qq|<p>Slow/Million Queries is a decent barometer of how much lag the Database is hitting.  Rising=bad, falling=good.|;
  return $str;
}

sub decloaker
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p><em>Or to drown my clothes, and say I was stripped.</em> --- [Parolles]</p>|;

  return qq|$str The Treaty of Algeron prohibits your presence.| if $APP->isGuest($USER);
  $APP->uncloak($USER, $VARS);
  $str .=  '...like a new-born babe....';

  return $str;
}

sub display_categories
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $canContributePublicCategory = ($APP->getLevel($USER) >= 1);
  my $guestUser = $Everything::CONF->guest_user;
  my $uid = $$USER{user_id};
  my $isCategory = 0;
  my $linktype = getId(getNode('category', 'linktype'));

  my $sql = '';
  my $ds = undef;
  my $str = '';
  my $ctr = 0;

  my $count = 50;
  my $page = int($query->param('p'));
  if ($page < 0)
  {
    $page = 0;
  }

  my $maintainerName = $query->param('m');
  $maintainerName =~ s/^\s+|\s+$//g;
  my $maintainer = undef;

  if (length($maintainerName) > 0)
  {
    $maintainer = getNode($maintainerName, 'user');
    if (!$$maintainer{node_id})
    {
      $maintainer = getNode($maintainerName, 'usergroup');
      if (!$$maintainer{node_id})
      {
        $maintainerName = '';
        $$maintainer{node_id} = 0;
      }
    }
  }

  my $userType = getId(getType('user'));
  my $usergroupType = getId(getType('usergroup'));
  my $categoryType = getId(getType('category'));

  my $order = $query->param('o');

  $str .= qq|<form method="get" action="/index.pl">|;
  $str .= qq|<input type="hidden" name="node_id" value="|.getId($NODE);
  $str .= qq|" />|;
  $str .= qq|<table><tr><td><b>Maintained By:</b></td><td>|;
  $str .= $query->textfield(-name => "m",
    -default => $maintainerName,
    -size => 25,
    -maxlength => 255);

  $str .= qq| (leave blank to list all categories)</td>|;
  $str .= qq|</tr><tr><td><b>Sort Order:</b></td><td>|;
  $str .= qq|<select name="o">|;
  $str .= qq|<option value="">Category Name</option>|;
  $str .= qq|<option value="m">Maintainer</option>|;
  $str .= qq|</select></td></tr></table>|;
  $str .= $query->submit("submit", "Submit");
  $str .= $query->end_form;

  my $contribute = "";
  $contribute = "<th>Can I Contribute?</th>" if !$APP->isGuest($USER);

  $str .= qq|<table width="100%"><tr>|;
  $str .= qq|<th>Category</th><th>Maintainer</th>$contribute</tr>|;

  my $orderBy = 'n.title,a.title';

  if ($order eq 'm')
  {
    $orderBy='a.title,n.title';
  }

  my $authorRestrict = "";
  $authorRestrict = "AND n.author_user = $$maintainer{node_id}\n" if ($$maintainer{node_id} > 0);

  my $startAt = $page * $count;

  $sql = "SELECT n.node_id, n.title, n.author_user
    , a.title AS maintainer
    , a.type_nodetype AS maintainerType
    FROM node n
    JOIN node a
    ON n.author_user = a.node_id
    WHERE n.type_nodetype = $categoryType
    $authorRestrict
    AND n.title NOT LIKE '%\_root'
    ORDER BY $orderBy
    LIMIT $startAt,$count";

  $ds = $DB->{dbh}->prepare($sql);
  $ds->execute() or return $ds->errstr;
  while(my $n = $ds->fetchrow_hashref)
  {
    my $maintName = $$n{maintainer};
    my $maintId = $$n{author_user};
    my $isPublicCategory = ($guestUser == $maintId);

    $ctr++;
    if($ctr % 2 == 0)
    {
      $str .= '<tr class="evenrow">';
    }else{
      $str .= '<tr class="oddrow">';
    }
    $str .= '<td>'.linkNode($$n{node_id}, $$n{title}).'</td>';

    my $authorLink = linkNode($$n{author_user}, $maintName);
    $authorLink = "Everyone" if $isPublicCategory;
    $authorLink .= ' (usergroup)' if ($$n{maintainerType} == $usergroupType);

    $str .= qq'<td style="text-align:center">$authorLink</td>\n';

    if (!$APP->isGuest($USER))
    {
      $str .= '<td style="text-align:center">';
      if (($isPublicCategory and $canContributePublicCategory) or ($maintId == $uid))
      {
        $str .= '<b>Yes!</b>';
      }elsif ($$n{maintainerType} == $usergroupType && $APP->inUsergroup($uid, $maintName)){
        $str .= '<b>Yes!</b>';
      }else{
        $str .= 'No';
      }
      $str .= "</td>\n"
    }
  
    $str .= '</tr>';
  }

  if ($ctr <= 0)
  {
    $str .= '<tr><td colspan="2"><em>No categories found!</em></td></tr>';
  }
  $str .= '</table>';

  $str .= '<p style="text-align:center">';
  if ($page > 0)
  {
    $str .= '<a href="/index.pl?node_id='.getId($NODE).'&p='.($page-1).'&m='.$maintainerName.'&o='.$order.'">&lt;&lt; Previous</a>';
  }

  $str .= ' | <b>Page '.($page+1).'</b> | ';
  if ($ctr >= $count)
  {
    $str .= '<a href="/index.pl?node_id='.getId($NODE).'&p='.($page+1).'&m='.$maintainerName.'&o='.$order.'">Next &gt;&gt;</a>';
  }
  $str .= '</p>';

  return $str;

}

sub do_you_c__what_i_c_
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<h4>What It Does</h4><ul>|;
  $str .= qq|<li>Picks up to 100 things you've cooled.</li>|;
  $str .= qq|<li>Finds everyone else who has cooled those things, too, then uses the top 20 of those (your "best friends.")</li>|;
  $str .= qq|<li>Finds the writeups that have been cooled by your "best friends" the most.</li>|;
  $str .= qq|<li>Shows you the top 10 from that list that you haven't voted on and have less than 10C!s.</li>|;

  $str .= qq|</ul>|;

  my $user = $query->param('cooluser');
  $str.=htmlcode('openform');
  $str.='<p>Or you can enter a user name to see what we think <em>they</em> would like:'.$query->textfield('cooluser', encodeHTML($user), 15,30);
  $str.=htmlcode('closeform').'</p>';


  my $user_id = $$USER{user_id};

  my $pronoun = 'You';
  if($user)
  {
    my $U = getNode($user, 'user');
    return $str . "<br />Sorry, no '" . encodeHTML($user) . "' is found on the system!" unless $U;
    $user_id=$$U{user_id};
    $pronoun='They';
  }

  my $numCools = 100;
  my $numFriends = 20;
  my $numWriteups = 10;
  my $maxCools = $query->param('maxcools') || 10;

  my $coolList = $DB->sqlSelectMany("coolwriteups_id","coolwriteups","cooledby_user=$user_id order by rand() limit $numCools");
  return $str."$pronoun haven't cooled anything yet. Sorry - you might like to try [The Recommender], which uses bookmarks, instead." unless $coolList->rows;

  my @coolStr = ();

  while (my $c = $coolList->fetchrow_hashref)
  {
    push (@coolStr, $$c{coolwriteups_id});
  }

  my $coolStr = join(',',@coolStr);

  my $userList = $DB->sqlSelectMany("count(cooledby_user) as ucount, cooledby_user","coolwriteups","coolwriteups_id in ($coolStr) and cooledby_user!=$user_id group by cooledby_user order by ucount desc limit $numFriends");

  return $str."$pronoun don't have any 'best friends' yet. Sorry." unless $userList->rows;


  my @userSet = ();

  while (my $u = $userList->fetchrow_hashref)
  {
    push (@userSet, $$u{cooledby_user});
  }

  my $userStr = join(',',@userSet);

  my $recSet = $DB->sqlSelectMany("count(coolwriteups_id) as coolcount, coolwriteups_id", "coolwriteups", "(select count(*) from coolwriteups as c1 where c1.coolwriteups_id = coolwriteups.coolwriteups_id and c1.cooledby_user=$user_id)=0 and (select author_user from node where node_id=coolwriteups_id)!=$user_id and cooledby_user in (".$userStr.") group by coolwriteups_id having coolcount>1 order by coolcount desc limit 300");

  my $count = undef;

  while (my $r = $recSet->fetchrow_hashref)
  {
    my $n = getNode($$r{coolwriteups_id});
    next unless $$n{type}{title} eq 'writeup';
    next if $APP->hasVoted($n, $USER);
    next if $$n{author_user} == 176726; ##Don't show Webby's writeups
    next if $$n{cooled} > $maxCools;
    next unless $n;
    $count++;
    $str .= linkNode($n)."<br />";
    last if ($count == $numWriteups);
  }

  return $str;

}

sub drafts
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $str = qq|<div id="pagebody">|;
  my $user = $query -> param('other_user');
  my $username = '';

  my $showhidenukedlink = undef;
  my $shownukedlinkparams = {};

  if ($user)
  {
    $shownukedlinkparams->{other_user} = $user;
    my $u = getNode($user, 'user');
    return '<div id="pagebody"><p>No user named "'.$query -> escapeHTML($user).'" found.</p></div>' unless $u;
    $user = $$u{node_id};
    # record displayed status:
    $username = $$u{title} unless $user == $$USER{node_id};
  }

  if($query->param("shownuked"))
  {
    $showhidenukedlink = linkNode($NODE, "Hide nuked", $shownukedlinkparams);
  }else{
    $shownukedlinkparams->{shownuked} = 1;
    $showhidenukedlink = linkNode($NODE, "Show nuked", $shownukedlinkparams);
  }

  $showhidenukedlink = "<strong>($showhidenukedlink)</strong>";



  $user ||= $$USER{node_id};
  $query -> delete('other_user') unless $username;

  my $status = {}; # plural of Latin 'status' is 'status'
  my ($ps, $cansee, $collaborators, $nukeeslast, $title, $showhide, $cs, $nukees) = ('','','','','','','','');
  my $draftType = getType('draft');

  my $nukedStatus = getNode("nuked", "publication_status");

  my $draftStatus = "publication_status != $$nukedStatus{node_id}";

  if($query->param("shownuked"))
  {
    $draftStatus = "publication_status = $$nukedStatus{node_id}";
  }

  my $statu = sub{
    $_[0]->{type} = $draftType;
    $ps = $_[0]->{publication_status};
    if ($$status{$ps})
    {
      $ps = $$status{$ps};
    }else{ # only look up each status once
      $ps = $ps ? $$status{$ps} = getNodeById($ps)->{title} : 'broken';
      $$status{$ps} = 1 unless $username; # to track if any of mine nuked
    }
    return qq'<td class="status">$ps</td>';
  };

  my @showit = (
    'title, author_user, publication_status, collaborators'
    , 'node JOIN draft ON node_id = draft_id'
    , "author_user = $user AND type_nodetype = $$draftType{node_id} AND $draftStatus"
    , 'ORDER BY title');

  unless ($username)
  {
    $title = 'Your drafts';
    $cs = '<th>Collaborators';
    $collaborators = sub{
      qq'<td class="collaborators">'.(defined($_[0]->{collaborators})?($_[0]->{collaborators}):('')).'</td>';
    };

    $showit[-1] = 'ORDER BY publication_status='
      .getId(getNode('nuked', 'publication_status'))
      .', title' if $nukeeslast;

    $showit[-1] .= ' LIMIT 25';
    unshift @showit, 'show paged content';

  }else{
    $title = "${username}'s drafts (visible to you)";
    $cansee = sub { 
      my $draft = shift; return $APP->canSeeDraft($USER, $draft, "find")
    };

    $cs = '<th title="shows whether you or a usergroup you are in is a collaborator on this draft">Collaborator?';
    $collaborators = sub{
      my $yes = '&nbsp;';
      if ($_[0]->{collaborators})
      {
        if ($_[0]->{collaborators} =~ qr/(?:^|,)\s*$$USER{title}\s*(?:$|,)/i)
        {
          $yes = 'you';
        }elsif ($ps = 'private' || $APP->canSeeDraft($USER, $_[0], 'edit') ){
          $yes = 'group';
        }
      }
      return qq'<td class="collaborators">$yes</td>';
    };

    @showit = ('show content', $DB -> sqlSelectMany(@showit));
  }

  my ($drafts, $navigation, $count) = htmlcode(
    @showit
    , '<tr class="&oddrow"> status, "<td>", title, "</td>", coll'
    , cansee => $cansee, status => $statu, coll => $collaborators);

  if ($drafts eq '')
  {
    if (!$username)
    {
      $str .= qq|<p>You have no drafts.</p>$showhidenukedlink|;
    } else {
      $str .= qq|<p>[${username}[user]] has no drafts visible to you.</p>$showhidenukedlink|;
    }
  }else{

    my $showcount = "";
    $showcount = "<p>You have $count drafts.</p>" if $navigation;

    my $outstr = "";
    $outstr = "<h2>$title</h2>$showhidenukedlink<br />
      $showcount
      <table><tr><th>status</th><th>title</th>$cs</th></tr>
      $drafts
      </table>
      $nukees
      $navigation<br />" if $drafts ne '';

    $str .= $outstr;
  }
  $str .= qq|</div>|; #pagebody
  $str .= htmlcode("openform","pagefooter");
  
  unless($query->param('other_user'))
  {
    $str .= htmlcode('editwriteup');
  }
  $str .= qq|</form>|;

  return $str;
}

sub drafts_for_review
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return 'Only [Sign Up|logged-in users] can see drafts.' if $APP->isGuest($USER);

  my $review = getId(getNode('review', 'publication_status'));
  my @noteResponse = ();
  @noteResponse = (
    ", (Select CONCAT(timestamp, ': ', notetext) From nodenote As response
    Where response.nodenote_nodeid = request.nodenote_nodeid
    And response.timestamp > request.timestamp
    Order By response.timestamp Desc Limit 1) as latestnote,
    (Select count(*) From nodenote As response
    Where response.nodenote_nodeid = request.nodenote_nodeid
    And response.timestamp > request.timestamp) as notecount"
    , "notecount > 0,"
    , '<th align="center" title="node notes">N?</th>'
    , 'notes') if $APP->isEditor($USER);

  my $drafts = $DB -> sqlSelectMany(
    "title, author_user, request.timestamp AS publishtime $noteResponse[0]"
    , "draft
    JOIN node on node_id = draft_id
    JOIN nodenote AS request ON draft_id = nodenote_nodeid
    AND request.noter_user = 0
    LEFT JOIN nodenote AS newer
      ON request.nodenote_nodeid = newer.nodenote_nodeid
      AND newer.noter_user = 0
      AND request.timestamp < newer.timestamp"
    , "publication_status = $review
    AND newer.timestamp IS NULL"
    , "ORDER BY $noteResponse[1] request.timestamp"
  );

  my %funx = (
    startline => sub{
      $_[0] -> {type}{title} = 'draft';
      '<td>';
    },
    notes => sub{
      $_[0]{latestnote} =~ s/\[user\]//;
      my $note = encodeHTML($_[0]{latestnote}, 'adv');
      '<td align="center">'
      .($_[0]{notecount} ? linkNode($_[0], $_[0]{notecount},
      {'#' => 'nodenotes', -title => "$_[0]{notecount} notes; latest $note"})
      : '&nbsp;')
      .'</td>';
    }
  );

  return "<table><tr><th>Draft</th><th>For review since</th>$noteResponse[2]</tr>"
    .htmlcode('show content', $drafts
    , qq!<tr class="&oddrow"> startline, title, byline, "</td>
    <td align='right'>", listdate, "</td>", $noteResponse[3]!,
    %funx).'</table>';
}

sub duplicates_found_
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $showTechStuff = 1;	#TODO maybe only show for @$% people later
  my $list = undef;
  my $author = '';
  my $lnode = $query->param('lastnode_id') || 0;
  my $UID = $$USER{node_id};
  my $oddrow = '';
  my $ONE = undef;

  #TODO - get fancy by also showing dates, if multiple of same type by same author
  foreach my $N (@{ $$NODE{group} })
  {
    $N = $DB->getNodeById($N, 'light');
    next unless canReadNode($USER, $N);
    $author = $$N{author_user};
    next if(($$N{type}{title} eq 'draft') and not $APP->canSeeDraft($USER, $N, 'find'));
    $ONE = $list ? undef : $N;
    $oddrow = ($oddrow ? '' : ' class="oddrow"');
    $list .= "<tr$oddrow>";
    if($showTechStuff)
    {
      $list .= '<td>'.$$N{node_id}.'</td>';
    }

    $list .= '<td>' . linkNode($N,'',{lastnode_id=>$lnode}) . '</td><td>' . $$N{type}{title}.'</td><td>';

    if($author)
    {
      $list .= '<strong>' if $author==$UID;
      $list .= linkNode($author,'',{lastnode_id=>0});
      $list .= '</strong>' if $author==$UID;
    }

    $list .= '<td>'.$$N{createtime}.'</td>';
    $list .= '</td></tr>';
  }

  unless ($list)
  {
    $NODE = $Everything::HTML::GNODE = getNodeById($Everything::CONF->not_found_node);
    return parseCode($$NODE{doctext});
  }elsif($ONE){
    $Everything::HTML::HEADER_PARAMS{-status} = 303;
    $Everything::HTML::HEADER_PARAMS{-location} = htmlcode('urlToNode', $ONE);
    return;
  }

  my $str = '<p><big>Multiple nodes named "'.$query->param('node').'" were found:</big></p><table><tr>';

  $str .= '<th>node_id</th>' if $showTechStuff;
  $str .= qq|<th>title</th><th>type</th><th>author</th><th>createtime</th></tr>|;
  $str .= $list; 
  $str .= qq|</table>|;

  $str .= qq|<p>On Everything2, different things can have the same title.|;
  $str .= qq| For example, a user could have the name "aardvark", but there could also be a page full of writeups called "[aardvark]".</p>|;
  $str .= qq|<p>If you are looking for information about a topic, choose |;
  $str .= qq|<strong>e2node</strong>; this is where people's writeups are shown.<br>|;
  $str .= qq|If you want to see a user's profile, pick <strong>user</strong>.<br>|;
  $str .= qq|Other types of page, such as <strong>superdoc</strong>, are special
and may be interactive or help keep the site running.</p>|;
  return $str;
}

sub e2_acceptable_use_policy
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return qq|<center><h1>Acceptable Use Policy</h1></center>

<hr />

<p>By using this website, you implicitly agree to the following condition(s):</p>

<ol>
<li>[Be cool]. Do not harass other users in any way (i.e., in the chatterbox, via /msg, in writeups, in the creation of nodeshells or in any other way). "Harassment" is defined as:
  <ul><li>Threatening (an)other user(s) in any way, and/or</li>
      <li>Creating additional accounts intended to annoy other users</li>
  </ul></li>
<li>Do not flood the chatterbox or the New Writeups list ("spamming").</li>
</ol>

<p>By willfully violating (at the discretion of the administration) any of the above condition(s), you may be subjected to the following actions:</p>

<ul>
<li>You may be forbidden from noding for as long as deemed necessary by the administration.</li>
<li>You may be forbidden from using the chatterbox for as long as deemed necessary by the administration.</li>
<li>Your account may be locked and made inaccessible.</li>
<li>Your IP address/hostname may be banned from accessing our webservers.</li>
<li>Depending on the severity of the violation(s), a complaint may be made to your internet service provider.</li>
</ul>

<p>Attempting to circumvent any disciplinary action <b>by any means</b> will most assuredly result in a complaint being made to your internet service provider.</p>

<p><small><small>Last revised: 23 April 2008</small></small></p>|;

}

sub e2_bouncer
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "Permission Denied" unless $APP->isChanop($USER);

  my $header ='<p>...a.k.a [Nerf] Borg.</p>';

  $header .= htmlcode('openform2','bouncer');

  my @stuff2 = (
    "Yeah, yeah, get a room...", 
    "I'll take door number three...", 
    "Hey, that's a llama back there!", 
    "Three doors, down, on your right, just past [Political Asylum]", 
    "They can't ALL be locked!?", 
    "Why be so stuffed up in a room? [Go outside]!"
    );

  # $roommenu gets put into the $table
  my $roommenu = '<select name="roomname"><option name="outside">outside</option>';
  # The rest of this builds the list of rooms for the bottom.
  my $str2 ="<hr><p align=\"center\">"
  . ($stuff2[rand(@stuff2)])
  . "</p><br>"
  . "<p align=\"left\">Visit room: </p>";

  my $csr2 = $DB->sqlSelectMany("node_id, title", "node", "type_nodetype=".getId(getType("room")));
  my $rooms2 = {};
  while (my $ROW2 = $csr2->fetchrow_hashref())
  {
    $$rooms2{lc($$ROW2{title})} = $$ROW2{node_id};
  }

  $str2.="<ul><li>[Go Outside|outside]</li>";
  foreach (sort(keys %$rooms2))
  { 
    my $nodehash = getNodeById($$rooms2{$_});
    $str2.="<li>".linkNode($nodehash); 
    $roommenu .= '<option name=' 
    . $nodehash->{'title'} 
    . '>'
    . $nodehash->{'title'}
    . '</option>';
  }

  $roommenu .= '</select>';
  $str2.="</ul>";

  my $table = qq|<table><tr><td valign="top" align="right" width="80"><p>Move user(s)</p>|;
  $table .= qq|<p><i>Put each username on its own line, and don\'t hardlink them.</i></p>|;
  $table .= qq|</td><td><textarea name="usernames" rows="20" cols="30">|;
  $table .= $query->param( 'usernames' );
  $table .= qq|</textarea></td></tr><tr>|;
  $table .= qq|<td valign="top" align="right">to room</td>|;
  $table .= qq|<td valign="top" align="right">$roommenu</td></tr>|;
  $table .= qq|<tr><td valign="top" colspan="2" align="right">|;
  $table .= qq|<input type="submit" name="sexisgood" value="submit" /></form>|;
  $table .= qq|</td></tr></table>|;

  if ( defined $query->param( 'usernames' ) && defined $query->param( 'roomname' ) )
  {
    my $usernames = $query->param( 'usernames' );
    my $roomname  = $query->param( 'roomname' );
    my $room      = getNode( $roomname, 'room' );
    my $str = '';

    if ( ! $room && ! ( $roomname eq 'outside' ) )
    {
      return '<p><font color="#c00000">Room <b>"' 
      . $roomname 
        . '"</b> does not exist.</font></p>';
    }elsif ( $roomname eq 'outside' ) {
      $room = 0;
      $str .= "<p>Moving users outside into the main room.</p>\n";
    } else {
      $str .= "<p>Moving users to room <b>" 
      . linkNode( $$room{ 'node_id' } ) . ":</b></p>\n";
    }

    # Remove whitespace from beginning and end of each line
    $usernames =~ s/\s*\n\s*/\n/g;

    my @users = split( '\n', $usernames );

    $str .= "<ol>\n";

    my $count = 0;

    foreach my $username ( @users )
    {
      my $user = getNode( $username, 'user' );

      if ( $user )
      {
        $APP->changeRoom( $user, $room );
        $str .= '<li>' . linkNode( $$user{ 'node_id' } ) . "</li>\n";
      } else {
        $str .= "<li><font color=\" #c00000\">User <b>\"" 
          . $username 
          . "\"</b> does not exist.</font></li>\n";
      }

      ++$count;
    }

    $str .= "</ol>\n";

    $str .= "<p>No users specified.</p>\n" if ( $count == 0 );

    return $header. $table . $str . $str2;
  } else {
    return $header. $table . $str2;
  }

}

sub e2_collaboration_nodes
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = '';

  # To be done:
  #   "create" for crtleads:
  #       allow "create by all" with a create maintainance that
  #       forbids preterite users from creating;
  # 
  #   "delete" for editors/crtleads:
  #       allow "delete by all" with delete maintainance, or 
  #       just allow delete by CEs and let non-CE crtleads lump
  #       it?
  #
  #   Test, test, test the locking code.
  #       Maybe ask nate how that feature was intended to work, 
  #       or hey, maybe it exists in a later version of 
  #       ecore...?
  #
  #   Damn, we need ACLs.

  #---------------------------------------------------------
  # Is the user allowed in?

  return "<p>Permission denied.</p>" unless ( $APP->isEditor($USER) );

  $str .= qq|<p><b>Here's how these puppies operate:</b></p>|;
  $str .= qq|<dl><dt><b>Access</b></dt><dd>|;
  $str .= qq|<p>Any CE or god can view or edit any collaboration node. A regular |;
  $str .= qq|user can't, unless one of us explicitly grants access. You grant |;
  $str .= qq|access by editing the node and adding the user's name to the |;
  $str .= qq|"Allowed Users" list for that node (just type it into the box; it |;
  $str .= qq|should be clear). You can also add a user<em>group</em> to the |;
  $str .= qq|list: In that case, every user who belongs to that group will have |;
  $str .= qq|access (<em>full</em> access) to the node. </p></dd> |;

  $str .= qq|<dt><b>Locking</b></dt>|;
  $str .= qq|<dd>|;
  $str .= qq|<p>The only difficulty with this is the fact that two different |;
  $str .= qq|users will, inevitably, end up trying to edit the same node at the |;
  $str .= qq|same time. They'll step on each other\'s changes. We handle this |;
  $str .= qq|problem the way everybody does: When somebody begins editing a |;
  $str .= qq|collaboration node, it is automatically "locked". CEs and gods can |;
  $str .= qq|forcibly unlock a collaboration node, but don't |;
  $str .= qq|do it too casually because, once again, you may step on the |;
  $str .= qq|user's changes. Any user can voluntarily release his or her |;
  $str .= qq|<em>own</em> lock on a collaboration node (but they'll forget |;
  $str .= qq|which is why you can do it yourself). Finally, all "locks" on |;
  $str .= qq|these nodes expire after fifteen idle minutes, or maybe it's |;
  $str .= qq|twenty. I can't remember. <strong>Use it or lose it.</strong></p>|;

  $str .= qq|<p>The "locking" feature may be a bit perplexing at first, but |;
  $str .= qq|it's necessary if the feature is to be useful in practice. |;
  $str .= qq|</p></dd></dl><br />|;
  $str .= qq|<p>The HTML "rules" here are the same as for writeups, except |;
  $str .= qq|that you can also use the mysterious and powerful |;
  $str .= qq|&lt;highlight&gt; tag. </p>|;

  $str .= '
    <hr />
    <b>Search for a collaboration node:</b><br />
    <form method="post" enctype="application/x-www-form-urlencoded">
    <input type="text" name="node" value="" size="50" maxlength="64">
    <input type="hidden" name="type" value="collaboration">
    <input type="submit" name="searchy" value="search">
    <br />
    <input type="checkbox" name="soundex" value="1" default="0">Near Matches
    <input type="checkbox" name="match_all" value="1" default="0">Ignore Exact
    </form>';

  $str .= '
    <hr />
    <b>Create a new collaboration node:</b><br />
    <form method="post">
    <input type="hidden" name="op" value="new">
    <input type="hidden" name="type" value="collaboration">
    <input type="hidden" name="displaytype" value="useredit">
    <input type="text" size="50" maxlength="64" name="node" value="">
    <input type="submit" value="create">
    </form>';

  $str .= '<br /><br /><br /><br />
    <p><i>Bug reports and tearful accusations (or admissions) of 
    infidelity go to <a href="/index.pl?node_id=470183">wharfinger</a>.</i></p>';

  return $str;
}

sub e2_gift_shop
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>Welcome to the Everything2 Gift Shop!</p>|;

  $str .= htmlcode("giftshop_star");
  $str .= htmlcode("giftshop_sanctify");
  $str .= htmlcode("giftshop_buyvotes");
  $str .= htmlcode("giftshop_votes");
  $str .= htmlcode("giftshop_ching");
  $str .= htmlcode("giftshop_buyching");
  $str .= htmlcode("giftshop_topic");
  $str .= htmlcode("giftshop_buyeggs");
  $str .= htmlcode("giftshop_eggs");


  $str .= qq|<p><hr width='300' /></p><p><b>Self Eggsamination</b></p>|;

  if ($$VARS{GPoptout})
  {
    $str.="<p>You currently have <b>".($$VARS{easter_eggs}||"0")."</b> easter egg".($$VARS{easter_eggs} == 1 ? "" :"s")." and <b>".($$VARS{tokens}||"0")."</b> token".($$VARS{tokens} == 1 ? "" :"s").".</p>";
  } else {
    $str.="<p>You currently have <b>".$$USER{GP}." GP</b>, <b>".($$VARS{easter_eggs}||"0")."</b> easter egg".($$VARS{easter_eggs} == 1 ? "" :"s").", and <b>".($$VARS{tokens}||"0")."</b> token".($$VARS{tokens} == 1 ? "" :"s").".</p>";
  }

  htmlcode('achievementsByType','miscellaneous,'.$$USER{user_id});

  $$VARS{oldexp} = $$USER{experience};
  $$VARS{oldGP} = $$USER{GP};

  return $str;
}

sub e2_marble_shop
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p><big>Yes!<br>We have no marbles!<br>We have no marbles today!</big></p><br><br><p>Thank-you for your custom.</p>|;
  $str .= qq|<p>Please come back the next time you lose them.</p>|;
  return $str;
}

sub e2_penny_jar
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '<p>You must be logged in to [touch the puppy|touch the pennies].</p>' if($APP->isGuest($USER));
  return "Sorry, it seems you are not interested in [GP|pennies] right now." if ($$VARS{GPoptout});

  my $userGP = $$USER{GP};
  my $pennynode = getNode("penny jar","setting"); 
  my $pennies = getVars($pennynode);
  my $str = "";

  return "<p>Sorry, there are no more [GP|pennies] in the jar! Would you like to [Give a penny, take a penny|donate one]?</p>" if $$pennies{1} < 1;

  $str.= "<p>Oh look! It's a jar of [GP|pennies]!</p><p>Would you like to give a penny or take a penny?</p>";

  if ($query->param('give'))
  {
    return "<p>Sorry, you do not have any GP to give!</p>" if $userGP < 1;

    $$pennies{1}++;
    setVars($pennynode, $pennies);
    $APP->adjustGP($USER, -1);
  }

  if ($query->param('take'))
  {
    return "<p>Sorry, there are no more [GP|pennies] in the jar! Would you like to [Give a penny, take a penny|donate one]?</p>" if $$pennies{1} < 1;
    $$pennies{1}--;
    setVars($pennynode, $pennies);
    $APP->adjustGP($USER, 1);
  }

  $str.=$query->start_form();
  $str.=$query->hidden('node_id', $$NODE{node_id});
  $str.=$query->submit('give','The more you give the more you get. Give!');
  $str.=$query->end_form();

  $str.=$query->start_form();
  $str.=$query->hidden('node_id', $$NODE{node_id});
  $str.=$query->submit('take','No! Giving is for the weak. Take!');
  $str.=$query->end_form();

  if ($$pennies{1} == 1)
  {
    $str.="<p>There is currently <b>1</b> penny in the penny jar.</p>";
  } else {

    if ($$pennies{1})
    {
      $str.="<p>There are currently <b>".$$pennies{1}."</b> pennies in the penny jar.</p>";
    } else {
      $str.="<p>There are no more pennies in the penny jar!</p>";

    }
  }

  return $str;
}

sub e2_rot13_encoder
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>This is the E2 Rot13 Encoder.  It also does decoding.  You can just paste the stuff you want swapped around in the little box and click the buttons. It's really quite simple.  Enjoy!</p>|;

  $str .= qq|<form name="myform"><textarea name="rotter" rows="30" cols="80">|;

  my $n = getNodeById($query->param("lastnode_id"));
  if(defined($n) and $$n{type}{title} eq "writeup")
  {
    $str .= encodeHTML($$n{doctext});
  }
  $str .= qq|</textarea><br><input type="button" name="e2_rot13_encoder" value="Rot13 Encode"><input type="button" name="e2_rot13_encoder" value="Rot13 Decode"></form><br><br><br><br><br><br><small><p align="right">Thanks to [mblase] for the function update.</p></small>|;

  return $str;
}

sub e2_source_code_formatter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

#    <!--  wharfinger  11/23/00                                              -->
#    <!--  This "code", such as it is, is in the public domain.              -->
#    <!--  Replace angle-brackets with &lt;/&gt; and square brackets with    -->
#    <!--  &#91;/&#93;                                                       -->

  return q|<script><!--
    function do_fix_brackets( widget, option ) {
        if ( option != 'fix' && option != 'restore' ) {
            window.alert(   'do_fix_brackets( ) error:\n\n' +
                            '    option == "' + option + '"\n\n' +
                            'It must be "fix" or "restore".' );
        } else {
            //  Realistically speaking, we could use any non-'fix' value 
            //  of option to signify 'restore' (I mean, that's what we ARE
            //  doing, right?), but that's ugly. For example, you could 
            //  call "do_fix_brackets( 'foo', 'fixbrackets' )" and have it 
            //  do just the opposite of what it looks like.
            widget.value = ( option == 'fix' )
                                ? fix_brackets( widget.value )
                                : restore_brackets( widget.value );

            widget.select();
            widget.focus();
        }

        return false;   //  Even if this was invoked by a "submit" button,
                        //  don't submit.
    }

    //---------------------------------------------------------------------
    //  Is there any way to pass by reference in JavaScript?
    function fix_brackets( str ) {
        str = str.replace( /\&/g, '&amp;' );
        str = str.replace( /\</g, '&lt;' );
        str = str.replace( /\>/g, '&gt;' );

        //  0x5b is left square bracket; 0x5d is right square bracket.
        //  We do that because E2 will jump to conclusions about what the 
        //  square brackets are for. If we needed the square brackets for 
        //  the set operator, we could do eval( '/\x5b0-9\x5d/g' ) or 
        //  something.
        str = str.replace( /\x5b/g, '&#91;' );
        str = str.replace( /\x5d/g, '&#93;' );

        return str;
    }

    //---------------------------------------------------------------------
    function restore_brackets( str ) {
        str = str.replace( /&lt;/g, '<' );
        str = str.replace( /&gt;/g, '>' );
        str = str.replace( /&amp;/g, '&' );

        //  0x5b is left square bracket; 0x5d is right square bracket.
        //  We do that because E2 will jump to conclusions about what the 
        //  square brackets are for.
        str = str.replace( /&#91;/g, '\x5b' );
        str = str.replace( /&#93;/g, '\x5d' );

        return str;
    }
    --></script>

    <!-- **** HTML **** -->
    <p align="justify">You have fallen into the loving arms of the E2 Source Code 
    Formatter. Just paste your [source code] into the box and click the 
    <b>"Reformat"</b> button, and [Vanna White\|all your dreams will come true].  
    If you don't know (or don't care) what [source code] is, you won't find this 
    thing useful at all. </p>

    <p align="justify">The <b>"Reformat"</b> button replaces [angle bracket]s, 
    [square bracket]s, and [ampersand]s with appropriate [HTML character 
    entities]. <b>"DEformat"</b> changes them back again. </p>

    <p align="justify">Because users' [screen resolution]s vary, we strongly urge 
    you to keep your code &lt;= 80 columns in width so that it doesn't mess with 
    E2's page formatting. If the lines are far too wide, [The Power Structure of Everything 2\|a god] 
    may feel compelled to fix the thing -- and most of our gods are not 
    programmers. To that end, we also strongly encourage you to use spaces 
    instead of tabs: Most browsers display tabs as eight spaces, which increases 
    the line width for no good reason since you probably only want four-space 
    tabs anyway. Even if you don't, you should. Don't start me on about where the 
    braces go. </p>

    <p align="justify">These operations are performed on the entire string, so 
    you'll want to paste in only the actual [source code] part of your [writeup]. 
    You'll need to supply your own <tt>&lt;pre&gt;</tt> [E2 HTML tags\|tag]s as 
    well. I fussed around with making it <tt>&lt;pre&gt;</tt>-aware, but that got 
    painful. </p>

    <dl>
    <dt><b>Other E2 Formatting Utilities:</b></dt>
    <dd><b>[Wharfinger's Linebreaker]:</b> For formatting poetry and [lyric]s.</dd>
    </dl>

    <form name="codefixer">
      <textarea name="edit" cols="80" rows="20"></textarea>

      <br>

      <input type="button" name="submit" value="Reformat" 
        onclick="javascript:do_fix_brackets( document.codefixer.edit, 'fix' )">
      <input type="button" name="submit" value="DEformat" 
        onclick="javascript:do_fix_brackets( document.codefixer.edit, 'restore' )">
      <input type="button" name="clear" value="Clear" 
        onclick="javascript:document.codefixer.edit.value='';">
      </input>
    </form>

    <br><hr>
    <p>Originally by [wharfinger]</p>|;

}

sub e2_sperm_counter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  #welcome to the E2 sperm counter.
  #We're all not breeding, don't be afraid.

  #Get the number of users on the system.
  my $usrs = $DB->sqlSelect("count(*)", "user");
  my $usrsnow = $DB->sqlSelect("count(*)", 'room');
  #85% of our users are male;
  $usrs *= .85;
 
  #at any particular point, one could have between 1.2 and 1.4 billion sperm
  #so lets do some scientific calculations as to why.

  my $rand = rand(200000000);
  my $rand2 = rand(200000000);
  $rand += 1200000000;
  $rand2 += 1200000000;

  $usrs *= $rand;
  $usrsnow *= $rand2;

  $usrs = ceil($usrs);
  $usrsnow = ceil($usrsnow);

  $usrs = reverse("$usrs");
  $usrsnow = reverse("$usrsnow");

  $usrs =~ s/(\d\d\d)/$&\,/g;
  $usrsnow =~ s/(\d\d\d)/$&\,/g;

  my $c = chop($usrs);
  $usrs.=$c unless($c eq ",");

  $c = chop($usrsnow);
  $usrsnow.=$c unless($c eq ",");

  $usrs = reverse($usrs);
  $usrsnow = reverse($usrsnow);

  return "<p align=\"center\">E2 Users world wide have<br><br> <big><big><big><big><big><big><strong>$usrs</strong></big></big></big></big></big></big><br>sperm swimming around.<br><br>Currently online there are<br><br><big><big><big><big><big><big><strong>$usrsnow</strong></big></big></big></big></big></big><br>being wasted now, as you node.</p>";

}

sub e2_ticket_center
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $str = q|<style type='text/css'>
    .staff_only { background: #c0ffee; display: block; }
    .smallcell { width: 100px; }
    .summarycell { width: 50%; }
    .summary { width: 90%; }
    .createticket { width: 90%; }
    </style><!-- / block context sensitive coloring problems -->|;

  ## This section is for ticket creation.  The list will display below the create area.

  my $isGod = $APP->isAdmin($USER);
  my $isCE = $APP->isEditor($USER);

  ## Don't display conditions
  return "$str<p>You must be logged in to view service tickets.</p>" if $APP->isGuest($USER);
  return $str unless($isGod); ## temp until system is ready

  ## Define variables
  my (@TKTTYPES) = $DB->getNodeWhere({type_nodetype => getId(getType('ticket_type'))});
  my @TKTTYPE;
  foreach(@TKTTYPES) { push @TKTTYPE, $_; }
  my $settickettype ="\n\t\t<select id='tickettype' name='tickettype'>";
  foreach(@TKTTYPE) { $settickettype.="\n\t\t\t<option value='".$_->{node_id}."'>".$_->{title}."</option>"; }
  $settickettype.="\n\t\t</select>";

  my $header = "<h3>Create a New Ticket</h3>\n"
    . '<form method="post" action="/index.pl" enctype="multipart/form-data">';
  my $ticketsummary = '<input type="text" class="summary" name="summary" maxlength="250">';
  my $ticketdescription = "<textarea id='description' name='description' "
    . htmlcode('customtextarea','1')
    . " wrap='virtual' >"
    . "</textarea>";

  my $createdby = "<input type='hidden' name='createdby' value='$$USER{node_id}'>";
  my $footer = "\n" . $createdby
    . "\n" . '<input type="hidden" name="op" value="new">'
    . "\n" . '<input type=hidden name="type" value="1949335">'
    . "\n" . $query->submit("createit", "Enter Ticket")
    . "\n" . $query->end_form;

  ## Admin Only checkbox only visible to admins, C_Es
  my $adminchecktitle = "";
  my $admincheck = "";
  if ($isGod || $isCE)
  {
    $adminchecktitle = '<span class="staff_only">Admin<br>Only?</span>';
    $admincheck = '<span class="staff_only"><input type="checkbox" name="adminonly" value="1">';
  }else{
    $adminchecktitle = "&nbsp;";
    $admincheck = "&nbsp;";
  }

  ## start multi-line string to define the table layout
  my $createtable = '
    <table border="0" class="createticket" cellpadding="0" cellspacing="0">
    <tr>
    <th class="smallcell">'.$adminchecktitle.'</td>
    <th>Type</td>
    <th class="summarycell">Short Summary</td>
    <tr>
    <td align="center">'.$admincheck.'</td>
    <td align="center">'.$settickettype.'</td>
    <td align="center">'.$ticketsummary.'</td>
    <tr>
    <th colspan="3">Detailed Description <small>(please be specific)</small></th>
    <tr><td colspan="3">'.$ticketdescription.'</td></table>';

  ## end multi-line string to create the table layout

  $str .= $header . $createtable . $footer;

  $str .= qq|<hr><h3>Ticket Listing</h3><!-- / block context sensitive coloring problems -->|;

  my $testnode = undef;
  my $output = "";
  my $csr = $DB->{dbh}->prepare("
    SELECT *
    FROM node
    WHERE type_nodetype = 1949335 LIMIT 100");
  $csr->execute();

  while (my $s = $csr->fetchrow_hashref)
  {
    $output .= "<p>";
    foreach my $keys (sort(keys(%{$s})))
    {
      $output .= $keys . ":" . $s->{$keys} . " ";
    }
    
    $output .= "summary: " . $s->{'summary'} . "</p>";
  }

  return $str.$output;
}

sub edev_faq
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = q|<!-- NPB TODO make in-page style sheets -->|;

  $str .= q|<p>Okey-dokey, here are some FAQs for those in the |.linkNode(getNode('edev','usergroup')).q| usergroup.
You, |.linkNode($USER,0,{lastnode_id=>0}) . ', ' . ( $APP->isDeveloper($USER,"nogods") ? '<strong>are</strong> a respected <small>(haha, yeah, right!)</small>' : 'are <strong>not</strong> a').q| member of the edev group here, on E2. In this FAQ, "I" is [N-Wing].
</p>|;

  $str .= q|<p>First: All E2 development is driven out of <a href="https://github.com/everything2/everything2">Github</a>. Anyone there can spin up a development environment, see how it works, submit pull requests, or ask for features that they can work on. There's plenty to chip in on. Check out the <a href="https://github.com/everything2/everything2/issues">open issues</a> and feel free to start contributing.</p>|;

  $str .= q|<p>Questions:</p><ol>|;
  $str .= q|<li><a href="#powers">What are some of my superpowers?</a></li>|;
  $str .= q|<li><a href="#msg">Why are random people sending me private messages that start with "EDEV:" or "ONO: EDEV:"?</a></li>|;

  $str .= q|<li><a href="#background">What is the background of edev and it's relationship to the development of the site/source?</a></li>|;
  $str .= q|<li><a href="#edevify">What is this "Edevify!" link thingy I see in my Epicenter nodelet?</a></li>|;
  $str .= q|<li><a href="#ownesite">Does everybody have their own Everything site for hacking on?</a></li>|;
  $str .= q|<li><a href="#edevite">What is an edevite?</a></li>|;
  $str .= q|<li><a href="#edevdoc">What is an Edevdoc?</a></li>|;
  $str .= q|<li><a href="#whyjoin">Why did others (or, why should I) join the edev group?</a></li>|;
  $str .= q|<li><a href="#improvements">How do we go about finding tasks here? If we have personal projects for the improvement of E2, what is the appropriate way to get started? Should I verify that what I'm thinking of is useful, or should I make it work and then submit source patches?</a></li>|;
  $str .= q|</ol>|;

  $str .= q|<p><hr /><a name="powers">Q: <strong>What are some of my superpowers?</strong></a><br />|;
  $str .= q|A: I wouldn't say <em>superpowers</em>, just <em>powers</em>. Anyway:</p>|;
  $str .= q|<ul>|;
  $str .= q|<li>You're a hash! (in the [Other Users] nodelet, [edevite]s have a <code>%</code> next to their name (which is only viewable by fellow edevites))</li>|;
  $str .= q|<li>You can see the source code for many things here. If you visit something like a [superdoc] (for example, this node), if you append <code>&amp;displaytype=viewcode</code> to the URL, it will show the code that generates that node. When you have the [Everything Developer] nodelet turned on, you can more easily simply follow the little "viewcode" link (which only displays on nodes you may view the source for). For example, you can see this node's source by going |.linkNode($NODE,'here',{'displaytype'=>'viewcode'}).q|</li>|;
  $str .= q|<li>You can see other random things, like [dbtable]s (nodes and other things (like softlinks) are stored in tables in the database; viewing one shows the field names and storage types) and [theme] (a theme contains information about a generic theme).</li>|;
  $str .= q|<li>You can see/use [List Nodes of Type], which lists nodes of a certain type. One example <small>(</small>ab<small>)</small>use of this is to get a list of rooms. [nate] in [Edev First Post!] <small>(doesn't that sound like a troll title?)</small> lists some other node types you may be interested in. Actually, you should probably read that anyway, it has other starting information, too.</li>|;
  $str .= q|<li>You have your own (well, shared with editors and admins) section in [user settings 2]. (As of the time this FAQ was written, there is only 1 setting there, which is explained in the <a href="#msg">next question</a>.)</li>|;
  $str .= q|<li>You can [Edevify] things. See the <a href="#edevify">later question</a> for more information about this.</li>|;
  $str .= q|</ul>|;

  $str .= q|<p><hr /><a name="msg">Q: <strong>Why/how are random people sending me private messages that have '([edev])' in front of them?</strong></a><br />|;
  $str .= q|A (short) : They aren't random people, and they aren't sending to just you.<br />|;
  $str .= q|A (longer) : When somebody is a member of a [usergroup], they can send a private message to that group, which will then be sent to everybody in that group. In this case, those "random people" are other people in the [edev] usergroup, and they're typing something like this in the chatterbox:<br /><br />|;
  $str .= q|<code>/msg edev Hi everybody, I'm Doctor Nick! Have you seen [EDev FAQ] yet?</code><br /><br />|;
  $str .= q|and (assuming the other person is you), everybody in edev would then get a message that looks something like:<br /><br />|;
  $str .= q|<form><input type="checkbox">|;
  $str .= qq|([edev]) <i> $$USER{title} says</i> Hi everybody, I'm Doctor Nick! Have you seen [EDev FAQ] yet?<br /><br />|;
  $str .= q|If the <code>/msg</code> is changed to a <code>/msg?</code> instead (with the question mark), then that message is only sent to people that are currently online (which will make the message start with 'ONO: '). For the most part, there isn't much reason to send this type of message in the edev group. For a little more information about this feature, see [online only /msg].|;
  $str .= q|</form></p>|;


  $str .= q|<p><hr /><a name="background">Q: <strong>What is the background of edev and it's relationship to the development of the site/source?</strong></a><br />|;
  $str .= q|A: Edev is the coordination list for development of Everything2.com. It is used for discussion of new features or of modifications, or to help people debug their problems. Some code snippets people have written as part of edev have been incorporated into the E2 code here. The main way this happens is by creating Github pull requests.|;
  $str .= q|</p>|;

  $str .= q|<p><hr /><a name="edevify">Q: <strong>What is this "Edevify!" link thingy I see in my Epicenter nodelet?</strong></a><br />|;
  $str .= q|A: This simply puts whatever node you're viewing on the [edev] (usergroup) page. About the only time to use this is when you create a normal writeup that is relevant to edev. Note: this does not work on things like "group" nodes, which includes [e2node]s; to "Edevify" your writeup, you must be viewing your writeup alone (the easiest way is to follow the idea/thing link when viewing your writeup from the e2node).|;
  $str .= q|</p>|;

  $str .= q|<p><hr /><a name="ownesite">Q: <strong>Does everybody have their own Everything site for hacking on?</strong></a><br />
A: Yes! Everything has a development environment that is powered by <a href="https://vagrantup.com">Vagrant</a> and <a href="https://www.virtualbox.org">VirtualBox</a>. Starting up your very own copy of the environment is as simple as installing a couple of pieces of software, cloning the repository, and typing <em>"vagrant up"</em>.|;
  $str .= q|</p>|;

  $str .= q|<p><hr /><a name="edevite">Q: <strong>What is an edevite?</strong></a><br />|;
  $str .= q|A: Instead of calling somebody "a member of the [edev] group" or "in the [edev] (user)group", I just call them an "edevite".|;
  $str .= q|</p>|;

  $str .= q|<p><hr /><a name="edevdoc">Q: <strong>What is an Edevdoc?</strong></a><br />|;
  $str .= q|A: The [Edevdoc] extends the [document] nodetype, but allows edevites (and only edevites) to create and view it. They are primarily useful in testing out APIs and writing Javascript pieces to test out new interfaces and functionality. You can also do it entirely in the development environment as well.|;
  $str .= q|</p>|;

  $str .= q|<p><hr /><a name="whyjoin">Q: <strong>Why did others (or, why should I) join the edev group?</strong></a><br />|;
  $str .= q|A from [anotherone]: I'm in the group because I like to take stuff apart, see how it works. [participate in your own manipulation\|Understand what's going on]. I've had a few of my ideas implemented, and it was cool knowing that I'd dome something useful.<br />|;
  $str .= q|A from [conform]: I'm interested (for the moment) on working on the theme implementation and I've got some ideas for nodelet UI improvements.<br />|;
  $str .= q|A from [N-Wing]: I originally (way back in the old days of Everything 1) had fun trying to break/hack E1 (and later E2) (hence my previous E2 goal, "Breaking Everything"). Around the time I decided to start learning some Perl, the edev group was announced, so I was able to learn Perl from working code <strong>and</strong> find more problems in E2 at the same time. (However, it wasn't until later I realized that E2 isn't the best place to start learning Perl from. <tt>:)</tt> )|;
  $str .= q|</p>|;

  $str .= q|<p><hr /><a name="improvements">Q: <strong>How do we go about finding tasks here? If we have personal projects for the improvement of E2, what is the appropriate way to get started? Should I verify that what I'm thinking of is useful, or should I make it work and then submit source patches?</strong></a><br />|;
  $str .= q|A: Generally, feel free to post a message to the group or <a href="https://github.com/everything2/everything2/issues">open an issue</a> on the page. </p>|;

  return $str;
}

sub edev_documentation_index
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @edoc = $DB->getNodeWhere ({}, "edevdoc", "title");
  my $str = "";
  foreach (@edoc) {
    $str.= linkNode($_) ."<br>\n";
  }


  $str.="<p><i>Looks pretty lonely...</i>" if @edoc < 10;

  return $str unless $APP->isDeveloper($USER);

  $str.=htmlcode('openform');
  $str.="<INPUT type=hidden name=op value=new>\n";
  $str.="<INPUT type=hidden name=type value=edevdoc>\n";
  $str.="<INPUT type=hidden name=displaytype value=edit>\n";
  $str.="<h2>Make that dev doc:</h2>";
  $str.=$query->textfield('node', "", 25);
  $str.=htmlcode('closeform');

  return $str;

}

sub edit_weblog_menu
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER) ;

  my $str = htmlcode( 'openform' ).'<fieldset><legend>Display:</legend>' ;

  if ( $query -> param( 'nameifyweblogs' ) )
  {
    $$VARS{ nameifyweblogs } = 1 ;
  } else {
    delete $$VARS{ nameifyweblogs } if $query -> param( 'submit' ) ;
  }

  $str .= $query -> checkbox( -name => 'nameifyweblogs' , -checked => ( $$VARS{ nameifyweblogs } ? 'checked' : '' ) ,
    -value => 1 , -label => 'Use dynamic names (-ify!)' ).'
    </fieldset>' ;


  my $wls = {};
  $wls = getVars( getNode( 'webloggables' , 'setting' ) ) if $$VARS{ nameifyweblogs } ;
  my $somethinghidden=0;

  $str .= "\n<fieldset><legend>Show items:</legend>\n" ;
  foreach( split ',' , $$VARS{ can_weblog } )
  {
    if ( $query -> param( 'show_'.$_ ) )
    {
      delete $$VARS{ 'hide_weblog_'.$_ } ;
    } elsif ( $query -> param( 'submit' ) ){
      $$VARS{ 'hide_weblog_'.$_ } = $$VARS{ 'hidden_weblog' } = $somethinghidden = 1 ;
    }

    my $groupTitle = "News" ;
    if ( $$VARS{ nameifyweblogs } )
    {
      $groupTitle = $$wls{ $_ } ;
    } else {
      $groupTitle = getNodeById($_,"light")->{title} unless $_ == 165580 ;
    }

    $str .= $query -> checkbox( -name => 'show_'.$_ , -checked => ( $$VARS{ 'hide_weblog_'.$_ } ? '' : 'checked' ) ,
      -value => 1 , -label => $groupTitle )."<br>\n" ;
  }

  delete $$VARS{ 'hidden_weblog' } unless $somethinghidden ;

  return $str.'</fieldset><input type="submit" name="submit" value="'.( $$VARS{ nameifyweblogs } ? 'Changeify!' : 'Submit' ).'"></form>';

}

sub editor_endorsements
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  
  my @grp = (@{getNode("gods","usergroup")->{group}},@{getNode("Content Editors","usergroup")->{group}}, @{getNode("exeds","nodegroup")->{group}});
  my %except = map {getNode($_,"user")->{node_id} => 1} ("Cool Man Eddie","EDB","Webster 1913","Klaproth");

  @grp = sort {lc(getNodeById($a)->{title}) cmp lc(getNodeById($b)->{title})} @grp;
  my $str = "Select your <b>favorite</b> editor to see what they've [Page of Cool|endorsed]:";


  $str.=htmlcode("openform");
  my $last=0;
  $str.="<select name=\"editor\">";
  foreach(@grp)
  {
    next if $last == $_;
    $last = $_;
    $str.="<option value=\"$_\"".(($query->param("editor")."" eq "$_")?(" SELECTED "):("")).">".getNodeById($_)->{title}."</option>" unless($except{$_}) or not getNodeById($_)->{type}->{title} eq "user"
  }
    $str.="</select><input type=\"submit\" value=\"Show Endorsements\"></form>";

  my $ed = $query->param("editor");
  $ed =~ s/[^\d]//g;
  return $str unless $ed && getNodeById($ed)->{type}->{title} eq "user";

  my $csr = $DB->sqlSelectMany("node_id", "links left join node on links.from_node=node_id", "linktype=".getId(getNode("coollink", "linktype"))." and to_node='$ed' order by title");

  my $innerstr = "";
  my $count = 0;
  while(my $row = $csr->fetchrow_hashref)
  {
    $count++;    
    my $n = getNodeById($$row{node_id});
    $$n{group} ||= [];
    my $num = scalar(@{$$n{group}});
    $innerstr.="<li>".linkNode($n).
    (($$n{type}{title} eq "e2node")?
    (" - $num writeup".(($num == 0 || $num > 1)?("s"):(""))):
    (" - ($$n{type}{title})"))."</li>";
  }

  $str.=linkNode(getNodeById($ed))." has endorsed $count nodes<br><ul>$innerstr</ul>";

  return $str;
}

sub everything_data_pages
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $str = q|<p>A note to client developers: |;
  $str .= q|The following are Everything Data Pages (nodetype=<code>fullpage</code>) -- you may write scripts to parse them and provide you with entertaining |;
  $str .= q|server-side data.  With the [New Nodes XML Ticker] and the [User Search XML Ticker] please don't hit it |;
  $str .= q|more than every 5 mins, as they are fairly expensive pages.  Please don't hit ANY of the pages more frequently |;
  $str .= q|than every 30 seconds -- although you may offer a "refresh" button to the users.  I'd prefer not to have tons of inactive users bogging down the server. |;
  $str .= q|</p><p><a href="headlines.rdf">http://everything2.com/headlines.rdf</a> is the RDF feed of Cool Nodes -- "Cool User Picks!".</p><p>|;

  $str .= '<table><tr><th>title</th><th>node_id</th>';
  my $isRoot = $APP->isAdmin($USER);
  my $isDev = $isRoot || $APP->isDeveloper($USER);

  $str .= '<th>viewcode</th>' if $isDev;
  $str .= '<th>edit</th>' if $isRoot;
  $str .= "</tr>\n";

  $str = '(<a href='.urlGen({node=>'List Nodes of Type', chosen_type=>'fullpage'}).'>alternate display</a> at [List Nodes of Type])'.$str if $isDev;

  my @nodes = $DB->getNodeWhere({type_nodetype => getId(getType('fullpage'))});
  foreach (@nodes)
  {
    $str.= '<tr><td>'.linkNode($_).'</td><td>'.$$_{node_id};
    $str.= '</td><td>'.linkNode($_, 'viewcode', {displaytype => 'viewcode'}) if $isDev;
    $str.= '</td><td>'.linkNode($_, 'edit', {displaytype => 'edit'}) if $isRoot;
    $str .= "</td></tr>\n";
  }

  $str .= '</table>';

  $str .= q|</p><br><br><hr><br><table>|;

  $str .="These are the second generation tickers, using a more unified XML base, and also exporting information more fully. These are of type [ticker].";

  @nodes = $DB->getNodeWhere({type_nodetype => getId(getType('ticker'))});
  foreach (@nodes)
  {
    $str.= '<tr><td>'.linkNode($_).'</td><td>'.$$_{node_id};
    $str.= '</td><td>'.linkNode($_, 'viewcode', {displaytype => 'viewcode'}) if $isDev;
    $str.= '</td><td>'.linkNode($_, 'edit', {displaytype => 'edit'}) if $isRoot;
    $str .= "</td></tr>\n";
  }

  $str .= q|</table>|;
  return $str;

}

sub everything_finger
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  my $wherestr = "";

  #old way
  unless($$VARS{infravision})
  {
    $wherestr.=' and ' if $wherestr;
    $wherestr.='visible=0';
  }

  my $csr = $DB->sqlSelectMany('*', 'room', $wherestr, 'order by experience DESC');

  $str.= '<table align="center" width="75%" cellpadding="2" border="1" cellspacing="0"><tr><th>Who</th><th>What</th><th>Where</th></tr>';

  my $UID = getId($USER);	#logged on user's ID
  my $uid;	#current display user's ID

  my $newbielook = $APP->isEditor($USER);

  my $flags = "";
  my $num = 0;
  while (my $U = $csr->fetchrow_hashref)
  {
    $num++;
    $uid = $$U{member_user};
    $str.='<tr><td>';
    $str.=linkNode($uid, $$U{nick}, {lastnode_id=>0});
  
    $flags = '';

    $flags .= '<font color="#ff0000">invis</font>' if $$U{visible};

    $flags .= '@' if $APP->isAdmin($uid);
    $flags .= '$' if $APP->isEditor($uid, "nogods") and not $APP->isAdmin($uid);
    $flags .= '%' if $APP->isDeveloper($uid, "nogods");

    my $difftime = time()-$U->{unixcreatetime};
    if($newbielook and $difftime < 60*60*24*30)
    {
      my $d = sprintf("%d", $difftime/(60*60*24))+1;
      $flags .= '<strong>' if $d<=3;
      $flags .= $d;
      $flags .= '</strong>' if $d<=3;
    }


    $str .= '</td><td>'.$flags.'</td><td>';

    $str .= ($$U{room_id}) ? linkNode($$U{room_id}) : 'outside';
    $str .= "</td></tr>\n";
  }

  $csr->finish;

  $str.='</table>';

  return '<em>No users are logged in!</em>' unless $num;
  my $intro = "There are currently $num users on Everything2<br>";

  return $intro.$str;

}

sub everything_document_directory
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = q|<style type="text/css">|;
  $str .= q|<!--
    th {
      text-align: left;
    }
    -->
    </style>|;

  $str .= q|<p>|;

  my $UID = getId($USER);

  return '<p>Please log in first.</p>' if $APP->isGuest($USER);

  my $isRoot = $APP->isAdmin($USER);
  my $isCE = $APP->isEditor($USER);
  my $isEDev = $APP->isDeveloper($USER);

  my $showLinkViewcode = $isEDev || $isRoot;
  my $showNodeId = $isEDev || $isRoot;

  my @types = ();
  my $filteredType = undef;
  my $pushit = 0;

  if ($query->param('filter_nodetype'))
  {
    $filteredType=$query->param('filter_nodetype');
    $pushit = 1;
    if ((!$isCE) && ($filteredType eq 'oppressor_superdoc'))
    {
      $pushit=0;
    } elsif ((!$isRoot) && ($filteredType eq 'restricted_superdoc')) {
      $pushit=0;
    }elsif ((!$isEDev) && ($filteredType eq 'EDevdoc')){
      $pushit=0;
    }

    if ($pushit)
    {
      push(@types, $filteredType);
    }
  } else {
    @types = qw(superdoc document superdocnolinks);
    push(@types, 'oppressor_superdoc') if $isCE;
    push(@types, 'restricted_superdoc') if $isRoot;
    push(@types, 'restricted_testdoc') if $isRoot;
    push(@types, 'Edevdoc') if $isEDev;
  }

  foreach(@types)
  {
    $_ = getId(getType($_));
  }

  #TODO checkboxes to NOT show things

  my %ids = ($$USER{node_id}=>$USER, $$NODE{node_id}=>$NODE);
  local *getNodeFromID = sub {
    my $nid = $_[0];
    return unless (defined $nid) && ($nid=~/^\d+$/);
    #already known, return it
    return $ids{$nid} if exists $ids{$nid};

    #unknown, find that (we also cache a mis-hit, so we don't try to get it again later)
    my $N = getNodeById($nid);
    return $ids{$nid}=$N;
  };

  my $opt = undef;

  my $choicelist = [
    '0','whatever the database feels like',
    'idA','node_id, ascending (lowest first)',
    'idD','node_id, descending (highest first)',
    'nameA','title, ascending (ABC)',
    'nameD','title, descending (ZYX)',
    'authorA','author\'s ID, ascending (lowest ID first)',
    'authorD','author\'s ID, descending (highest ID first)',
    'createA','create time, ascending (oldest first)',
    'createD','create time, descending (newest first)',
  ];

  $opt .= 'sort order: ' . htmlcode('varsComboBox','EDD_Sort', 0, @$choicelist) . "<br />\n";

  $opt .= 'only show things';
  $opt.=' written by ' . $query->textfield('filter_user') . '<br />';
  $opt .= 'only show nodes of type' . $query->textfield('filter_nodetype') . '<br />';

  $str .= qq|Choose your poison, sir:<form method="POST">|;
  $str .= qq|<input type="hidden" name="node_id" value="$NODE->{node_id}">|;
  $str .= qq|$opt<input type="submit" value="Fetch!"></form>|;

  my $filterUser = (defined $query->param('filter_user')) ? $query->param('filter_user') : undef;
  if(defined $filterUser)
  {
    $filterUser = getNode($filterUser, 'user') || getNode($filterUser, 'usergroup') || undef;
  }

  if(defined $filterUser)
  {
    $filterUser = getId($filterUser);
  }

  #mapping of unsafe VARS sort data into safe SQL
  my %mapVARStoSQL = (
    '0' => '',
    'idA' => 'node_id ASC',
    'idD' => 'node_id DESC',
    'nameA' => 'title ASC',
    'nameD' => 'title DESC',
    'authorA' => 'author_user ASC',
    'authorD' => 'author_user DESC',
    'createA' => 'createtime ASC',
    'createD' => 'createtime DESC',
    );

  my $sqlSort = '';
  if( (exists $VARS->{EDD_Sort}) && (defined $VARS->{EDD_Sort}) )
  {
    if(exists $mapVARStoSQL{$VARS->{EDD_Sort}})
    {
      $sqlSort = $mapVARStoSQL{$VARS->{EDD_Sort}};
    }
  }

  $str.='<table><tr bgcolor="#dddddd">';
  $str .= '<th class="oddrow"><small><small>viewcode</small></small></th>' if $showLinkViewcode;
  $str .= '<th class="oddrow">title</th><th class="oddrow">author</th><th class="oddrow">type</th><th class="oddrow">created</th>';
  $str .= '<th class="oddrow">node_id</th>' if $showNodeId;
  $str .= '</tr>';

  my @nodes = $DB->getNodeWhere({type_nodetype => \@types, author_user => $filterUser},'',$sqlSort);
  my $shown = 0;
  my $limit = $query->param('edd_limit') || 0;
  if($limit =~ /^(\d+)$/)
  {
    $limit = $1 || 0; 
  } else {
    $limit = 0;
  }

  unless($limit)
  {
    #default to a reasonable limit if don't specify limit
    $limit = 60;
    $limit += 10 if $isEDev;
    $limit += 10 if $isCE;
    $limit += 10 if $isRoot;
  }

  foreach my $n (@nodes)
  {
    last if $shown >= $limit;
    ++$shown;
    my $user = getNodeFromID($$n{author_user});

    $str .= '<tr><td>';
    $str .= '<a href='.urlGen({'node_id'=>$$n{node_id},'displaytype'=>'viewcode'}).'>vc</a></td><td>' if $showLinkViewcode;
    $str .= linkNode($n, 0, {lastnode_id=>0});
    $str .= qq|</td><td>$$user{title}</td><td><small>$$n{type}{title}</small></td><td><small>|;
    $str .= htmlcode('parsetimestamp',$$n{createtime}.',1');
    $str .= '</small></td>';

    if($showNodeId)
    {
      $str .= '<td>' . $$n{node_id} . '</td>';
    }

    $str .= '</tr>';
  }

  $str = (($shown != scalar(@nodes)) ? linkNode($NODE,scalar(@nodes),{edd_limit=>scalar(@nodes), lastnode_id=>0}) : $shown) .
' found, ' . $shown . ' most recent shown.<br />' . $str . '</table>';

  $str = 'Lucky you; you also can use <a href='.urlGen({'node'=>'List Nodes of Type','type'=>'superdoc'}).'>List Nodes of Type</a>,</p><p>' . $str if ($isEDev || $isCE);

  $str .= q|</p>|;
  return $str;

}

sub everything_i_ching
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my %figures = (
    'BBBBFB' => 'Shih, the army',
    'BFBBBB' => 'Pi, holding together (union)',
    'FFBFFF' => 'Hsiao Ch\'u, the taming power of the small',
    'FFFBFF' => 'Lu, treading (conduct)',
    'BBBFFF' => 'T\'ai, peace',
    'FFFBBB' => 'P\'i, standstill (stagnation)',
    'FFFFBF' => 'T\'ung Jo e\'n, fellowship with men',
    'FBFFFF' => 'Ta Yu, possession in great measure',
    'BBBFBB' => 'Ch\'ien, Modesty',
    'BBFBBB' => 'Yu, enthusiasm',
    'BFFBBF' => 'Sui, following',
    'FBBFFB' => 'Ku, Work on What Has Been Spoiled (Decay)',
    'FBFBBF' => 'Shih Ho, biting through',
    'FBBFBF' => 'Pi, grace',
    'FBBBBB' => 'Po, splitting apart',
    'BBBBBF' => 'Fu, return, the turning point',
    'BFFFBB' => 'Hsien, influence (wooing)',
    'BBFFFB' => 'Ho\' e\'ng, duration',
    'FBBBFF' => 'Sun, decrease',
    'FFBBBF' => 'I, increase',
    'BFFFFF' => 'Kuai, break-through (resoluteness)',
    'FFFFFB' => 'Kou, coming to meet',
    'BFFBFB' => 'K\'un, oppression (exhaustion)',
    'BFBFFB' => 'Ching, the well',
    'FFBFBB' => 'Chien, development (gradual progress)',
    'BBFBFF' => 'Kuei Mei, the marrying maiden',
    'BBFFBF' => 'Fo\'^e\'ng, abundance (fullness)',
    'FBFFBB' => 'Lu, the wanderer',
    'FFBBFB' => 'Huan, dispersion (dissolution)',
    'BFBBFF' => 'Chieh, limitation',
    'BFBFBF' => 'Chi Chi, after completion', 
    'FFFFFF' => 'Ch\'ien, the creative',
    'BBBBBB' => 'K\'un, the receptive',
    'BFBBBF' => 'Chun, difficulty at the beginning',
    'FBBBFB' => 'Mo\'eng, youthful folly',
    'BFBFFF' => 'Hsu, waiting (nourishment)',
    'FFFBFB' => 'Sung, conflict',
    'BBBBFF' => 'Lin, approach',
    'FFBBBB' => 'Kuan, contemplation (view)',
    'FFFBBF' => 'Wu Wang, innocence (the unexpected)',
    'FBBFFF' => 'Ta Ch\'u, the taming power of the great',
    'FBBBBF' => 'I, the corners of the mouth (providing nourishment)',
    'BFFFFB' => 'Ta Kuo, preponderance of the great',
    'BFBBFB' => 'K\'an, the abysmal (water)',
    'FBFFBF' => 'Li, the clinging (fire)',
    'FFFFBB' => 'Tun, retreat',
    'BBFFFF' => 'Ta Chuang, the power of the great',
    'FBFBBB' => 'Chin, progress',
    'BBBFBF' => 'Ming I, darkening of the light',
    'FFBFBF' => 'Chai Jo\' e\'n, the family (the clan)',
    'FBFBFF' => 'K\'uei, opposition',
    'BFBFBB' => 'Chien, obstruction',
    'BBFBFB' => 'Hsieh, deliverence',
    'BFFBBB' => 'Ts\'ui, gathering together (massing)',
    'BBBFFB' => 'Sho\'^e\'ng, pushing upward',
    'BFFFBF' => 'Ko, revolution (molting)',
    'FBFFFB' => 'Ting, the caldron',
    'BBFBBF' => 'Cho\'^e\'n, the arousing (shock, thunder)',
    'FBBFBB' => 'Ko\'^e\'n, keeping still, mountain',
    'FFBFFB' => 'Sun, the gentle (the penetrating, wind)',
    'BFFBFF' => 'Tui, the joyous (lake)',
    'FFBBFF' => 'Chung Fu, inner truth',
    'BBFFBB' => 'Hsiao Kuo, preponderance of the small'
    );

  #coin method

  my @pset = ("B","F","B","F");
  my @sset = ("F","F", "B", "B");

  my $primary = "";
  my $secondary = "";
  while (length($primary) < 6)
  {
    my $coins = int(rand(2))+int(rand(2))+int(rand(2));

    $primary .= $pset[$coins];
    $secondary .= $sset[$coins];
  
  }

  my $PNODE = getNode($figures{$primary},'e2node');
  return "$figures{$primary} not found!"  unless $PNODE;
  my $PWRITEUP = getNodeById($$PNODE{group}[0]);

  my $SNODE = getNode($figures{$secondary}, 'e2node');
  return "$figures{$secondary} not found!" unless $SNODE;
  my $SWRITEUP = getNodeById($$SNODE{group}[0]);

  my $str = "";

  $str .= q|<table width=100% border=0 cellpadding=3 cellspacing=1>|;
  $str .= q|<tr><TH width=50%>Primary Hexagram</TH><TH width=50%>Secondary Hexagram</TH></TR>|;
  $str .= q|<TR><td width=50% valign=top>|;

  $str .= "<center>".linkNode($PNODE)."</center></td><td width=50% valign=top>";
  $str .= "<center>".linkNode($SNODE)."</center></tr>";

  $str .= q|<tr bgcolor=black><td colspan=2>|;
  $str .= q|<table width=100% bgcolor=black cellpadding=2 cellspacing=0><tr><td align=center width=50%>|;
  $str .= htmlcode('generatehex', $primary)."</td><td width=50% align=center>";
  $str .= htmlcode('generatehex', $secondary)."</td></tr></table>";

  $str .= "</td></tr><tr><td valign=top width=50%>";
  $str .= "<p>".parseLinks($$PWRITEUP{doctext});
  $str .= "</td><td valign=top width=50%>";
  $str .= "<p>".parseLinks($$SWRITEUP{doctext});

  $str .= "</td></tr></table>";

  $str .= q|<br><p align=right>|;
  $str .= q|<i>The [Everything I Ching] is brought to you by [The Gilded Frame] and [nate]</i>|;
  $str .= q|<p align=center><font size=5>|.linkNode($NODE, 're-divine').q|</font>|;

  return $str;
}

sub everything_poll_archive
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $numtoshow=10;
  my $startat = int($query->param("startat"))||0;

  my @polls = $DB->getNodeWhere({poll_status => 'closed'}, 'e2poll', "e2poll_id DESC LIMIT $startat, $numtoshow");

  my $str = '<ul>';

  foreach (@polls)
  {
    $str .= '<li>'.htmlcode('showpoll', $_).'</li>';
  }

  $str .= '</ul>';

  my $PrevLink = '';
  $PrevLink = linkNode($NODE, 'previous', {startat => $startat-$numtoshow}) if $startat;
  my $NextLink = '';
  $NextLink = linkNode($NODE,'next',{startat => $startat + $numtoshow}) if scalar @polls == $numtoshow;

  $str .= qq'<p align="right" class="pagination">$PrevLink $NextLink</p>';

  return $str;

}

sub everything_poll_creator
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $pollgod = 'mauler';
  my $turnPollsOff=0;
  return 'Sorry, poll creation has been temporarily disabled.' if ($turnPollsOff);

  #new restrict check for any usergroup
  my $isRoot = $APP->isAdmin($USER);

  #my $userlevel=$APP->getLevel($USER);
  #return 'You must be Level 3 to create polls. Sorry.' if (($userlevel<3)&&(!$isRoot));

  my $str = q|<h3>Important! Read this or weep!</h3>|;
  $str .= q|<ul>|;
  $str .= q|<li>Welcome to the E2 Poll Creator! Please use this form to create a poll on any topic that interests you. Please do not abuse this privilege</li>|;
  $str .= q|<li>By default, all polls have a "None of the above" option at the end. Be imaginative and use as many of the available option slots as possible so that it will not be needed.</li>|;
  $str .= qq|<li>People cannot vote on a poll until the current poll god, [$pollgod\[user]], has made it the [Everything User Poll[superdoc]\|Current User Poll].</li>|;
  $str .= q|<li>Old completed polls are at the [Everything Poll Archive[superdoc]]. New polls in the queue for posting are at [Everything Poll Directory[superdoc]]. For more information, see [Polls[by Virgil]]. </li>|;
  $str .= qq|<li>If you accidentally stumbit a poll before it is complete, /msg [$pollgod\[user]], who will delete it.</li>|;
  $str .= q|<li>You cannot create a poll without a question, without a title, or with the same title as an existing poll.</li>|;
  $str .= q|</ul><form name="pollmaker" method="post"><input type="hidden" name="op" value="new">|;
  $str .= q|<input type="hidden" name="type" value="e2poll"><fieldset><legend>Sumbit a new poll</legend><table>|;
  $str .= q|<tr><th align="right">Title:</th>|;
  $str .= q|<td><input type="text" size="50" maxlength="64" name="node" value=""></td>|;
  $str .= q|</tr>|;
  $str .= q|<tr><th align="right">Question:</th>|;
  $str .= q|<td><input type="text" size="50" maxlength="255" name="e2poll_question" value=""></td>|;
  $str .= q|</tr>|;
  $str .= q|<tr><th align="left" colspan="2">Answers:</th></tr>|;

  for (1 .. 12)
  {
    $str .= qq|<tr><th align="right">$_:</th>|;
    $str .= qq|<td> <input type="text" size="50" maxlength="255" name="option$_" value=""></td>|;
    $str .= qq|</tr>|;
  }

  $str .= q|<tr><th>And finally:</th><td>None of the above</td></tr>|;
  $str .= q|</table><input type="submit" value="Create Poll"></fieldset></form>|;

  return $str;
}

sub everything_poll_directory
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $isRoot = $APP->isAdmin($USER);

  my $dailypoll = '';
  $dailypoll = $query->param('dailypoll') if $isRoot;
  my $poll_id = $query->param("poll_id");
  my $oldpolls = $query->param("oldpolls")||0;
  my $pollfilter = undef;
  my $pollLink = "";
  my %oldPollParameter = ();

  if ($oldpolls)
  {
    $pollLink = linkNode($$NODE{node_id}, 'Hide old polls');
    %oldPollParameter = (oldpolls => 1);
  }else{
    $pollfilter = {'poll_status !' => 'closed'};
    $pollLink = linkNode($$NODE{node_id}, 'Show old polls', {oldpolls => 1});
  }

  if ($dailypoll)
  {
    $DB->sqlUpdate('e2poll', {poll_status => 'closed'}, "poll_status='current'");
    $DB->sqlUpdate('e2poll', {poll_status => 'current'}, "e2poll_id=$poll_id");

    htmlcode('addNotification', 'e2poll', '', {e2poll_id => $poll_id});
  }

  my ($PrevLink, $NextLink) = ("","");
  my $numtoshow=8;

  my $startat = $query->param("startat")||0;
  if ($startat)
  {
    my $finishat=$startat-$numtoshow;
    $PrevLink=linkNode($NODE,'previous',{startat => $finishat, %oldPollParameter});
  }

  my @nodes = $DB->getNodeWhere($pollfilter, 'e2poll', "e2poll_id DESC LIMIT $startat, $numtoshow");
  my $str = "";

  $str .= '<p>Go to the <b>'.linkNodeTitle('Everything User Poll[superdoc]').'</b>.';
  $str .= '</p><p>'.$pollLink.'.' if $isRoot;
  $str .= '</p><ul>';

  foreach my $n (@nodes)
  {
    getRef $n;
    $str .= '<li>'.htmlcode('showpoll', $n, 'show status');

    if ($isRoot)
    {
      $str .= '<p>'.($$n{poll_status} ne 'current'
        ? linkNode($$NODE{node_id}, 'make current'
        , {poll_id => $$n{node_id}, dailypoll => 1}).' | ': '')
	.linkNode($n, 'edit', {displaytype => 'edit'})
        .' | '
        .linkNode($n, 'delete', {node_id => $$n{node_id}, confirmop => 'nuke'})
        .'</p>';
    }

    $str .= '</li>';
  }

  if (scalar @nodes == $numtoshow)
  {
    $NextLink = linkNode($NODE, 'next', {startat => $startat + $numtoshow, %oldPollParameter});
  }
	
  $str.= qq'</ul><p align="right" class="pagination">$PrevLink $NextLink</p>';
  return $str;

}

sub everything_quote_server
{
  return qq|<br><br><b><font size="3"><div id="quoteserver" align="center"></div></font></b><br><br><br>|;
}

sub everything_user_poll
{
  return htmlcode('showcurrentpoll');
}

sub everything_user_search
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = q|<p>Here you can list all the writeups contributed by any user.</p>|;

  $str .= htmlcode('openform','-method','get');
  
  $str .= q|<fieldset><legend>Choose user</legend>|;
  $str .= q|<label>User name:|;

  my @friends = (
    'lawnjart', 'clampe', 'dem bones', 'Jet-Poop', 'dannye', 'sensei', 'jessicapierce',
    'junkpile', 'Lord Brawl', 'ToasterLeavings', 'wharfinger', 'Lometa', 'riverrun',
    'jaybonci', 'Quizro', 'Demeter', 'ideath', 'dann', 'Evil Catullus', 'Mr. Hotel',
    'Roninspoon', 'wertperch', 'anthropod', 'Professor Pi', 'Igloowhite', 'iceowl',
    'panamaus', 'sid', 'Oolong', 'mauler', 'aneurin', 'Wiccanpiper', 'avalyn', 'TheDeadGuy',
    'The Debutante', 'LaggedyAnne', 'Junkill', 'Jack', 'Timeshredder', 'Noung',
    'The Custodian', 'Tem42', 'Aerobe', 'Auspice');

  my $friend = $query->param('usersearch');

  $friend ||= $friends[rand(@friends)];

  $str .=  
   $query->textfield('usersearch', $friend)
   . $query->hidden('showquery')
   ;

  $str .= q|</label>|;

  $str .= q|<label>Order By:|;

  my $choices = [
    'writeup.publishtime DESC', 'writeup.publishtime ASC',
    'node.title ASC', 'node.title DESC',
    'node.reputation DESC', 'node.reputation ASC',
    'writeup.wrtype_writeuptype ASC', 'writeup.wrtype_writeuptype DESC',
    'length(node.title) ASC', 'length(node.title) DESC',
    'node.hits ASC', 'node.hits DESC',
    'RAND()'];

  my $labels = {
    'writeup.publishtime DESC' => 'Age, Newest First',
    'writeup.publishtime ASC' => 'Age, Oldest First',
    'node.title ASC' => 'Title, Forwards (...012...ABC...)',
    'node.title DESC' => 'Title, Backwards (...ZYX...210...)',
    'node.reputation DESC' => 'Reputation, Highest First',
    'node.reputation ASC' => 'Reputation, Lowest First',
    'writeup.wrtype_writeuptype ASC' => 'Type (person, thing, idea, place, ...)',
    'writeup.wrtype_writeuptype DESC' => 'Type (..., place, idea, thing, person)',
    'length(node.title) ASC' => 'Title Length, Shortest First',
    'length(node.title) DESC' => 'Title Length, Longest First',
    'node.hits DESC' => 'Times Viewed, Most First',
    'node.hits ASC' => 'Times Viewed, Least First',
    'RAND()' => 'Random'};

  # while we have the options, check parameter validity:
  # don't let user execute arbitrary SQL -- VERY BAD

  $query->delete('orderby') if $query->param('orderby') and not $$labels{$query->param('orderby')};

  $str .= $query->hidden('filterhidden') .
    $query->popup_menu(
      -name => 'orderby',
      -values => $choices,
      -labels => $labels,
      -default => 'writeup.publishtime DESC');

  $str .= q|</label>|;

  $str .= q|<input type="submit" name="submit" value="submit"></fieldset></form>|;

  # keep all necessary parameters in %params hash for sort/filter links
  my %params = $query->Vars();
  my $us = $APP->htmlScreen($params{usersearch}); #user's title to find WUs on

  unless($us)
  {
    $str .= '<p>Please give a user name.</p>';
  }else{
    #quit if invalid user given
    my $user = getNode($us, 'user');

    unless($user)
    {
      $str .= 'It seems that the user "'.$us.'" doesn\'t exist... how very, very strange... (Did you type their name correctly?)';
    }else{

      if($user->{title} eq 'EDB')
      {
        $str .= '<p align="center"><big><big><strong>G r o w l [EDB reads his Message Inbox|!]</strong></big></big>';
      }else{

        # constants
        my $typeID = getId(getType('writeup')) or return "Ack! Can't get writeup nodetype.";
        my $perpage = 50;	# number to show at a time

        my $uid = getId($user);	# lowercase = user searching on
        my $UID = $$USER{node_id}; # uppercase = user that is viewing
        my $isRoot = $APP->isAdmin($USER);
        my $isEd = $APP->isEditor($USER);
        my $isMe = ($uid == $UID) && ($uid!=0);
        my $rep = $isMe || $isEd;
        my $isGuest = $APP->isGuest($USER);

        # remove url-derived and other superfluous parameters, include defaults
        delete @params{qw(node node_id type op submit)};
        delete $params{page} unless(defined($params{page}) and $params{page} > 1);
        $params{usersearch} = $$user{title}; # clean/right case for links
        $params{orderby} ||= 'writeup.publishtime DESC';

	$params{filterhidden} = 0 if not defined($params{filterhidden});
	$params{filterhidden} = (0,1,2)[int $params{filterhidden}] if $rep;

        # set up query
        my $edSelect = '';
        $edSelect = ", (SELECT 1 FROM nodenote
          WHERE nodenote.noter_user != 0
          AND (nodenote.nodenote_nodeid = node.node_id
          OR nodenote.nodenote_nodeid = writeup.parent_e2node)
          LIMIT 1 ) AS hasnote" if $isEd;

        my ($voteSelect, $voteJoin) = ('','');
        ($voteSelect, $voteJoin) = (
          ', vote.weight'
          , "LEFT OUTER JOIN vote ON vote.voter_user = $UID AND vote.vote_id = node.node_id"
          ) unless $isGuest;

        my ($filter, $showFilter) = ('','');
        ($filter, $showFilter) = (
          'AND writeup.notnew '.('= 0', '!= 0')[$params{filterhidden}-1]
          , ' published '
          .('not ')[$params{filterhidden}-1]
          .'hidden' ) if $params{filterhidden};

        my @sqlQuery = (
          "node.node_id, writeup.parent_e2node, writeup.cooled,
            type.title AS type_title, node.reputation, writeup.notnew, writeup.publishtime,
            $uid AS author_user
            $voteSelect
            $edSelect", 
          "node LEFT OUTER JOIN writeup
            ON writeup.writeup_id = node.node_id $voteJoin
            JOIN node AS type ON type.node_id=writeup.wrtype_writeuptype",
          "node.author_user = $uid
            AND node.type_nodetype = $typeID $filter",
          "ORDER BY $params{orderby}, node.node_id ASC LIMIT $perpage");

        # utility functions for display
        my $tweakedLink = sub{
          # returns a sorting link with the current parameters, as overridden by given values
          # arguments:
          # $text - link text
          # $settings - hash ref of override values

          my($text, $settings) = @_;
          delete $$settings{page} unless (defined($$settings{page}) and $$settings{page} > 1);

          return "<strong>$text</strong>"
          unless scalar map {$$settings{$_} ne $params{$_} ? 1 : ()} keys %$settings;

          my %linkParams = %params;
          @linkParams{keys %$settings} = @$settings{keys %$settings};
          return linkNode($NODE, $text, \%linkParams);
        };

        my $sortLink = sub{
          # returns a heading sort up/down choice

          my ($disp1, $disp2, $orderField, $backwards) = @_;
          my ($sort1, $sort2) = ("$orderField ASC", "$orderField DESC");
          ($sort1, $sort2) = ($sort2, $sort1) if $backwards;

          return &$tweakedLink($disp1, {orderby => $sort1}). '/'
            . &$tweakedLink($disp2, {orderby => $sort2});
        };

        # header
        my $head = '';
        $head = '<h2>query arguments:</h2><pre>'
          .encodeHTML(join "\n,\n", @sqlQuery)
          .'</pre>' if $isRoot && $params{showquery};

        if($rep)
        {
          # explain extra information, and offer choice based on it
          $head .= qq!<p><small>Writeups published with '<em>Don't display in "New Writeups"</em>' checked have "H" for <strong>h</strong>idden in the "H" column.!;
          $head .= ' Writeups with node notes have "N" in the "HN" column.' if $isEd;
          $head .= '</small></p><p>Show: '
            .&$tweakedLink('all writeups', {filterhidden => 0})
            .', '
            .&$tweakedLink('only unhidden writeups', {filterhidden => 1})
            .', '
            .&$tweakedLink('only hidden writeups', {filterhidden=> 2})
            .'</p>';
        }

        # build table header row, sort row and instructions for content rows in parallel

        # defining width here stops IE7 wrapping later
        my $thRow ='<tr><th align="center"><abbr title="Cools" style="width:2em">C!s</abbr></th><th align="left">Writeup Title (type)</th>';

        my $sortRow = '<tr><td>&nbsp;</td><td align="left"><small>'
          .&$sortLink('forwards', 'backwards', 'node.title')
          .'</small></td>';

        my $instructions = '<tr class="&oddrow">c, "<td align=\'left\'>", parenttitle, type, "</td>"';

        my %funx = (
          c => sub {
            my $cMsg = '&nbsp;';
            my $numCools = $_[0]->{cooled};
            if ($numCools)
            {
              $cMsg = "${numCools}C!";
              $cMsg .= 's' if $numCools > 1;
              $cMsg = "<strong>$cMsg</strong>";
            }
            return '<td align="center">' . $cMsg . '</td>';
          }
        );

        if ($rep)
        {
          $thRow .= '<th colspan="2" align="center"><abbr title="Reputation">Rep</abbr></th>';
          $sortRow .= '<td colspan="2" align="center"><small>'
            .&$sortLink('inc', 'dec', 'node.reputation').'</small></td>';
          $instructions .= ',rep';
          $funx{rep} = sub {
            my $wu = shift;
            my $r = $$wu{reputation} || 0;

            my $votescast = $DB->{dbh}->selectall_hashref(
              "SELECT weight, COUNT(voter_user) AS total
              FROM vote
              WHERE vote_id = $$wu{node_id}
              GROUP BY weight", 'weight'
            );

            my $p = $votescast->{1}->{total} || 0;
            my $m = $votescast->{-1}->{total} || 0;

            return qq'<td class="reputation">$r</td><td class="reputation"><small>+$p/-$m</small></td>';
          };
        }

        unless ($isMe || $isGuest)
        {
          $thRow .= '<th><abbr title="Your vote">Vote</abbr></th>';
          $sortRow .= '<td>&nbsp;</td>';
          $instructions .=',vote';
          $funx{vote} = sub{
            '<td align="center">'
            .('-', '&nbsp;', '+')[(defined($_[0]->{weight})?($_[0]->{weight}+1):(1))]
            .'</td>';
            };
        }

        if ($rep)
        {
          $thRow .= '<th><abbr title="H=Hidden';
          my $flags = 'H';
          $sortRow .= '<td>&nbsp;</td>';
          $instructions .= ',hn';
          $funx{hn} = sub{
            '<td align="center">'.($_[0]->{notnew} ? 'H' : '').($_[0]->{hasnote} ? 'N' : '').'</td>';
          };

	  if($isEd)
          {
            $thRow .= ', N=Has node note';
            $flags .= 'N';
          }

          $thRow .= qq'">$flags</abbr></th>';
        }

        $thRow .= '<th align="center">Published</th></tr>';
        $sortRow .= '<td align="center"><small>'
          .&$sortLink('newest','oldest', 'writeup.publishtime', 1).' first</small></td></tr>';
        $instructions .= ', "<td align=\'right\'><small>", listdate , "</small></td>"';

        # get it...
        my ($wulist, $pages, $countWUs, $startRow, $lastRow) =
          htmlcode('show paged content', @sqlQuery, $instructions, %funx);

          my $userHas = $isMe ? 'You have' : linkNode($user).' has';

        unless($countWUs)
        {
          $str .= "$head<p>$userHas no writeups$showFilter.</p>";
        }else{
          $countWUs = ($countWUs == 1 ? 'one writeup' : "$countWUs writeups").$showFilter
          .($countWUs > $perpage ? ". Showing writeups $startRow to $lastRow" : '');
        }

        $str .= "$head<p>$userHas $countWUs:</p>";
        $str .= qq|<table border='0' cellspacing='0' width='100%'>$thRow$sortRow$wulist</table>|;
	$str .= $pages;
      }
    }
  }
  return $str;
}

sub everything_s_best_users
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p align="right"><small>[News for noders.  Stuff that matters.]</small></p>|;

  # Form toolbar (check boxes and Change button)
  $str .= qq|<p align="right">|;
  $str .= "<small>If you miss the merit display, you can go and complain to [ascorbic], but try getting some perspective first.</small>" if $$VARS{ebu_showmerit};

  if ( !$APP->isGuest($USER) )
  {
    # Clear/reset the form control variables
    delete $$VARS{ebu_showmerit}; # if($query->param("gochange"));
    delete $$VARS{ebu_showdevotion} if($query->param("gochange"));
    delete $$VARS{ebu_showaddiction} if($query->param("gochange"));
    delete $$VARS{ebu_newusers} if($query->param("gochange"));
    delete $$VARS{ebu_showrecent} if($query->param("gochange"));
    # $$VARS{ebu_showmerit} = 1 if($query->param("ebu_showmerit") eq "on");
    $$VARS{ebu_showdevotion} = 1 if($query->param("ebu_showdevotion") eq "on");
    $$VARS{ebu_newusers} = 1 if($query->param("ebu_newusers") eq "on");
    $$VARS{ebu_showaddiction} = 1 if($query->param("ebu_showaddiction") eq "on");
    $$VARS{ebu_showrecent} = 1 if($query->param("ebu_showrecent") eq "on");

    # Show the mini-toolbar 
    $str .= htmlcode("openform")
    # . "<input type=\"checkbox\" name=\"ebu_showmerit\" "
    # . ($$VARS{ebu_showmerit}?' CHECKED ':'')
    # . ">Display by merit "
    . "<input type=\"checkbox\" name=\"ebu_showdevotion\" "
    . ($$VARS{ebu_showdevotion}?' CHECKED ':'')
    . ">Display by [devotion] "
    . "<input type=\"checkbox\" name=\"ebu_showaddiction\" "
    . ($$VARS{ebu_showaddiction}?' CHECKED ':'')
    . ">Display by [addiction] "
    . "<input type=\"checkbox\" name=\"ebu_newusers\" "
    . ($$VARS{ebu_newusers}?' CHECKED ':'')
    . ">Show New users  "
    . "<input type=\"checkbox\" name=\"ebu_showrecent\" "
    . ($$VARS{ebu_showrecent}?' CHECKED ':'')
    . ">Don't show fled users &nbsp;<input type=\"hidden\" "
    . "name=\"gochange\" value=\"foo\">"
    . "<input type=\"submit\" value=\"change\"></p>";
  } else {
    # No toolbar for the Guest User.
    return '';
  }

  $str .= qq|<p>Shake these people's manipulatory appendages.  They deserve it.<br /><em>A drum roll please....</em></p>|;

  $str .= qq|<!-- Start the TABLE ...  --->|;
  $str .= qq|<table border="0" width="70%" align="center">|;
  $str .= qq|<!-- I left this out of the code block to avoid escaping the quotes. -->|;
  $str .= qq|<tr bgcolor="#ffffff">|;

  # Find out the date 2 years ago
  my $rows = undef;
  my $datestr = undef;

  my $queryText = "SELECT DATE_ADD(CURDATE(), INTERVAL -2 YEAR)";
  $rows = $DB->{dbh}->prepare($queryText);
  $rows->execute();
  $datestr = $rows->fetchrow_array();

  # Body of the table

  # Declare and init the string that contains our whole HTML stream.

  # Build the rest of the table's heading row
  $str .= "<th></th><th>User</th>";
  # ... only include the Merit column if the checkbox is on.
  if ( $$VARS{ebu_showmerit} )
  {
    $str .= "<th>Merit</th>";
  }

  if ( $$VARS{ebu_showdevotion} )
  {
    $str .= "<th>Devotion</th>";
  }

  if ( $$VARS{ebu_showaddiction} )
  {
    $str .= "<th>Addiction</th>";
  }

  $str .= "<th>Experience</th><th># Writeups</th><th>Rank</th><th>Level</th>";
  $str .= "</tr>";

  # Build the database query
  # ... skip these users

  my $skip = {
    'dbrown'=>1,
    'nate'=>1,
    'hemos'=>1,
    'Webster 1913'=>1,
    'Klaproth'=>1,
    'Cool Man Eddie'=>1,
    'ShadowLost'=>1,
    'EDB'=>1,
    'everyone'=>1,
  };

  # ... set the query limits (including 'no monkeys')
  my $maxShow = 60;
  my $limit = $maxShow;

  $limit += (keys %$skip);

  my $recent = '';
  if ($$VARS{ebu_newusers})
  {
    $recent = " and (select createtime from node where node_id=user.user_id)>'$datestr 00:00:00'";
  }

  # use the same cutoff date for fled users that we do for recent users
  # the old code cut off recent users at 2 years and fled users at 1 year

  my $noFled = '';
  if ($$VARS{ebu_showrecent})
  {
    $noFled = " and user.lasttime>'$datestr 00:00:00' ";
  }

  # Run the query
  my $csr = '';
  if ( $$VARS{ebu_showmerit} )
  {
    # Query for all users with >24 writeups, sort by merit
    $csr = $DB->sqlSelectMany("user_id", "user", "numwriteups > 24 $noFled order by merit desc limit $limit");
  }

  if ( $$VARS{ebu_showdevotion} )
  {
    # Query for all users with >24 writeups, sort by merit
    $csr = $DB->sqlSelectMany("user_id", "user", "numwriteups > 24 $noFled order by (numwriteups*merit) desc limit $limit");
  }

  if ( $$VARS{ebu_showaddiction} )
  {
    # Query for all users with >24 writeups, sort by merit
    $csr = $DB->sqlSelectMany("user_id, ((numwriteups*merit)/datediff(now(),node.createtime)) as addiction", "user, node", "numwriteups > 24 $noFled and node.node_id=user.user_id order by addiction desc limit $limit");
  }

  if ($csr eq '')
  {
    # default
    # Query for all users, sort by XP (classic EBU sort)
    $csr = $DB->sqlSelectMany("user_id", "user", "user_id > 0 $noFled $recent order by experience desc limit $limit");
  }

  # Set up to loop over the result set
  my $uid = getId($USER) || 0;
  my $isMe = 0;
  my $step = 0;
  my $color = '';
  my $range = { 'min' => 135, 'max' => 255, 'steps' => $maxShow };

  my $curr = 0;
  my $lvlttl = getVars(getNode('level titles', 'setting'));
  my $lvl = 0;

  # Loop over the result set and display each row
  my $place=0;
  while(my $nid = $csr->fetchrow_hashref)
  {
    my $node = getNodeById($nid->{user_id});
    next if(exists $$skip{$$node{title}});
    next if($step >= $maxShow);

    # This record is for the person who is logged in
    $isMe = $$node{node_id}==$uid; 

    $lvl = $APP->getLevel($node);

    # Get the user vars for the user of record
    my $V = getVars($node);

    # Fled users may have actual #numwriteups < 25 if they've
    # had writeups nuked since they last logged in.
    next unless $$V{numwriteups};	#if no WUs, less-than test breaks
    next if (($$V{numwriteups} < 25) && (!$$VARS{ebu_newusers}));
    # Devotion is broken because numwriteups in the db isn't accurate
    # ($$V{numwriteups} is accurate, though)
    my $devo = int(($$V{numwriteups} * $$node{merit}) + .5);
    my $merit = sprintf('%.2f', $$node{merit} || 0);

    $curr = $$range{max} - (($$range{max} - $$range{min})/$$range{steps}) * $step;
    $curr = sprintf('%02x', $curr);
    $color = '#' . $curr . $curr . $curr;

    $str.= "<tr bgcolor=\"$color\" >";
    $str.="<td align=\"center\"><small>";
    $str.=++$place;
    $str.="</small></td><td>";
    $str.=($isMe ? '<strong>' : '');
    $str.=(linkNode($node,0,{lastnode_id=>undef}));
    $str.=($isMe ? '</strong>' : '') . "</td>";
    if ( $$VARS{ebu_showmerit} )
    {
      $str.= "<td>$merit</td>";
    }

    if ( $$VARS{ebu_showdevotion} )
    {
      $str.= "<td>$devo</td>";
    }
    
    if ( $$VARS{ebu_showaddiction} )
    {
      my $addict = sprintf('%.3f',$nid->{addiction});
      $str.= "<td>$addict</td>";
    }
    
    $str.="<td>$$node{experience}</td><td>$$V{numwriteups}</td><td>$$lvlttl{$lvl}</td><td>$lvl</td></tr>\n";

    ++$step;
  }

  $str .= qq|</table>|;
  return $str;
}

sub everything_s_best_writeups
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return 'Curiosity killed the cat, ya know.' unless( $APP->isEditor($USER) );

  my $str = 'Everything\'s 50 "Most Cooled" Writeups (visible only to staff members):';
  my $csr = $DB->{dbh}->prepare('SELECT writeup_id FROM writeup ORDER BY cooled DESC LIMIT 50');

  $csr->execute();

  $str .= '<br><br><table><tr bgcolor="#CCCCCC"><td width="200">Writeup</td><td width="200">Author</td></tr>';
  while(my $row = $csr->fetchrow_hashref())
  {
    my $bestnode = getNodeById($$row{writeup_id});
    next unless($bestnode);

    my $bestparent = getNodeById($$bestnode{parent_e2node});
    my $bestuser = getNodeById($$bestnode{author_user});

   $str.='<tr><td>'.linkNode($bestnode, $$bestnode{title}).' - '.linkNode($bestparent, 'full').' <b>'.$$bestnode{cooled}.'C!</b></td><td> by '.linkNode($bestuser, $$bestuser{title}).'</td></tr>';
  }

  $str .= '</table>';

  return $str;
}

sub page_of_cool
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @grp = (@{getNode("gods","usergroup")->{group} || []},@{getNode("Content Editors","usergroup")->{group} || []}, @{getNode("exeds","nodegroup")->{group} || []});
  my $except = {};

  foreach my $except_user("Cool Man Eddie","EDB","Webster 1913","Klaproth","PadLock")
  {
    my $user = $DB->getNode($except_user, "user");
    if($user)
    {
      $except->{$user->{node_id}} = 1
    }
  }
  @grp = sort {lc(getNodeById($a)->{title}) cmp lc(getNodeById($b)->{title})} @grp;
  my $first_block = "Browse through the latest editor selections below, or choose a specific editor (or former editor) to see what they've endorsed:";

  $first_block.=htmlcode("openform");
  $first_block.="<select name=\"editor\">";
  foreach(@grp){
    $first_block.="<option value=\"$_\"".(($query->param("editor")."" eq "$_")?(" SELECTED "):("")).">".getNodeById($_)->{title}."</option>" unless($except->{$_}) || not getNodeById($_)->{type}->{title} eq "user";
    $except->{$_} = 1;
  }

  $first_block.="</select><input type=\"submit\" value=\"Show Endorsements\"></form>";

  my $ed = $query->param("editor");
  $ed =~ s/[^\d]//g;

  if($ed && getNodeById($ed)->{type}->{title} eq "user")
  {
    my $csr = $DB->sqlSelectMany("node_id", "links left join node on links.from_node=node_id", "linktype=".getId(getNode("coollink", "linktype"))." and to_node='$ed' order by title");

    my $innerstr;
    my $count = 0;
    while(my $row = $csr->fetchrow_hashref)
    {
      $count++;
      my $n = getNodeById($$row{node_id});
      $$n{group} ||= [];
      my $num = scalar(@{$$n{group}});
      $innerstr.="<li>".linkNode($n).
        (($$n{type}{title} eq "e2node")?
        (" - $num writeup".(($num == 0 || $num > 1)?("s"):(""))):
        (" - ($$n{type}{title})"))."</li>";
    }

    $first_block.=linkNode(getNodeById($ed))." has endorsed $count nodes<br><ul>$innerstr</ul>";

  }

  my $second_block = qq|<table width="100%" cellpadding="2" cellspacing="0" border="0"><tr align="left"><th>Title</th><th>Cooled by</th></tr>|;

  my $COOLNODES = getNode 'coolnodes', 'nodegroup';
  my $COOLLINKS = getNode 'coollink', 'linktype';
  my $cn = $$COOLNODES{group};
  my $clink = getId $COOLLINKS;

  my $return = '';
  my $increment = 50;
  my $next = $query->param('next');
  $next ||= 0;

  my $count = 0;


  foreach (reverse @$cn) {
    $count++;
    next if $count < $next;
    last if $count > $next+$increment;
    my $csr = $DB->{dbh}->prepare("select * from links where from_node=".getId($_)." and linktype=$clink");
    my $str = '<tr class="';
    $str .= ( int($count) & 1 ) ? 'oddrow' : 'evenrow';
    $str .= '">';
    $csr->execute;
    my $link = $csr->fetchrow_hashref;
    $csr->finish;
    $str.= '<td>'.linkNode($_).'</td>';
    if ($link) {
      $str.='<td>'.linkNode($$link{to_node}).'</td>';
    } else {
      $str.='<td>&nbsp;</td>';
    }
    $str.="</tr>\n";
    $second_block .= $str;
  }
  my $next_elements ='<tr><td>';

  if ($next > 0) {
    $next_elements.=linkNode($NODE, "prev $increment", {next => $next-$increment});
  } else {
    $next_elements.='&nbsp;';
  }
  $next_elements.='</td><td>';

  if ($next+$increment < @$cn) {
    $next_elements.=linkNode($NODE, "next $increment", {next => $next+$increment});
  } else {
    $next_elements.='&nbsp;';
  }

  $second_block.=$next_elements.'</td></tr></table>';

  return $first_block.$second_block;
}

sub news_archives
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $isGod = $APP->isAdmin( $USER );
  my $isEd = $APP->isEditor( $USER );
  my $webloggables = getVars(getNode("webloggables", "setting"));
  my $view_weblog = $query->param('view_weblog');
  my $skipped = 0;
  my @labels = ();

  foreach my $node_id (sort { lc($$webloggables{$a}) cmp lc($$webloggables{$b}) } keys(%$webloggables)){
    my $title =  $$webloggables{$node_id};
    my $wclause = "weblog_id='$node_id' AND removedby_user=''";
    my $count = $DB->sqlSelect('count(*)','weblog',"$wclause");
    my $link = linkNode($NODE,$title,{'view_weblog'=>"$node_id"});
    $link = "<b>$link</b>" if $node_id == $view_weblog;
    push @labels, "$link<br /><font size='1'>($count node".
    ($count==1?'':'s').')</font>';
  }

  my $text = "";
  if (!$view_weblog) {
    $text = "<table border='1' width='100%' cellpadding='3'>";

    my $labelcount=0;
    foreach (@labels) {
      if ($labelcount % 8 ==0) {$text.="<tr>";}
      $text .= "<td align='center'>".$_."</td>";
      if ($labelcount % 8 == 7) {$text.="</tr>";}
      $labelcount++;
    }

    $text.="</table>";

    return $text;
  }

  return $text if (($view_weblog == 114)||($view_weblog==923653))&&(!($isEd));

  if($isGod && (my $unlink_node = $query->param('unlink_node'))){
    $unlink_node =~ s/\D//g;
    $DB->sqlUpdate('weblog',{'removedby_user'=>$$USER{user_id}},
       "weblog_id='$view_weblog' AND to_node='$unlink_node'");
  }

  $text .= '<p align="center"><font size="3">Viewing news items for <b>'.
           linkNode(getNode($view_weblog)).'</b></font> - <small>[News Archives|back to archive menu]</small></p>';

  $text .= "<table border='1' width='100%' cellpadding='3'>".
         "<tr><th>Node</th><th>Time</th><th>Linker</th>".
         ($isGod?'<th>Unlink?</th>':'').'</tr>';
  my $wclause = "weblog_id='$view_weblog' AND removedby_user=''";
  my $csr = $DB->sqlSelectMany('*','weblog',$wclause,'order by tstamp desc');
  while(my $ref = $csr->fetchrow_hashref()){
    my $N = getNode($$ref{to_node});
    $skipped++ unless $N;
    next unless $N;
    my $link = linkNode($N);
    my $time = htmlcode('parsetimestamp',"$$ref{tstamp},128");
    my $linker = getNode($$ref{linkedby_user});
    $linker = $linker?linkNode($linker):'<i>unknown</i>';
    my $unlink = linkNode($NODE,'unlink?',
      {'unlink_node'=>$$ref{to_node},'view_weblog'=>$view_weblog});
    $text .= "<tr><td>$link</td><td><small>$time</small></td><td>$linker</td>".
             ($isGod?"<td>$unlink</td>":'').'</tr>';
  }
  $text .= "</table>";

  $text .= "<br /><table border='1' width='100%' cellpadding='3'>".
         "<tr><th>$skipped deleted node".($skipped==1?' was':'s were').
         ' skipped</th></tr></table>' if $skipped;

  return $text;
}

sub superbless
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  return '<p>You have not yet learned that spell.</p>' unless $APP->isEditor($USER);
  
  my $str = "";
  if(htmlcode('verifyRequest', 'superbless'))
  {
    my @params = $query->param;
    my @users = ();
    my @gp = ();

    foreach (@params) {
      if(/^EnrichUsers(\d+)$/) {
        $users[$1] = $query->param($_);
       }
       if(/^BestowGP(\d+)$/) {
         $gp[$1] = $query->param($_);
       }
    }

    my $curGP = undef;
    for(my $count=0; $count < @users; $count++)
    {
      next unless $users[$count] and $gp[$count];

      my ($U) = getNode ($users[$count], 'user');
      if (not $U) {
        $str.="couldn't find user $users[$count]<br />";
        next;
      }

      $curGP = $gp[$count];
 
      unless ($curGP =~ /^\-?\d+$/) {
        $str.="$curGP is not a valid GP value for user $users[$count]<br>";
        next;
      }

      my $signum = ($curGP>0) ? 1 : (($curGP<0) ? -1 : 0);

      $str .= "User $$U{title} was given $curGP GP.";
      $APP->securityLog($NODE, $USER, "$$U{title} was superblessed $curGP GP by $$USER{title}");

      if($signum!=0) {
        $$U{karma}+=$signum;
        updateNode($U, -1);
        htmlcode('achievementsByType','karma');
        $APP->adjustGP($U, $curGP);
      } else {
        $str .= ', so nothing was changed';
      }
      $str .= "<br>\n";
    }
  }
  my $count = 10;

  $str .= htmlcode('openform', 'superblessForm')
  . htmlcode('verifyRequestForm', 'superbless')
  . '<table border="1">';

  $str.="<tr><th>Bestow user</th><th>with GP</th></tr> ";

  for (my $i = 0; $i < $count; $i++)
  {
    $query->param("EnrichUsers$i", '');
    $query->param("BestowGP$i", '');
    $str.="<tr><td>";
    $str.=$query->textfield(
      -name => "EnrichUsers$i"
      , -size => 40
      , -maxlength => 80
      , -class => 'userComplete');
    $str.="</td><td>";
    $str.=$query->textfield("BestowGP$i", '', 4, 7);
    $str.="</td></tr>";
  }

  $str .= '</table>'. htmlcode('closeform');

  return $str;
}

sub spam_cannon
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $MAX_VICTIMS = 20;

  my $uid   = getId( $USER );
  my $foad  = "<p><strong>Permission Denied.</strong></p>\n";
  my $level  = $$VARS{ 'level' };

  $level =~ s/([0-9]+).*$/$1/;

  return $foad unless $APP->isEditor($USER);

  my $msgtext = '';
  if ( defined $query->param( 'spam_message' ) ) {
    $msgtext = $query->param( 'spam_message' );
    $msgtext =~ s/&/&amp;/g;
    $msgtext =~ s/\[/&#91;/g;
    $msgtext =~ s/\]/&#93;/g;
    $msgtext =~ s/"/&quot;/g;
  }

  my $str = '<p>The Spam Cannon sends a single /msg to multiple recipients, without having to create a usergroup. Usergroups are not yet supported as recipients, but /msg aliases are. </p><p>The privilege of using this tool will be revoked if abused. </p>' . htmlcode( 'openform2', 'spammer' );

  $str.= qq|<table><tr><td valign="top" align="right" width="100"><p><b>Recipients:</b></p>|;
  $str.= qq|<p><i>Put each username on its own line, and don't hardlink them. Don't bother with underscores.</i></p>|;
  $str.= qq|</td><td><textarea name="recipients" rows="20" cols="30">|;
  $str.= $query->param( 'recipients' );
  $str.= qq|</textarea></td></tr>|;
  $str.= qq|<tr><td valign="top" align="right"><p><b>Message:</b></p></td>|;
  $str.= qq|<td><input type="text" size="40" maxlength="243" name="spam_message" value="$msgtext"></td></tr>|;
  $str.= qq|<tr><td valign="top" colspan="2" align="right"><input type="submit" value="Send"></td></tr></table></form>|;

  if(defined $query->param( 'recipients' ) && defined $query->param( 'spam_message' ))
  {
    my $recipients = $query->param( 'recipients' );
    my $message   = $query->param( 'spam_message' );

    # Remove HTML tags from message
    $message =~ s/<[^>]+>//g;

    # Feedback to user
    $str .= "<dl>\n<dt><b>Sent message:</b></dt>\n";
    $str .= "<dd>" . $message . "</dd>\n";
    $str .= "<dd>&nbsp;</dd>\n";
    $str .= "<dt><b>To users:</b></dt>\n";

    # Remove whitespace from beginning and end of each line in 
    # list of recipients.
    $recipients =~ s/\s*\n\s*/\n/g;

    # Split recipient list into array
    my @users = split( '\n', $recipients );
    my $count = 0;
    my $sent;  # Keep track of who we've sent the /msg to, so as to avoid repeats.

    # Iterate through recipient list
    foreach my $victimname ( @users )
    {
      if ( ++$count > $MAX_VICTIMS )
      {
        $str .= "<dd><font color=\"#c00000\"><strong>Enough.</strong></font> You trying to talk to the whole world at once?</dd>\n";
        last;
      }

      # If it's an alias, get the proper username before getting the user hash.
      my $victim = getNode( $victimname, 'user' );

      if(defined($victim))
      {
        if($victim->{message_forward_to})
        {
          $victim = getNodeById($victim->{message_forward_to});
        }

        # Skip duplicates
        if ($$sent{ $$victim{ 'node_id' } } )
        {
          $str .= "<dd><font color=\"#c00000\">You sent this to " . linkNode( $$victim{ 'node_id' } ) . " already.</font></dd>\n";
          next;
        } else {
          $$sent{ $$victim{ 'node_id' } } = 1;
        }

        # Some feedback for the user
        $str .= "<dd>".linkNode( $$victim{ 'node_id' } )."</dd>\n";

        # Insert message into messages table.
	# $DB->sqlInsert( 'message', { msgtext => "(massmail): " . $message, author_user => $$USER{ 'node_id' }, for_user => $$victim{ 'node_id' } } );
      } else {
        # SAY WHAT?! HE AIN'T HERE! HE DON'T EXIST!
        $str .= "<dd><font color=\"#c00000\">User <b>\"" . $victimname . "\"</b> does not exist.</font></dd>\n";
      }
    }

    $str .= "</dl>\n";
    $str .= "<p>No users specified.</p>\n" if ( $count == 0 );
  }

  $str .= "<br>\n";
  return $str;
}

sub pit_of_abomination
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $str = htmlcode("openform");
  $str .= qq|<p>For they are an Offense in thine Eyes, and that thine Eyes might be freed from the sight of their Works, thou mayest abominate them here. And their feeble Screeds shall not appear in that List which is call&egrave;d New Writeups, nor shall they be shewn amongst the Works of the Worthy in the Nodes of E2. Yet still mayest thou seek them out when thy Fancy is such.|;
  $str .= qq|<fieldset><legend>Abominate</legend>|;
  $str .= qq|<label>Wretch's name:<input type="text" name="abomination"></label>|;
  $str .= qq|<label title="also ignore user's messages and chat"><input type="checkbox" name="pratenot" value="1" checked="checked">disdain also their prattle</label>|;
  $str .= qq|<br><input type="submit" name="abominate" value="Abominate!">|;

  if (scalar($query->param('abominate')) and my $abominame = $query->param( 'abomination'))
  {
    unless(my $abomination = getNode( $abominame , 'user' ))
    {
      $str .= '<p>User '.encodeHTML( $abominame ).' not found.' ;
    } else {
      $$VARS{ unfavoriteusers } .= ',' if $$VARS{ unfavoriteusers } ;
      $$VARS{ unfavoriteusers } .= $$abomination{ user_id } unless $$VARS{ unfavoriteusers } =~ /\b$$abomination{ user_id }\b/ ;
      $str .= htmlcode('ignoreUser', $abominame) if $query -> param('pratenot');
    }
  }

  $str .= qq|</fieldset></form>|;
  $str .= htmlcode("openform");

  if(scalar $query->param('debominate'))
  {
    foreach($query->multi_param('debominees'))
    {
      $$VARS{ unfavoriteusers } =~ s/\b$_\b,?// ;
    }
  }

  $$VARS{ unfavoriteusers } =~ s/,$// ;

  if($VARS->{unfavoriteusers})
  {
    my @abominees = split ',' , $$VARS{ unfavoriteusers } ;
    $str .= '<p>Yet should they swear Betterment and rue their Ways, repenting in Sackcloth and Ashes,
thou mayest in thy great Mercy relent.
<fieldset><legend>Relent</legend>
	'.$query -> checkbox_group( -name => 'debominees' , -values => [ @abominees ] ,
		-labels => { map { $_ => getNodeById( $_ ) -> { title } } @abominees } ,
		-linebreak => 'true' ) .
	$query -> submit( -name=> 'debominate' , -value => 'Relent!' ).'</fieldset>' ;
  } else {
    $str .= '<p>In thy Mercy hast thou stayed thy Hand.';
  }

  $str .= qq|</form>|;
  return $str;
}

sub level_distribution
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>The following shows the number of active E2 users at each level (based on users logged in over the last month).</p>|;

  my $levels = {};
  my $queryText = "SELECT setting.setting_id,setting.vars FROM setting,user WHERE setting.setting_id=user.user_id AND user.lasttime>=DATE_ADD(CURDATE(), INTERVAL -1 MONTH) AND setting.vars LIKE '%level=%'";

  my $rows = $DB->{dbh}->prepare($queryText);
  $rows->execute() or return $rows->errstr;

  while(my $dbrow = $rows->fetchrow_arrayref)
  {
    $dbrow->[1] =~ m/level=([0-9]+)/;
    if(exists($levels->{$1}))
    {
      $levels->{$1} = $levels->{$1}+1;
    }else{
      $levels->{$1} = 1;
    }
  }

  $str .= '<table align="center"><tr><th>Level</th><th>Title</th><th>Number of Users</th></tr>';
  my $ctr = 0;
  foreach my $key (sort {$levels->{$b} <=> $levels->{$a}} (keys(%$levels)))
  {
    $ctr++;

    if($ctr % 2 ==0)
    {
      $str .= '<tr class="evenrow">';
    } else {
      $str .= '<tr class="oddrow">';
    }
    $str .= '<td>'.($key+0).'</td><td style="text-align:center">'.(getVars(getNode('level titles', 'setting'))->{($key+0)} || 0).'</td><td style="text-align:right">'.$levels->{$key}.'</td></tr>';
  }

  $str .= '</table>';
  return $str;
}

sub manna_from_heaven
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $numDays = $query->param("days") || 30;

  my $str="<form method='get'><input type='hidden' name='node_id' value='".$$NODE{node_id}."' /><input type='text' value='$numDays' name='days' /><input type='submit' name='sexisgood' value='Change Days' /></form>";
  my $usergroup = getNodeById(923653); #content editors node

  my $wuCount;
  my $wuTotal = 0;

  $str.="<table width='25%'><tr><th width='80%' >User</th><th width='20%'>Writeups</th></tr>";

  foreach(@{$$usergroup{group}})
  {
    my $u = getNodeById($_);
    next if $$u{title} eq 'e2gods';
    $wuCount = $DB->sqlSelect("count(*)", "node", "type_nodetype=117 and author_user=".$_." and TO_DAYS(NOW())-TO_DAYS(createtime) <=$numDays");
    $wuTotal += $wuCount;
    $str.="<tr><td><b>" . linkNode($u) . "</b></td><td>" . linkNode(getNode('everything user search', 'superdoc'), " $wuCount" , {usersearch => $$u{title}, orderby => 'createtime DESC'}) . "</td></tr>";
  }

  $usergroup = getNodeById(829913); # e2gods

  foreach(@{$$usergroup{group}})
  {
    my $u = getNodeById($_);
    $wuCount = $DB->sqlSelect("count(*)", "node", "type_nodetype=117 and author_user=".$_." and TO_DAYS(NOW())-TO_DAYS(createtime) <=$numDays");
    $wuTotal += $wuCount;
    $str.="<tr><td><b>" . linkNode($u) . "</b></td><td>" . linkNode(getNode('everything user search', 'superdoc'), " $wuCount" , {usersearch => $$u{title}, orderby => 'createtime DESC'}) . "</td></tr>";
  }

  $str.="<tr><td><b>Total</b></td><td>$wuTotal</td></tr>";
  $str.="</table>";

  return $str;

}

sub content_reports
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|These jobs are run on a 24 hour basis and cached in the database. They show user-submitted content that is in need of repair.|;
  $str .= qq|<table style="padding: 2px; margin: 5px;">|;

  my $drivers = 
  {
    "editing_invalid_authors" => 
      {"title" => "Invalid Authors on nodes", "extended_title" => "These nodes do not have authors. Either the users were deleted or the records were damaged. Includes all types"},
    "editing_null_node_titles" => {"title" => "Null titles on nodes", "extended_title" => "These nodes have null or empty-string titles. Not necessarily writeups."},
    "editing_writeups_bad_types" => {"title" => "Writeup types that are invalid", "extended_title" => "These are writeup types, such as (thing), (idea), (definition), etc that are not valid"},
    "editing_writeups_broken_titles" => {"title" => "Writeup titles that aren't the right pattern", "extended_title" => "These are writeup titles that don't have a left parenthesis in them, which means that it doesn't follow the 'parent_title (type)' pattern."},
    "editing_writeups_invalid_parents" => {"title" => "Writeups that don't have valid e2node parents", "extended_title" => "These nodes need to be reparented"},
    "editing_writeups_under_20_characters" => {"title" => "Writeups under 20 characters", "extended_title" => "Writeups that are under 20 characters"},
    "editing_writeups_without_formatting" => {"title" => "Writeups without any HTML tags", "extended_title" => "Writeups that don't have any HTML tags in them, limited to 200, ignores E1 writeups."},
    "editing_writeups_linkless" => {"title" => "Writeups without links", "extended_title" => "Writeups post-2001 that don't have any links in them"},
    "editing_e2nodes_with_duplicate_titles" => {"title" => "Writeups with titles that only differ by case", "extended_title" => "Writeups that only differ by case"},
  };

  if($query->param("driver"))
  {
    my $driver = $query->param("driver");
    my $datanode = getNode($driver, "datastash");

    if($datanode and exists $drivers->{$driver})
    {
      my $data = $DB->stashData($driver);
      $data = [] unless(UNIVERSAL::isa($data, "ARRAY"));
      $str .= "<h2>".$drivers->{$driver}->{title}.qq|</h2><br />|;
      $str .= "<p>".$drivers->{$driver}->{extended_title}.qq|</p>|;

      if(scalar(@$data))
      {
        $str .= "<ul>";
        foreach my $node_id (@$data)
        {
           my $N = getNodeById($node_id);
           if($N)
           {
             $str .= qq|<li><a href="/?node_id=$node_id">node_id: $node_id title: |.($N->{title} || "")." type: $N->{type}->{title} </li>";
           }else{
             $str .= qq|<li>Could not assemble node reference for id: $node_id</li>|;
           }
        }
        $str .= "</ul>";
      }else{
        $str .= "Driver <em>$driver</em> has no failures";
      }
    }else{
      $str .= "Could not access driver: <em>$driver</em>.";
    }

    $str .= "<br />Back to ".linkNode($NODE)."<br />";
  }else{
    $str .= qq|<tr><td><strong>Driver name</strong></td><td style="text-align: center"><strong>Failure count</strong><td></tr>|;

    foreach my $driver (sort {$a cmp $b} keys %$drivers)
    {
      my $datanode = getNode($driver, "datastash");
      next unless $datanode;
      next unless $datanode->{vars};

      my $data = $DB->stashData($driver);
      $data = [] unless UNIVERSAL::isa($data, "ARRAY");

      $str .= qq|<tr><td style="padding: 4px">|.linkNode($NODE, $drivers->{$driver}->{title}, {"driver" => $driver}).qq|</td><td style="width: 150px; text-align: center;">|.scalar(@$data).qq|</td></tr>|;
    }

  }

  $str .= qq|</table>|;
  return $str;
}

sub topic_archive
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str ="<table>";
  $str .="<th>$_</th>\n" foreach("Time","Details");

  my $sectype=getId(getNode("E2 Gift Shop","superdoc")); # So probably 1872678 then
  my $startat= $query->param("startat");
  $startat =~ s/[^0-9]//g;
  $startat ||= 0;

  my $csr = $DB->sqlSelectMany('*', 'seclog', "seclog_node=$sectype AND seclog_time>'2011-01-22 00:00:00' order by seclog_time DESC limit $startat,50");

  while(my $row = $csr->fetchrow_hashref)
  { 
    $str.="<tr>\n";
    $str.="   <td><small>$$row{seclog_time}</small></td>\n";
    $str.="   <td>".$$row{seclog_details}."</td>\n";
    $str.="</tr>\n";
  }

  $str.="</table>";

  ### Generate the pager
  my $cnt = $DB->sqlSelect("count(*)", "seclog", "seclog_node=$sectype AND seclog_time>'2011-01-22 00:00:00'");
  my $firststr = "$startat-".($startat+50);
  $str.="<p align=\"center\"><table width=\"70%\"><tr>";
  $str.="<td width=\"50%\" align=\"center\">";
  if(($startat-50) >= 0)
  {
    $str.=linkNode($NODE,$firststr,{"startat" => ($startat-50), "sectype" => $sectype});
  }else{
    $str.=$firststr;
  }
  $str.="</td>";
  $str.="<td width=\"50%\" align=\"center\">";
  my $secondstr = ($startat+50)."-".(($startat + 100 < $cnt)?($startat+100):($cnt));

  if(($startat+50) <= ($cnt))
  {
    $str.=linkNode($NODE,$secondstr,{"startat" => ($startat+50), "sectype" => $sectype});
  }else{
    $str.="(end of list)";
  }

  $str .= '</tr></table>';
  return $str;

}

sub writeups_by_type
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  ####################################################################
  # get all the URL parameters

  my $wuType = abs int($query->param("wutype"));

  my $count = $query->param("count") || 50;
  $count = abs int($count);

  my $page = abs int($query->param("page"));

  ####################################################################
  # Form with list of writeup types and number to show

  my (@WRTYPE) = $DB->getNodeWhere({type_nodetype => getId(getType('writeuptype'))});
  my %items;
  map $items{$$_{node_id}} = $$_{title}, @WRTYPE;

  my @idlist = sort { $items{$a} cmp $items{$b} } keys %items;
  unshift @idlist, 0;
  $items{0} = 'All';

  my $str = htmlcode('openform')
	  .qq'<fieldset><legend>Choose...</legend>
	  <input type="hidden" name="page" value="$page">
	  <label><strong>Select Writeup Type:</strong>'
	  .$query->popup_menu('wutype', \@idlist, 0, \%items)
	  .'</label>
	  <label> &nbsp; <strong>Number of writeups to display:</strong>'
	  .$query->popup_menu('count', [10, 25, 50, 75, 100, 150, 200, 250, 500], $count)
	  .'</label> &nbsp; '
	  .$query -> submit('Get Writeups')
	  .'</fieldset></form>';

  ####################################################################
  # get writeups
  #

  my $where = "wrtype_writeuptype=$wuType" if $wuType;
  my $wus = $DB->sqlSelectMany('
 	  node.node_id, writeup_id, parent_e2node, publishtime,
	  node.author_user,
	  type.title AS type_title','
	  writeup
	  JOIN node ON writeup_id = node.node_id
	  JOIN node type ON type.node_id = writeup.wrtype_writeuptype',
	  $where,'
	  ORDER BY publishtime DESC LIMIT '.($page * $count).','.$count);

  ####################################################################
  # display
  #

  $str .= '<table style="margin-left: auto; margin-right: auto;">
	  <tr>
	  <th>Title</th>
	  <th>Author</th>
	  <th>Published</th>
	  </tr>';

  my $oddrow = 1;
  while(my $row = $wus->fetchrow_hashref)
  {
	  $str .= $APP->writeups_by_type_row($row, $VARS, ($oddrow % 1 == 0));
    $oddrow++;
  }

  $str .= "</table>";

  $str .= '<p class="morelink">';
  $str .= linkNode($NODE, '&lt&lt Prev',
	  {wutype => $wuType, page => $page-1, count => $count}).' | ' if $page;

  $str .= '<b>Page '.($page+1).'</b> | '
	  .linkNode($NODE, 'Next &gt;&gt;',
	  	{wutype => $wuType, page => $page+1, count => $count})
	  .'</p>';

  return $str;
}

sub nodelet_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = '';
  if($APP->isGuest($USER))
  {
    $str = '<p>You need to sign in or '.linkNode(getNode('Sign up','superdoc'), 'register').' to use this page.</p>';
  }else{
    $PAGELOAD->{pageheader} = '<!-- bottom -->'.htmlcode('settingsDocs');
    $str = htmlcode('openform',-id=>'pagebody');

    $str .= qq|<fieldset><legend>Choose and sort nodelets</legend> You can change the order of nodelets by dragging and dropping the menus here (don't forget to save) or by dragging them around by the title on most other pages.|;
    $str .= htmlcode("rearrangenodelets","nodelets","classic nodelets",1);
    $str .= qq|If the 'Epicenter' nodelet is not selected, its functions are placed in the page header.</fieldset>|;

    my $settingsstr = "";
    my @nodelets= split ',', $$VARS{nodelets};
    foreach my $nodelet (@nodelets){
	    my $n = getNodeById($nodelet);
	    my $name = $$n{title}.' nodelet settings';
	    next unless $n && $$n{type}->{title} eq 'nodelet' &&
		  getNode($name,'htmlcode');
	    my $id = lc($name);
	    $id =~ s/\W//g;
	    $settingsstr .= qq'<fieldset id="$id"><legend>$name</legend>\n'.htmlcode($name)."\n</fieldset>\n";
    }
    $str .= "<h2>Settings</h2>\n$settingsstr" if $settingsstr;

    $str .= htmlcode("closeform","Save settings");
  }
  return $str;
}

1;
