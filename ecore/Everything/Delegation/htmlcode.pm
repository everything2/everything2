package Everything::Delegation::htmlcode;

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

# TODO: use strict
# use strict;
# TODO: use warnings
# use warnings;

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
  *listCode = *Everything::HTML::listCode;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *urlGen = *Everything::HTML::urlGen;
  *urlGenNoParams = *Everything::HTML::urlGenNoParams;
  *insertNodelet = *Everything::HTML::insertNodelet;
  *breakTags = *Everything::HTML::breakTags;
  *screenTable = *Everything::HTML::screenTable;
  *encodeHTML = *Everything::HTML::encodeHTML;
  *cleanupHTML = *Everything::HTML::cleanupHTML;
  *getType = *Everything::HTML::getType;
  *htmlScreen = *Everything::HTML::htmlScreen;
  *updateNode = *Everything::HTML::updateNode;
  *rewriteCleanEscape = *Everything::HTML::rewriteCleanEscape;
  *setVars = *Everything::HTML::setVars;
  *cleanNodeName = *Everything::HTML::cleanNodeName;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *recordUserAction = *Everything::HTML::recordUserAction;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *confirmUser = *Everything::HTML::confirmUser;
  *removeFromNodegroup = *Everything::HTML::removeFromNodegroup;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *updateLinks = *Everything::HTML::updateLinks;
  *changeRoom = *Everything::HTML::changeRoom;
  *cloak = *Everything::HTML::cloak;
  *uncloak = *Everything::HTML::uncloak;
  *isMobile = *Everything::HTML::isMobile;
  *isSuspended = *Everything::HTML::isSuspended;
}

# Used by showchoicefunc
use Everything::XML;

# Used by parsetime
use Time::Local;

# Used by shownewexp, publishwriteup, static_javascript
use JSON;

# Used by publishwriteup
use DateTime;
use DateTime::Format::Strptime;

# Used by parsetimestamp
use Time::Local;

# Used by typeMenu
use Everything::FormMenu;

# Used by verifyRequestHash, getGravatarMD5
use Digest::MD5 qw(md5_hex);

# Used by uploaduserimage
use POSIX qw(strftime);
use Net::Amazon::S3;
use File::Copy;
use Image::Magick; 

# This links a stylesheet with the proper content negotiation extension
# linkJavascript below talks a bit about the S3 strategy
#
sub linkStylesheet
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # Generate a link to a stylesheet, incorporating the version 
  # number of the node into the URL. This can be used in conjunction
  # with a far-future expiry time to ensure that a stylesheet is
  # cacheable, yet the most up to date version will always be
  # requested when the node is updated. -- [call]
  my ($n, $displaytype) = @_;
  $displaytype ||= 'view' ;

  unless (ref $n) {
    unless ($n =~ /\D/) {
      $n = getNodeById($n);
    } else {
      $n = getNode($n, 'stylesheet');
    }
  }

  if ($n) {
    return urlGen({
      node_id => $n->{node_id},
      displaytype => $displaytype
    }, 1) if(($$USER{node_id} == $$n{author_user} && $$USER{title} ne "root") || $VARS->{useRawStylesheets});

    my $filename = "$$n{node_id}.$$n{contentversion}.min";
    if($ENV{HTTP_ACCEPT_ENCODING} =~ /gzip/)
    {
      $filename.= ".gzip";
    }
    $filename .= ".css";
    return "http://jscss.everything2.com/$filename";
  } else {
    return $n;
  }

}

# This puts the meta description tag so that we are more findable by google
#
sub metadescriptiontag
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return $APP->metaDescription($NODE);
}

# Part of the [Master Control] nodelet
#
sub admin_searchform
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($PARAM) = @_;

  my $nid = getId($NODE) || '';
  return unless $APP->isEditor($USER); 

  my $servername = `hostname`;
  chomp $servername;
  $servername =~ s/\..*//g;
  my $str = "\n\t\t\t<span class='var_label'>node_id:</span> <span class='var_value'>$nid</span>
			<span class='var_label'>nodetype:</span> <span class='var_value'>".linkNode($$NODE{type})."</span>
			<span class='var_label'>Server:</span> <span class='var_value'>$servername</span>";

  $str .= "\n\t\t\t<p>".htmlcode('nodeHeavenStr',$$NODE{node_id})."</p>";

  if($$USER{node_id}==9740) { #N-Wing
    $str .= join("<br>",`uptime`).'<br>';
  };

  $str .= "\n\t\t\t".$query->start_form("POST",$query->script_name);

  $str .= "\n\t\t\t\t".'<label for ="node">Name:</label> ' . "\n\t\t\t\t".
  $query->textfield(-name => 'node',
    -id => 'node',
    -default => "$$NODE{title}",
    -size => 18,
    -maxlength => 80) . "\n\t\t\t\t".
  $query->submit('name_button', 'go') . "\n\t\t\t" .
  $query->end_form;

  $str .= "\n\t\t\t" .$query->start_form("POST",$query->script_name).
    "\n\t\t\t\t" . '<label for="node_id">ID:</label> ' . "\n\t\t\t\t".
  $query->textfield(
    -name => 'node_id',
    -id => 'node_id',
    -default => $nid,
    -size => 12,
    -maxlength => 80) . "\n\t\t\t\t".
  $query->submit('id_button', 'go');

  $str.= "\n\t\t\t" . $query->end_form;

  return '<div class="nodelet_section">
    <h4 class="ns_title">Node Info</h4>
    <span class="rightmenu">'.$str.'
    </span>
    </div>';
}

# This wraps around the googleads code, even though we could just dump it into the template eventually
# TODO: Wind this down
sub zenadheader
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $ad_text = undef;

  if($APP->isGuest($USER)) 
  {
    $ad_text = htmlcode( 'googleads' );
    $ad_text = '<div class="headerads">'.$ad_text.'</div>' if $ad_text;
  }else{
    return "<!-- noad:settings -->";
  }
  return $ad_text;
}

# This links javascript to the page with the proper content encoding. What is not obvious is that
# we store the CSS files in gzip format on disk in S3, since S3 can't do content negotiation on the fly.
# TODO: Abscract out the jscss entry to a configurable bucket
#
sub linkjavascript
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($n) = @_;

  unless (ref $n) {
    unless ($n =~ /\D/) {
      $n = getNodeById($n);
    } else {
      $n = getNode($n, 'jscript');
    }
  }

  if ($n) {
    return urlGen({node_id => $n->{node_id}}, 1)
      if(($$USER{node_id} == $$n{author_user} && $$USER{title} ne "root") || $VARS->{useRawJavascript} );

    my $filename = "$$n{node_id}.$$n{contentversion}.min";
    if($ENV{HTTP_ACCEPT_ENCODING} =~ /gzip/)
    {
      $filename.= ".gzip";
    }

    $filename .= ".js";
    return "http://jscss.everything2.com/$filename";
  } else {
    return $n;
  }
}

# On htmlpages, this shows the inherited value for a nodetype
#
sub displayInherited
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This diplays inherited values for a nodetype.  This
  # checks to see if the given field has any inherited
  # values.

  my ($field) = @_;
  my $str = "";
  my $TYPE = undef;

  return "" unless ((isNodetype($NODE)) && (defined $field) && ($$NODE{extends_nodetype} > 0));

  if($field eq "sqltable")
  {
    $TYPE = $DB->getType($$NODE{extends_nodetype});
    $str .= "$$TYPE{sqltablelist}" if(defined $TYPE);
  }
  elsif(($field eq "grouptable") && ($$NODE{$field} eq ""))
  {
    $TYPE = $DB->getType($$NODE{node_id});
    my $gt = "";
    $gt = "$$TYPE{$field}" if(defined $TYPE);
    $str .= $gt if ($gt ne "");
  }
  elsif($$NODE{$field} eq "-1")
  {
    $TYPE = $DB->getType($$NODE{extends_nodetype});
    my $node = undef; $node = $DB->getNodeById($$TYPE{$field});
    my $title = undef; $title = $$node{title} if (defined $node);
    $title ||= "none";
    $str .= $title;
  }

  $str = " ( Inherited value: $str )" if ($str ne "");
  return $str;
}

# Used as a convenience function in a couple of places
#
sub displaySetting
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This displays the value of a setting given the key
  # $setting - the name of the setting node
  # $key - the key to display

  my ($setting, $key) = @_;
  my $SETTING = $DB->selectNodeWhere({title => $setting},
    $DB->getType('setting'));
  my $vars;
  my $str = "";

  $SETTING = $$SETTING[0];  # there should only be one in the array
  $vars = getVars($SETTING);
  $str .= $$vars{$key};
  return $str;
}

# Used exclusively on the dbtable display/edit pages
# TODO: This can go exclusively into template code
#
sub displaytable
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This generates an HTML table that contains the fields
  # of a database table.  The output is similar to what
  # you get when 'show columns from $table' is executed.
  my ($table, $edit) = @_;
  my @fields = $DB->getFieldsHash($table);
  my $field = undef;
  my $str = "";

  $edit = 0 if(not defined $edit);

  $str .= "<table border=1 width=400>\n";

  $field = $fields[0];

    $str .= " <tr>\n";
  foreach my $fieldname (keys %$field)
  {
    $str .= "  <td bgcolor=\"#cccccc\">$fieldname</td>\n";
  }

  $str .= "  <td bgcolor=\"#cccccc\">Remove Field?</td>\n" if($edit);
  $str .= " </tr>\n";

  foreach $field (@fields)
  {
    $str .= " <tr>\n";
    foreach my $value (values %$field)
    {
      $value = "&nbsp;" if($value eq ""); # fill in the blanks
      $str .= "  <td>$value</td>\n";
    }
    $str .= "  <td>" .
      $query->checkbox(-name => $$field{Field} . "REMOVE",
          -value => 'REMOVE',
          -label => 'Remove?') .
      "  </td>\n" if($edit);
    $str .= " </tr>\n";
  }

  $str .= "</table>\n";

  if($edit)
  {
    $str .= "<br>\n";
    $str .= "Add new field:<br>";
    $str .= "Field Name: ";
    $str .= $query->textfield( -name => "fieldname_new",
        -default => "",
        -size => 30,
        -maxlength => 50);
    $str .= "<br>Field type: ";
    $str .= $query->textfield( -name => "fieldtype_new",
        -default => "",
        -size => 15,
        -maxlength => 20);
    $str .= " (i.e. int(11), char(32), text, etc.)";
    $str .= "<br>Default value: ";
    $str .= $query->textfield( -name => "fielddefault_new",
        -default => "",
        -size => 50,
        -maxlength => 50);
    $str .= "<br>\n";
    $str .= $query->checkbox(-name => "fieldprimary_new",
        -value => "primary",
        -label => "Primary Key?");
    $str .= "<br>\n";
  }

  $str;

}

# Only used in [Gigantic Code Lister]
#
sub showChoiceFunc
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  no strict 'refs';

  my @modules = (
    'Everything',
    'Everything::XML',
    'Everything::NodeBase',
    'Everything::Application',
    'Everything::HTML'
  );
  my $str = "";
  my $showHTMLCODE = $$VARS{scf_nohtmlcode} ? 0 : 1;	#must be 0 or 1

  if(not $query->param('choicefunc')) {
    my %funcs = {};
    my $rows = 0;
    $str .= '<table><tr>';

    my $colwidth = int (100/(int(@modules)+$showHTMLCODE)) .'%';
    foreach my $modname (@modules) {
      my $stash = \%{ "${modname}::" };
      my @modfuncs = ();
      foreach(keys %$stash) {
        push (@modfuncs, $_) if (defined *{"${modname}::$_"}{CODE} and ($modname eq 'Everything' or not exists $Everything::{$_})) ;
      }

      @modfuncs = sort {$a cmp $b} @modfuncs;
      $funcs{$modname} = \@modfuncs;
      $rows = int(@modfuncs) if $rows < int(@modfuncs);
      $str.='<th width="'.$colwidth.'">'.$modname.'</th>';
    }

    if($showHTMLCODE) {
      $str.="<th width=\"$colwidth\">HTMLCODE</th>\n";
      my @HTMLCODE = $DB->getNodeWhere({1=>1}, $DB->getType('htmlcode'), 'title ASC', 'light');
      $funcs{htmlcode}= \@HTMLCODE;
      $rows=int(@HTMLCODE) if $rows < @HTMLCODE;
    }

    $str .= "</tr>\n";

    my $count=0;
    while($count < $rows) {
      $str.='<tr>';
      foreach(@modules) {
        $str.= '<td>';
        $str.=linkNode($NODE, $funcs{$_}[$count], { choicefunc => $funcs{$_}[$count], lastnode_id=>0 }) if (int (@{ $funcs{$_} }) > $count);
        $str.='</td>';
      }
      $str.='<td>';
      $str.= linkNode($funcs{htmlcode}[$count]) if $count < @{ $funcs{htmlcode} };
      $str.="</td></tr>\n";
      $count++;
    }  

    return $str.='</table>';
  }

  #else, we have have a specific function to display
  $str.= 'or go back to the code '.linkNode($NODE, 'index');
  my $choicefunc = $query->param('choicefunc');
  my $parentmod = '';

  foreach my $modname (@modules) {
    next if $parentmod;
    my $stash = \%{ "${modname}::" };
    if (exists $stash->{$choicefunc}) {
      $parentmod=$modname;
    }
  }

  unless($parentmod) {
    $choicefunc =~ s/</\&lt\;/g;
    $choicefunc =~ s/>/\&gt\;/g;
    return "<em>Sorry, man.  No dice on $choicefunc</em>.<br />\n"; 
  }


  my $parentfile = undef;
  my @mod = ();

  foreach (@INC)
  {
    $parentfile = "$_\/".$parentmod.".pm";
    $parentfile =~ s/\:\:/\//g;
    open MODULE, $parentfile or next;
    @mod = <MODULE>;
    close MODULE;
    last;
  }


  if (@mod) {
    $str.= "module $parentmod loaded: ".int(@mod)." lines\n";
  } else {
    $str.= "hmm. couldn't load modules $parentfile\n";
  }

  my $count = 0;
  my @lines = ();
  my $fullText = '';
  while(@mod > $count and not @lines) {
    $fullText .= $mod[$count];
    if($mod[$count] =~ /^sub $choicefunc\s*/) {
      my $i = $count;
      my $flag = undef;
      do {
        $i--;
        $mod[$i]=~/\s*(\S)/;

        $flag = (not defined $1 or $1 eq '#');
      } while($i > 0 and $flag);

      do {
        $i++;
        push @lines, $mod[$i];
      } while (not ($mod[$i] =~ /^\}\s*$/ ));

    }
    $count++;
  }

  if (@lines) {
    $str.= listCode(join('', @lines));
  } else {
    $str = listCode($fullText);
  }
  return $str;
}

# Only used in [dbtable edit page]
#
sub updatetable
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This checks the CGI params to see what we need to do
  # to this table.
  my ($table) = @_;

  # Check to see if we need to remove a column
  foreach my $param ($query->param)
  {
    if(($param =~ /REMOVE$/) && ($query->param($param) eq "REMOVE"))
    {
      my $fieldname = $param;
      $fieldname =~ s/REMOVE$//;
      $DB->dropFieldFromTable($table, $fieldname); 

      # Null out this field
      $query->param($param, "");
    }
  }

  # If we need to create a new field in the table...
  if((defined $query->param("fieldname_new")) && (defined $query->param("fieldtype_new")) )
  {
    my $fieldname = $query->param("fieldname_new");
    my $fieldtype = $query->param("fieldtype_new");
    my $primary = $query->param("fieldprimary_new");
    my $default = $query->param("fielddefault_new");

    $DB->addFieldToTable($table, $fieldname, $fieldtype, $primary, $default); 

    $query->param("fieldname_new", "");
    $query->param("fieldtype_new", "");
    $query->param("fieldprimary_new", "");
    $query->param("fielddefault_new", "");
  }

  return "";

}

#  Used in the debate display code.
#  TODO: Take SIZELIMIT and move it to a configuration item 
#  $displaymode:
#       0       Display first comment only, no children at all (used in edit page & replyto page)
#       1       Display full text of all comments (used in display page)
#       2       Display all of first comment, first n bytes of others (not used)
#       3       Display only first n bytes of all comments (not used)
#       4       Display only titles of children (used in compact page)
#       5       Display only titles (used implicitly in compact page)
#
#   $parent is only used internally: passed when we recurse to
#   signal that we're recursing and also save a few cycles

sub displaydebatecomment
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $rootnode = getNodeById( $_[0]->{ 'root_debatecomment' } );
  unless(isGod($USER)) {
    my $restrictGroup = $$rootnode{restricted} || 923653; # legacy magic number for old CE discussions
    return '<p><strong>Permission Denied</strong></p>' unless $APP->inUsergroup($USER,getNodeById($restrictGroup));
  }


  # While this doesn't exist in the database as an htmlcode, we're going to use it to make the global passing easier
  return htmlcode("displaydebatecommentcontent", @_);
}

sub displaydebatecommentcontent
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $node, $displaymode, $parent ) = @_;
  $displaymode += 0;

  my $rootnode = getNodeById($node->{root_debatecomment});

  my $SIZELIMIT = 768;

  my $instructions = 'div';
  my $parentlink = undef;
  if ($parent){
    $instructions = 'li';
    $parentlink = qq'<a href="#debatecomment_$$parent{node_id}">$$parent{title}</a>';
  }elsif ( $$node{parent_debatecomment} ){
    $parent = getNodeById( $$node{ 'parent_debatecomment' } );
    $parentlink = linkNode($parent);
  }

  $instructions .= ' class="comment"' if $parentlink;
  $instructions = qq'<$instructions id="debatecomment_$$node{node_id}">title,byline,date';
  $instructions .= ',responseto' if $parentlink;
  $instructions .= ','.( $displaymode != 3 ? 'content' : $SIZELIMIT ).',links' if $displaymode < 5;
  $instructions .= ',comments' if $$node{group} && $displaymode > 0;

  my %funx = (
    responseto => sub{qq' (response to "$parentlink")';},
    links => sub{
      my $str = "";
      $str .= linkNode($node, 'edit', {displaytype=>'edit'}).' | ' if $$node{ 'author_user' } == $$USER{ 'node_id' } || isGod( $USER );
      $str .= linkNode($node, 'reply', {displaytype=>'replyto'}) . " | <span class='debatelink'>&#91;$$rootnode{'title'}&#91;$$node{'node_id'}&#93;|LinkToMe&#93;</span>";
      return $str;
    },
    comments => sub{
      # close contentfooter before adding comments... ugh: spare div because show content still wants to close the footer:
      my @unwrap = ();
      @unwrap = ('</div>','<div>') if $displaymode < 5;
      ++$displaymode if $displaymode == 2 || $displaymode == 4;
      my $str = qq'$unwrap[0]<ul class="comments">';
      foreach (@{$$node{group}}){
        $str .= htmlcode("displaydebatecommentcontent",getNodeById($_), $displaymode, $node, $rootnode);
      }
      return $str ."</ul>$unwrap[1]";
    }
  );
  return htmlcode("show content",$node, $instructions, %funx);
}

sub showdebate
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $displaymode ) = @_;
  my $displaymodelink = '';

  if ( $displaymode != 0 ) {
    my %othermode = (); %othermode = (displaytype=>'compact') unless $query->param( 'displaytype' ) eq 'compact';
    my $modedesc = %othermode ? 'compact' : 'display full';
    $displaymodelink = linkNode($NODE, $modedesc, \(%othermode, title=>$modedesc)).' | '.
   linkNode($NODE, 'feed', {displaytype => 'atom', lastnode_id => ''}) . ' | ';
  }

  my $ug_id = $$NODE{restricted} ||= 923653;#Hack for old CE nodes
  my $ug = getNodeById($ug_id);

  my $str = '<p>[ ' . $displaymodelink . linkNode( getNode('Usergroup discussions', 'superdoc'), "$$ug{title} discussions", {show_ug=>$ug_id}) . ' | ' . linkNode( getNode('Usergroup discussions', 'superdoc'), 'all discussions' ) . ' ]</p>';

  if ( $$NODE{ 'root_debatecomment' } && $$NODE{ 'root_debatecomment' } != $$NODE{ 'node_id' } ) {
    my $rootnode = getNodeById( $$NODE{ 'root_debatecomment' } );
    if ( $rootnode ) {
        $str .= '<p>See whole discussion: <b>' . linkNode( $$NODE{ 'root_debatecomment' } ) . '</b>' .
          ' by <b>' . linkNode( $$rootnode{ 'author_user' } ) . '</b></p>';
    }
  }else{ 
    #When viewing the root node, update the last seen timestamp;

    #This is a little inefficient, since it's two SQL calls for what
    #should be only one. The right way to do this would be with
    #triggers, but those look less forward to implement with purely e2
    #code. --Swap
    my $lastread = $DB -> sqlSelect("dateread", "lastreaddebate", "user_id=$$USER{node_id} and debateroot_id=$$NODE{node_id}");

    if($lastread){
      $DB -> sqlUpdate("lastreaddebate", {-dateread => "NOW()"}, "user_id=$$USER{node_id} and debateroot_id=$$NODE{node_id}");
    }
    else{
      $DB -> sqlInsert("lastreaddebate", {"user_id" => $$USER{node_id}, "debateroot_id" => $$NODE{node_id}, -dateread => "NOW()" } );
    }
  }

  $str . htmlcode( 'displaydebatecomment', $NODE, $displaymode );

}

sub closeform
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  $query->submit("sexisgood", $_[0]||"submit") .
  $query->end_form;
}

sub displayNODE
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($limit) = @_;
  return unless $APP->isAdmin($USER);

  $limit ||= 90000;
  my $str = '';
  my @noShow = ('table', 'type_nodetype', 'passwd');

  foreach my $key (keys %$NODE) {
    unless (grep /^$key$/, @noShow) {
      $str .= "<li><B>$key: </B>";
    
      if ($key && $key =~ /\_/ && !($key =~ /\_id/))
      {
         $str .= linkNode($$NODE{$key}, "") if($$NODE{$key});
         $str .= "none" unless($$NODE{$key});
      }			
      elsif ($$NODE{$key} and UNIVERSAL::isa($$NODE{$key},"HASH")) {
        $str .= linkNode($$NODE{$key}, "", {lastnode => getId ($NODE)});
      } else {$str .= $$NODE{$key} if (length ($$NODE{$key}) < $limit);}	
    $str .= "<BR>\n";
    }
  }

  return $str;
}

# This is the old-style groupeditor with code that we are not sure that works anymore
# It appears that we have javascript that removes this code and replaces it with a more modern editor
# TODO: Is this still used?

