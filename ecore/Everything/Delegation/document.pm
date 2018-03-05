package Everything::Delegation::document;

use strict;
use warnings;

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
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *insertNodelet = *Everything::HTML::insertNodelet;
  *getType = *Everything::HTML::getType;
  *updateNode = *Everything::HTML::updateNode;
  *setVars = *Everything::HTML::setVars;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *isMobile = *Everything::HTML::isMobile;
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *getPageForType = *Everything::HTML::getPageForType;
  *opLogin = *Everything::HTML::opLogin;
  *replaceNodegroup = *Everything::HTML::replaceNodegroup;
}

sub document_25
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
 
  my $OUTPUT = htmlcode("ennchoice");
  $OUTPUT .= qq|<br>(see also [Writeups by Type])<br><br>|;
  $OUTPUT .= qq|<p ALIGN=LEFT><p></p></ul>|;
  $OUTPUT .= qq|<table cellpadding=0 cellspacing=0 width=100%>|.htmlcode("newnodes","25").qq|</table>|;
  return $OUTPUT; 
}

sub a_year_ago_today
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p align="center">Turn the clock back!</p><br><br>|;
  return $str."Don't be chatting here, show some reverence.  Besides, this page ain't cheap!" if ($query->param('op') eq 'message');

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  $year+=1900;
  my $yearsago = $query->param('yearsago');
  $yearsago =~ s/[^0-9]//g;
  $yearsago||=1;

  my $startat = $query->param('startat');
  $startat =~ s/[^0-9]//g;
  $startat ||=0;

  my $limit = 'type_nodetype='.getId(getType('writeup'))." and createtime > (CURDATE() - INTERVAL $yearsago YEAR) and createtime < ((CURDATE() - INTERVAL $yearsago YEAR) + INTERVAL 1 DAY)";

  my $cnt = $DB->sqlSelect('count(*)', 'node', $limit);
  my $csr = $DB->sqlSelectMany('node_id', 'node', "$limit order by createtime  limit $startat,50");

  $str.='<ul>';
  while(my $row = $csr->fetchrow_hashref())
  {

    my $wu = getNodeById($$row{node_id});
    my $parent = getNodeById($$wu{parent_e2node});
    my $author = getNodeById($$wu{author_user});
    $str.='<li>('.linkNode($parent,"full").') - '.linkNode($wu, $$parent{title})." by ".linkNode($author)." <small>entered on ".htmlcode("parsetimestamp",$$wu{createtime})."</small></li>";

  }

  $str = "$cnt writeups submitted ".(($yearsago == 1)?("a year"):("$yearsago years"))." ago today".$str;
  my $firststr = "$startat-".($startat+50);
  $str.="<p align=\"center\"><table width=\"70%\"><tr>";
  $str.="<td width=\"50%\" align=\"center\">";
  if(($startat-50) >= 0){
     $str.=linkNode($NODE,$firststr,{"startat" => ($startat-50),"yearsago" => $yearsago});
  }else{
     $str.=$firststr;
  }
  $str.="</td>";
  $str.="<td width=\"50%\" align=\"center\">";
  my $secondstr = ($startat+50)."-".(($startat + 100 < $cnt)?($startat+100):($cnt));

  if(($startat+50) <= ($cnt)){
     $str.=linkNode($NODE,$secondstr,{"startat" => ($startat+50), "yearsago" => $yearsago});
  }else{
     $str.="(end of list)";
  }

  $str.="</td>";
  $str.="</tr></table></p>";
  $str.="<p align=\"center\"><hr width=\"200\"></p>";
  $str.="<p align=\"center\">";
  my @years;
  for(1999..($year-1))
  {
    push @years,(($yearsago == ($year-$_))?("$_"):(linkNode($NODE, "$_",{"yearsago" => ($year-$_)})));
  }
  $str.= join " | ", reverse(@years);
  $str.="</p>";
  return $str;
}

sub about_nobody
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<br><br><p><center><table width="40%"><tr><td><i>About Nobody</i><p>|;
  
  my $iterations = 20;
  my @verbs = (
    'talks about',
    'broke',
    'walked',
    'saw you do',
    'cares about',
    'drew on',
    'can breathe under',
    'remembers',
    'cleaned up',
    'does',
    'fell on',
    'thinks badly of',
    'picks up',
    'eats'
  );

  my @dirobj = (
    'questions',
    'you',
    'the vase',
    'the dog',
    'the walls',
    'water',
    'last year',
    'the yard',
    'Algebra',
    'the sidewalk',
    'you',
    'the slack'
  );

  while ($iterations--)
  {
    $str .= "Nobody " . $verbs[rand(@verbs)] . ' ' .  $dirobj[rand(@dirobj)] . ".<br>";
  }
  $str .= "</td></table><br>and on and on [about Nobody].<p align=right>Andrew Lang/[nate|Nate Oostendorp]";
  return $str;
}

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

1;