sub groupeditor
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $id = getId($NODE);
  my $str = "
    <script language=\"JavaScript\">
    function saveForm()
    {
      var myForm;
      var myOption;
      var i;

      for(i=1; i <= document.forms.f$id.group.length; i++) 
      {
        myForm = eval(\"document.forms.f\" + \"$id\");
        myOption = eval(\"document.forms.f\" + \"$id\" + \".group\");
        myForm[i].value = myOption.options[i-1].value;
      }

      return true;
    }

    function swapUp()
    {
      with(document.forms.f$id.group){
        var x=selectedIndex;
        if(x == -1) { return; }
        if(options.length > 0 && x > 0) {
          tmp = new Option(options[x].text, options[x].value);
          options[x].text = options[x-1].text;
          options[x].value = options[x-1].value;
          options[x-1].text = tmp.text;
          options[x-1].value = tmp.value;

          options[x-1].selected = true
        }
      }

    }

    function swapDn()
    {
      with(document.forms.f$id.group)
      {
        x=selectedIndex;
        if(x == -1) { return; }
        if(x+1 < options.length) {
          tmp = new Option(options[x].text, options[x].value);
          options[x].text = options[x+1].text
          options[x].value = options[x+1].value;
          options[x+1].text = tmp.text;
          options[x+1].value = tmp.value;		
          options[x+1].selected = true;
	}
      } 
    }

    function deleteOp()
    {
      with(document.forms.f$id.group)
      {
        x=selectedIndex;
        if(x == -1) { return; }

        for(i=x;i<options.length - 1;i++) {
          options[i].text = options[i+1].text;
          options[i].value = options[i+1].value;
        }

	if(options.length != 0 && options.length != 1){options[x].selected = 1;}

        if(selectedIndex == -1)
        { 
          //Opera workaround, browser bug
          options[options.length -1].text = \"\"; 
          options[options.length -1].value= \"\";
        }
        else
        {
          options[options.length - 1] = null;
	}
      }
    }

    function zoomOp()
    {

      with(document.forms.f$id.group)
      {
        if(selectedIndex == -1) { return; }
        window.open('index.pl?node_id=' + options[selectedIndex].value, 'hernandez','');
      }

    }
  </SCRIPT>";

  $str .= "<form method=\"POST\" name=\"f$id\" onSubmit=\"saveForm()\">";

  my $GROUP = $$NODE{group};

  $GROUP ||= [];

  #generate the select box
  $str .= "\n<br /><select name=\"group\" size=\"9\">\n";
  foreach my $item (@$GROUP) {
    my $ITEM = $DB->getNodeById($item, 'light');
    my $authoruser = $DB->getNodeById( $$ITEM{ 'author_user' } );

    $str .= ' <option value="' . getId($ITEM) . "\">$$ITEM{title} by $$authoruser{title} ($$ITEM{node_id})\n";
  }
  $str .= '</select><br />';

  #generate the hidden elements
  for (my $i = 0; $i < (5 + @$GROUP); $i++) {
    $str .= "<input type=\"hidden\" name=\"$i\" value=\"\">\n";
  }

  $str .= $query->hidden('node_id', getId $NODE) . $query->hidden('displaytype');

  $str .= '
    <a href="javascript:deleteOp();" title="remove node from group">remove</a>
    <a href="javascript:swapUp();">up</a>
    <a href="javascript:swapDn();">down</a>
    <a href="javascript:zoomOp();">view</a>

  <input type="submit" border="0" value="Save" onClick="javascript:saveForm()">';

  $str .= '</form>';

  return $str;
}

# This lists the code for a particular node. 
# TODO: Refactor this once delegation is done and patches are dead

sub listcode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field,$codenode) = @_;
  $codenode ||= $NODE ;
  my $code = $$codenode{$field};

  my $type = $codenode->{type}->{title};

  if($codenode->{delegated})
  {
    $code = "Error: could not find code in delegated $type";
    my $file="/var/everything/ecore/Everything/Delegation/$type.pm";

    my $filedata = undef;
    my $fileh = undef;

    open $fileh,$file;
    {
      local $/ = undef;
      $filedata = <$fileh>;
    }

    close $fileh;

    my $name="$$NODE{title}";
    $name =~ s/[\s\-]/_/g;
    if($filedata =~ /^(sub $name.*?^})/ims)
    {
      $code = $1;
    }
  }

  $code = listCode($code, 1);

  my $patchTitle = undef;
  my $patchID = undef;
  my $patchNode = undef;

  if ($field eq 'script_text') {
    $patchID = $$codenode{script_id};
    $patchNode = getNode($patchID);
    $patchTitle = $$patchNode{title};
  } else {
    $patchID = $$codenode{node_id};
    $patchTitle = $$codenode{title};
  }

  # This searches for [{ text }] nodelet section calls and replaces the text with a link.
  $code =~ s/\&\#91;\{\s*(nodeletsection)\s*:\s*([^,\s}]*)\s*,\s*([^,\s}]*)(.*?)\}\&\#93;/"[\{<a href=".urlGen({node=>$1, type=>'htmlcode'}).">$1<\/a>:<a href=".urlGen({node=> $2 . "section_" . $3, type=>'htmlcode'}).">$2, $3<\/a>$4\}]"/egs;

  # This searches for [{ text }] and replaces the text with a link.
  $code =~ s/\&\#91;\{([^<]*?)((\:(.*?))*?)\}\&\#93;/"[\{<a href=".urlGen({node=>$1, type=>'htmlcode'}).">$1<\/a>$2}]"/egs;

  #this searches for "htmlcode("text", params...)" nodelet section calls and replaces the text with a link to the htmlcode.
  $code =~ s/htmlcode\s*\(\s*("|\')(nodeletsection)\1[,\s]*(['"])[\s,]*([^,\)'"]+)[\s'",]+([^,\)'"]+)[\s'"]*((\s*\,(.*?))*?)\s*\)/"htmlcode\($1<a href=".urlGen({node=>$2, type=>'htmlcode'}).">$2<\/a>$1, <a href=".urlGen({node=> $4 . "section_" . $5, type=>'htmlcode'}).">$3$4$3, $3$5$3<\/a>, $3$6\)"/egs;

  #this searches for "htmlcode("text", params...)" and replaces the text with a link to the htmlcode.
  $code =~ s/htmlcode\s*\(\s*("|\')\s*([^'"]*?)\s*\1(((\s*^\s*\d+:\s*)*\s*,\s*[^,]+?)*?)\s*\)/"htmlcode\($1<a href=".urlGen({node=>$2, type=>'htmlcode'}).">$2<\/a>$1$3\)"/megs;

  my $text = '<small>'.htmlcode('varcheckbox', 'listcode_smaller', 'Smaller code listing')."</small>\n";

  #ascorbic, sometime in autumn 2008
  my $author_id = $$codenode{author_user};
  if($author_id){
    $text = '<p>Originally by ' . linkNode($$codenode{author_user}) . '</p>' . $text;
  }
  else{
    $text = "<p>No author! This is a bug, get it fixed!</p>".$text;
  }

  #N-Wing, Sat, Jun 15, 2002 - help reduce long line horiz scrolling
  $code = '<div style="font-size: smaller;">'.$code.'</div>' if $VARS->{listcode_smaller};

  #breaks the form on code edit pages an' patching a patch may get confusing.
  return $text.$code if ($query->param('displaytype') eq 'edit' or $$codenode{type}{title} eq 'patch');

  if($codenode->{delegated})
  {
    return $code. '<strong>This is a "delegated" code, part of the transition of removing routines from the database. To submit a patch, you must do so on <a href="https://github.com/everything2/everything2/blob/master/ecore/Everything/Delegation/htmlcode.pm">github</a></strong>';
  }

  return $text unless $APP->isDeveloper($USER);
  $text = htmlcode('openform') . $text . '<input type="submit" name="sexisgood" value="resize"></form>'.$code ;

  $text .= '<strong>Submit a patch</strong>';
  $text .= $query->start_form('POST',$ENV{script_name}) . '<input type="hidden" name="op" value="new"><input type="hidden" name="type" value="patch"> <input type="hidden" name="node" value="'.$patchTitle.' (patch)"> <input type="hidden" name="patch_for_node" value="'.$patchID.'"> <input type="hidden" name="patch_field" value="'.$field.'"> ';

  $text .= 'patch\'s purpose: '.$query->textfield('patch_purpose','',55,240)."<br />\n";
  $text .= $query->textarea('patch_code', $$codenode{$field}, 20, 60);
  $text .= "<br />\n";
  $text .= 'You are creating a patch here. It is possible to '.linkNode($codenode,'edit code directly',{displaytype => 'edit'}).', but don\'t do that with live code.<br />' if $APP->isAdmin($USER);
  $text .= $query->submit();
  $text .= $query->end_form;

  return $text;
}

# Only really used in the nodetype display page
#
sub listgroup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field) = @_;

  my $G = $$NODE{$field};

  if(($G eq '') || ($G == 0)) {
    return 'none';
  } elsif($G == -1) {
    return 'parent';
  }

  getRef $G;
  return 'none' unless ref $G;

  my $str = linkNode($G) . " ($$G{type}{title})";
  return $str unless ($$G{group});

  $str .= "\n<ol>\n";
  my $groupref = $$G{group};
  foreach my $item (@$groupref) {
    my $N = $DB->getNodeById($item, 'light');
    $str .= '<li>' . linkNode($N) . " ($$N{type}{title})</li>\n";
  }

  $str .= "</ol>\n";
  return $str;
}

# Used everywhere, needs to be a template function
#
sub openform
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($name, $method) = @_;

  my %params = ();

  unless ( $name =~ /^-/ ) {
    $params{ -method } = $method if $method ;
    $params{ -name } = $params{-id} = $name if $name ;
  } else {
    %params = @_ ;
  }

  $params{ -method } ||= 'post';
  $query->start_form( -action => urlGenNoParams($NODE,1) , %params ) .
  $query->hidden("displaytype") . "\n" .
  $query->hidden('node_id', $$NODE{node_id});
}

# This needs to go away, but that's at the end of a very long road
#
sub parsecode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field, $nolinks) = @_;
  my $text = $$NODE{$field};
  $text = parseCode ($text);
  $nolinks ||= $PAGELOAD->{noparsecodelinks};

  $text = parseLinks($text) unless $nolinks;
  return $text;
}

# [{parsetime:FIELD}]
# Parses out a datetime field into a more human-readable form
#
sub parsetime
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field)=@_;

  my ($date, $time) = split / /,$$NODE{$field};

  my ($hrs, $min, $sec) = split /:/, $time;
  my ($yy, $mm, $dd) = split /-/, $date;

  return '<i>never</i>' unless (int($yy) and int($mm) and int($dd));

  my $epoch_secs=timelocal( $sec, $min, $hrs, $dd, $mm-1, $yy);
  my $nicedate =localtime ($epoch_secs);

  $nicedate =~ s/(\d\d):(\d\d):(\d\d).*$/$yy at $1:$2:$3/;
  $nicedate;
}

sub password_field
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field) = @_;

  #like all good password fields, we should have a confirm
  my $name = "$$NODE{type}{title}_$field";

  my ($p1, $p2) = ($query->param($name.'1'), $query->param($name.'2'));
  my $str = undef;

  my $oldpass = $query -> param("oldpass");

  if ( $oldpass or $p1 or $p2){
    if(confirmUser($USER -> {title}, $oldpass)) {
      if ( !$p1 and  !$p2){
        $str .= "I can't let you have no password! Please input <em>something</em>.<br>"
      } 
      elsif ($p1 eq $p2 ) {
        $APP -> updatePassword($USER, $p1);
        opLogin(); # without 'user' & 'passwd' query parameters, sets cookie for current user
        $str .= 'Password updated.<br>';
      }
      else {
        $str .= "Passwords don't match!<br>";
      }
    }
    else {
      $str .= "Sorry, partner, no can do if you don't tell me your old password.<br>";
    }
  }

  $query -> delete('oldpass', $name.1, $name.2);

  return $str . '<label>Your current password:'.$query -> password_field(-name=>"oldpass", size=>10, maxlength=>10, -label=>'') . '</label><br>

  <label>Enter a new password:'.$query->password_field(-name=>$name.'1', size=>10, maxlength=>10).'</label><br>

  <label>Repeat new password:'.$query->password_field(-name=>$name."2", size=>10, maxlength=>10).'</label>';
}

sub nodelet_meta_container
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return 'you disabled nodelets' if $$VARS{nodelets_off};
  return '' if $query->param('nonodelets');

  my $str = undef;

  unless ( $$VARS{nodelets} ) {
    #push default nodelets on
    my ($DEFAULT) = $DB->getNodeById( $Everything::CONF->{system}->{default_nodeletgroup} );
    $$VARS{nodelets} = join ',', @{ $$DEFAULT{group} } ;
  }

  my $required = getNode('Master Control', 'nodelet') -> { node_id } ;
  if( $APP->isEditor($USER) ) {
    # If Master Control is not in the list of nodelets, add it right at the beginning. 
    $$VARS{ nodelets } = "$required,".$$VARS{ nodelets } unless $$VARS{ nodelets } =~ /\b$required\b/ ;
  }else{
    # Otherwise, if it is there, remove it, keeping a comma as required
    $$VARS{nodelets} =~ s/(,?)$required(,?)/$1 && $2 ? ",":""/ge;
  }

  # Replace [New Writeups - Zen[nodelet]] (1868940) with [New Writeups[nodelet]] (263)
  $$VARS{nodelets} =~ s/\b1868940\b/263/g;
  # Ensure we didn't just cause New Writeups to occur twice
  $$VARS{nodelets} =~ s/(\b263\b.*),263\b/$1/g;

  my $nodelets = $PAGELOAD->{pagenodelets} || $$VARS{nodelets} ;
  my @nodelets = (undef); @nodelets = split(',',$nodelets) if $nodelets ;

  return '' unless @nodelets;

  my $CB = getNode('chatterbox','nodelet') -> {node_id} ;
  if (!$APP->isGuest($USER) and ($$VARS{hideprivmessages} or (not $$VARS{nodelets} =~ /\b$CB\b/)) and my $count = $DB->sqlSelect('count(*)', 'message', 'for_user='.getId($USER))) {
    my $unArcCount = $DB->sqlSelect('count(*)', 'message', 'for_user='.getId($USER).' AND archive=0');
    $str.='<p id="msgnum">you have <a id="msgtotal" href='.
      urlGen({'node'=>'Message Inbox','type'=>'superdoc','setvars_msginboxUnArc'=>'0'}).'>'.$count.'</a>'.
      ( $unArcCount>0 ? '(<a id="msgunarchived" href='.
      urlGen({'node'=>'Message Inbox','type'=>'superdoc','setvars_msginboxUnArc'=>'1'}).'>'.$unArcCount.'</a>)' : '').
      ' messages</p>';
  }

  my $errWrapper = '<div class="nodelet">%s</div>';

  my $nodeletNum=0;

  foreach(@nodelets) {
    my $current_nodelet = $DB->getNodeById($_);
    $nodeletNum++;
    unless(defined $current_nodelet) {
      $str .= sprintf($errWrapper, 'Ack! Unable to get nodelet '.$_.'.</td></tr>');
      next;
    }

    my $nl = insertNodelet($current_nodelet);
    unless(defined $nl) {
      $str .= sprintf($errWrapper, 'Ack! Result of nodelet '.$_.' undefined.</td></tr>');
      next;
    }

    $str .= $nl;
  }

  return $str;

}

# Only used semi-temporarily by the mobile stuff
#
sub searchform
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($PARAM) = @_; 
  my $str = $query->start_form("GET",$query->script_name).
    $query->textfield(-name => "node",
      -default => "",
      -size => 50,
      -maxlength => 230) .
    $query->submit("go_button", "go");

  $str.='<input type="hidden" name="lastnode_id" value="'.$$NODE{node_id}.'">'; 
  $str.= $query->end_form unless $PARAM eq 'noendform';
  return $str;
}

# Only used by the serverstats nodelet, likely to go away
#
sub serverstats
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  
  my $date = `date`;
  my $uptime = `uptime`;
  my @uptime = ();
  my $str = undef;

  $uptime =~ s/^\s*(.*?)\s*$/$1/;
  @uptime = split /,?\s+/, $uptime;

  $str = $date . "<br>";
  shift @uptime;

  $str .= "@uptime[0..3]" . "<br>";

  foreach (@uptime[-3..-1]){
    if ($_ > 1.0) {
      $_ = "<font color=#CC0000>" . $_ ."</font>, ";
    }else{
      $_ .= ", "; 
    }
  }
  $str .= "@uptime[-3..-1]". "<br>";

  return $str;
}

# Due to its incredibly generic name, I'm unsure if we use this
#
sub setvar
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($var, $len) = @_;
  $len ||=10;
  if (my $q = $query->param("set$var")) {$$VARS{$var} = $q;}
  if ($query->param("sexisgood") and not $query->param("set$var")){
    $$VARS{$var}="";
  }
  $query->textfield("set$var", $$VARS{$var}, $len);

}

# Only used in the nodetest edit page
#
sub yesno_field
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field) = @_;

  my $val = int($$NODE{$field});

  return $val . $query->radio_group("$$NODE{type}{title}_$field", ['1', '0'], $val, 0, { '0' => 'no', '1'=> 'yes'});
}

sub textfield
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field, $length, $expandable) = @_;
  $length ||= 20;
  my @expandable = (); @expandable = ( class => 'expandable' ) if $expandable ;
  $query->textfield(-name=>$$NODE{type}{title} .'_'. $field, value=>$$NODE{$field}, size=>$length ,@expandable );
}

sub parselinks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field) = @_;
  my $n = undef; $n = (( $APP->isGuest($USER) )?(undef):($NODE));
  parseLinks( $$NODE{$field} , $n ) ;

}

sub textarea
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field, $rows, $cols, $wrap) = @_;
  $cols ||= 80;
  $rows ||= 30;
  my $wrapSet = [ ];
  $wrapSet = [ -wrap => $wrap ] if ($wrap);

  my $name = $$NODE{type}{title} . "_" . $field;

  return $query->textarea(
    -name       => $name
    , -id       => $name
    , -default  => $$NODE{$field}
    , -rows     => $rows
    , -columns  => $cols
    , @$wrapSet
  );

}

# This is pretty ancient and needs to go away
#
sub windowview
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "" unless $DB -> canUpdateNode($USER, $NODE);
  my ($displaytype, $title, $width, $height) = @_;

  $title||=$$NODE{title};
  $width||=300;
  $height||=400;

  return "<SCRIPT language=\"javascript\">
	function launchThaDamnWinda() {
	window.open('" .
		urlGen({node_id => getId ($NODE),
			displaytype => $displaytype}, "noquotes") .
		"','". getId ($NODE) ."',
		'width=$width,height=$height,scrollbars=yes');	
	}
  </SCRIPT><A href=\"javascript:launchThaDamnWinda()\">$title</a>";
}

# The mother of all display functions:
# generic content/contentinfo display
# arguments:
# 0. single hashref or node id, arrayref of node ids or hashrefs, sql cursor for node(s) to show
# 1. string containing comma-separated list of instructions:
#	(optional) 'xml' to specify xml output and/or
#	(optional) html tag, used for wrapping each node (attributes optional, quotes="double")
#		- default is <div>
#		- may include class attribute (which is added to default class(es))
#		- class tokens starting with & are interpreted as function names and executed on the node
#		- no default classes for xml, otherwise:
#		- default class is 'item' if content is included, otherwise 'contentinfo'
#			- div class 'contentinfo' also wraps headers/footers before and after content,
#			  with class 'contentheader' or 'contentfooter' as appropriate
#
#	and then/or:
#	list of fields to display, which can be:
#		* a function name, either a built-in mark-up function or an additional one passed in the next argument
#		* "text"
#		* a hash key to a value to be marked up as
#			- <span class="[key]>">value</span> (not xml) or
#			- <[key]>encodeHTML(value)</[key> (xml)
#		* 'content' to show the doctext
#		* 'unfiltered' to show the doctext without screening the html
#		* a number n, to display the first n bytes of the doctext
#	Multiple content/unfiltered/numbers can be specified one after the other, separated by '-':
#	they will be used in turn for successive items. The last one is used for any remaining items.
# 	If content is truncated and not xml a link is provided to the node in a div class="morelink"
#	If xml is specified content is encoded and wrapped as <content type="html">
# 2. (optional) additional markup functions
#	If one of these has the key 'cansee' it will be used to check whether to show an item:
#	return '1' for yes.
#
# doctext is parseCoded if a node type is present and (inherits from) superdoc
# tables in doctext are screened for logged-in users
# TODO: Unwind the parseCode bits
#
sub show_content
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $input , $instructions , %infofunctions ) = @_ ;

  my $showanyway = 96 ; # how many bytes not to bother chopping off shortened content
  # pack/unpack input

  my @input = ( $input ) ;
  if ( ref $input eq 'ARRAY' ) {
    @input = @$input ;
  } elsif ( ref( $input ) =~ /DBI/ ) {
    @input = @{ $input->fetchall_arrayref( {} ) } ;
  }

  return '' unless getRef( @input );

  # define standard info functions

  my $getAuthor = sub{ $_[0]->{author} ||= getNodeById($_[0] -> {author_user}, 'light') || {}; } ;

  my $author = $infofunctions{author} ||= sub {
    linkNode( &$getAuthor , '' , {-class => 'author'}) ;
  } ;

  $infofunctions{ byline } ||= sub { '<cite>by '.&$author.'</cite>' ; } ;

  my $title = $infofunctions{ title } ||= sub {  linkNode($_[0] , '' , {-class => 'title'}) ; } ;

  $infofunctions{ parenttitle } ||= sub { 
    my $parent = getNodeById($_[0]{parent_e2node},'light'); 
    return '<span class="title noparent">(No parent node) '.&$title.'</span>' unless $parent ;
    my $author = &$getAuthor;
    return linkNode($parent, '', {
      -class => 'title'
      , '#' => $$author{title}
      , author_id => $$author{node_id}
    });
  };

  $infofunctions{ type } ||= sub {
    my $type = $_[0]{type_title} || getNodeById($_[0]{wrtype_writeuptype}) || $_[0]{type};
    $type = $type -> {title} if(UNIVERSAL::isa($type,"HASH"));
    if ($type eq 'draft'){
      my $status = getNodeById($_[0]{publication_status});
      $type = ($status ? $$status{title} : '(bad status)').' draft';
    }

    return '<span class="type">('.linkNode($_[0]{node_id}||$_[0]{writeup_id}, $type || '!bad type!').')</span>';
  };

  my $date = $infofunctions{date} ||= sub {
    return '<span class="date">'
      .htmlcode('parsetimestamp', $_[0]{publishtime} || $_[0]{createtime}, 256 + $_[1]) # 256 suppresses the seconds
      .'</span>' ;
  };

  $infofunctions{listdate} ||= sub{
    &$date($_[0], 4 + 512); # 4 suppresses day name, 512 adds leading zero to hours
  };

  my $oddrow = '';
  $infofunctions{oddrow} ||= sub{
    $oddrow = $oddrow ? '' : 'oddrow';
  };

  # decode instructions

  my $xml = '1' if $instructions =~ s/^xml\b\s*// ;

  my ($wrapTag, $wrapClass, $wrapAtts) = split(/\s+class="([^"]+)"/, $1) if $instructions =~ s/^\s*<([^>]+)>\s*//;
  $wrapAtts .= $1 if $wrapTag =~ s/(\s+.*)//;

  $instructions =~ s/\s*,\s*/,/g ;
  $instructions =~ s/(^|,),+/$1/g ; # remove spare commas

  my @sections = split( /,?((?:(?:content|[\d]+|unfiltered)-?)+),?/ , $instructions ) ;
  my $content = $sections[1] ;

  $wrapTag ||= 'div';
  $wrapClass .= ' ' if $wrapClass;
  $wrapClass .= $content ? 'item' : 'contentinfo';

  my @infowrap = ('<div class="contentinfo contentheader">', '', '<div class="contentinfo contentfooter">') if $content && !$xml;

  # define content function

  if ( $content ) {
    my $lastnodeid = undef;
    if ( !$APP->isGuest($USER) ) {
      $lastnodeid = $$NODE{ parent_e2node } if $$NODE{ type }{ title } eq 'writeup' ;
      $lastnodeid = $$NODE{ node_id } if $$NODE{ type }{ title } eq 'e2node' ;
    }

    my $HTML = getVars( getNode( 'approved HTML tags' , 'setting' ) ) ;
    my @content = split /-/, $content;
    my $i = 0;

    $infofunctions{$content} = sub {
      my $N = shift ;
      my $length = undef; $length = $content[$i] if $content[$i] =~ /\d/ ;
      $$HTML{ noscreening } = ($content[$i] eq 'unfiltered');
      $i-- unless $content[++$i];

      my $text = $N->{ doctext } ;
      # Superdoc stuff hardcoded below
      $text = parseCode( $text ) if exists( $$N{ type } ) and ( $$N{ type_nodetype } eq 14 or $$N{ type }{ extends_nodetype } eq 14 ) ;
      $text = breakTags( $text ) ;

      my ( $dots , $morelink ) = ( '' , '' ) ;
      if ( $length && length( $text ) > $length + $showanyway ) {
        $text = substr( $text , 0 , $length );
        $text =~ s/\[[^\]]*$// ; # broken links
        $text =~ s/\s+\w*$// ; # broken words
        $dots = '&hellip;' ; # don't add here in case we still have a broken tag at the end
        $morelink = "\n<div class='morelink'>(". linkNode($$N{node_id} || $$N{writeup_id}, 'more') . ")\n</div>";
      }

      $text = screenTable( $text ) if $lastnodeid ; # i.e. if writeup page & logged in
      $text = parseLinks( cleanupHTML( $text , $HTML ) , $lastnodeid ) ;
      return "\n<div class=\"content\">\n$text$dots\n</div>$morelink" unless $xml ;

      $text =~ s/<a .*?(href=".*?").*?>/<a $1>/sg ; # kill onmouseup etc
      return '<content type="html">'.encodeHTML( $text.$dots ).'</content>' ;
    };
  }

  # do it

  my $str = '';
  foreach my $N ( @input ) {
    next if $infofunctions{cansee} and $infofunctions{cansee}($N) != 1;

    my $class = qq' class="$wrapClass"' unless $xml;
    while ($class =~ m/\&(\w+)/) {
      my $intendedName = $1 ;
      my $intendedFunc = $infofunctions{ $intendedName } ;
      if ( $intendedFunc ) {
        $class =~ s/\&$intendedName/&$intendedFunc( $N )/e ;
      } else {
        $class =~ s/\&$intendedName/-Bad-info-function-'$intendedName'-/ ;
      }
    }

    $str .= qq'<$wrapTag$class$wrapAtts>';
    my $count = 0;

    foreach ( @sections ) {
      $str .= $infowrap[$count];
      my @chunks = split( /,+/ , $_ ) ;

      foreach ( @chunks ) {
        if ( exists( $infofunctions{ $_ } ) ) {
          $str .= $infofunctions{ $_ }( $N ) ;
        } elsif (/^"([^"]*)"$/){
          $str .= $1;
        } elsif ( $xml ) {
          $str .= "<$_>".encodeHTML( $$N{ $_ } )."</$_>" ;
        } else {
          $str .= "<span class=\"$_\">".$$N{ $_ }.'</span>' ;
        }

        $str .= "\n" ;
      }

      $str .= '</div>' if $infowrap[$count++];
    }
    $str .= "</$wrapTag>";
  }

  return $str ;
}

# Used in the usergroup editing functions 
#
sub usergroupmultipleadd
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $nomulti;
  %$nomulti = map{ getNode($_, "usergroup")->{node_id} => 1 } qw/gods e2gods/;

  if ($APP->isAdmin($USER) and not exists($$nomulti{$$NODE{node_id}})) {
    my $adder = getNode("simple usergroup editor", "superdoc");

    return linkNode($adder, "Add/drop multiple users", {'for_usergroup' => $$NODE{node_id}});
  }

  return '';

}

# Used in the collaboration nodetype
# parseLinks() and htmlScreen() on given field for 
# the node we're on (in? at?). 
#
# wharfinger
# 2/19/02
#
sub showcollabtext
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $field ) = @_;

  my $doctext = $$NODE{ 'doctext' };
  my $TAGNODE = getNode( 'approved html tags', 'setting' );
  my $TAGS    = getVars( $TAGNODE );

  $$TAGS{ 'highlight' } = 1;

  $doctext = breakTags( parseLinks( htmlScreen( $doctext, $TAGS ) ) );

  #N-Wing 2002.04.16.n2 - took out \s* - IIRC, tags can't have gaps in front
  $doctext =~ s/<highlight\s*>/<span class="oddrow">/gi;
  $doctext =~ s/<\/highlight\s*>/<\/span>/gi;

  return $doctext;
}

# Probably going to be something that gets encapsulated into an object method
#
sub mysqlproctest
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $procname = $NODE->{title};
  my $parameters = $NODE->{parameters};
  my $proctext = $NODE->{doctext};

  my $value = $DB->createMysqlProcedure("ecore_test_$procname", $parameters, $proctext, "PROCEDURE", 1);
  if(not ref $value eq "ARRAY")
  {
    return "Creation not attempted";
  }

  if($value->[0] == 1)
  {
    $DB->dropMysqlProcedure("ecore_test_$procname", "PROCEDURE");
    return "Created successfully";
  }

  if($value->[0] == 0)
  {
    return "Mysql procedure creation failed: ".$value->[1];
  }
}


# A major piece of page rendering, this can certainly go into a template
# TODO: Move the badwords stuff to a setting in the production file
# TODO: Make nodes auto-scan themselves on editing or submission to talk about why
#   they are not google-safe
#
sub softlink
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  my ($softserve) = @_; #parameter used by formxml_writeup and formxml_e2node

  if($softserve eq 'xml'){
    return if $$VARS{noSoftLinks};
  }
  return if($query->param('no_softlinks'));

  my $N = undef; $N = getNodeById($$NODE{parent_e2node},'light') if $$NODE{type}{title} eq 'writeup' ;
  $N ||= $NODE;
  my $lnid = undef;
  if ($APP->isGuest($USER) ) {
    $lnid=0;
  } else {
    $lnid=$$N{node_id};
  }

  my %unlinkables = {};
  foreach( values %{$Everything::CONF->{system}->{maintenance_nodes}} ) {
    $unlinkables{$_} = 1;
  }
  return if $unlinkables{ $$N{node_id} };

  my $isEditor = $APP->isEditor($USER);
  my $cantrim = $isEditor;

  my $limit = undef;
  if( $APP->isGuest($USER) ) {
    $limit = 24;
  } elsif($isEditor) {
    $limit = 64;
  } else {
    $limit = 48;
  }

  my $csr = $DB->{dbh}->prepare(
    'select node.type_nodetype, node.title, links.hits, links.to_node 
    from links use index (linktype_fromnode_hits), node 
    where links.from_node='.$$N{node_id}."
    and links.to_node = node.node_id and links.linktype=0 
    order by links.hits desc limit $limit"
  );

  $csr->execute;
  my @nodelinks = ();
  while (my $link = $csr->fetchrow_hashref) {
    push @nodelinks, $link;
  }
  $csr->finish;

  #Look for the non-nodeshells --[Swap]
  my @e2node_ids = map { $_ -> {to_node}} @nodelinks;

  my %fillednode_ids = {};

  if(@e2node_ids){
    my $sql = "SELECT DISTINCT nodegroup_id FROM nodegroup
      WHERE nodegroup_id IN ("
      .join(", ", @e2node_ids).")";

    #Populate the hash with autovivify (man perlglossary) --[Swap]
    %fillednode_ids = map {  $_ => undef } @{$DB->{dbh} -> selectcol_arrayref($sql)} ;
  }



  #xml output here;
  if($softserve){
    my $ss ='';
    if($softserve eq 'xml') {
      foreach my $n (@nodelinks){
        my $tn = getNodeById($$n{to_node},'light');
        my $nodeshelltest = exists $fillednode_ids{$$tn{node_id}};
        $ss .= '<e2link node_id="'.$$tn{node_id}.'" weight="'.$$n{hits}.'" filled="'.($nodeshelltest? '1' : '0').'">'
          .encodeHTML($$tn{title})."</e2link>\n";
      }
      return $ss;
    }
  }

  return '' unless @nodelinks ;
  my $str = "\n".'<table cellpadding="10" cellspacing="0" border="0" width="100%">'."\n\t".'<tr>';
  my $n=0;

  my @maxval = (255,255,255);
  my @minval = (170,170,170);
  my $format = '%02x';

  my $showTitle = undef;

  my $gradeattstart ||= 'bgcolor="#';
  my $dimensions = scalar @maxval - 1;
  my $steps = scalar @nodelinks;

  my $e2nodetype = getId(getType('e2node'));
  my $grade = undef;
  my $nid = undef;
  my @badOnes = ();	#auto-clean bad links
  my $numCols = 4;

  my $thisnode = $$N{node_id};

  foreach my $l (@nodelinks) {
    my @badwords = qw(boob breast butt ass lesbian cock dick penis sex oral anal drug pot weed crack cocaine fuck wank whore vagina vag cunt tits titty twat shit slut snatch queef queer poon prick puss orgasm nigg nuts muff motherfuck jizz hell homo handjob fag dildo dick clit cum bitch rape ejaculate bsdm fisting balling);
    if( $APP->isGuest($USER) )
    {
      my $isbad = 0;
      foreach my $word (@badwords) {
        if($$l{title} =~ /\b$word/i or $$l{title} =~ /$word\b/i){ $isbad = 1; last; }
      }
      next if $isbad;
    }

    $nid = $$l{to_node};
    my $nodeshelltest = exists $fillednode_ids{$nid};
    next if (!$nodeshelltest && $$VARS{hidenodeshells});

    push(@badOnes,$nid) if $cantrim;	#assume link is guilty...

    next if $$l{type_nodetype} != $e2nodetype;
    next if exists $unlinkables{$nid};
    next if $thisnode == $nid;
    pop(@badOnes) if $cantrim;	#...until proven innocent

    #==================
    #nate sez: don't touch this, we have to send this data up to [googleads] b/c they look for naughtywords
    # in links
    if (not exists $$NODE{linklist}) {
      $$NODE{linklist} = [ $l ];
    } else {
      push @{$$NODE{linklist}}, $l;
    }
    #end nate sez
    #=================

    unless ($$VARS{nogradlinks}){
      $grade = " $gradeattstart";
      foreach (0..$dimensions) {
        $grade .= sprintf($format, $maxval[$_] - ($maxval[$_] - $minval[$_])/$steps * $n);
      }
      $grade .= '"' ;
    }

    $str.= "</tr>\n\t<tr>" if($n && !($n%$numCols));
    $str.= "\n\t\t".'<td'.$grade.qq' class="sw$$l{hits}'.($nodeshelltest ? '' : ' nodeshell').'">';

    $str.= $query->checkbox('cutlinkto_'. $nid, 0, '1', '') if $cantrim;
    $showTitle = $$l{title};

    $str.= linkNode($nid, $showTitle, {lastnode_id=>$lnid}) ;

    $str.= ' ('.$$l{hits}.')' if $cantrim;
    $str.="</td>";
    ++$n;
  }

  for(;$n%$numCols;++$n) { $str.="\n\t\t".'<td'.(
    $$VARS{nogradlinks}||$$VARS{nogradekw} ? '' : ' class="slend"'
  ).'>&nbsp;</td>'; }
  $str.="\n\t</tr>\n</table>\n";

  if($cantrim) {
    #TODO: call a FN to delete these instead (or maybe only if admin)
    foreach(@badOnes) {
      $str .= '<input type="hidden" name="cutlinkto_'.$_.'" value="1" />';
    }

    $str = htmlcode('openform')
      .'<input type="HIDDEN" name="op" value="linktrim">'
      .'<input type="HIDDEN" name="cutlinkfrom" value="'.$$N{node_id}.'">'
      .htmlcode('verifyRequestForm', "linktrim")
      . $str;

    my $nbo = scalar(@badOnes);
    $str .= '('.$nbo.' extra will be trimmed) ' if $nbo;
    $str .= $query->submit('go','trim links') . '</form>';
  }

  return $str;
}

sub daylog
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @months = qw(January February March April May June July August September October November December);

  my ($sec,$min,$hour,$mday,$mon,$year) = gmtime(time);
  $year+= 1900;

  my $daydate = "$months[$mon] $mday, $year";
  # Create daylog e2node if it's not already there.
  $DB -> insertNode($daydate, 'e2node', getNode('Cool Man Eddie', 'user')) unless getNode($daydate, 'e2node');

  # Link to monthly ed log/root
  my $mnthdate = $months[$mon].' '.$year;

  return parseLinks(qq'<ul class="linklist">
    <li class="loglink">[$daydate|Day logs for $daydate]</li>
    <li class="loglink">[Editor Log: $mnthdate|Editor logs for $mnthdate]</li>
    <li class="loglink">[root log: $mnthdate|Coder logs for $mnthdate]</li>
    <li class="loglink">[Log Archive[superdoc]]</li>
    </ul>');
}

# Used in some old placement code. Very likely able to be removed
#
sub clearimage
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($height, $width) = @_;

  $height ||= 1;
  $width ||= 1;
  return "<img src=\"http://static.everything2.com/clear.gif\" border=\"0\" height=\"$height\" width=\"$width\" alt=\"\">";
}

# This will almost certainly go into a template
#
sub showbookmarks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($edit, $createform) = @_;
  #the maximum number to display

  return unless $$NODE{type}{title} eq 'user';


  my $user_id =getId($NODE);
  my $linktype=getId(getNode('bookmark', 'linktype'));

  my $str = "";
  if ($edit and $createform) {
    $str.=htmlcode('openform');
  }

  $str.="<ul class=\"linklist\" id=\"bookmarklist\">\n";
  my $sqlstring = "from_node=$user_id and linktype=$linktype ORDER BY title";

  my $csr = $DB->sqlSelectMany('to_node, title,
    UNIX_TIMESTAMP(createtime) AS tstamp',
    'links JOIN node ON to_node=node_id',
    $sqlstring);

  my $count = $csr->rows();
  while (my $link = $csr->fetchrow_hashref) {
    my $linktitle = lc($$link{title}); #Lowercased for case-insensitive sort
    if ($edit) {
      if ($query->param("unbookmark_$$link{to_node}")) {
        $DB->sqlDelete('links',
          "from_node=$user_id 
          AND to_node=$$link{to_node}
          AND linktype=$linktype");
      } else {
       $str.="<li tstamp=\"$$link{tstamp}\" nodename=\"$linktitle\" >".$query->checkbox("unbookmark_$$link{to_node}", 0, '1', 'remove').' '.linkNode($$link{to_node})."</li>\n";
      }
    } else {
      $str.="<li tstamp=\"$$link{tstamp}\" nodename=\"$linktitle\">".linkNode($$link{to_node},0,{lastnode_id=>undef})."</li>\n";
    }
  }

  $csr->finish;
  $str.="</ul>\n";

  if ($edit and $createform) {
    $str.=htmlcode('closeform');
  } elsif ( $count) {
    my $javascript = '<script type="text/javascript" src="/node/jscript/sortlist"></script>'."\n";

    $javascript .= '<p><a href="javascript:void(0);" onclick="sort(this)" list_id="bookmarklist" order="desc" '
      .'sortby="nodename">Sort by name</a> ';

    $javascript .= '<a href="javascript:void(0);" onclick="sort(this)"'
      .'list_id="bookmarklist" order="desc" '
      .'sortby="tstamp">Sort by date</a>'."\n</p>\n";

    $str = '<div id="bookmarks"><h4>User Bookmarks:</h4>'."\n"
      .$javascript.$str.'</div>';
  }

  return $str;

}


# displaywriteuptitle - pass the writeup's node_id and timestamp
# Likely moving over to a template function
# TODO: Restore hits code
#
sub displaywriteuptitle
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($num, $timestamp) = @_;

  my $WRITEUP = undef;
  my $votenum = 0;
  if (not $num) {
    $WRITEUP = $NODE;
  } else {
    my @group = (); 
    (@group) = @{ $$NODE{group} } if ($$NODE{group});
    @group or return;
    return if $num > @group;
    $WRITEUP = getNodeById($group[$num-1]);
    $votenum = getId($WRITEUP);
  }

  unless ($$WRITEUP{author_user}==$$USER{node_id} || $query->param('op') || $APP->isSpider() )
    { 0 && $DB->sqlUpdate ("node", { -hits => 'hits+1' }, "node.node_id=$$WRITEUP{node_id}"); } 

  return htmlcode('displayWriteupInfo',$votenum);
}

# Almost certainly a template piece
#
sub e2createnewnode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $title = $query->param('node');

  #Don't allow creation of nodes that begin with http(s)://
  $title =~ s/^\s*https?:\/\///;

  return '' unless $title;

  return '<p>If you '
    .linkNode(getNode("login","superdoc"), 'Log in')
    .' you could create a "'
    .$query -> escapeHTML($title)
    ."\" node. If you don't already have an account, you can "
    . linkNode($Everything::CONF->{system}->{create_new_user}, 'register here')
    .'.' if $APP->isGuest($USER);

  my $n = getNode($title, 'e2node');
  return '<p>'.linkNode($n).' already exists.</p>' if $n;

  my $str = '<p>Since we didn\'t find what you were looking for, you can search again, or create a new draft or e2node (page): </p>'
    .$query -> start_form(-method => 'get', action => '/')
    .'<fieldset><legend>Search again</legend>'
    .$query -> textfield(
      -name => 'node',
      size => 50,
      maxlength => 100
    )
    .' '
    .$query -> hidden('lastnode_id')
    .$query -> submit('searchy', 'search')
    .'<br>'
    .$query -> checkbox(
    -name => 'soundex',
      value => 1,
      label => 'Near Matches '
    )
    .$query -> checkbox(
      -name => 'match_all',
      value => 1,
      label => 'Ignore Exact'
    )
    .'</fieldset></form>'
    .$query -> start_form(-method => 'get', action => '/')
    .'<fieldset>
      <legend>Create new...</legend>
      <small>You can correct the spelling or capitalization here.</small>
      <br>'
    .$query -> textfield(
      -name => 'node',
      size => 50,
      maxlength => 100
    )
    .$query -> hidden('lastnode_id')
    .$query -> hidden(-name => 'op', value => 'new', -force => 1)
    .' <button type="submit" name="type" value="draft">New draft</button>
    <button type="submit" name="type" value="e2node">New node</button>';

  if ($APP->isAdmin($USER)){
    $str .= '<p>Lucky you, you can <strong>'
      .linkNode(getNode('create node', 'restricted_superdoc'),
      'create any type of node...', {newtitle => $title})
      .'</strong></p>';
  }

  $str .= '</fieldset></form>';

  if ($APP->isEditor($USER)){
    $str .= "<p>If you wish to exercise your Editorial Power to create a [document[nodetype]], create a draft, click on the 'Advanced option(s)' button, and then use the nice shiny 'Publish as document' button provided for this purpose.</p>";
  }

  return $str;

}

# Moving to template
#
sub bookmarkit
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER);

  my ( $N , $text , $title ) = @_ ;
  $N ||= $NODE ;
  getRef $N;
  $text ||= 'bookmark!' ;
  my $whatto = ( $$N{type}{title} eq 'e2node' ? 'entire page' : $$N{type}{title} ) ;
  $title ||= "Add this $whatto to your everything2 bookmarks" ;

  my $linktype = getNode('bookmark','linktype')->{node_id};
  return '('.linkNode( $USER , 'bookmarked' , { '-title' => "You have bookmarked this $whatto" } ).')'
    if $DB->sqlSelect('count(*)', 'links', 'from_node='.$$USER{node_id}.' and to_node='.$$N{node_id}." and linktype=$linktype");

  my $params = htmlcode('verifyRequestHash', 'bookmark');
  $$params{'op'} = 'bookmark';
  $$params{'bookmark_id'} = $N -> {node_id};
  $$params{'-title'} = $title ;
  $$params{'-class'} = "action ajax bookmark$$N{node_id}:bookmarkit:$$N{node_id}" ;
  $$params{'-id'} = "bookmark$$N{node_id}" ;

  return linkNode($NODE, $text, $params);
}

sub setupuservars
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER);

  my $SETTINGS = getVars $NODE;
  my $now = $DB->sqlSelect("UNIX_TIMESTAMP(now())");

  my $maint_nodes = undef;
  unless (exists $$SETTINGS{nwriteupsupdate} and $now - $$SETTINGS{nwriteupsupdate} < 3600) {
    $$SETTINGS{nwriteupsupdate} = $now;
    my $type1 = getId(getType('writeup'));
    my $user = getId($NODE);

    my $wherestr = "type_nodetype=$type1 AND author_user=$user ";
    $maint_nodes = join(", ", @{$APP->getMaintenanceNodesForUser($user)} );
    $wherestr .= " AND node_id NOT IN ($maint_nodes)" if $maint_nodes;

    my $writeups = $DB->sqlSelect("count(*)", "node",$wherestr);

    $$SETTINGS{numwriteups} = int($writeups);
  }

  if($$USER{user_id} == $$NODE{user_id})
  {
    #add numwriteups to $USER for honor roll

    $$USER{numwriteups} = $$SETTINGS{numwriteups};
    updateNode($USER, $USER);

    delete $$VARS{can_weblog};
    my $wls = getVars(getNode("webloggables", "setting"));
  
    my @canwl = ();
    foreach(keys %$wls)
    {
      my $n = getNodeById($_);
      next unless $n;
      unless($$n{type}{title} eq "usergroup")
      {
        if($APP->isAdmin($USER) ){
          push @canwl, $_;
        }

        next;
      }
 
      if( $APP->isAdmin($USER) || $DB->isApproved($USER, $n) ){
        push @canwl, $_;
        next;
      }  
    }
    push @canwl, getId(getNode('News for noders. Stuff that matters.', 'superdoc')) if $APP->isEditor($USER);
    $$VARS{can_weblog} = join ",", sort{$a <=> $b} @canwl;
  }


  my $numcools = $DB->sqlSelect('count(*)', 'coolwriteups', 'cooledby_user='.getId($NODE));
  $$SETTINGS{coolsspent} = linkNode(getNode('cool archive','superdoc'), $numcools, { useraction => 'cooled', cooluser => $$NODE{title} }) if $numcools;

  my $feedlink = linkNode(getNode('new writeups atom feed', 'ticker'), 'feed', {'foruser' => $$NODE{title}}, {'title' => "Atom syndication feed of latest writeups", 'type' => "application/atom+xml"});

  $$SETTINGS{nwriteups} = $$SETTINGS{numwriteups} . " - " . "<a href=\"/user/".rewriteCleanEscape($$NODE{title})."/writeups\">View " . $$NODE{title} . "'s writeups</a> " . ' <small>(' . $feedlink .')</small>' if $$SETTINGS{numwriteups};

  $$SETTINGS{nwriteups} = 0 if not $$SETTINGS{numwriteups};

  ##Last writeup cache
  if($$SETTINGS{numwriteups} !~ /^\d+$/) {
    #sometimes this gets messed up!
  } elsif($$SETTINGS{numwriteups} > 0){

    my $maintStr = "";
    unless($maint_nodes){
      $maint_nodes = join(", ", @{$APP->getMaintenanceNodesForUser($NODE)} );
      $maintStr = " AND node_id NOT IN ($maint_nodes) " if $maint_nodes;
    }

    my $lastnoded = getNodeById($$SETTINGS{lastnoded});
    delete $$SETTINGS{lastnoded} unless $lastnoded and $$lastnoded{type}{title} eq 'writeup';

    $$SETTINGS{lastnoded} ||= $DB->sqlSelect('node_id', 'node JOIN writeup ON node_id=writeup_id',
      "author_user=$$NODE{node_id}"
      .$maintStr
      ." ORDER BY publishtime DESC LIMIT 1");
  }

  my $lvl = $APP->getLevel($NODE);
  $$SETTINGS{level} = $lvl;
   
  my $TITLES= getVars(getNode('level titles','setting'));
  $$SETTINGS{level} .= " ($$TITLES{$$SETTINGS{level}})";

  if ($$NODE{title} eq 'thefez') { $$SETTINGS{level} = "-1 (Arcanist)" } # --N
  if ($$NODE{title} eq 'alex') { $$SETTINGS{level} = "âˆž (Ascended)" } # --a

  $$SETTINGS{level} .= " \/ $$NODE{experience}";

  setVars($NODE, $SETTINGS);
   
  return '';
}

sub shownewexp
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($shownumbers, $isxml, $newwuonly) = @_;

  #send TRUE if you want people to see how much exp they gained/lost
  return if $APP->isGuest($USER);
  unless($$VARS{oldexp}) {
    $$VARS{oldexp} = $$USER{experience};
  }

  my $str = "";

  return  if ($$VARS{oldexp} == $$USER{experience} and not $newwuonly);
  my $VSETTINGS = getVars(getNode('vote settings', 'setting'));

  my $newexp = $$USER{experience} - $$VARS{oldexp};

  my $xmlstr = "";
  $xmlstr = '<xpinfo>' if $isxml;
  $xmlstr .= "<xpchange value=\"$newexp\">$$USER{experience}</xpchange>" if $isxml;

  unless($newwuonly)
  {
    my $xpNotify = $newexp;

    if($newexp > 0) {
      $str.='You [node tracker[superdoc]|gained] ';
    } else {
      $$VARS{oldexp} = $$USER{experience};
      return;
    }

    htmlcode('achievementsByType','experience');

    my $notification = getNode('experience','notification')->{node_id};
    if ($$VARS{settings}) {
      my $all_notifications = from_json($$VARS{settings})->{notifications};
      if ($all_notifications->{$notification}) {
        my $argSet = { amount => $xpNotify};
        my $argStr = to_json($argSet);
        $argStr =~ s/,/__/g;
        my $addNotifier = htmlcode('addNotification', $notification,$$USER{user_id},$argStr);
      }
    }

    if ($shownumbers) {
      if ($newexp > 1) {
        $str.='<strong>'.$newexp.'</strong> experience points!';
      } else {
        $str.='<strong>1</strong> experience point.';
      }
    } else {
      $str.='experience!';
    }
  }

  $$VARS{oldexp} = $$USER{experience};
  #reset the new experience flag

  my $lvl = $APP->getLevel($USER)+1;
  my $LVLS = getVars(getNode('level experience', 'setting'));
  my $WRPS = getVars(getNode('level writeups', 'setting'));

  my $expleft = $$LVLS{$lvl} - $$USER{experience} if exists $$LVLS{$lvl};
  my ($numwu, $wrpleft) = (undef,undef);

  #No honor roll here

  $$VARS{numwriteups} ||= 0;
  $numwu = $$VARS{numwriteups};
  $wrpleft = ($$WRPS{$lvl} - $numwu) if exists $$WRPS{$lvl};

  $xmlstr .= "<nextlevel experience=\"$expleft\" writeups=\"$wrpleft\">$lvl</nextlevel>" if $isxml;

  $str.= '<br />You need <strong>'.$expleft.'</strong> more XP to earn [The Everything2 Voting/Experience System[superdoc]|level] '.$lvl.'.' if $expleft > 0;
  $str.= '<br />You need <strong>'.$wrpleft.'</strong> more writeups to earn [The Everything2 Voting/Experience System[superdoc]|level] '.$lvl.'.' if $wrpleft > 1;
  $str.= '<br />To reach [The Everything2 Voting/Experience System[superdoc]|level] '.$lvl.', you only need one more writeup!' if $wrpleft == 1;
  $str = parseLinks($str);

  $xmlstr.='</xpinfo>' if $isxml;

  return $xmlstr if $isxml;
  return $str;
}

sub votehead
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $uid=$$USER{node_id};
  my $canDoStuff = $$USER{votesleft} || $APP->isEditor($USER) unless $APP->isGuest($USER);
  my $str = "";
  $str.="\n\t".htmlcode('openform2','pagebody');
  $str.="\n\t\t".'<input type="hidden" name="op" value="vote" />' if $canDoStuff;	#don't bother with vote opcode if user can't vote

  return $str;
}

# TODO: Don't call the tools htmlcodes by variable procedure, call it explicitly because we kind of manage this codebase via grep
#
sub voteit
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER) ;
  my ( $N , $showwhat ) = @_ ;
  $N ||= $NODE ;
  getRef( $N ) ;

  my $isEditor = $APP->isEditor($USER) ;
  return $isEditor ? 'no writeup' : '' unless $N and $$N{writeup_id} || $$N{draft_id};

  $showwhat ||= 7 ; #1: kill only; 2: vote only; 3: both

  my $n = $$N{node_id} ;
  my $votesettings = getVars(getNode('vote settings','setting')) ;
  my $isMine = $$USER{user_id}==$$N{author_user};

  my $author = getNodeById( $$N{author_user} );
  $author = $query -> escapeHTML($$author{title}) if $author;

  my $edstr = '';

  if ($showwhat & 1 and $isEditor || $isMine || $$N{type}{title} eq 'draft') { # admin tools
    $edstr .= htmlcode("$$N{type}{title}tools", $N);
  }

  return $edstr unless $$N{type}{title} eq 'writeup' and $showwhat & 2 ;

  my $uplbl = $$votesettings{upLabel} || 'up' ;
  my $dnlbl = $$votesettings{downLabel} || 'down' ;
  my $nolbl = $$votesettings{nullLabel} || 'none';

  my $novotereason = '';
  $novotereason = 'this writeup is a definition' if $$N{wrtype_writeuptype} eq getId(getNode('definition', 'writeuptype')) ;
  $novotereason = 'voting has been disabled for this writeup' if $APP->isUnvotable($N);

  my $votestr = '';
  $votestr = '&nbsp; ' if $edstr ;
  my $prevvote = $isMine ? 0 : $DB->sqlSelect('weight', 'vote', 'vote_id='.$n.
    ' and voter_user='.$$USER{user_id}) || 0;

  $votestr .= "<span id=\"voteinfo_$n\" class=\"voteinfo\">" ;
  if ( $isMine || $prevvote and !$novotereason ) { # show votes cast
    my $uv = '';
    my $r = $$N{reputation} || 0;
    my ($p) = $DB->sqlSelect('count(*)', 'vote', "vote_id=$n AND weight>0");
    my ($m) = $DB->sqlSelect('count(*)', 'vote', "vote_id=$n AND weight<0");

    #Hack for rounding, add 0.5 and chop off the decimal part.
    my $rating = int(100*$p/($p+$m) + 0.5) if ($p || $m);
    $rating ||= 0 ;
    $rating .= '% of '.($p+$m).' votes' ;

    # mark up voting info
    $p = '+'.$p;
    $m = '-'.$m;
    if ($prevvote>0) {
      $uv='+';
      $p = '<strong>'.$p.'</strong>';
    } elsif ($prevvote<0) {
      $uv='-';
      $m = '<strong>'.$m.'</strong>';
    } else {
      $uv='?';
    }

    $r = '<strong>'.$r.'</strong>' if $query->param('vote__'.$n);

    $votestr .= '<span class="votescast" title="'.$rating.'"><abbr title="reputation">Rep</abbr>: '.$r.' ( '.$p.' / '.$m.' )' .
      ' (<a href="/node/superdoc/Reputation+Graph?id='.$n.'" title="graph of reputation over time">Rep Graph</a>)';
    $votestr .= ' ('.$uv.') ' unless $isMine;
      $votestr .= '</span>' ;
  }

  unless ( $isMine ) {
    $novotereason = ' unvotable" title="'.$novotereason if $novotereason ;
    $votestr.="<span class=\"vote_buttons$novotereason\">";
    if ( $novotereason ) {
      $votestr .= '(unvotable)' ;
    } elsif ($$USER{votesleft}) {
      $votestr .= 'Vote:' unless $votestr =~ /votescast/ ;
      my @values = ( 1 , -1 ) ;
      push( @values , 0 ) if $$VARS{nullvote} && $$VARS{nullvote} ne 'off' ; #'off' for legacy
      my %labels = ( 1 => $uplbl , -1 => $dnlbl , 0 => $nolbl ) ;
      my $confirm = 'confirm' if $$VARS{votesafety};
      my $replace = 'replace ' unless $$VARS{noreplacevotebuttons};
      my $clas = $replace."ajax voteinfo_$n:voteit?${confirm}op=vote&vote__$n=" ;
      my $ofauthor = $$VARS{anonymousvote} == 1 && !$prevvote ? 'this' : $author."'s" ;
      my %attributes = (
        1 => { class => $clas."1:$n,2" , title => "upvote $ofauthor writeup" },
        -1 => { class => "$clas-1:$n,2" , title => "downvote $ofauthor writeup" },
        0 => {class => $replace }
      ) ;

      if ( $prevvote ){
        $attributes{ $prevvote } = { class=>$replace , disabled=>'disabled',
          title=>'you '.( $prevvote>0 ? 'up' : 'down')."voted $author\'s writeup" } ;
      }

      $votestr .= $query -> radio_group( -name=>"vote__$n" , Values=>\@values ,
        default=>$prevvote, labels=>\%labels, attributes=>\%attributes );

      if (my $numvoteit = $query->param('numvoteit')) { # this hackery is for votefooter: vote or blab button
        $query->param('numvoteit', $numvoteit+1);
      } else {
        $query->param('numvoteit', 1);
      }	
    }else{
      $votestr.= '<strong>vote failed:</strong> ' if $query->param("vote__$n") && $query -> param("vote__$n") != $prevvote;
      my $level = $APP->getLevel($USER);
      $votestr.= '('.linkNodeTitle("Why Don't I Have Votes Today?|out of votes").')' if $level && htmlcode('displaySetting' , 'level votes', $level) ;
    }

    $votestr .='</span>' ;
  }

  $votestr .='</span>' ;
  return $edstr.$votestr ;

}

# choose an e2node to be the parent of a draft
# optionally, publish the draft to it as a writeup
# TODO: Consolidate this under a controller, somehow
# TODO: What bug is in searchNodeName
sub parentdraft
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $N = shift || $NODE;
  getRef $N;
  return '<div class="error">Not a draft.</div>' unless $$N{type}{title} eq 'draft';

  my $publish = undef; $publish = 1 if lc($query -> param('parentdraft')) eq 'publish';

  my $wrap = sub{ $query -> div({id => "draftstatus$$N{node_id}", class => 'parentdraft'}
    , $_[0]
    .htmlcode('openform')
    .$query -> submit(
      -name => 'cancel',
      value => 'Cancel'.($publish ? ' publication' : ''),
      class => "ajax draftstatus$$N{node_id}:setdraftstatus:$$N{node_id}")
    .'</form>'
    .$query -> script({type => 'text/javascript'}
      , "parent.location='#draftstatus$$N{node_id}';"
      )
  )};

  my ($str, $publishAs) = (undef,undef);

  if ($publish){
    # check the user is allowed to post writeups
    $str = htmlcode('nopublishreason', $USER);
    return &$wrap("<h3>Draft cannot be published</h3><p>$str</p>") if $str;

    # check if the draft meets minimal formal requirements
    my $userLevel = $APP->getLevel($USER);

    unless ($$N{doctext} =~ /\S/){
      $str = '<p>No content.</p>';
    }elsif($$N{doctext} =~ /\[(http\:\/\/(?:\w+\.)?everything2\.\w+)/i or !$userLevel && $$N{doctext} !~ /\[(?!http:).+]/){
      $str = "<p><strong>Do not</strong> use the external link format to link
        to other pages on this site (&#91;$1...&#93;).</p>" if $1;

      $str = '<p>You may have read '
        .linkNode(getNode('E2 Quick Start', 'e2node'))
        .' a little too quickly.</p><p>Writeups on Everything2 should include '
        .linkNode(getNode('Links on Everything2','e2node'),'links')
        .' to other pages on the site. You can make an on-site link like this: &#91;'
        .linkNode(getNode('hard link','e2node'))
        .'&#93; or like this: &#91;'
        .linkNode(getNode('pipe link','e2node'),'link one thing|show another')
        .'&#93;. This way, each writeup is integrated with the rest of the site and new and old works can complement each other.</p>
          <p>You can also link to other websites like this: &#91;http://example.com|external link&#93;, but external links do not help to integrate a writeup into Everything2. </p>'
        .$str;
    }

    return &$wrap("<h3>Draft not ready for publication</h3>$str") if $str;

    $publishAs = $query -> param('publishas') if $userLevel and $query -> param('publishas') and htmlcode('canpublishas', $query -> param('publishas')) == 1;
    $publishAs = getNode($publishAs, 'user') if $publishAs;
  }

  # Can publish/choose parent
  # work out which e2nodes to offer based on title...

  my $title = $query -> param('title');
  if ($title){
    $title = cleanNodeName($title);
    $query -> param('title', $title);
  }else{
    $title = $$N{title};
    # remove number/writeuptype from end of title (user can put it back later if they really want it)
    $title =~ s/ \($1\)$// if $title =~ / \(([\w\d]+)\)$/ and $1 eq int($1) || getNode($1, 'writeuptype');
  }

  # ...existing parent...

  my $linktype = getId(getNode 'parent_node', 'linktype');
  my $parent = $DB -> sqlSelect('to_node', 'links', "from_node=$$N{node_id} AND linktype=$linktype");

  # ... and choice last time around
  my $e2node = $query -> param('writeup_parent_e2node');

  my @existing = ();
  my $newoption = 1;

  unless ($e2node){
    # no choice made yet. The user chooses an e2node from:
    # 1. the draft's current parent
    # 2. the e2node whose title matches this draft
    # 3. e2nodes found with a search on the title
    # 4. a new e2node with this draft's title
	
    push @existing, getNodeById($parent) if $parent;

    my $nameMatch = getNode($title, 'e2node', 'light');
    push @existing, $nameMatch if $nameMatch and $$nameMatch{node_id} != $parent;

    $newoption = 0 if $nameMatch;
    $nameMatch = getId $nameMatch;
	
    if ($newoption or !$publish && $parent){
      # if no existing e2node with this title, or if changing existing parent, look for similar
      my $e2type = getId(getType('e2node'));
      my @findings = @{$APP->searchNodeName($title, [$e2type], 0, 1)}; # without soundex
      @findings = @{$APP->searchNodeName($title, [$e2type], 1, 1)} unless @findings; # with soundex

      push @existing, map($_ && $$_{type_nodetype} == $e2type &&  # there's a bug in searchNodeName...
        $$_{node_id} != $parent && $$_{node_id} != $nameMatch ? $_: (), @findings);
      @existing = @existing[0..24] if @existing > 25; # enough is enough
    }

  }elsif(int $e2node){
    # user has chosen an existing e2node (not 'new')
    $newoption = 0;
    push @existing, getNodeById($e2node);
  }

  # radio buttons for multiple options, hidden control if only one
  my %prams = (name => 'writeup_parent_e2node');
  unless ($newoption + scalar @existing == 1){
    $prams{type} = 'radio';
    $prams{checked} = 'checked';
  }else{
    # no choice:
    $prams{type} = 'hidden';
    ($e2node, $title) = $newoption ? ('new', $title) : ($existing[0]->{node_id}, $existing[0]->{title});
  }

  # provide e2node options: to choose existing, create new, or both

  $str = htmlcode('openform')
    .qq'<fieldset class="draftstatus"><legend>Choose destination</legend>'
    .$query -> hidden('draft_id', $$N{node_id})
    .$query -> hidden('title', $title);

  $str .= $query -> h3(($publish ? 'Publish under' : 'Attach to').' existing title (e2node):')
    .$query -> ul({class => 'findings'}, 
      join('',, map($query -> li($query -> input({value => $$_{node_id}, %prams})
	.' '
        .linkNode($_)
        .(delete $prams{checked} ? '' : '')
        ), @existing)
      )
    )  if @existing;

  $str .= $query -> h3('Create a new page (e2node) with this title:')
    .$query -> ul({class => 'findings'} , $query -> li($query -> label(
      $query -> input({value => 'new', %prams})
      .' '
      .$query -> escapeHTML($title)
      ))
    ) if $newoption;


  # provide buttons

  my $ajaxTrigger = 1; # we normally want to submit this form with ajax

  unless ($publish && $e2node){
    # attach only or multiple options:
    # we have to wait until there's only one option before offering
    # to publish so setwriteuptype can set type/hidden

    $str .= $query -> p($query -> submit('choose', 'Choose'));

  }else{
    # publishing and only one option/user has chosen: see if this user can publish here:
    my $nopublish = undef; $nopublish = htmlcode('nopublishreason', $publishAs || $USER, $e2node)
      unless $e2node eq 'new'; # the user has already been checked

    unless ($nopublish){
      # no reason not to allow publication
      # error report if tried to publish already and failed nonetheless:
      $str .= parseLinks("<p>Publication failed: please try again, and if it still doesn't work, please contact an [Content Editors|editor].</p>")
        if $query -> param('op') eq 'publishdraft';

      $str .= '<p>'
        .htmlcode('setwriteuptype', $N, $title)
        .'</p><p>'
        .$query -> submit('publish',  'Publish')
        .'</p><input type="hidden" name="op" value="publishdraft">';
		
      $ajaxTrigger = 0; # we want to go to the e2node

    }else{
      # known reason why this user can't publish this draft here
      $publish = 0;
      $str .= '<h3>Your draft cannot be published at <i>'
        .$query -> escapeHTML($title)
        .'</i>:</h3><p>';

      if (UNIVERSAL::isa($nopublish,'HASH')){
        $str .= linkNodeTitle("${title}[by "
          .($publishAs ? "$$publishAs{title}]|$$publishAs{title} has" : "$$USER{title}]|You have")
          .' a writeup there already.');

      }else{
        $str .= $nopublish;
        my $options = undef; $options = "Attach this draft to '"
          .$query -> escapeHTML($title)
          ."'" unless $e2node =~ /\D/ or $parent == $e2node;

        my $review = getId(getNode 'review', 'publication_status');
        $options .= ($options ? ' and request review of it' : 'Request review of this draft').'' unless $$N{publication_status} == $review;

        $str .= '</p><p>'
          .$query -> hidden(
            -name => 'draft_publication_status',
            -value => $review,
          )
          .$query -> submit('attach', $options)if $options;
      }

      $str .= '</p>';
    }
  }

  $str .= $query -> hidden('parentdraft') if $publish;
  $str .= htmlcode('canpublishas') if $publishAs;

  $str .= $query -> hidden(
    -name => 'ajaxTrigger',
    value => 1,
    class => "ajax draftstatus$$N{node_id}:"
      .($publish ? 'parentdraft:' : 'setdraftstatus:').$$N{node_id}
    ) if $ajaxTrigger;

  return &$wrap(
    "$str</fieldset></form>"
    .htmlcode('openform')
    .'<fieldset><legend>Try a different title</legend><p>'
    .$query -> hidden('parentdraft')
    .$query -> hidden('publishas')
    .$query -> hidden(
      -name => 'ajaxTrigger',
      value => 1,
      class => "ajax draftstatus$$N{node_id}:parentdraft:$$N{node_id}"
    )
    .$query -> textfield(
      -name => 'title',
      value => $title,
      size => 80
    )
    .$query -> submit('search','Search')
    .'</p></fieldset></form>'
  );
}

sub openform2
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($name) = @_;
  $name ||= '';

  return $query->start_form(-method => 'POST',
    -action => urlGenNoParams($NODE,1),
    -name => $name,
    -id => $name) .
    $query->hidden('displaytype').
    $query->hidden('node_id', getId $NODE);

}


# called from [publishdraft] or from [writeup maintenance create]
# we have already checked that everything exists,
# and that this user can publish this writeup to this node
#
sub publishwriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($WRITEUP, $E2NODE) = @_;

  my $WRTYPE = getNodeById($query->param('writeup_wrtype_writeuptype'));
  # if we haven't been given a type, use the default:
  $WRTYPE = getNode('thing', "writeuptype") unless $WRTYPE and $$WRTYPE{type}{title} eq 'writeuptype';

  my ($sec,$min,$hour,$mday,$mon,$year) = localtime(time);
  my $notnew = $query->param("writeup_notnew") || 0;

  # some of this should theoretically happen automatically. But sometimes fails. So:
  $$WRITEUP{parent_e2node} = getId $E2NODE;
  $$WRITEUP{wrtype_writeuptype} = getId $WRTYPE;
  $$WRITEUP{notnew} = $notnew;
  $$WRITEUP{title} = "$$E2NODE{title} ($$WRTYPE{title})";
  $$WRITEUP{hits} = 0; # for drafts
  $$WRITEUP{publishtime} = $$E2NODE{updated} = sprintf '%4d-%02d-%02d %02d:%02d:%02d', $year+1900,$mon+1,$mday,$hour,$min,$sec;

  $DB->sqlInsert('newwriteup', {node_id => getId($WRITEUP), notnew => $notnew});

  updateNode $WRITEUP, $USER; # after newwriteup insertion to update New Writeup data
  updateNode $E2NODE, -1;

  unless ($$WRTYPE{title} eq 'lede'){
    # insert into the node group, last or before Webster entry;
    # make sure Webster is last while we're at it
	
    my @addList = getNodeWhere({
      parent_e2node => $$E2NODE{node_id},
      author_user => getId(getNode('Webster 1913', 'user'))
      }, 'writeup');
	
    removeFromNodegroup($E2NODE, $addList[0], -1) if @addList; # remove Webster
	
    unshift @addList, $WRITEUP;
    insertIntoNodegroup($E2NODE, -1, \@addList);
  }else{
    # insert at top of node group
    insertIntoNodegroup($E2NODE, -1, $WRITEUP, 0);
  }

  # No XP, writeup count, notifications or achievement for maintenance nodes
  if ( $APP->isMaintenanceNode($E2NODE) ){
    recordUserAction('createwriteupemaintenance', $$WRITEUP{node_id}, $$E2NODE{node_id});
    return;
  }

  # record new node creation:
  recordUserAction('createwriteup', $$WRITEUP{node_id}, $$E2NODE{node_id});

  return if $$WRITEUP{author_user} != $$USER{node_id}; # no credit for publishas

  # credit user
  $$USER{experience}+=5;
  updateNode $USER, $USER;

  $$VARS{numwriteups}++;
  $$VARS{lastnoded} = $$WRITEUP{writeup_id};

  htmlcode('achievementsByType','writeup');

  # Inform people who have this person as one of their favorite authors
  my $favoriteNotification = getNode("favorite","notification")->{node_id};
  my $favoriteLinkType = getNode("favorite","linktype")->{node_id};
  my $faves = $DB->sqlSelectMany(
    "from_node",
    "links",
    "to_node = $$USER{user_id} AND linktype= $favoriteLinkType");

  while (my $f = $faves->fetchrow_hashref){
    my $fVars = getVars(getNodeById($$f{from_node}));
    if ($$fVars{settings}) 
    {
      if (from_json($$fVars{settings})->{notifications}->{$favoriteNotification})
      {
        my $argSet = { writeup_id => getId($WRITEUP),
          favorite_author => $$USER{user_id}};
        my $argStr = to_json($argSet);
        my $addNotifier = htmlcode('addNotification',
          $favoriteNotification, $$f{from_node},$argStr);
      }
    }
  }

  # Determine if this is a user created in the last two weeks
  my $dateParser = new DateTime::Format::Strptime(
    pattern => '%F %T',
    locale  => 'en_US',
  );

  # This only really doesn't happen in the test environment
  if(my $createTime = $dateParser->parse_datetime($$USER{createtime}))
  {
    my $userAge = DateTime->now()->subtract_datetime($createTime);
    my $youngAge = DateTime::Duration->new(days => 14);
    my $isYoungin = (DateTime::Duration->compare($userAge, $youngAge) < 0 ? 1 : 0);

    # Make a notification about a newbie writeup

    if($$VARS{numwriteups} == 1 || $isYoungin)
    {
      htmlcode('addNotification' , "newbiewriteup", undef,
        {
          writeup_id => getId($WRITEUP),
          author_id => $$USER{user_id},
          publish_time => DateTime->now()->strftime("%F %T")
        }
      );
    }
  }

  $query -> param('publish', 'OK');

}

# Used to basically display theme stuff. Likely going to be moved to a template function
# Currently used in settings, themes, and nodeballs
#
sub displayvars
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $SETTINGS = getVars $NODE;
  my $str = '';
  my ($keyclr, $valclr) = ('#CCCCFF', '#DEDEFF');

  my @skeys = keys %$SETTINGS;
  if(not @skeys) { 
    return "<em>the node's settings are empty</em><br>\n";
  }

  $str .= scalar(@skeys).' key/value pair';
  $str .= 's' unless scalar(@skeys)==1;
  $str .= ':';

  @skeys = sort {$a cmp $b} @skeys;

  $str.="<table width=\"100%\" cellpadding=\"1\" cellspacing=\"1\" border=\"0\">\n";
  $str.="<TR><TH>Setting</TH><TH>Value</TH></TR>\n";
  foreach (@skeys) {
    $str.= '<tr><td class="setting" bgcolor="'.$keyclr.'">'.$_.'</td><td class="setting" bgcolor="'.$valclr.'">'.encodeHTML($$SETTINGS{$_}, 1)."</td></tr>\n";  
  }
  $str .="</table>\n";
  return $str
}

sub editvars
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "<i>you can't update this node</i>" unless $DB->canUpdateNode($USER, $NODE);
  my $SETTINGS = getVars($NODE);
  my @params = $query->param;
  my $str=''; 

  foreach (@params) {
    if(/setsetting_(.*)$/) {
      $$SETTINGS{$1}=$query->param('setsetting_'.$1);
    }
  }

  foreach (@params) {
    if(/delsetting_(.*)$/) { #for s/a/b in 'cloakers'
      delete $$SETTINGS{$1};
    }
  }


  if($query->param('newsetting') ne '' and $query->param('newval') ne ''){
    my $title = $query->param('newsetting');
    $$SETTINGS{$title} = $query->param('newval');
  }

  setVars ($NODE, $SETTINGS);
  my @skeys = keys %$SETTINGS;
  @skeys = sort {$a cmp $b} @skeys;

  my ($keysize, $valsize) = (15, 30);
  my $oddrow = '';

  $str.="<table class='setvarstable'>\n";
  $str.="<tr><th>Remove</th><th>Setting</th><th>Value</th></tr>\n";
  foreach(@skeys) {
    $oddrow = ($oddrow ? '' : ' class="oddrow"');
    my $value = encodeHTML($$SETTINGS{$_});

    #  This breaks if there's a double quote in the text, so we replace with &quot;
    $value =~ s/\"/&quot;/g;
    $str.=qq'<tr$oddrow><td><input type="checkbox" name="delsetting_$_"></td>
      <td class="setting"><b>$_</b></td>
      <td class="setting"><textarea name="setsetting_$_" class="expandable"
        cols="$valsize" rows="1">$value</textarea></td></tr>\n';
  }

  $str.=qq'<tr><td></td>
    <td><input type="text" name="newsetting" size="$keysize"></td>
    <td><textarea name="newval" class="expandable" cols="$valsize" rows="1"></textarea></td></tr>\n';
  $str.="</table>\n";

  return $str;
}

# Used by the legacy display stuff: printable and node heaven
#
sub displaywriteuptext
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  #displaywriteuptext - pass writeup's node_id

  my ($num) = @_;

  my $WRITEUP = undef;
  my $LNODE = undef;
  if (not $num) {
    $LNODE = $$NODE{parent_e2node}; 
    $WRITEUP=$NODE;
  } else {
    $LNODE = getId($NODE);
    my @group = ();
    @group = @{$$NODE{group}} if $$NODE{group};
    return unless @group;
    $WRITEUP = getNodeById($group[$num-1]);
  }

  return '' unless $WRITEUP;

  my $TAGNODE = getNode('approved html tags', 'setting');
  my $TAGS=getVars($TAGNODE);

  my $text = htmlcode('standard html screen', $$WRITEUP{doctext}, $LNODE);
  my $wuid = getId($WRITEUP);
  return '<!-- google_ad_section_start --><!-- '.$wuid.'{ -->'.$text.'<!-- }'.$wuid.' --><!-- google_ad_section_end -->';

}

# Used by the category display page, and the legacy page display, via displaywriteuptext
#
sub standard_html_screen
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($text, $lastnode_id) = @_;

  my $TAGNODE = getNode('approved html tags', 'setting');
  my $TAGS = getVars($TAGNODE);

  $lastnode_id = undef if ($APP->isGuest($USER));

  $text = htmlScreen($text, $TAGS);
  $text = screenTable ($text);
  $text = parseLinks($text, $lastnode_id);
  $text = breakTags($text);
  return $text;
}

# Used to link the viewcode page in the edev nodelet
#
sub viewcode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isDeveloper($USER);

  my $ntt = $$NODE{type}{title};
  return unless ($ntt eq 'superdoc') || ($ntt eq 'superdocnolinks') || ($ntt eq 'nodelet');

  return '<font size="1">'.linkNode($NODE, 'viewcode', {'displaytype'=>'viewcode', 'lastnode_id'=>0}).'</font>';
}

sub addwriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $canPublishDirectly = 2; # this level doesn't have to create draft first

  if ( $APP->isMaintenanceNode($NODE) ){
    $canPublishDirectly = -1;
  }

  # get existing wu or reason for no new posting:
  my $MINE = undef; #mod_perl safety
  $MINE = delete $PAGELOAD->{my_writeup}; # saved by [canseewriteup]
  $MINE ||= htmlcode('nopublishreason', $USER, $NODE);
  return '<div class="nodelock"><p>'.$MINE.'</p></div>' if $MINE and !UNIVERSAL::isa($MINE,'HASH');

  # OK: user can post or edit a writeup/draft

  my ($str, $draftStatusLink, $lecture) = (undef,undef,undef);

  if ($MINE){
    return '<p>You can edit your contribution to this node at'.linkNode($MINE).'</p>' if $$VARS{HideWriteupOnE2node}; # user doesn't want to see their text

    $str.=$query->start_form(-action => urlGenNoParams($MINE, 'noQuotes'), -class => 'writeup_add')
      .$query -> hidden(-name => 'node_id', value => $$MINE{node_id}, -force => 1); # go to existing writeup/draft on edit
	
    $draftStatusLink = '<p>'
      .linkNode($MINE, 'Set draft status...', {
        -id => "draftstatus$$MINE{node_id}"
        , -class => "ajax draftstatus$$MINE{node_id}:setdraftstatus?node_id=$$MINE{node_id}:$$MINE{node_id}"
      }).'</p>' if $$MINE{type}{title} eq 'draft';

  } else {
    # set default type for [editwriteup]
    $MINE = {type => {title=>'writeup'}};

    # restricted options and lecture for new users:
    my $level = $APP->getLevel($USER);
    if ($level <= $canPublishDirectly){
      $$MINE{type}{title} = 'draft' if $level < $canPublishDirectly;

      $lecture = '<p class="edithelp">Before publishing a writeup, you '
        .($$MINE{type}{title} ne 'draft' ? 'should normally ' : '')
        .'first post it as a '
        .linkNode(getNode('Drafts','superdoc'), 'draft')
        .'. This gives you a chance to correct any mistakes in the content or formatting before anyone else
          reads and can vote on it, or to ask other users to make suggestions or improvements.</p>'
    }

    $str.=$query->start_form(
      -action => '/user/'
      .rewriteCleanEscape($$USER{title})
      .'/writeups/'
      .rewriteCleanEscape($$NODE{title}),
        -name=>'wusubform',
        -class => 'writeup_add')
      .qq'
        <input type="hidden" name="node" value="new writeup">
        <input type="hidden" name="writeup_parent_e2node" value="$$NODE{node_id}">
        <input type="hidden" name="draft_title" value="$$NODE{title}">';
  }

  return $str.htmlcode('editwriteup', $MINE, $lecture)."</form>$draftStatusLink";
}

# Used everywhere
#  inverse of this is in varcheckboxinverse
#	checked   : $$VARS is 1
#	unchecked : $$VARS doesn't exist
#
sub varcheckbox
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($k, @title) = @_;

  return if ($APP->isGuest($USER)) || ($$USER{title} eq 'everyone');
  my $title = join ', ', @title;
  $title ||= $k;

  if($query->param('setvar_'.$k)) {
    $$VARS{$k} = 1;
  } elsif($query->param('sexisgood')) {
    delete $$VARS{$k};
  }

  return $query->checkbox('setvar_'.$k, $$VARS{$k}, '1', $title);

}

# Used everywhere
#  inverse of varcheckbox
#	checked   : $$VARS doesn't exist
#	unchecked : $$VARS is 1
#
sub varcheckboxinverse
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($k, @title) = @_;

  return if ($APP->isGuest($USER)) || ($$USER{title} eq 'everyone');
  my $title = join ', ', @title;
  $title ||= $k;

  if($query->param('unsetvar_'.$k)) {
    delete $$VARS{$k};
  } elsif($query->param('sexisgood')) {
    $$VARS{$k} = 1;
  }

  return $query->checkbox('unsetvar_'.$k, !$$VARS{$k}, '1', $title);
}

# usersearchform - Used in joker's chat only.
#   TODO - Remove this
#
sub usersearchform
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($PARAM) = @_;

  my $default ='';
  my $lnid = getId($NODE);
  my $ParentNODE = $NODE;
  if(!$APP->isGuest($USER) and my $ln = $query->param('lastnode_id')  and ($query->param('lastnode_id') =~ /^\d+$/)) {
    my $LN = getNode $ln;
    if($$LN{type}{title} eq 'writeup') {
      $LN = getNodeById($$LN{parent_e2node});
    }
    $default = $$LN{title} if $LN;
  }

  if($$NODE{type}{title} eq 'writeup') {
    $ParentNODE = getNodeById($$NODE{parent_e2node});
  }
  $lnid = $$ParentNODE{node_id} if $ParentNODE;

  my $title=$query->param('node');
  $query->param('node', $default); 

  my $str = '';

  $str.="
    <script type='text/javascript' >
      function fullText() {
        fT = \$('full_text');
        if (fT.checked) {
          searchForm = fT.parentNode.parentNode.parentNode.parentNode.parentNode.parentNode;
          searchForm.id = 'searchbox_017923811620760923756:pspyfx78im4';
          searchForm.action = '/title/Google%20Search%20Beta';
          searchForm.method = 'GET';

          cx = document.createElement('input');
          cx.type = 'hidden';
          cx.name = 'cx';
          cx.value ='017923811620760923756:pspyfx78im4';

          cof = document.createElement('input');
          cof.type = 'hidden';
          cof.name = 'cof';
          cof.value ='FORID:9';

          sa = document.createElement('input');
          sa.type = 'hidden';
          sa.name = 'sa';
          sa.value = 'Search';

          searchForm.appendChild(cx);
          searchForm.appendChild(cof);
          searchForm.appendChild(sa);

          \$('node_search').name = 'q';
       }
      return true;
    }
    </script>";

  $str .= $query->start_form("GET",$query->script_name, "onSubmit='return fullText();'");
  $str .= '<table cellpadding="0" cellspacing="0"><tr valign="middle">';
  $str.= '<td>'.
  $query->textfield(-name => 'node',
    -id => 'node_search',
    -default => $default,
    -size => 28,
    -maxlength => 80);
  $str.='<input type="hidden" name="lastnode_id" value="'.$lnid.'" />';

  $str.='</td><td>';
  $str.='<input type="submit" name="searchy" value="search" />';

  $query->param('node', $title); 

  $str.= '</td><td style="font-family:sans-serif;">';

  $query->param('soundex', '');
  $query->param('match_all', '');
  $query->param('nosoftlink', '');

  $str.="\n".$query->checkbox(
    -name => 'soundex',
    -value => '1',
    -label => '',
  );

  $str.="<small><small>Near Matches</small></small>";

  $str.="<br />\n".$query->checkbox(
    -name => 'match_all',
    -default => '0',
    -value => '1',
    -label => '',
  );
  $str.="<small><small>Ignore Exact</small></small>";

  $str.="<br />\n".$query->checkbox(
    -id => "full_text",
    -name => 'full_text',
    -value => '1',
    -label => ''
  );

  $str.="<small><small>Full Text</small></small>";

  return $str . '</td></tr></table>';
}

# newwriteups - Unsure where this is used; tough to tell because of ajax call stuff and because of the number of stylesheets
#   TODO - Where is this used?
sub newwriteups
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($limit) = @_;
  $limit ||= 15;

  my $str = '<table width="100%" border="0" cellpadding="0" cellspacing="0">';

  my $qry = "SELECT parent_e2node, (select title from node where node_id=writeup.wrtype_writeuptype limit 1) as type_title, writeup_id, (select author_user from node where node_id=writeup.writeup_id limit 1) as author_user, (select title from node where node_id=writeup.parent_e2node limit 1) as parent_title FROM writeup where notnew=0 ORDER BY writeup.publishtime DESC LIMIT $limit ";

  my $csr = $Everything::dbh->prepare($qry);

  $csr->execute or return "newwriteups: can't get";

  my $count=0;
  my @colors = ('#CCCC99');


  while(my $N = $csr->fetchrow_hashref) {
    my $clr = $colors[$count++%int(@colors)];
    my $st = $$N{parent_title};
    my $len = 24;
    my @words = split ' ', $st;

    foreach (@words) {
      if(length($_) > $len) {
        $_ = substr($st, 0, $len);
        $_ .= '...';
      }
    }

    $st = join ' ', @words;
    $str .= '<tr bgcolor="'.$clr.'"><td class="oddrow" align="center" colspan="2"><strong>'.linkNode($$N{author_user}, '', {lastnode_id=>undef});

    $str .= '</strong></td>';
    $str .= '</tr><tr><td align="left">'.linkNode($$N{parent_e2node}, $st, {lastnode_id=>undef}) 
      .'</td><td align="right"><small>('.linkNode($$N{writeup_id}, $$N{type_title},{lastnode_id=>undef}).')</small>';
    $str.= "</td></tr>\n";
  }

  $csr->finish;
  $str.="</font></td></tr></table>\n";

  return $str;
}

# editSingleVar - used by the user edit page
#
sub editSingleVar
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "<i>you can't update this node</i>" unless canUpdateNode($USER, $NODE);
  my ($var, $title) = @_;
  my $SETTINGS = getVars($NODE);
  my @params = $query->param;
  my $str=""; 

  foreach (@params) {
    if (/setsetting_$var$/) {
      $$SETTINGS{$var}=$query->param("setsetting_$var");    
    }
  }

  if(getId($USER) == getId($NODE))
  { 
    $$VARS{$var} = $$SETTINGS{$var};
  } else { 
    setVars ($NODE, $SETTINGS);
  }

  my ($keysize, $valsize) = (15, 30);
  my ($keyclr, $valclr) = ("#CCCCFF", "#DEDEFF");
  my $t = $title ? $title:$var;

  $str.="<TABLE width=100% cellpadding=2 cellspacing=0>\n";
  $str.="<TR><TD width=20% class=\"oddrow\" bgcolor=$keyclr><b>$t</b></TD>" .
    "<TD class=\"oddrow\" bgcolor=$valclr>".$query->textfield("setsetting_$var", $$SETTINGS{$var}, $valsize)."</TD></TR>\n";
  $str.="</TABLE>\n";

  return $str;
}

sub setwriteuptype
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N, $title) = @_;

  my $type = undef;
  if (ref $N){
    $type = $$N{wrtype_writeuptype};
  }else{
    $type = $N;
  }

  my $hidebox = undef;

  unless ($type){
    # no old type: new writeup/draft for publication
    my $checked = undef;

    $title ||= $$NODE{title};
    return $query -> hidden('writeup_notnew', 1).'Writeup type: thing; don\'t show in New Writeups nodelet' if $APP->isMaintenanceNode($NODE);

    if (
      $title =~ /^(January|February|March|April|May|June|July|August|September|October|November|December) [1-9]\d?, \d+/i ||
      $title =~/^(dream|editor|root) Log: /i ||
      $$VARS{HideNewWriteups}
    ){
      $type = getNode('log', 'writeuptype')->{node_id} if $1;
      $checked = 1;
    }

    $checked = ' checked="checked"' if $checked or ref($N) && 
      ($$N{reputation} || $DB -> sqlSelect('vote_id', 'vote', "vote_id=$$N{node_id}")
      || $DB -> sqlSelect(
        'LEFT(notetext, 25)'
        , 'nodenote'
        , "nodenote_nodeid=$$N{node_id} AND noter_user = 0"
        , 'ORDER BY timestamp LIMIT 1'
      ) eq 'Restored from Node Heaven');

    $type ||= getNode('thing', 'writeuptype') -> {node_id};

    $hidebox = qq!<label><input type="checkbox" name="writeup_notnew" value="1"$checked>don't show in New Writeups nodelet</label>!;
  }

  my $str = '<label title="Set the general category of your writeup, which helps identify the type of content in writeup listings."><strong>Writeup type:</strong>';

  my (@WRTYPE) = getNodeWhere({type_nodetype => getId(getType('writeuptype'))});

  my %items = ();

  my $isEd = $APP->isEditor($USER) || $$USER{title} eq 'Webster 1913' || $$USER{title} eq 'Virgil';

  my $isE2docs = $APP->inUsergroup($USER,"E2Docs");

  foreach (@WRTYPE){
    next if (!$isEd and lc($$_{title}) eq 'definition' || lc($$_{title}) eq 'lede');
    next if ((!$isEd or !$isE2docs) and lc($$_{title}) eq 'help');
    $items{$$_{node_id}} = $$_{title};
  }

  $items{$type} = '('.$type.')' if !defined($items{$type});
  my @idlist = sort { $items{$a} cmp $items{$b} } keys %items;

  $str.=$query->popup_menu('writeup_wrtype_writeuptype', \@idlist, $type, \%items) . '</label>';
  return $str . $hidebox;

}

# [{parsetimestamp:time,flags}]
# Parses out a datetime field into a more human-readable form
# note: the expected time format in the parameter is: yyyy-mm-dd hh:mm:ss, although the year part works for any year after year 0
#	flags: optional flags:
#		1 = hide time (only show the date)
#		2 = hide date (only show the time)
#		4 = hide day of week (only useful if showing date)
#		8 = show 'UTC' (recommended to show only if also showing time)
#		16 = show full name of day of week (only useful if showing date)
#		32 = show full name of month (only useful if showing date)
#		64 = ignore user's local time zone settings
#		128 = compact (yyyy-mm-dd@hh:mm)
#		256 = hide seconds
#		512 = leading zero on single-digit hours
#
sub parsetimestamp
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($timestamp,$flags)=@_;
  $flags = ($flags || 0)+0;
  my ($date, $time, $yy, $mm, $dd, $hrs, $min, $sec) = (undef,undef,undef,undef,undef,undef,undef,undef);
 
  if($timestamp =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})$/)
  {
    ($yy, $mm, $dd, $hrs, $min, $sec) = ($1, $2, $3, $4, $5, $6);
    #let's hear it for fudge:
    $mm-=1;
  }elsif($timestamp =~ / /)
  {
    ($date, $time) = split / /,$timestamp;

    ($hrs, $min, $sec) = split /:/, $time;
    ($yy, $mm, $dd) = split /-/, $date;
    $mm-=1;
  }

  # I repeat: let's hear it for fudge!
  return "<em>never</em>" unless (int($yy)>0 and int($mm)>-1 and int($dd)>0);

  my $epoch_secs = timelocal( $sec, $min, $hrs, $dd, $mm, $yy);

  if(!($flags & 64) && $VARS->{'localTimeUse'}) {
    $epoch_secs += $VARS->{'localTimeOffset'} if exists $VARS->{'localTimeOffset'};
    #add 1 hour = 60 min * 60 s/min = 3600 seconds if daylight savings
    $epoch_secs += 3600 if $VARS->{'localTimeDST'};	#maybe later, only add time if also in the time period for that - but is it true that some places have different daylight savings time stuff?
  }

  my $wday = undef;
  ($sec, $min, $hrs, $dd, $mm, $yy, $wday, undef, undef) = localtime($epoch_secs);
  $yy += 1900;	#stupid Perl
  ++$mm;

  my $niceDate='';
  if(!($flags & 2)) {	#show date
    if ($flags & 128) { # compact
      $mm = substr('0'.$mm,-2);
      $dd = substr('0'.$dd,-2);
      $niceDate .= $yy. '-' .$mm. '-' .$dd;
    } else {
      if(!($flags & 4))
      {	
        #4=hide week day, 0=show week day
        $niceDate .= ($flags & 16)	#16=full day name, 0=short name
          ? (qw(Sunday Monday Tuesday Wednesday Thursday Friday Saturday))[$wday].', '
          : (qw(Sun Mon Tue Wed Thu Fri Sat))[$wday].' ';
      }

      my $fullMonthName = $flags & 32;
      $niceDate .= ($fullMonthName
        ? (qw(January February March April May June July August September October November December))
        : (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)))[$mm-1];

      $dd='0'.$dd if length($dd)==1 && !$fullMonthName;
      $niceDate .= ' ' . $dd;
      $niceDate .= ',' if $fullMonthName;
      $niceDate .= ' '.$yy;
    }
  }

  if(!($flags & 1)) {	#show time
    if ($flags & 128) { # if compact
      $niceDate .= '@' if length($niceDate);
    } else {
      $niceDate .= ' at ' if length($niceDate);
    }

    my $showAMPM='';
    if($VARS->{'localTime12hr'}) {
      if($hrs<12) {
        $showAMPM = ' AM';
        $hrs=12 if $hrs==0;
      } else {
        $showAMPM = ' PM';
        $hrs -= 12 unless $hrs==12;
      }
    }

    $hrs = '0'.$hrs if $flags & 512 and length($hrs)==1;
    $min = '0'.$min if length($min)==1;
    $niceDate .= $hrs.':'.$min;
    if (!($flags & 128 or $flags & 256)) { # if no compact show seconds
      $sec = '0'.$sec if length($sec)==1;
      $niceDate .= ':'.$sec;
    }	

    $niceDate .= $showAMPM if length($showAMPM);
  }

  $niceDate .= ' UTC' if length($niceDate) && ($flags & 8);	#show UTC

  return $niceDate;

}

sub coolit
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);
  my $ntypet = $$NODE{type}{title};
  return unless ($ntypet eq 'e2node' || $ntypet eq 'superdoc' || $ntypet eq 'superdocnolinks' || $ntypet eq 'document');

  my $str = '<span id="editorcool">' ;
  my $class = "action ajax editorcool:coolit" ;

  my $COOLLINK = getNode('coollink','linktype') -> {node_id};
  my $COOLNODE = getNode('coolnodes','nodegroup');
  my $link = undef;

  if ( exists $PAGELOAD->{edcoollink} ){
    $link = $PAGELOAD->{edcoollink} ; # cached by [page header]
  } else {
    $link = $DB->sqlSelectHashref('to_node', 'links', 'from_node='.$$NODE{node_id}.' and linktype='.$COOLLINK.' limit 1');
  }

  return '' if $link and $ntypet ne 'e2node' || ($$NODE{group} && @$NODE{group}) # let anyone uncool a nodeshell
    and ( $APP->isEditor($$link{to_node}) ) and $$link{to_node}!=$$USER{node_id} ;

  if ($query->param('uncoolme')) {
    $DB->sqlDelete('links', 'from_node='.$$NODE{node_id}.' and linktype='.$COOLLINK.' limit 1');
    removeFromNodegroup($COOLNODE, $NODE, -1);
    $str .= '(you uncooled it) ' ;
    $link = undef ;
  }

  if ($link) {
    $str.= linkNode( $NODE , 'uncool' , { notanop => 'uncoolme' , confirmop => 'hellyeah' ,
      -title => 'uncool this node' , -class => $class }) ;
  } elsif (not $query->param('coolme')) {
    $str.=linkNode($NODE,'cool!',{coolme => 'hellyea', '-title' => 'Editor Cool this node', '-class'=>$class});
  } else {
    insertIntoNodegroup($COOLNODE, -1, $NODE);
    updateLinks($USER, $NODE, $COOLLINK);
    $str.='You cooled it. ('.linkNode( $NODE , 'undo' , { 'uncoolme' => 'oops' , -title => 'undo cool' , -class => $class }).')' ;

    if($ntypet eq 'e2node') {
      my $eddie = getId(getNode('Cool Man Eddie','user'));
      my @group = @{ $$NODE{group} } if $$NODE{group};
      my $WRITEUP = undef;
      my $nt = $$NODE{title};
	
      if(scalar(@group)) {
        my @authors = map { getNodeById($_)->{author_user} } @group;
        htmlcode('sendPrivateMessage',{
          'author_id' => $eddie,
          'recipient_id' => \@authors,
          'message' => 'Yo, the entire node ['.$nt.'], in which you have a writeup, was editor cooled. Your reward is knowing you\'re cooler than liquid nitrogen.',
          'fromgroup_id' => $$USER{node_id},	#group is editor that did cool
        });
      }

    }	#if e2node
  }

  return "$str</span>" ;
}

# Used largely on htmlpages; very likely able to move this to a template function
#
sub node_menu
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field, @VALUES) = @_;
  my @idlist = ();
  my %items = {};
  my @TYPES = ();

  $field or return;
  my ($fieldname, $type) = split /\_/, $field;
  my ($name) = $$NODE{type}{title} .'_'. $field;

  #if no explicit types, use the field name to determine
  @VALUES or push @VALUES, $type;

  foreach (@VALUES)
  {
    next if ($_ eq 'user');
    if(/^-/)
    {
      # If one of the types is in the form of
      # -name_value, we need to split it apart
      # and store it.	
      my ($name, $value) = (undef,undef);
      $_ =~ s/^-//;
		
      ($name, $value) = split '_', $_;
      push @idlist, $value;
      $items{$value} = $name;

      undef $_;  # This is not a type	
    } else {
      my $TYPE = $DB->getType($_); 
      push @TYPES, $TYPE if(defined $TYPE); #replace w/ node refs
    }
  }

  my $NODELIST = $DB->selectNodeWhere({ type_nodetype => \@TYPES }, "", "title") if @TYPES;

  foreach my $N (@$NODELIST) {
    $N = $DB->getNodeById($N, 'light');
    my $id = getId $N;
    push @idlist, $id;
    $items{$id} = $$N{title};
  }

  # The default thing to select
  my $SELECT = $$NODE{$field};

  if(not defined $items{"0"})
  {
    # We have no value for zero, make it default if current value is not in menu
    $items{"0"} = $items{$SELECT} ? 'none' : ' ' ;
    unshift @idlist, "0";
  }

  return $query->popup_menu($name, \@idlist, $SELECT, \%items);

}

# Used only in the [Settings] page where they select theme, so this is really likely going to get killed shortly
# This constructs an HTML popup menu using the FormMenu
# package of Everything.  Values of the menu come from
# the specified "setting" node.
#
# $name - the name for the form item drop down
# $selected - which item should be selected by default.
#    undef if nothing specific.
# The remaining items passed are the names of the types.
#
sub typeMenu
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $name = shift;
  my $selected = shift;

  my $menu = new Everything::FormMenu;
  my $typename = undef;

  while(@_ > 0)
  {
    $typename = shift @_;
    $menu->addType($typename);
  }

  return $menu->writePopupHTML($query,$name,$selected);
}

# Used in the zen epicenter. Very likely a future template function
#
sub randomnode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($title) = @_;
  $title||='random';
  my $rnd = int(rand(100000));

  return '<a href='.urlGen({op=>'randomnode', garbage=>$rnd}).">$title</a>";
}

# On its way to being a template mixin
#
sub votefoot
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $uid = $$USER{user_id};
  return $query->end_form if $$NODE{type}{title} eq "e2node" && not $$NODE{group} || $APP->isGuest($USER) ;
  my $isKiller = $APP->isEditor($USER);

  my $voteButton = undef;
  my $killButton = undef;
  my $rowFormat =  '<div id="votefooter">%s%s</div>';

  if( $query->param('numvoteit') && $$USER{votesleft} ) {
    $voteButton = "<input type='submit' name='sexisgreat' id='votebutton' value='vote!'>";
  } elsif ( !$APP->isGuest($USER) ) {
    $voteButton = "<input type='submit' name='sexisgreat' id='blabbutton' value='blab!' title='send writeup messages'>";
  }

  $killButton = $isKiller && $$NODE{type}{title} ne 'draft' ? "<p><input type='submit' name='node' id='killbutton' value='The Killing Floor II'>" : '';

  return sprintf($rowFormat, $voteButton, $killButton) . $query->end_form;
}

# One of the many nodeletsection htmlcodes. 
#
sub episection_admins
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "\n\t\t<ul>";
  $str.=linkNodeTitle('nate\'s secret unborg doc|Unborg Yourself')."<br />\n" if $$VARS{borged};
  $str.=
    "\n\t\t\t<li>".linkNodeTitle('Edit These E2 Titles').'</li>'.
    "\n\t\t\t<li>".linkNodeTitle('The Node Crypt').'</li>'.
    "\n\t\t\t<li>".linkNodeTitle('Node Heaven Search').'</li>'.
    "\n\t\t\t<li>".linkNodeTitle('God Powers and How to Use Them|Admin HOWTO').'</li>';

  $str.="\n\t\t</ul>";
  return $str;
}

sub weblog
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $interval, $log_id, $remlabel, $hideLinker, $skipFilterHTML, $listOnly ) = @_ ;

  $log_id ||= getId( $NODE ) ;
  $interval ||= 5 ;
  $listOnly ||= 0 ;

  my $endat = $interval ;
  if ($query && $query->param( 'nextweblog' )) {
    $endat = $query->param( 'nextweblog' );
  }

  my $offset = ( $endat == $interval ? '' : ' OFFSET '.( $endat - $interval ) ) ;

  my $csr = $DB->sqlSelectMany(
    'weblog_id, to_node, linkedby_user, linkedtime' ,
    'weblog' ,
    "weblog_id=$log_id AND removedby_user=0" ,
    "ORDER BY linkedtime DESC LIMIT $interval$offset" ) ;

  my %weblogspecials = ();

  $weblogspecials{ getloggeditem } = sub {
    my ( $L ) = @_ ;
    my $N = getNodeById( $L->{ to_node } ) ;
    # removed nodes/de-published drafts:
    return "Can't get node id ".$L->{ to_node } unless $N and $$N{type}{title} ne 'draft';
    $_[0] = { %$N , %$L } ; # $_[0] is a hashref from a DB query: no nodes harmed
    return '' ;
  } ;

  return "<ul>\n".htmlcode( 'show content' , $csr , '<li> getloggeditem, title, byline' , %weblogspecials ).
    "\n</ul>" if $listOnly eq '1' ;

  my $instructions = 'getloggeditem, title, byline, date' ;
  my $uid = getId( $USER ) ;
  my $canRemove = $APP->isAdmin($USER) ;
  my $isCE = $canRemove || $APP->isEditor($USER) ;
  $canRemove ||= ( $$USER{ node_id } == $APP -> getParameter($NODE, 'usergroup_owner') ) ;

  # linkedby: 0=show (default), 1=CE can see, 2=root can see, 3 or anything else=nobody can see
  # BUG: 2 -> owner can see if CE even if not root
  if( !defined $hideLinker ) {
    $hideLinker = 0 ;
  } elsif ( !( ( $hideLinker =~ /^(\d)$/ ) && ( ( $hideLinker = $1 ) <= 3 ) ) ) {
    $hideLinker = 3;
  }

  --$hideLinker if $isCE ;
  --$hideLinker if ( $canRemove ) ;

  unless ( $hideLinker > 0 ) {
    $instructions .= ', linkedby' ;
    $weblogspecials{ linkedby } = sub {
      my $N = shift ;
      return '<div class="linkedby">linked by '.linkNode( $$N{linkedby_user}, '', {lastnode_id =>0} ).'</div>' unless $$N{linkedby_user}==$$N{author_user} ;
      return '' ;
    } ;
  }

  $remlabel ||= "remove";
  if ( $canRemove ) {
    $instructions .= ', remove' ;
    eval( q|$weblogspecials{ remove } = sub {
    my $N = shift ;
    return '<a class="remove" href='
      . urlGen( { node_id => $$N{ weblog_id }, source => $$N{ weblog_id } , to_node => $$N{ to_node } , op => 'removeweblog' } )
      . '>'.'|.$remlabel.q|'.'</a>' ;
    }|);
  }

  $instructions .= ( $skipFilterHTML ne '1' ? ', content' : ', unfiltered' ) ;

  my $str = htmlcode( 'show content' , $csr , $instructions , %weblogspecials ) ;
  my $isolder = $DB->sqlSelect( 'linkedtime' , 'weblog' ,
    "weblog_id=$log_id AND removedby_user=0" , "ORDER BY linkedtime DESC LIMIT 1 OFFSET $endat" ) ;

  if ( $offset or $isolder ) {
    $str .= '<div class="morelink">' ;
    $str .= linkNode( $NODE, '<- newer', { nextweblog => $endat - $interval } ) if $offset ;
    $str .= ' | ' if $offset and $isolder ;
    $str .= linkNode( $log_id , 'older ->' , { nextweblog => $endat + $interval } ) if $isolder ;
    $str .= '</div>' ;
  }

  return "<div class=\"weblog\">\n$str\n</div>" ;
}

# displays hints on improving the writeup
# parameters:
#   (use no parameters when in a writeup display page)
#
sub writeuphints
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $writeup = undef;

  if(ref $_[0] eq "ARRAY")
  {
    $writeup = $_[0]->[0];
  }else{
    $writeup = $$NODE{doctext};
  }

  my $UID = getId($USER);
  my $isCE = $APP->isEditor($USER);
  my $isMyWU = ($$NODE{author_user}==$UID);
  my @problems;	#all problems found

  #don't show unless it is your own writeup, or you are an editor
  unless($isMyWU) {
    if($isCE) {
      push @problems, '<big>Note</big>: This isn\'t your writeup, so don\'t feel obliged to fix any problems listed here.';
    } else {
      return;
    }
  }

  my $showDefault = !$$VARS{nohints};
  my $showHTML = !$$VARS{nohintHTML};
  my $showXHTML = $$VARS{hintXHTML};	#pref: strict HTML
  my $showSilly = $$VARS{hintSilly};
  my $showSpelling = !$$VARS{nohintSpelling};

  return unless $showDefault || $showHTML || $showXHTML || $showSilly || $showSpelling;

  my $showCat = 1;	#1 to show hint categories, 0 to hide
  my $curCat = undef;

  return if $APP->isMaintenanceNode($NODE);

  my $c = undef;
  my $i = undef;

  #several tests are done on links, so may as well just find all links only once
  #note: scalar(@wuPartText) == scalar(@wuPartLink)+1
  #note: $wuPartText[$n] before $wuPartLink[$n] before $wuPartText[$n+1]

  my @wuPartText = ();
  my @wuPartLink = ();
  #there is probably a better way of doing this
  my @allParts = split(/\[(.*?)\]/s, $writeup);
  $i = -1;
  $c = scalar(@allParts);

  foreach(@allParts) {
    push(@wuPartText, $allParts[++$i]);
    if($i<$c) {
      push(@wuPartLink, $allParts[++$i]);
    }
  }

  #Count paragraphs, accounting for both <p...> and <BR><BR>
  my @allParagraphs = split(/\<\w*?p|<br>\w*?<br>/si, $writeup);

  $writeup = ' '.$writeup.' ';	#cheap hack - stylewise :( and speedwise :) - to make \s match at start and end

  #warning to bones:  you will need to escape any single quotes!
  #"let's" -> "let\'s" -- (you get the idea)
  #also, use &#91; and &#93; instead of [ and ], respectively

  #default hints
  if($showDefault) {
    $curCat = $showCat ? '(essential) ' : '';

    if(length $writeup < 512) {
      push(@problems, $curCat.'You have a whole lot more space for your writeup...why so short? Tell us more! Try to include some references or "further reading" through hard-links.');
    }

    my $numlinks = scalar(@wuPartLink);
    #count number of paragraphs in the writeup
    my $numparagraphs = scalar(@allParagraphs);

    #New linking suggestion:  see if we have an average of at least one link per paragraph rather than by character count.
    if($numlinks < $numparagraphs) {
      push(@problems, $curCat.'How about linking other nodes in your writeup? To link, put "&#91;" and "&#93" around a node name: &#91;Brian Eno&#93; creates a link to '.linkNodeTitle('Brian Eno').'. Also, you can use a pipe (|) to designate a title. &#91;Brian Eno|Master of Sound&#93; links to '.linkNodeTitle('Brian Eno').', but looks like this: '.linkNodeTitle('Brian Eno|Master of Sound').'.
</p><p>
Use the pipe to reduce the number of <em>dead-end links</em> in your writeups by showing one thing and pointing to another. For example:  &#91;fiction|those crazy voices in my head&#93;.
</p><p>
You don\'t even need to have nodes created to make links to them, once you\'ve linked you can create the nodes simply by clicking on them -- the Everything search will give you a list of similar choices...use the <em>pipe</em> to point to these or create a new node!'
        );
    }

    #forgot to close a link - long link
    $i=127;	#too high? (99 was too short for some crazy softlinkers)
    $c='';

    foreach(@wuPartLink) {
      if(length($_)>$i) {
        $c.=', ' if length($c);
        $c.='" <code>&#91;'.encodeHTML(substr($_,0,$i),1).'</code> "';
      }
    }

    if(length($c)) {
      push @problems, $curCat.'You may have forgotten to close a link. Here is the start of the long links: '.$c.'.';
    }

    #forgot to close a link - [ in a link
    $c='';

    foreach(@wuPartLink) {
      if( index($_,'[')!=-1 ) {
        next if $_ =~ /[^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?/ ; # direct link, regexp from parselinks in HTML.pm
        $c.=', ' if length($c);
        $c.='" <code>&#91;'.encodeHTML($_,1).'&#93;</code> "';
      }
    }

    if(length($c)) {
      push @problems, $curCat.'It looks like you forgot to close a link, since you tried to link to a node with &#91; in the title. Here is what you linked to: '.$c.'.';
    }

    #forgot to close a link - no final ]
    if( ($i=index($wuPartText[-1],'['))!=-1 ) {
      push @problems, $curCat.'Oops, it looks like you forgot to close your last link. You ended with: " <code>'.encodeHTML(substr($wuPartText[-1],$i),1).'</code> ".';
    }

  } #end show default hints

  #HTML hints
  if($showHTML) {
    $curCat = $showCat ? '(basic HTML) ' : '';

    #HTML tags in links
    $c='';
    foreach(@wuPartLink) {
      $i = (($i=index($_,'|'))==-1) ? $_ : substr($_,0,$i);	#only care about part that links, not display
      if($i =~ /<.*?>/) {
        $c.=', ' if length($c);
        $c.='" <code>'.encodeHTML($i,1).'</code> "';
      }
    }

    if(length($c)) {
      push @problems, $curCat.'You placed an HTML tag in a link. Either put the tag outside the link, or create a #pipe link, and put the tag in the display part. You tried to link to: '.$c.'.';
    }

    #non-escaped special characters & < > [ ]
    if($writeup =~ /\s([&<>])\s/) {
      push @problems, $curCat.'The ampersand, less-than, and greater-than symbols have special meaning in HTML, and so to show them by themselves, they have to be entered a certain way. Here is how you should enter them:
        <table border="1" cellpadding="5" cellspacing="0">
        <tr><th>symbol name</th><th>symbol to display</th><th>what to enter</th></tr>
        <tr><td>ampersand</td><td>&amp;</td><td><code>&amp;amp;</code></td></tr>
        <tr><td>less than</td><td>&lt;</td><td><code>&amp;lt;</code></td></tr>
        <tr><td>greater than</td><td>&gt;</td><td><code>&amp;gt;</code></td></tr>
        </table>
        For example, to show the symbol '.($i=encodeHTML($1,1)).' enter it as: " <code>'.encodeHTML($i).'</code> ".';
    }

    if($writeup =~ /\s([\[\]])\s/) {
      push @problems, $curCat.'On Everything, the square brackets, &#91; and &#93; have a special meaning - they form links to other nodes. If you want to just display them, you will have to use an HTML entity. To show an open square bracket &#91; type in " <code>&amp;#91;</code> ". To show a close square bracket &#93; type in " <code>&amp;#93;</code> ". If you already know this, and are wondering why you\'re seeing this message, you probably accidently inserted a space at the very '.($1 eq '[' ? 'start' : 'end').' of a link.';
    }

    #no closing semicolon on entity
    if($writeup =~ /\s&(#?\w+)\s/) {
      push @problems, $curCat.'All HTML entities should have a closing semicolon. You entered: " <code>'.($i='&amp;'.encodeHTML($1)).'</code> " but the correct way is: " <code>'.$i.';</code> ".';
    }

  } #end show HTML hints

  #strict HTML
  if($showXHTML) {
    $curCat = $showCat ? '(stricter HTML) ' : '';

    #bold tag
    if($writeup =~ /<[Bb](\s.*?)?>/) {
      push @problems, $curCat.'If you want text to be bold, the <code>&lt;strong&gt;</code> tag (instead of the <code>&lt;b&gt;</code> tag) is better in most cases.';
    }

    #italics tag
    if($writeup =~ /<[Ii](\s.*?)?>/) {
      push @problems, $curCat.'If you want text to be italics, there are a few other tags you could use instead of <code>&lt;i&gt;</code>. The <code>&lt;em&gt;</code> tag is the most commonly used alternative, which gives something <em>emphasis</em>. In rarer cases, use <code>&lt;cite&gt;</code> to cite something (such as a book title) or <code>&lt;var&gt;</code> to indicate a variable. However, using the  <code>&lt;i&gt;</code> tag here is OK for certain things, such as foreign words.';
    }

    #tt tag
    if($writeup =~ /<tt(\s.*?)?>/i) {
      push @problems, $curCat.'There are a few other tags you may want to use instead of the <code>&lt;tt&gt;</code> tag. You may want to use <code>&lt;code&gt;</code>, to indicate a code fragment; <code>&lt;samp&gt;</code>, to show sample output from a program, or <code>&lt;kbd&gt;</code>, to indicate text for the user to enter (on a keyboard).';
    }

    #maybe check for balanced tags? have to watch for <br /> <hr /> (anything else?)

    #no closing paragraph tags
    if(($writeup =~ /<[Pp](\s.*?)?>/) && ($writeup !~ /<\/[Pp]>/)) {
      push @problems, $curCat.'Each paragraph tag, <code>&lt;p&gt;</code> , should have a matching close paragraph tag, <code>&lt;/p&gt;</code> .';
    }

  } #end show strict HTML hints

  #
  # spelling
  #

  my $spellInfo = undef;
  if($showSpelling) {
    $spellInfo = getNode('bad spellings en-US','setting');
    if(defined $spellInfo) {
      $spellInfo = getVars($spellInfo);
    }
  }

  if((defined $spellInfo) && $showSpelling) {
    $curCat = $showCat ? 'spelling <small>(English)</small> ' : '';
    my @badThings = ();
    my %problemCount = undef;	#key is problem description, value is number of times

    foreach(keys(%$spellInfo)) {
      unless(substr($_,0,1) eq '_') {
        push(@badThings, $_);
        $problemCount{$_} = 0;
      }
    }

    #find all spelling problems
    my $cheapSpellCheck;
    foreach(@allParts) {
      $cheapSpellCheck = lc($_);
      $cheapSpellCheck =~ s/ +/_/gs;

      foreach(@badThings) {
        if(index($cheapSpellCheck, $_)!=-1) {
          ++$problemCount{$_};	#count the number of times spelling incorrectly (once per section)
        }
      }

    }

    #summary
    foreach(keys(%problemCount)) {
      $i = $problemCount{$_};
      next if $i==0;
      $c = $curCat;
      push(@problems, $c . $$spellInfo{$_} );
    }

  }

  undef $spellInfo;

  #silly hints
  #	every now and then, change which hints are commented out to keep things interesting
  if($showSilly)
  {
    $curCat = $showCat ? '(<em>s</em><sup>i</sup><strong>L</strong><sub>l</sub><big>y</big>) ' : '';

    #silly hint - "bad" words
    #what other good "bad" words are there?
    if( (index($writeup,'AOL')!=-1) || ($writeup =~ /\smicrosoft\s/i) || ($writeup =~ /\sbill gates\s/i) ) {
      push @problems, $curCat.'Shame on you! You used a bad word!';
    }

    if($writeup =~ /\ssoy\s/i) {
      push @problems, $curCat.'SOY! SOY! SOY! Soy makes you strong! Strength crushes enemies! SOY!';
    }

    if($writeup =~ /server error/i) {
      push @problems, $curCat.'Ah, quit your griping.';
    }

  }  #end show silly hints

  return if !scalar(@problems) || (!$isMyWU && $isCE && (scalar(@problems)==1));
  my $str = join('</p><p>',@problems);
  return unless $str;
  $str = parseLinks($str, $$NODE{parent_e2node});

  $str = '<p><big><strong>Hints!</strong></big> (choose which writeup hints display at <a href='.urlGen({'node'=>'Writeup Settings','type'=>'superdoc'}).'">Writeup Settings</a>)</p><p>'.$str.'</p>';

  return $str;
}

# Almost certainly going to be a template item
#
sub guestuserbanner
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "";
  return "" unless($APP->isGuest($USER));
  return "" if(isMobile());
  return "" unless($NODE->{type}->{title} eq "writeup" or $NODE->{type}->{title} eq "e2node");

  my $style = q|-moz-border-radius: 10px; -webkit-border-radius: 10px; border-radius: 10px; align: center; width: 80%; background-color: #fdffd4; border-style:solid; border-color: #bbbbbb; border-width: 1px; min-width:300px; min-height: 70px; margin-left: auto; margin-right: auto; margin-bottom: 10px; padding: 10px; font-family: 'arial',sans-serif; font-size: 130%;|;

  my $nodeshell = "";
  if($NODE->{type}->{title} eq "e2node" or $query->param('nodeshell') == 1)
  {
    if(not defined $NODE->{group} or scalar(@{$NODE->{group}}) == 0)
    {
      $nodeshell = "<br /><br /><em><strong>$$NODE{title}</strong></em> is a topic without any content; merely an idea or a thought that someone found interesting. If you sign up for an account, you can add something here.";
    }
  }

  return "<div id=\"guestuserbanner\" style=\"$style\"><strong>Welcome!</strong><br /><em>Everything2</em> is a community of readers and writers who write about pretty much anything and share their feedback with others. It's a great place to get help with your writing or just lose yourself in nearly a half-million pieces from over a decade in existence. People come here to contribute and read fiction, nonfiction, poetry, reviews, or their thoughts on the day. If you'd like to give feedback, offer a correction, or contribute your own work, <a href=\"/node/superdoc/Sign+up\">sign up</a>!$nodeshell</div>";

}

# This is going away when Node Heaven is going away en masse
#
sub nodeHeavenStr
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($e2node) = @_;

  return '' unless isGod($USER);
  return '' unless $$NODE{type_nodetype} eq 116;

  return '';

  my $title = getNodeById($e2node)->{title};
  my $N = $DB->sqlSelect('count(*)', 'heaven', "type_nodetype=117 and title LIKE ".$DB->{dbh}->quote($title." (%"));

  $N ||= 'no';

  return "This node has ".linkNode(getNode('Node Heaven Title Search','restricted_superdoc'),$N, {heaventitle => $$NODE{title}})." writeup".( $N != 1 ? "s" : "")." in Node Heaven.";
}

# Also going into a template
#
sub googleanalytics
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return qq!
  <script type="text/javascript">

    var _gaq = _gaq || [];
    _gaq.push(['_setAccount', 'UA-1314738-1']);
    _gaq.push(['_setDomainName', 'everything2.com']);
    _gaq.push(['_setAllowLinker', true]);
    _gaq.push(['_trackPageview']);

    (function() {
      var ga = document.createElement('script'); ga.type = 'text/javascript'; ga.async = true;
      ga.src = ('https:' == document.location.protocol ? 'https://ssl' : 'http://www') + '.google-analytics.com/ga.js';
      var s = document.getElementsByTagName('script')[0]; s.parentNode.insertBefore(ga, s);
    })();
  </script>!;
}

# This is actually a major work item for the site. All of our javascript needs to be in 1 file with it being evaluated at the bottom, not the top
#
sub javascript_decider
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  while ($$VARS{includedJS} =~ s/(^|,)(?:
    (1878034)| # Everything2 Ajax
    (1872965)| # Zen Nodelet Collapser
    1872456| # Prototype 1
    1872457| # Prototype 2
    1842173	 # async voting
    )\b($|\1)?,*/$1/x ) 
  {
    delete $$VARS{noquickvote} if $2;
    delete $$VARS{nonodeletcollapser} if $3;
  }

  my ($str, $N) = (undef, undef);
  my @JS = ( getNode('boilerplate javascript','jscript'),getNode('default javascript', 'jscript'));
  push @JS, getNode('Everything2 Ajax', 'jscript') unless $$VARS{noquickvote} ;
  push @JS, getNode('Zen Nodelet Collapser', 'jscript') unless $$VARS{nonodeletcollapser} ;
  push @JS , split(',', $$VARS{includedJS}) if $$VARS{includedJS};

  # TODO: Move to a setting
  my $jscss = "http://jscss.everything2.com";
  $str = "";

  my $jsType = getId(getType('jscript'));
  foreach (@JS) {
    getRef $_;
    next unless $_ && $$_{type_nodetype} == $jsType;
    $str .= "<script src='".htmlcode("linkjavascript",$$_{node_id})."' type='text/javascript'></script>\n";
  }

  return $str;

}

sub static_javascript
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  $$VARS{fxDuration} = '1' if (delete $$VARS{notransitions});

  my $lastnode = $$NODE{node_id};
  $lastnode = $$NODE{parent_e2node} if $$NODE{type}{title} eq 'writeup';
  $lastnode = $query->param("lastnode_id")||0 if $$NODE{title} eq 'Findings:' && $$NODE{type}{title} eq 'superdoc';

  my $e2 = undef;
  $e2->{node_id} = $$NODE{node_id};
  $e2->{lastnode_id} = $lastnode;
  $e2->{title} = $$NODE{title};
  $e2->{guest} = ($APP->isGuest($USER))?(1):(0);

  my $cookie = undef;
  foreach ('fxDuration', 'collapsedNodelets', 'settings_useTinyMCE', 'autoChat', 'inactiveWindowMarker'){
    if (!$APP->isGuest($USER)){
      $$VARS{$_} = $cookie if $cookie = $query -> cookie($_);
      delete $$VARS{$_} if $cookie eq '0';
    }
    $e2->{$_} = $$VARS{$_} if ($$VARS{$_});
  }

  $e2 -> {collapsedNodelets} =~ s/\bsignin\b// if $query -> param('op') eq 'login';
  $e2 = encode_json($e2);

  my $min = undef; $min = '.min' unless $APP->inDevEnvironment();
  my $libraries = qq'<script src="http://code.jquery.com/jquery-1.4.4$min.js" type="text/javascript"></script>';
  # mark as guest but only in non-canonical domain so testing and caching both work

  my $js_decisions = htmlcode('javascript_decider');

  unless ($APP->isGuest($USER)){
      $libraries .= '<script src="http://ajax.googleapis.com/ajax/libs/jqueryui/1.8.14/jquery-ui.min.js" type="text/javascript"></script>';
  }

  $libraries .= '<script src="'.htmlcode("linkjavascript",getNode("jquery bbq","jscript")).'" type="text/javascript"></script>';

  return qq|
    <script type='text/javascript' name='nodeinfojson' id='nodeinfojson'>
      e2 = $e2;
    </script>
    $libraries
    $js_decisions|;
}

sub zenFooter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str=' Everything2 &trade; is brought to you by Everything2 Media, LLC. All content copyright &#169; original author unless stated otherwise.';

  if ( rand() < 0.1 ) {
    my @gibberish = (
      "We are the bat people.", "Let sleeping demons lie.",
      "Monkey! Bat! Robot Hat!", "We're sneaking up on you.",
    );
    $str .= '<br /><i>' . $gibberish[int(rand(@gibberish))];
    $str .= '</i>';
  }

  return $str;
}

sub verifyRequestHash
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  #Generates a hashref used to verify the form submission. Pass a prefix.
  my ($prefix) = @_;
  my $rand = rand(999999999);
  my $nonce = md5_hex($$USER{passwd} . ' ' . $$USER{email} . $rand);

  return {$prefix . '_nonce' => $nonce, $prefix . '_seed' => $rand};
}

sub createdby
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER);
  return unless $$NODE{type}{title} eq 'e2node';

  my $crby = undef;
  $crby = $$NODE{createdby_user} || $$NODE{author_user} || 0;
  $crby=getNodeById($crby);

  my $text = "";
  $text = $$VARS{hideauthore2node} ? 'anonymous' : '' ;
  return '<div class="createdby"  title="Created on '.htmlcode('parsetimestamp', $$NODE{createtime}, 4).'">'.(
    $crby ? 'created by '.linkNode($crby,$text,{lastnode_id=>0}) : '(creator unknown)').'</div>';
}

sub displaynltext
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($nltitle, $title) = @_;

  my $CN = getNode($nltitle, 'nodelet');
  return unless $CN;
  my $str = "";

  $str.="<tr><td><h3>$title</h3></td></tr>" if $title;

  $str.=$$CN{nltext};

  return $str;
}

# Not currently used; left for clarity, but a strong candidate for removal
#
sub lockroom
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless isGod($USER);
  my $R ||= $$USER{in_room};
  return if $R == 0;

  getRef($R);

  my $open = "1\;";
  my $locked = "0\;";

  my $title = "";
  if($$R{criteria} eq $open) {
    $title = '(lock)';
  } elsif($$R{criteria} eq $locked) {
    $title = '(unlock)';
  } else {
    return;
  }

  return linkNode($NODE, $title, {op=>'lockroom', target => getId($R)});
}

# Used in the epicenter, chatterbox, and a few other places
#
sub borgcheck
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $$VARS{borged};
  my $t = time;
  my $str = "";
  my $numborged = $$VARS{numborged};
  $numborged ||= 1;
  $numborged *=2;

  if ($t - $$VARS{borged} < 300+60*$numborged) {
    $str .= linkNodeTitle('You\'ve Been Borged!');
  } else {
    $$VARS{lastborg} = $$VARS{borged};
    delete $$VARS{borged};
    $str .= '<em>'.linkNodeTitle('EDB') . ' has spit you out...</em>'; 
    $DB->sqlUpdate('room', {borgd => '0'}, 'member_user='.getId($USER));
  }

  return $str.'<br /><br />';
}

sub newnodes
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($limit) = @_;
  $limit ||= 50;

  my $qry = 'SELECT writeup_id FROM writeup';

  my $isEd = $APP->isEditor($USER);

  $qry.= ' WHERE notnew=0 ' unless $isEd;
  $qry.= " ORDER BY publishtime DESC LIMIT $limit";

  my $ed = undef;
  $ed = 'ed,' if $isEd;
  my $funk = sub{
    my $N = shift; # $N is a full node by now
    my $str.='<td>';

    if($$N{notnew}){
      $str .= '(<font color="red">H!</font>)';
      $str .= '(<a href='.urlGen({'node_id'=>$$NODE{node_id}, 'op'=>'unhidewriteup', 'hidewriteup'=>$$N{node_id}}).'>un-h!</a>)';
    } else {
      $str .= '(<a href='.urlGen({'node_id'=>$$NODE{node_id}, 'op'=>'hidewriteup', 'hidewriteup'=>$$N{node_id}}).'>h?</a>)';
    }

    $str .= '(<font color="red">...</font>)' if $DB->sqlSelect('notnew', 'newwriteup', "node_id=$$N{node_id}") != $$N{notnew};
    $str.='</td><td>';
    $str.='&nbsp;</td>';
    return $str;
  };

  my $nids = $DB->{dbh} -> selectcol_arrayref($qry);

  return htmlcode('show content', $nids ,
    qq'<tr class="&oddrow">$ed "<td>", parenttitle, type, "</td><td>", listdate, "</td><td>", author, "</td>"', 'ed' => $funk);

}

sub uploaduserimage
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field) = @_;

  return if isSuspended($NODE,"homenodepic");

  my $aws_access_key_id = $Everything::CONF->{s3}->{homenodeimages}->{access_key_id};
  my $aws_secret_access_key = $Everything::CONF->{s3}->{homenodeimages}->{secret_access_key};

  my $s3 = Net::Amazon::S3->new(
   {
      aws_access_key_id     => $aws_access_key_id,
      aws_secret_access_key => $aws_secret_access_key,
      retry                 => 1,
   }
  );

  my $bucket = $s3->bucket($Everything::CONF->{s3}->{homenodeimages}->{bucket});

  my $str ='';
  my $image = Image::Magick -> new(); 
  my $name = $field.'_file';
  my $tmpfile = '/tmp/everythingimage' . int(rand(10000)); 

  my $sizelimit = 800000;
  my $maxWidth = 200;
  $maxWidth = 400 if (($APP->getLevel($NODE)>4)||(isGod($USER)));
  my $maxHeight = 400;
  $maxHeight = 800 if (($APP->getLevel($NODE)>4)||(isGod($USER)));


  $sizelimit = 1600000 if (isGod($USER));

  my $fname = undef;
  if ($fname = $query->upload($name))
  { 
    my $basename = $$NODE{title};
    $basename =~ s/\W/_/gs;
    my $imgname = $basename;
  
    UNIVERSAL::isa($query->uploadInfo($fname),"HASH") or return "Image upload failed. If this persists, contact an administrator.";
    my $content = $query->uploadInfo($fname)->{'Content-Type'};
    unless ($content =~ /(jpeg|jpg|gif|png)$/)
    {
      return "this doesn't look like a jpg, gif or png!" 
    }
  
    $imgname .= '.'.$1;
    $tmpfile .= '.'.$1;

    my $size = undef;
    {
       my $buf = undef;
       $buf = join ('', <$fname>);
       $size = length($buf);

       if($size > $sizelimit)
       {
         return "your image is too big.  The current limit is $sizelimit bytes";
       }

       open OUTFILE, ">$tmpfile";
       print OUTFILE $buf;
       close OUTFILE;
    }

    $str.=$image->Read($tmpfile);
    my ($width, $height)=$image->Get('width', 'height'); 
    my $proportion=1;
    my $resizing=0;
    if ($width> $maxWidth)
    {
      $proportion=$maxWidth/$width;
      $resizing=1;
    }

    if ($height> $maxHeight)
    {
      if (($maxHeight/$height)<$proportion)
      {
        $proportion=$maxHeight/$height; 
      }
    
      $resizing=1;
    }
  
    if ($resizing==1)
    {
      $width=$width*$proportion;
      $height=$height*$proportion;

      $image->Resize(width=>$width,  height=>$height, filter=>"Lanczos");
      $image->Write($tmpfile); 
    }
    undef $image;

    unless( $bucket->add_key_filename($basename,$tmpfile, { content_type => $content} ) )
    {
      return "Image upload failed on REST call. Try again in a few";
    }

    $$NODE{$field} = "/$basename";
    $DB->updateNode ($NODE, $USER);
  
    $DB->getDatabaseHandle()->do('replace newuserimage set newuserimage_id='.getId($NODE));

    unlink($tmpfile);


    $str.="$size bytes received!  Make sure to SHIFT-reload on your user page, if you see the old image.";
  } else {
    $str.="<small>the rules are simple: only upload jpgs, gifs, and pngs. ". ($sizelimit/1000)."k max.  
      Big images will be resized to $maxWidth pixels across, or $maxHeight tall.  We <strong>will</strong> take away this privilege if what you post is copyrighted or
      obscene - ".linkNodeTitle('be cool').'</small>';
    $str.=$query->filefield($name);
  }

  return $str;
}

# Used only in [Everything I Ching]
#
sub generatehex
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($hex)= @_;

  my $str = "<table width=100% bgcolor=white border=0 cellpadding=3 cellspacing=0>";

  my $rows = "";
  while (my $letter = chop $hex) {
    my $row = "<tr><td align=center><img width=128 height=14 src=";
    if (uc($letter) eq 'B') {
      $row .="http://static.everything2.com/broke.gif";
    } else {
      $row .="http://static.everything2.com/full.gif";
    }
    $row.="></td></tr>";
    $rows = $row.$rows;
  }

  $str.=$rows;
  return $str."</table>";
}

# Super likely going to be moved to a template if we even need to keep it.
# It is only used by the printable htmlcode pages, which are likely to be moved to CSS.
#
sub printableheader
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($WRITEUP) = @_;
  getRef $WRITEUP;
  $WRITEUP ||= $NODE;

  my $TYPE = $$WRITEUP{wrtype_writeuptype};
  my $E2NODE = getNode $$WRITEUP{parent_e2node}; 
  getRef $TYPE;

  if(getId($NODE)==getId($WRITEUP)) {
    #new way - let displayWriteupInfo handle individual WU header and footer
    return htmlcode('displayWriteupInfo', getId($WRITEUP));
  }

  my $str="<b>";
  $str.= "$$E2NODE{title} " unless getId($NODE) != getId($WRITEUP);
  $str.="(".linkNode($WRITEUP, $$TYPE{title}).") by&nbsp;".linkNode($$WRITEUP{author_user})."</b>\n";

  $str="<table cellpadding=0 cellspacing=0 border=0 width=100%><tr>
    <td>$str</td>
    <td align=right>";
 
  if($$WRITEUP{cooled})
  {
    $str .= htmlcode('writeupcools',$WRITEUP->{node_id});
  }
  
  $str .= "</td><td align=right>"."<font size=2>".htmlcode('parsetimestamp', "$$WRITEUP{publishtime}")."</font></td></tr></table>";

  return $str;
}

# Similar to printableheader only used by the printable htmlpages. Shares its fate.
#
sub printablefooter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = '<table width="100%" border="0"><tr><td align="left"><b>';

  my $E2NODE = undef;

  $E2NODE=getNode $$NODE{parent_e2node} if $$NODE{type}{title} eq 'writeup';
  $E2NODE ||= $NODE;
  my $site = $Everything::CONF->{system}->{site_url};
  $site =~ s/\/$//;
  $site.= "/title/$$E2NODE{title}";
  $site =~ s/ /\+/g;

  $str.= $site. "</b></td><td align='right'><b>http://everything2.com/node/$$NODE{node_id}</b></td></tr></table>";

  return $str;
}

# Changeroom is the room changing widget
# TODO: Develop a notion of public accounts
#
sub changeroom
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->isGuest($USER);
  return if $$USER{title} eq 'everyone';
  return ("You are locked in your current room for " . ceil(($$VARS{lockedin} - time)/ 60) . " minutes.<br><br>") if ($$VARS{lockedin} > time);

  my $str = "";
  $str = ' instant ajax chatterbox_chatter:#' if $query and $query -> param('ajaxTrigger') and defined $query->param('changeroom')	and $query->param('changeroom') != $$USER{in_room};
  my $RM = getNode('e2 rooms', 'nodegroup');
  my @rooms = @{ $$RM{group}  };
  my @aprrooms;
  my %aprlabel;
  my ($nodelet) = @_ ;
  $nodelet =~ s/ /+/g;

  foreach(@rooms) {
    my $R = getNodeById($_);
    next unless eval($$R{criteria});
    if(defined $query->param('changeroom') and $query->param('changeroom') == $_ and $$USER{in_room} != $_)
    {
      changeRoom($USER, $R);
    }
  
    push @aprrooms, $_;
    $aprlabel{$_} = $$R{title};
  }

  return unless @aprrooms;

  push @aprrooms, '0';
  $aprlabel{0}='outside';

  if(defined $query->param('changeroom') and $query->param('changeroom') == 0)
  {
    #steppin' outside
    #$$USER{in_room} = 0;
    #updateNode($USER, -1);
	changeRoom($USER, 0);
    #we should also edit the rooms table
  }

  my $isCloaker = $APP->userCanCloak($USER);
  if($query->param('sexiscool') and $isCloaker)
  {
    if($query->param('cloaked'))
    {
      cloak($USER, $VARS);
    } else {
      uncloak($USER, $VARS);
    }
  }

  my $id = $nodelet ;
  $id =~ s/\W//g ;
  $nodelet = ":$nodelet" if $nodelet ;
  my $ajax = 'ajax '.( $nodelet ? lc($id).':updateNodelet' : 'room_options:changeroom' ).'?ajaxTrigger=1&' ;
  $str ="<div class='nodelet_section$str' id='room_options'>";
  $str.="<h4 class='ns_title'>Room Options</h4>";
  $str.=htmlcode('openform');
  $str.=$query->checkbox(-name=>'cloaked', checked=>$$VARS{visible}, value=>1, label=>'cloaked', class=>$ajax."sexiscool=1&cloaked=/$nodelet") if $isCloaker;

  #$str.=htmlcode('lockroom').' '.htmlcode('createroom');
  $str.=' '.htmlcode('createroom');

  $str.='<br>';
  $str.=$query->popup_menu(-name=>'changeroom', Values=>\@aprrooms, default=>$$USER{in_room}, labels=>\%aprlabel,class=>$ajax."changeroom=/$nodelet");
  $str.=$query->submit('sexiscool','go');
  $str.='</form></div>';

  return $str;
}

# Createroom, likely moving to a controller
#
sub createroom
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->getLevel($USER) >= $Everything::CONF->{create_room_level};
  my $cr = getId(getNode('create room','superdoc'));
  return '<span title="create a new room to chat in">'. linkNode($cr,'create',{lastnode_id=>0}). '</span>';
}

#  allows users to select nodelets and their order
#  usage: [{rearrangenodelets:nodelets,default nodelets}]
#  first parameter:  user variable which stores the comma delimited list of selected node_id's ie $$VARS{nodelets}
#  second parameter: nodeletgroup which contains nodelets a user can choose from
#  optional third parameter: send form controls only, not an entire form
# TODO: Move me to templates
#
sub rearrangenodelets
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if( $APP->isGuest($USER) );
  my($varsfield,$nodeletgroup,$formoff)=@_;
  return 'Missing parameter.' unless $varsfield && $nodeletgroup;

  my $i = undef;
  my @selected = ();
  my $prefix = 'nodeletedit';

  if ($query -> param($prefix)){
    my $id = undef;
    foreach (grep /^$prefix\d+/, $query->param()){
      push(@selected, $id) if ($id=$query -> param($_)) && !grep(/^$id$/, @selected);
    }
    $$VARS{nodelets} = join ',', @selected;
  } else {
    @selected = split ',', $$VARS{nodelets};
  }

  my %names = ('0'=>'(none)');
  my @ids = (@{ getNode($nodeletgroup,'nodeletgroup')->{group} });
  foreach(@ids,@selected){ # include @selected in case user has a non-standard nodelet selected
    $names{$_} ||= getNodeById($_)->{title};
  }
  @ids = sort { lc($names{$a}) cmp lc($names{$b}) } keys %names; # keys to include non-standard

  my @menus = ();
  for ($i=1;$selected[$i-1];$i++){
    push @menus, $query -> popup_menu(-name => $prefix.$i, values => \@ids,
    labels => \%names, default => $selected[$i-1], force=>1);
  }

  while($ids[$i]){
    push @menus, $query -> popup_menu(-name => $prefix.$i, values => \@ids,
    labels => \%names, default => '0', force=>1);
    $i++;
  }

  my $str = $query->hidden(-name => $prefix, value=>1).qq'<ul id="rearrangenodelets"><li>\n'.
    join("</li>\n<li>", @menus)."</li></ul>\n";

  return $str if $formoff;
  return htmlcode('openform').$str.htmlcode('closeform');

}

# This needs to move to a template
#
sub minilogin
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $op = $query->param("op");
  $query->delete('passwd');

  my $goto = getId($NODE);
  $goto = $Everything::CONF->{system}->{default_node} if $goto == $Everything::CONF->{system}->{default_guest_node};
  return $query->start_form(-method => "POST", -action => $query->script_name, -name => "loginform", -id => "loginform") .
    $query->hidden("node_id", $goto) . "\n" .
    $query->hidden("lastnode_id") . "\n" .
    $query->hidden(-name => "op", value => "login", force => 1) . "\n" .
    '
      <table border="0">
      <tr>
      <td><strong>Login</strong></td>
      <td>'. $query->textfield (-name => "user", -size => 10, -maxlength => 20, -tabindex => 1).'</td>
      </tr>
      <tr>
      <td><strong>Password</strong></td>
      <td>'.$query->password_field(-name => "passwd", -size => 10, -maxlength => 240, -tabindex => 2) .' </td>
      </tr>
      </table>
      <font size="2">'.
    $query->checkbox(
      -name => "expires"
      , -checked => ""
      , -value => "+10y"
      , -label => "remember me"
      , -tabindex => 3
    ).
    ($op eq "login" ? '<p><i>Login incorrect.</i><br>If you are unable to login, try resetting your password. If you don\'t have access to the email attached to your account or are otherwise stuck, email <a href="mailto:accounthelp@everything2.com">accounthelp@everything2.com</a></p></td></tr>' : "")
."</font>" .
    $query->submit(
      -name => "login"
      , -value => "Login"
      , -tabindex => 4
    )."<br />".
    linkNodeTitle("Reset password[superdoc]|Lost password")."
    <p><strong>".linkNode($Everything::CONF->{system}->{create_new_user},'Sign up')."</strong></p>\n" .
    $query->end_form;
}



#displays firmlinks for this e2node or writeup
#	for admins, also shows widgets to allow deleting of checked items
# TODO - Template code
#
sub firmlinks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $currentnode = undef;
  my $inE2Node = undef;
  my $parentstr = '' ;
  if($$NODE{type}{title} eq 'e2node') {
    $currentnode = $NODE;
    $inE2Node=1;
  } elsif($$NODE{type}{title} eq 'writeup') {
    $currentnode = getNodeById($$NODE{parent_e2node});
    $parentstr .= '<div class="topic" id="parentlink">' ;

    my $nwriteups = undef;
    unless($currentnode and $$currentnode{group} and $nwriteups = @{$currentnode->{group}})
    {
      $parentstr .= 'This node is unparented. ';
      $parentstr .= $APP->isEditor($USER)? linkNode(getNode('Magical Writeup Reparenter', 'superdoc'), 'Reparent it.', {old_writeup_id => $$NODE{node_id}})
        : 'Please contact an editor to have this repaired.';
      return "$parentstr</div>";
    }

    my $nodeTitle=$$currentnode{title};
    $parentstr .= linkNode($currentnode,"See all of $nodeTitle").
      ( $nwriteups == 1 ? ', no other writeups in this node' :
        (  $nwriteups == 2 ? ', there is 1 more in this node' :
	', there are '.($nwriteups-1).' more in this node' ) ) . '.</div>' ;
    $inE2Node=0;
  }

  return unless($currentnode);

  my $firmlink = getNode('firmlink', 'linktype');
  return unless($firmlink);

  my $firmlinkId = $$firmlink{node_id};
  my $RECURSE = 1;
  my $cantrim = $DB -> canUpdateNode($USER, $currentnode) || $APP->isEditor($USER);

  my $sqlQuery = qq|;
    SELECT links.to_node, note.firmlink_note_text
    FROM links
    LEFT JOIN firmlink_note AS note
      ON note.from_node = links.from_node
      AND note.to_node = links.to_node
    WHERE links.linktype = $firmlinkId
      AND links.from_node = $$currentnode{node_id}|;

  my $csr = $DB->getDatabaseHandle()->prepare($sqlQuery);
  my @links = ();

  if($csr->execute()) {
    while(my $row = $csr->fetchrow_hashref()) {
      my $linkedNode = getNodeById($row->{to_node});
      my $text = $row->{firmlink_note_text};
      push @links, { 'node' => $linkedNode, 'text' => $text };
    }
    $csr->finish();
  }

  my $str = '';
  foreach(sort {lc($$a{node}->{title}) cmp lc($$b{node}->{title})} @links)
  {
    my ($linkedNode, $linkText) = ($$_{node}, $$_{text});
    $str .=' , ' if $str;
    $str .= $query->checkbox('cutlinkto_'.$$linkedNode{node_id}, 0, '1', '') if $cantrim;
    $str .= linkNode($linkedNode);
    $str .= encodeHTML(" $linkText") if $linkText ne '';
  }

  my $firmhead = '';

  if ($str ne '') {
    if($cantrim) {
      $firmhead = htmlcode('openform', 'firmlinktrim_form')
        .htmlcode('verifyRequestForm', 'linktrim')
        .'<input type="hidden" name="op" value="linktrim">'
        .'<input type="hidden" name="linktype" value="'.$firmlinkId.'">'
        .'<input type="hidden" name="cutlinkfrom" value="'.$$currentnode{node_id}.'">';
    }

    $firmhead .= '<strong>See';
    if( !$inE2Node || (exists $$NODE{group}) && (defined $$NODE{group}) && ( scalar(@{$$NODE{group}})>0 ) ) {
      $firmhead .= ' also';
    }
    $firmhead .= ': </strong>';

    if($cantrim) {
      $str.= ' &nbsp; '.$query->submit('go','un-link').'</form>';
    }

    $str = "\t<div class='topic' id='firmlink'>".$firmhead.$str."</div>";
  }

  return "$parentstr\n$str" ;
}

# Used by nodeletsection
#
sub ednsection_edev
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $csr = $DB->sqlSelectMany("to_node", "weblog", "weblog_id=".getNode('edev','usergroup')->{node_id}." and removedby_user=0", "order by tstamp DESC limit 5" );

  my $str = "";
  while (my $W = $csr->fetchrow_hashref) {
    $str.= linkNode($$W{to_node}, undef, {lastnode_id => undef})."<br>";
  }

  return $str;
}

# Only used in the patch system. Deletable once that is wound down.
#
sub settype
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($patch_id) = @_;
  $patch_id ||= $NODE -> {node_id};

  my $PATCH = getNodeById($patch_id);

  my $patch_status = getNodeById($PATCH -> {cur_status});

  #Process changes, if any
  if( $APP->isAdmin($USER) )
  {
    my $new_status = $query -> param('patch_status');
    if( $new_status and $new_status != $patch_status -> {status_id})
    {
      $NODE -> {cur_status} = $new_status;
      updateNode($NODE,-1);
    }
  }

  my $applied = $patch_status -> {applied};

  #Only get the statuses that match this status, so that you can't go
  #from applied to unapplied statuses without hitting the little applied
  #button.
  my @statuses = getNodeWhere({-applied => $applied},"status","node_id");

  my %dropdown_labels = ();

  foreach my $status(@statuses)
  {
    my $status_title = $status -> {title};
    $status_title .= " *" if $$status{status_id} == $$patch_status{status_id}; 
    $dropdown_labels{$status -> {status_id}} = $status_title;
  }

  my @status_ids = keys %dropdown_labels;

  my $str = $query -> popup_menu("patch_status", \@status_ids, $patch_status -> {status_id}, \%dropdown_labels);

  return $str;
}

sub getGravatarMD5
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $gravatarUser = shift;
  getRef $gravatarUser;

  my $defaultEmail = "$$gravatarUser{title}\@chat.everything2.com";
  my $email = $DB->sqlSelect("setting_value", "uservars", "user_id = $$gravatarUser{user_id}". " AND setting_name = 'gravatar_email'");

  $email = $defaultEmail unless defined $email;
  $email = lc $email;
  $email =~ s/^\s+|\s+$//g;

  return md5_hex($email);

}

sub writeupssincelastyear
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($userID) = @_;

  # Ignore maintenance writeups such as [Broken Nodes] and [Edit these E2 Titles]
  my $notIn = " AND node.node_id NOT IN (";
  my $firstIn = 1;

  foreach (values %{$Everything::CONF->{system}->{maintenance_nodes}} )
  {
    # Look for numbers, and presume all numbers are node IDs
    next unless /^\d+$/;

    if ($firstIn)
    {
      $firstIn = 0;
      $notIn .= $_;
    } else {
      $notIn .= ', ' . $_;
    }
  }

  $notIn .= ") ";

  # No node restriction string if no maintenance nodes were found
  $notIn = "" if $firstIn;

  my $sqlStr = "SELECT COUNT(*)
    FROM node JOIN writeup ON writeup.writeup_id=node.node_id
    WHERE publishtime > (NOW() - INTERVAL 1 YEAR)
    AND author_user=$userID $notIn";

  my $dbh = $DB->getDatabaseHandle();
  my $qh = $dbh -> prepare($sqlStr);
  $qh -> execute();
  my ($numwriteups) = $qh -> fetchrow();
  $qh -> finish();

  return $numwriteups;
}

# This is almost certainly identical to the flattenUsergroup functionality that already exists inside of the NodeBase
# but I am keeping it for compatibility. Ultimately it can be wound into something less oddly specific
#
sub usergroupToUserIds
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  #Given a ug_id or a ug hash, convert it to a comma-separated string of user IDs
  my ($ug) = @_;

  #Given a ug_id or a ug hashref, convert it recursively to an array of user IDs
  my @uids = htmlcode("explode_ug",$ug);

  my $out = "@uids";

  $out =~ s/ /,/g;
  return $out;
}

# Used this to kill off a local subref in usergroupToUserIds
#
sub explode_ug
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($ug) = @_;
  $ug = getNodeById($ug) if $ug =~ /^\d+$/;

  my @ids = @{$$ug{'group'}};

  my @result = ();
  foreach my $id(@ids){
    if(getNodeById($id) -> {'type'} -> {'title'} eq 'user'){
      push @result, $id;
    } else{
      push @result, htmlcode("explode_ug",$id);
    }
  }

  return @result;
}

sub unignoreUser
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($uname) = @_;

  my $U = getNode($uname, 'user');
  $U ||= getNode($uname, 'usergroup');
  if ($U) {
    return if $$U{title} eq 'EDB';
    unless ($DB->sqlSelect('*','messageignore',"messageignore_id=$$USER{node_id} AND ignore_node=$$U{node_id}")) {
      return 'not yet ignoring '.$$U{title};
    } else {
      $DB->sqlDelete('messageignore',"messageignore_id=$$USER{node_id} AND ignore_node=$$U{node_id}");
    }
  } else {
    $uname = encodeHTML($uname);
    return "<strong>$uname</strong> doesn't seem to exist on the system!" unless $U;
  }

  $query->param('DEBUGignoreUser', 'tried to unignore '.$$U{title});
  return "$$U{title} unignored";

}

sub assign_patch
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  #This should only be called from patch display page --[Swap]
  my ($patch_id) = @_;

  $patch_id ||= $NODE -> {node_id};

  my $PATCH = getNodeById($patch_id);

  my $assigned_to = $PATCH -> {assigned_to};

  #Process changes, if any
  if(isGod($USER) ){
    my $new_assign = $query -> param('assigned_to');
    if( $new_assign and $new_assign != $assigned_to ){
      $PATCH -> {assigned_to} = $new_assign;
      updateNode($PATCH,-1);
    }
  }

  my @splat_ids = @{ getNode('%%','usergroup')->{group} };

  my %dropdown_labels = ();

  foreach my $splat_id(@splat_ids){
    my $splat_title = getNodeById($splat_id) -> {title};
    $splat_title .= " *" if $splat_id == $assigned_to;
    $dropdown_labels{$splat_id} = $splat_title;
  }

  $dropdown_labels{0} = "Nobody";
  $dropdown_labels{0} .= " *" unless $assigned_to;
  push @splat_ids,0;

  my $str = undef;

  $str .= $query -> popup_menu("assigned_to", \@splat_ids,
    $assigned_to,
    \%dropdown_labels);

  return $str;
}

sub zensearchform
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $lastnodeId = $query->param("softlinkedFrom");
  $lastnodeId ||= $query -> param('lastnode_id') unless $APP->isGuest($USER);

  my $lastnode = getNodeById($lastnodeId) if defined $lastnodeId;
  my $default = undef; $default = $$lastnode{title} if $lastnode;

  my $str = $query->start_form(
    -method => "GET"
    , -action => $query->script_name
    , -id => 'search_form'
    ).
    $query->textfield(-name => 'node',
      value => $default,
      force => 1,
      -id => 'node_search',
      -size => 28,
      -maxlength => 230);

  my $lnid = undef;
  $lnid = $$NODE{parent_e2node} if $$NODE{type}{title} eq 'writeup' and $$NODE{parent_e2node} and getNodeById($$NODE{parent_e2node});
  $lnid ||= getId($NODE);

  $str.='<input type="hidden" name="lastnode_id" value="'.$lnid.'">';
  $str.='<input type="submit" name="searchy" value="search" id="search_submit" title="Search within Everything2">';

  $str.=qq'\n<span title="Include near matches in the search results">'.$query->checkbox(
    -id => "near_match",
    -name => 'soundex',
    -value => '1',
    checked => 0,
    force => 1,
    -label => 'Near Matches'
  ) . "</span>";

  $str.=qq'\n<span title="Show all results, even when there is a page matching the search exactly">'.$query->checkbox(
    -id => "match_all",
    -name => 'match_all',
    -value => '1',
    checked => 0,
    force => 1,
    -label => 'Ignore Exact',
  ) . "</span>";

  return $str . "\n</form>";
}

sub ednsection_cgiparam
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = '';
  $str = '[<i>Ajax call parameters, not original page parameters</i>]<br>' if $query->param('displaytype')eq 'ajaxupdate';
  my $c=0;
  foreach my $var ($query->param) {
    next if $var eq 'passwd';
    my $q=$query->param($var);

    #Sanitise the variable for display
    $var =~ s/\</\&lt\;/g;
    $var =~ s/\>/\&gt\;/g;

    next if $q eq '';
    next if ($var eq 'op') && !$q;
    ++$c;

    my $maxLen = 70;
    my $isDebug = ($var =~ /^debug/i);
    $maxLen *= 2 if $isDebug;

    $str .= '<tt>' if $isDebug;
    $str .= '<strong>'.$var.'</strong>';
    if((my $l=length($q))>$maxLen) {
      $str .= ':'.encodeHTML(substr($q,0,$maxLen),1).'... ('.$l.')';
    } elsif($q) {
      $str .= ':'.encodeHTML($q,1);
    }

    $str .= '</tt>' if $isDebug;
    $str .= "<br>\n";
  }

  $str = "<small>$c<br></small>\n".$str if $c;
  return $str;
}

# TODO: Make me into template code
# TODO: Why is Everything::node in here?
#
sub endsection_globals
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @globals = qw($USER $THEME $VARS $DB $query);
  my $ajax='ajax ednsection_globals:nodeletsection:edn,globals';

  my $str = '<table cellpadding="0" cellspacing="1" border="0">';
  foreach (@globals) {
    $str.='<tr>';
    no strict 'refs';
    my $reftype = eval "ref $_";
    $str.="<td><small>$_</small></td>";
    $str.='<td><small>';
    my %options = (
      "Everything::node" => sub {
        my $nid = eval "$_"."->{node_id}";
        $str.= "NODE: ".linkNode($nid)." ($nid)";
      },
     "Everything::NodeBase" => sub {
        $str.= "NODEBASE (".$DB->{dbname}.")";
      },
      "HASHREF" => sub {
         $str.= linkNode($NODE, "HASHREF", { "show$_" => 1, -class=>$ajax });
         $str.= " (".int(eval("keys \%{$_}")).")";
      },
      "HASH" => sub {
         $str.= linkNode($NODE, "HASH", { "show$_" => 1, -class=>$ajax });
         $str.= " (".int(eval("keys $_")).")";
      }
    );

    my %expand = (
      "HASHREF" => sub {
        no strict;
        my $hr = eval "$_";
        my $count = 0;
        foreach my $key (keys %$hr) {
          $str.="\n<tr><td>$key</td>";
          $str.='<td><code>'.encodeHTML($$hr{$key}).'</code></td>' if exists $$hr{$key};
          $str.="</tr>\n";
        }
      }, 
      "HASH" => sub {
        no strict;
        my $hr = eval "\\$_";
        my $count = 0;
        foreach my $key (keys %$hr) {
          $str.="\n<tr><td><small>$key</small></td>";
          $str.='<td><small><code>'.encodeHTML($$hr{$key}).'</code></small></td>' if exists $$hr{$key};
          $str.="</tr>\n";
        }
      }
    );

    /^(.)/;
    my $firstchar = $1;
    $reftype = "HASHREF" if $reftype eq 'HASH' and $firstchar eq '$'; 
    $reftype = "HASH" if not $reftype and $firstchar eq '%'; 
    $reftype = "Everything::node" if $reftype eq 'HASHREF' and eval ("exists \$$_".'{node_id}');

    if ($_ eq '$PAGELOAD' or (defined $query->param("show$_") and exists $expand{$reftype})) {
      my $ref = $expand{$reftype};
      $str.='<table>';
      &$ref($_);
      $str.='</table>';
    } elsif (exists $options{$reftype}) {
      my $ref = $options{$reftype};
      &$ref($_);
    } else {
      $str.= $reftype;
    }

    $str.='</small></td>';
    $str.="</tr>\n";

  }
  
  use strict 'refs';
  return $str.'</table>';
}

# Used on the edev nodelet only
#
sub ednsection_patches
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $patches = $DB->sqlSelectMany("patch_id, (select author_user from node where node_id=patch.patch_id limit 1) as author_user, (select title from node where node_id=patch.patch_id limit 1) as title", "patch", "cur_status=1983892 order by patch_id desc limit 7");
  return 'No patches. Word.' unless $patches->rows;


  my $str = '<table id="ednsection_patches">';
  while (my $patch = $patches->fetchrow_hashref){
    $str.= "<tr><td class='oddrow' align='center'><b>".
      linkNode($$patch{author_user}).
      "</b></td></tr><tr><td>".
      linkNode($$patch{patch_id},$$patch{title},{lastnode_id=>0}).
      "</td></tr>";
  }

  $str.= '</table><p align="center">'.linkNodeTitle("Patch Manager") ;
  return $str;
}

# Used on our mobile page only
#
sub zenMobileTabs
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless isMobile();
  my $canEdit = canUpdateNode($USER, $NODE) && $USER->{user_id} == $NODE->{author_user};
  my $dt = $query->param('displaytype') || 'display';
  my @tabs = ();

  if ($dt eq 'display') {
    push @tabs, [1, 'display'];
  } else {
    push @tabs, [0, linkNode($NODE, 'display')];
  }

  if ($canEdit) {
    if ($dt eq 'edit') {
      push @tabs, [1, 'edit'];
    } else {
      push @tabs, [0, linkNode($NODE, 'edit', { displaytype => 'edit'})];
    }
  }

  if ( !$APP->isGuest($USER) ) {
    my $cb = getNode('chatterbox', 'nodelet');
    if ($cb && $dt eq 'shownodelet' && $query->param('nodelet_id') == $cb->{node_id}) {
      push @tabs, [1, 'chat'];
    } else {
      push @tabs, [0, linkNode($NODE, 'chat', { displaytype => 'shownodelet', nodelet_id => $cb->{node_id}})];
    }
  }

  if ( !$APP->isGuest($USER) ) {
    my $ou = getNode('other users', 'nodelet');
    if ($ou && $dt eq 'shownodelet' && $query->param('nodelet_id') == $ou->{node_id}) {
      push @tabs, [1, 'other users'];
    } else {
      push @tabs, [0, linkNode($NODE, 'other users', { displaytype => 'shownodelet', nodelet_id => $ou->{node_id} })];
    }
  }

  if ($dt eq 'listnodelets') {
    push @tabs, [1, 'more...'];
  } else {
    push @tabs, [0, linkNode($NODE, 'more...', { displaytype => 'listnodelets' })];
  }

  return ('<div id="zen_mobiletabs">'
    .(join ' | ', map {
      my ($selected, $str) = @$_;
      '<span class="'.($selected?'zen_mobiletab_selected' : 'zen_mobiletab').'">'.$str.'</span>'
      } @tabs)
    . '</div>');
}

# Used only on the user display page
# pass a user object (or nothing to default to the current node, or current user if the current node is not a user), and the groups the user belongs to will be returned
#
sub showUserGroups
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $U = $_[0];
  if($U) {
    $U = getId($U);
  } else {
    if($$NODE{type_nodetype}==getId(getNode('user', 'nodetype'))) {
      $U = getId($NODE);
    } else {
      $U = getId($USER);
    }
  }

  my $userID = getId($USER);
  return if(!$U);

  my @groups = ();

  if (($$VARS{hidehomenodeUG} && !$APP->isAdmin($USER) ) || $APP->isGuest($USER) ) {
    return unless $APP->isEditor($U);
    push( @groups, linkNode(getNode('gods', 'usergroup'),0,{lastnode_id=>0})) if $APP->isAdmin($U);
    push( @groups, linkNode(getNode('Content Editors', 'usergroup'),0,{lastnode_id=>0})) if $APP->isEditor($U,"nogods");
    push( @groups, linkNode(getNode('edev', 'usergroup'),0,{lastnode_id=>0})) if $APP->isDeveloper($U,"nogods");
  } else {

    my @insiders = ();
    my $csr = $DB->sqlSelectMany("node_id", "node", "type_nodetype=".getId(getType("usergroup")));
    my $row = undef;
    push @insiders, $$row{node_id} while($row = $csr->fetchrow_hashref());
    no warnings;

    my $str = "";
    my @skips = ();

    # Can skip (i.e. hide) usergroups from display.
    # If you are a god, you can see all usergroups, even skipped ones. This is so 
    # fled users can easily be removed from usergroups.
    # TODO: Make me a setting or UG param
    if (!$APP->isAdmin($USER) ) {
      @skips= ('HD2','Eurohostages','PDXCB','nodahs','weeklings','Horace Phair','SIGTITLE','e2gods');
    }


    foreach(@insiders) {
      my $n = getNodeById($_);
      next unless !(htmlcode("in_an_array",$$n{title},@skips));
      my $usergroup = getNodeById($$n{node_id});
      my $in_usergroup=htmlcode("in_an_array",$U,@{$$usergroup{group}});
      push( @groups, linkNode(getNode($$n{title}, 'usergroup'),0,{lastnode_id=>0})) if $in_usergroup;
    }
  }


  return if !scalar(@groups);
  return join(', ', @groups);

}

# Only used in the list usergroups code above, probably replaceable with grep
#
sub in_an_array
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $needle = shift;
  my @haystack = @_;

  for (@haystack) {
    return 1 if $_ eq $needle;
  }
  return 0;
}

sub showuserimage
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $DB->isApproved($NODE, getNode('users with image', 'nodegroup')) or $APP->getLevel($NODE) >= 1;
  return if isSuspended($NODE,"homenodepic");
  return unless $$NODE{imgsrc};
  my $imgsrc = $$NODE{imgsrc};
  $imgsrc = "$$NODE{title}";
  $imgsrc =~ s/\W/_/g;
  $imgsrc = "/$imgsrc" if ($imgsrc !~ /^\//);
  return '<img src="http://'.$Everything::CONF->{homenode_image_host}.$imgsrc.'" id="userimage">'; 
}
1;
