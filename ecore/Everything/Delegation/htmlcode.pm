package Everything::Delegation::htmlcode;

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

use strict;
use warnings;

## Until all of the evals are dead, this is a strict necessity
## no critic (ProhibitStringyEval)

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
  *canReadNode = *Everything::HTML::canReadNode;
  *canDeleteNode = *Everything::HTML::canDeleteNode;
  *evalCode = *Everything::HTML::evalCode;
  *getPageForType = *Everything::HTML::getPageForType;
  *opLogin = *Everything::HTML::opLogin;
}

# Used by parsetime, parsetimestamp, timesince, giftshop_buyching 
use Time::Local;

# Used by shownewexp, publishwriteup, static_javascript, hasAchieved,
#  showNewGP, notificationsJSON, Notifications_nodelet_settings,sendPrivateMessage
use JSON;

# Used by publishwriteup,isSpecialDate
use DateTime;

# Used by publishwriteup
use DateTime::Format::Strptime;

# Used by verifyRequestHash, getGravatarMD5, verifyRequest, verifyRequestForm
use Digest::MD5 qw(md5_hex);

# Used by uploaduserimage, giftshop_buyching
use POSIX qw(strftime ceil floor);
use File::Copy;
use Image::Magick;

# Used by socialBookmarks
use CGI qw(-utf8);

# Used by create_short_url;
use POSIX;

# Used by display_draft
use Everything::Delegation::htmlpage;

# Used by uploaduserimage
use Everything::S3;

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
    return $APP->asset_uri("$n->{node_id}.css");
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

  my $servername = $Everything::CONF->server_hostname;
  my $str = "<span class='var_label'>node_id:</span> <span class='var_value'>$nid</span>
			<span class='var_label'>nodetype:</span> <span class='var_value'>".linkNode($$NODE{type})."</span>
			<span class='var_label'>Server:</span> <span class='var_value'>$servername</span>";

  $str .= $query->start_form('POST',$query->script_name);

  $str .= '<label for ="node">Name:</label> '.q|<input type="text" name="node" id="node" value="|.$APP->encodeHTML($NODE->{title}).q|" size="18" maxlength="80" />|.$query->submit('name_button', 'go').$query->end_form;

  $str .= $query->start_form('POST',$query->script_name).'<label for="node_id">ID:</label> '.
  $query->textfield(
    -name => 'node_id',
    -id => 'node_id',
    -default => $nid,
    -size => 12,
    -maxlength => 80).
  $query->submit('id_button', 'go');

  $str.= $query->end_form;

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
    return q|<!-- noad:settings -->|;
  }
  return $ad_text;
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
  my $str = '';
  my $TYPE = undef;

  return '' unless ((isNodetype($NODE)) && (defined $field) && ($NODE->{extends_nodetype} > 0));

  if($field eq 'sqltable')
  {
    $TYPE = $DB->getType($NODE->{extends_nodetype});
    $str .= "$$TYPE{sqltablelist}" if(defined $TYPE);
  }
  elsif(($field eq 'grouptable') && ($NODE->{$field} eq ''))
  {
    $TYPE = $DB->getType($NODE->{node_id});
    my $gt = '';
    $gt = "$$TYPE{$field}" if(defined $TYPE);
    $str .= $gt if ($gt ne '');
  }
  elsif($NODE->{$field} eq '-1')
  {
    $TYPE = $DB->getType($NODE->{extends_nodetype});
    my $node = undef; $node = $DB->getNodeById($TYPE->{$field});
    my $title = undef; $title = $node->{title} if (defined $node);
    $title ||= 'none';
    $str .= $title;
  }

  $str = " ( Inherited value: $str )" if ($str ne '');
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
  my $str = '';

  $SETTING = $SETTING->[0];  # there should only be one in the array
  $vars = getVars($SETTING);
  $str .= $vars->{$key};
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
  my $str = '';

  $edit = 0 if(not defined $edit);

  $str .= q|<table border=1 width=400>|;

  $str .= q| <tr>|;
  foreach my $fieldname (keys %{$fields[0]})
  {
    $str .= qq|<td bgcolor="#cccccc">$fieldname</td>|;
  }

  $str .= q|<td bgcolor="#cccccc">Remove Field?</td>| if($edit);
  $str .= q| </tr>|;

  foreach my $field (@fields)
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

  $str .= htmlcode( 'displaydebatecomment', $NODE, $displaymode );
  return $str;
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

  return $query->submit("sexisgood", $_[0]||"submit").$query->end_form;
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
    unless (grep {/^$key$/} @noShow) {
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

  my $delegated = $type eq "container" || $type eq "htmlcode" || $type eq "opcode" || $type eq "maintenance" || $type eq "htmlpage";

  if($delegated)
  {
    $code = "Error: could not find code in delegated $type";
    my $file="/var/everything/ecore/Everything/Delegation/$type.pm";

    my $filedata = undef;
    my $fileh = undef;

    open $fileh,"<",$file;
    {
      local $/ = undef;
      $filedata = <$fileh>;
    }

    close $fileh;

    my $name="";
    if($NODE->{type}->{title} eq "maintenance")
    {
      my $mainttype = getNodeById($NODE->{maintain_nodetype})->{title};
      my $maintop = $NODE->{maintaintype};
      $name = $mainttype."_".$maintop;
    }else{
      $name="$$NODE{title}";
    }
    $name =~ s/[\s\-]/_/g;
    if($filedata =~ /^(sub $name\s.*?^})/ims)
    {
      $code = $1;
    }
  }

  $code = $APP->listCode($code, 1);

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

  my $dt = $query->param('displaytype');
  $dt = "" if not defined($dt);
  return $text.$code if ($dt eq 'edit');

  if($delegated)
  {
    return $code. '<strong>This is a "delegated" code, part of the transition of removing routines from the database. To submit a patch, you must do so on <a href="https://github.com/everything2/everything2/blob/master/ecore/Everything/Delegation/'.$NODE->{type}->{title}.'.pm">github</a></strong>';
  }

  return $text unless $APP->isDeveloper($USER);
  $text .= '<br />'.linkNode($codenode,'Edit this code',{displaytype => 'edit'}).'<br />' if $APP->isAdmin($USER);

  return $text.$code;
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

  unless ($name and $name =~ /^-/ ) {
    $params{ -method } = $method if $method ;
    $params{ -name } = $params{-id} = $name if $name ;
  } else {
    %params = @_ ;
  }

  $params{ -method } ||= 'post';
  return $query->start_form( -action => $APP->urlGenNoParams($NODE,1) , %params ) .
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

  my ($field) = @_;

  my ($date, $time) = split / /,$$NODE{$field};

  return '<i>never</i>' unless defined($date) and defined($time);

  my ($hrs, $min, $sec) = split /:/, $time;
  my ($yy, $mm, $dd) = split /-/, $date;

  return '<i>never</i>' unless (defined($yy) and int($yy) and defined($mm) and int($mm) and defined($dd) and int($dd));

  my $epoch_secs=timelocal( $sec, $min, $hrs, $dd, $mm-1, $yy);
  my $nicedate =localtime ($epoch_secs);

  $nicedate =~ s/(\d\d):(\d\d):(\d\d).*$/$yy at $1:$2:$3/;
  return $nicedate;
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
    if($APP->confirmUser($USER -> {title}, $oldpass, undef, $query)) {
      if ( not $p1 and not $p2){
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

  $query->delete('oldpass', $name.1, $name.2);

  $str = "" if not defined($str);
  return $str.'<label>Your current password:'.$query->password_field(-name=>"oldpass", size=>10, -label=>'').'</label><br>

  <label>Enter a new password:'.$query->password_field(-name=>$name.'1', size=>10).'</label><br>

  <label>Repeat new password:'.$query->password_field(-name=>$name."2", size=>10).'</label>';
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

  my $str = "";

  my $nodelets = [];
  if($APP->isGuest($USER))
  {
    $nodelets = $Everything::CONF->guest_nodelets;
  }else{
    unless ( $$VARS{nodelets} )
    {
      #push default nodelets on
      $VARS->{nodelets} = join(',',@{$Everything::CONF->default_nodelets});
    }

    my $required = getNode('Master Control', 'nodelet')->{node_id};
    if( $APP->isEditor($USER) ) {
      # If Master Control is not in the list of nodelets, add it right at the beginning. 
      $$VARS{ nodelets } = "$required,".$$VARS{ nodelets } unless $$VARS{ nodelets } =~ /\b$required\b/ ;
    }else{
      # Otherwise, if it is there, remove it, keeping a comma as required
      $$VARS{nodelets} =~ s/(,?)$required(,?)/$1 && $2 ? ",":""/ge;
    }
    my $nodeletlist = $PAGELOAD->{pagenodelets} || $$VARS{nodelets} ;
    $nodelets = [split(',',$nodeletlist)] if $nodeletlist ;

    return '' unless scalar(@$nodelets) > 0;

    my $CB = getNode('chatterbox','nodelet') -> {node_id} ;
    if (($$VARS{hideprivmessages} or (not $$VARS{nodelets} =~ /\b$CB\b/)) and my $count = $DB->sqlSelect('count(*)', 'message', 'for_user='.getId($USER))) {
      my $unArcCount = $DB->sqlSelect('count(*)', 'message', 'for_user='.getId($USER).' AND archive=0');
      $str.='<p id="msgnum">you have <a id="msgtotal" href='.
        urlGen({'node'=>'Message Inbox','type'=>'superdoc','setvars_msginboxUnArc'=>'0'}).'>'.$count.'</a>'.
        ( $unArcCount>0 ? '(<a id="msgunarchived" href='.
        urlGen({'node'=>'Message Inbox','type'=>'superdoc','setvars_msginboxUnArc'=>'1'}).'>'.$unArcCount.'</a>)' : '').
        ' messages</p>';
    }
  }

  my $errWrapper = '<div class="nodelet">%s</div>';

  my $nodeletNum=0;

  foreach(@$nodelets) {
    my $current_nodelet = $DB->getNodeById($_);
    $nodeletNum++;
    unless(defined $current_nodelet) {
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
  $str.= $query->end_form unless($PARAM and $PARAM eq 'noendform');
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
  return $query->textfield("set$var", $$VARS{$var}, $len);
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
  return $query->textfield(-name=>$$NODE{type}{title} .'_'. $field, value=>$$NODE{$field}, size=>$length ,@expandable );
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
  return parseLinks( $$NODE{$field} , $n );
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
#			- <[key]>$APP->encodeHTML(value)</[key> (xml)
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
    my $localauthor = &$getAuthor;
    return linkNode($parent, '', {
      -class => 'title'
      , '#' => $$localauthor{title}
      , author_id => $$localauthor{node_id}
    });
  };

  $infofunctions{ type } ||= sub {
    my $type = $_[0]{type_title} || getNodeById($_[0]{wrtype_writeuptype}) || $_[0]{type};
    $type = $type->{title} if(UNIVERSAL::isa($type,"HASH"));
    if ($type eq 'draft'){
      my $status = getNodeById($_[0]{publication_status});
      $type = ($status ? $$status{title} : '(bad status)').' draft';
    }

    return '<span class="type">('.linkNode($_[0]{node_id}||$_[0]{writeup_id}, $type || '!bad type!').')</span>';
  };

  my $date = $infofunctions{date} ||= sub {
    return '<span class="date">'
      .htmlcode('parsetimestamp', $_[0]{publishtime} || $_[0]{createtime}, 256 + defined($_[1])?($_[1]):(0)) # 256 suppresses the seconds
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

  my $xml = 0;
  $xml = '1' if $instructions =~ s/^xml\b\s*// ;

  my ($wrapTag, $wrapClass, $wrapAtts) = ("", undef, undef);
  ($wrapTag, $wrapClass, $wrapAtts) = split(/\s+class="([^"]+)"/, $1) if $instructions =~ s/^\s*<([^>]+)>\s*//;

  $wrapAtts .= $1 if $wrapTag =~ s/(\s+.*)//;
  $wrapAtts ||= "";

  $instructions =~ s/\s*,\s*/,/g ;
  $instructions =~ s/(^|,),+/$1/g ; # remove spare commas

  my @sections = split( /,?((?:(?:content|[\d]+|unfiltered)-?)+),?/ , $instructions ) ;
  my $content = $sections[1] ;

  $wrapTag ||= 'div';
  $wrapClass .= ' ' if $wrapClass;
  $wrapClass .= $content ? 'item' : 'contentinfo';

  my @infowrap = ();
  @infowrap = ('<div class="contentinfo contentheader">', '', '<div class="contentinfo contentfooter">') if $content && !$xml;

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
      $text = parseCode( $text ) if exists( $$N{ type } ) and ( $$N{ type_nodetype } eq "14" or $$N{ type }{ extends_nodetype } eq "14" ) ;
      $text = $APP->breakTags( $text ) ;

      my ( $dots , $morelink ) = ( '' , '' ) ;
      if ( $length && length( $text ) > $length + $showanyway ) {
        $text = substr( $text , 0 , $length );
        $text =~ s/\[[^\]]*$// ; # broken links
        $text =~ s/\s+\w*$// ; # broken words
        $dots = '&hellip;' ; # don't add here in case we still have a broken tag at the end
        $morelink = "\n<div class='morelink'>(". linkNode($$N{node_id} || $$N{writeup_id}, 'more') . ")\n</div>";
      }

      $text = $APP->screenTable( $text ) if $lastnodeid ; # i.e. if writeup page & logged in
      $text = parseLinks( $APP->htmlScreen( $text , $HTML ) , $lastnodeid ) ;
      return "\n<div class=\"content\">\n$text$dots\n</div>$morelink" unless $xml ;

      $text =~ s/<a .*?(href=".*?").*?>/<a $1>/sg ; # kill onmouseup etc
      return '<content type="html">'.$APP->encodeHTML( $text.$dots ).'</content>' ;
    };
  }

  # do it

  my $str = '';
  foreach my $N ( @input ) {
    next if $infofunctions{cansee} and $infofunctions{cansee}($N) != 1;

    my $class = ''; $class = qq' class="$wrapClass"' unless $xml;
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
      $str .= ($infowrap[$count] || "");
      my @chunks = split( /,+/ , $_ ) ;

      foreach ( @chunks ) {
        if ( exists( $infofunctions{ $_ } ) ) {
          $str .= $infofunctions{ $_ }( $N ) ;
        } elsif (/^"([^"]*)"$/){
          $str .= $1;
        } elsif ( $xml ) {
          $str .= "<$_>".$APP->encodeHTML( $$N{ $_ } )."</$_>" ;
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
# parseLinks() and $APP->htmlScreen() on given field for 
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

  $doctext = $APP->breakTags( parseLinks( $APP->htmlScreen( $doctext, $TAGS ) ) );

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

  if($softserve and $softserve eq 'xml'){
    return "" if $$VARS{noSoftLinks};
  }
  return "" if($query->param('no_softlinks'));

  my $N = undef; $N = getNodeById($$NODE{parent_e2node},'light') if $$NODE{type}{title} eq 'writeup' ;
  $N ||= $NODE;
  my $lnid = undef;
  if ($APP->isGuest($USER) ) {
    $lnid=0;
  } else {
    $lnid=$$N{node_id};
  }

  my %unlinkables = ();
  foreach( @{$Everything::CONF->maintenance_nodes} ) {
    $unlinkables{$_} = 1;
  }
  return "" if $unlinkables{ $$N{node_id} };

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

  my %fillednode_ids = ();

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
          .$APP->encodeHTML($$tn{title})."</e2link>\n";
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

  my $gradeattstart = 'bgcolor="#';
  my $dimensions = scalar @maxval - 1;
  my $steps = scalar @nodelinks;

  my $e2nodetype = getId(getType('e2node'));
  my $grade = '';
  my $nid = undef;
  my @badOnes = ();	#auto-clean bad links
  my $numCols = 4;

  my $thisnode = $$N{node_id};

  foreach my $l (@nodelinks) {
    my @badwords = qw(boob breast butt ass lesbian cock dick penis sex oral anal drug pot weed crack cocaine fuck wank whore vagina vag cunt tits titty twat shit slut snatch queef queer poon prick puss orgasm nigg nuts muff motherfuck jizz hell homo handjob fag dildo dick clit cum bitch rape ejaculate bsdm fisting balling fetish suicide);
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
    $$VARS{nogradlinks} ? '' : ' class="slend"'
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

  my $daylogs = $DB->stashData("dayloglinks");

  my $str = qq|<ul class="linklist">|;

  foreach my $block (@$daylogs)
  {
    $str .= qq|<li class="loglink">|.linkNodeTitle("$block->[0]|$block->[1]").qq|</li>|;
  }
  $str .= qq|</ul>|;
  return $str;
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
  my $bookmarks = $APP->get_bookmarks($NODE) || [];


  my $str = "";
  if ($edit and $createform) {
    $str.=htmlcode('openform');
  }

  $str.="<ul class=\"linklist\" id=\"bookmarklist\">\n";
  my $count = scalar(@$bookmarks);
  foreach my $link (@$bookmarks) {

    next unless defined($link->{title});
    # Not all bookmarks have a tstamp component
    $link->{tstamp} ||= "";

    my $linktitle = lc($$link{title}); #Lowercased for case-insensitive sort
    if ($edit) {
      if ($query->param("unbookmark_$$link{node_id}")) {
        if($USER->{node_id} eq $NODE->{node_id} || $APP->isAdmin($USER))
        {
          $APP->delete_bookmark($NODE, $link);
        }
      } else {
       $str.="<li tstamp=\"$$link{tstamp}\" nodename=\"$linktitle\" >".$query->checkbox("unbookmark_$$link{node_id}", 0, '1', 'remove').' '.linkNode($$link{node_id})."</li>\n";
      }
    } else {
      $str.="<li tstamp=\"$$link{tstamp}\" nodename=\"$linktitle\">".linkNode($$link{node_id},0,{lastnode_id=>undef})."</li>\n";
    }
  }

  $str.="</ul>\n";

  if ($edit and $createform) {
    $str.=htmlcode('closeform');
  } elsif ( $count) {
    my $javascript = '';

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
    . linkNode($Everything::CONF->create_new_user, ' register here')
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
  $$params{'bookmark_id'} = $N->{node_id};
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

    $$USER{numwriteups} = $$SETTINGS{numwriteups} || '';
    $USER->{numwriteups} = 0 if($USER->{numwriteups} eq "");
    updateNode($USER, $USER);

    delete $$VARS{can_weblog};
    my $wls = getVars(getNode("webloggables", "setting"));
  
    my @canwl = ();
    foreach(keys %$wls)
    {
      my $n = getNodeById($_);
      next unless $n;
 
      if( $APP->isAdmin($USER) || $DB->isApproved($USER, $n) ){
        push @canwl, $_;
        next;
      }  
    }
    $$VARS{can_weblog} = join ",", sort{$a <=> $b} @canwl;
  }


  my $numcools = $DB->sqlSelect('count(*)', 'coolwriteups', 'cooledby_user='.getId($NODE));
  $$SETTINGS{coolsspent} = linkNode(getNode('cool archive','superdoc'), $numcools, { useraction => 'cooled', cooluser => $$NODE{title} }) if $numcools;

  my $feedlink = linkNode(getNode('new writeups atom feed', 'ticker'), 'feed', {'foruser' => $$NODE{title}}, {'title' => "Atom syndication feed of latest writeups", 'type' => "application/atom+xml"});

  $$SETTINGS{nwriteups} = $$SETTINGS{numwriteups} . " - " . "<a href=\"/user/".$APP->rewriteCleanEscape($$NODE{title})."/writeups\">View " . $$NODE{title} . "'s writeups</a> " . ' <small>(' . $feedlink .')</small>' if $$SETTINGS{numwriteups};

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
  if ($$NODE{title} eq 'alex') { $$SETTINGS{level} = "(Ascended)" } # --a

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

  my $expleft = 0; $expleft = $$LVLS{$lvl} - $$USER{experience} if exists $$LVLS{$lvl};
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
  my $canDoStuff = undef;
  $canDoStuff = $$USER{votesleft} || $APP->isEditor($USER) unless($APP->isGuest($USER));
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
  return $isEditor ? 'no writeup' : '' unless($N and $$N{writeup_id} or $$N{draft_id});

  $showwhat ||= 7 ; #1: kill only; 2: vote only; 3: both

  my $n = $$N{node_id} ;
  my $votesettings = getVars(getNode('vote settings','setting')) ;
  my $isMine = $$USER{user_id}==$$N{author_user};

  my $author = getNodeById( $$N{author_user} );
  $author = $query -> escapeHTML($$author{title}) if $author;

  my $edstr = '';

  if (($showwhat & 1) and $isEditor or $isMine or $$N{type}{title} eq 'draft') { # admin tools
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
  if ( $isMine or $prevvote and not $novotereason ) { # show votes cast
    my $uv = '';
    my $r = $$N{reputation} || 0;
    my ($p) = $DB->sqlSelect('count(*)', 'vote', "vote_id=$n AND weight>0");
    my ($m) = $DB->sqlSelect('count(*)', 'vote', "vote_id=$n AND weight<0");

    #Hack for rounding, add 0.5 and chop off the decimal part.
    my $rating = 0;
    $rating = int(100*$p/($p+$m) + 0.5) if ($p || $m);
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
      my $confirm = "";
      $confirm = 'confirm' if $$VARS{votesafety};
      my $replace = "";
      $replace = 'replace ' unless $$VARS{noreplacevotebuttons};
      my $clas = $replace."ajax voteinfo_$n:voteit?${confirm}op=vote&vote__$n=" ;
      my $ofauthor = (defined($VARS->{anonymousvote}) && $VARS->{anonymousvote} == 1 && !$prevvote ? 'this' : $author."'s");
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
    }elsif($$N{doctext} =~ /\[(http\:\/\/(?:\w+\.)?everything2\.\w+)/i or not $userLevel and $$N{doctext} !~ /\[(?!http:).+]/){
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
    $title = $APP->cleanNodeName($title);
    $query -> param('title', $title);
  }else{
    $title = $$N{title};
    # remove number/writeuptype from end of title (user can put it back later if they really want it)
    $title =~ s/ \($1\)$// if($title =~ / \(([\w\d]+)\)$/ and $1 eq int($1) or getNode($1, 'writeuptype'));
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
	
    if ($newoption or not $publish and $parent){
      # if no existing e2node with this title, or if changing existing parent, look for similar
      my $e2type = getId(getType('e2node'));
      my @findings = @{$APP->searchNodeName($title, [$e2type], 0, 1)}; # without soundex
      @findings = @{$APP->searchNodeName($title, [$e2type], 1, 1)} unless @findings; # with soundex

      push @existing, map {$_ && $$_{type_nodetype} == $e2type &&  # there's a bug in searchNodeName...
        $$_{node_id} != $parent && $$_{node_id} != $nameMatch ? $_: () } @findings;
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

  #TODO: Why are there two commas here?
  $str .= $query->h3(($publish ? 'Publish under' : 'Attach to').' existing title (e2node):')
    .$query -> ul({class => 'findings'}, 
      join('',, map {$query -> li($query -> input({value => $$_{node_id}, %prams})
	.' '
        .linkNode($_)
        .(delete $prams{checked} ? '' : '')
        )} @existing)
      ) if @existing;

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
    -action => $APP->urlGenNoParams($NODE,1),
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

  my $WRTYPE = getNodeById(scalar($query->param('writeup_wrtype_writeuptype')));
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

  # If you are publishing as another user, and you have permission to, let this go through.
  if($WRITEUP->{author_user} != $USER->{node_id} && htmlcode("canpublishas",getNodeById($WRITEUP->{author_user})->{title}))
  {
    updateNode($WRITEUP, -1);
  }else{
    unless(updateNode($WRITEUP, $USER))
    {
      Everything::printLog("In publishwriteup, user '$$USER{title}' Could not update writeup id: '$$WRITEUP{node_id}'"); 
    }
  }

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
    return;
  }

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

  return $query->param('publish', 'OK');

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
    $str.= '<tr><td class="setting" bgcolor="'.$keyclr.'">'.$_.'</td><td class="setting" bgcolor="'.$valclr.'">'.$APP->encodeHTML($$SETTINGS{$_}, 1)."</td></tr>\n";  
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
    my $value = $APP->encodeHTML($$SETTINGS{$_});

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
  return '<div class="nodelock"><p>'.$MINE.'</p></div>' if($MINE and not UNIVERSAL::isa($MINE,'HASH'));

  # OK: user can post or edit a writeup/draft

  my ($str, $draftStatusLink, $lecture) = ("","","");

  if ($MINE){
    return '<p>You can edit your contribution to this node at'.linkNode($MINE).'</p>' if $$VARS{HideWriteupOnE2node}; # user doesn't want to see their text

    $str.=$query->start_form(-action => $APP->urlGenNoParams($MINE, 'noQuotes'), -class => 'writeup_add')
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
      .$APP->rewriteCleanEscape($$USER{title})
      .'/writeups/'
      .$APP->rewriteCleanEscape($$NODE{title}),
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

  return "" if ($APP->isGuest($USER)) || ($$USER{title} eq 'everyone');
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

  return "" if ($APP->isGuest($USER)) || ($$USER{title} eq 'everyone');
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
  if(not $APP->isGuest($USER) and my $ln = $query->param('lastnode_id')  and ($query->param('lastnode_id') =~ /^\d+$/)) {
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

  my $csr = $DB->{dbh}->prepare($qry);

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

  my $hidebox = '';

  unless ($type){
    # no old type: new writeup/draft for publication
    my $checked = "";

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

    $checked = ' checked="checked"' if($checked or ref($N) and 
      ($$N{reputation} or $DB->sqlSelect('vote_id', 'vote', "vote_id=$$N{node_id}")
      or $DB->sqlSelect(
        'LEFT(notetext, 25)'
        , 'nodenote'
        , "nodenote_nodeid=$$N{node_id} AND noter_user = 0"
        , 'ORDER BY timestamp LIMIT 1'
      ) eq 'Restored from Node Heaven'));

    $type ||= getNode('thing', 'writeuptype') -> {node_id};

    $hidebox = qq!<label><input type="checkbox" name="writeup_notnew" value="1"$checked>don't show in New Writeups nodelet</label>!;
  }

  my $str = '<label title="Set the general category of your writeup, which helps identify the type of content in writeup listings."><strong>Writeup type:</strong>';

  my (@WRTYPE) = getNodeWhere({type_nodetype => getId(getType('writeuptype'))});

  my %items = ();

  my $isEd = $APP->isEditor($USER) || $$USER{title} eq 'Webster 1913' || $$USER{title} eq 'Virgil';

  my $isE2docs = $APP->inUsergroup($USER,"E2Docs");

  foreach (@WRTYPE){
    next if ((not $isEd) and (lc($$_{title}) eq 'definition' or lc($$_{title}) eq 'lede'));
    next if ((not $isEd or not $isE2docs) and lc($$_{title}) eq 'help');
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

  return '' if($link and ($ntypet ne 'e2node' or ($$NODE{group} and @$NODE{group})) # let anyone uncool a nodeshell
    and ( $APP->isEditor($$link{to_node}) ) and $$link{to_node}!=$$USER{node_id});

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
      my @group = (); @group = @{ $$NODE{group} } if $$NODE{group};
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
  my %items = ();
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
      my ($localname, $value) = (undef,undef);
      $_ =~ s/^-//;
		
      ($localname, $value) = split '_', $_;
      push @idlist, $value;
      $items{$value} = $localname;

      undef $_;  # This is not a type	
    } else {
      my $TYPE = $DB->getType($_); 
      push @TYPES, $TYPE if(defined $TYPE); #replace w/ node refs
    }
  }

  my $NODELIST = ();
  $NODELIST = $DB->selectNodeWhere({ type_nodetype => \@TYPES }, "", "title") if @TYPES;

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
  return $query->end_form if($$NODE{type}{title} eq "e2node" and not $$NODE{group} or $APP->isGuest($USER));
  my $isKiller = $APP->isEditor($USER);

  my $voteButton = "";
  my $killButton = "";
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
    "\n\t\t\t<li>".linkNodeTitle('The Node Crypt').'</li>'.
    "\n\t\t\t<li>".linkNodeTitle('Edit These E2 Titles').'</li>'.
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

  $skipFilterHTML = 0 if not defined($skipFilterHTML);

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

  ## no critic (RequireCheckingReturnValueOfEval)
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
  ## use critic (RequireCheckingReturnValueOfEval)

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
      if((length($_) || 0)>$i) {
        $c.=', ' if length($c);
        $c.='" <code>&#91;'.$APP->encodeHTML(substr($_,0,$i),1).'</code> "';
      }
    }

    if(length($c)) {
      push @problems, $curCat.'You may have forgotten to close a link. Here is the start of the long links: '.$c.'.';
    }

    #forgot to close a link - [ in a link
    $c='';

    foreach(@wuPartLink) {
      next unless defined($_);
      if( index($_,'[')!=-1 ) {
        next if $_ =~ /[^[\]]*(?:\[[^\]|]*[\]|][^[\]]*)?/ ; # direct link, regexp from parselinks in HTML.pm
        $c.=', ' if length($c);
        $c.='" <code>&#91;'.$APP->encodeHTML($_,1).'&#93;</code> "';
      }
    }

    if(length($c)) {
      push @problems, $curCat.'It looks like you forgot to close a link, since you tried to link to a node with &#91; in the title. Here is what you linked to: '.$c.'.';
    }

    if(defined($wuPartText[-1]))
    {
      #forgot to close a link - no final ]
      if( ($i=index($wuPartText[-1],'['))!=-1 ) {
        push @problems, $curCat.'Oops, it looks like you forgot to close your last link. You ended with: " <code>'.$APP->encodeHTML(substr($wuPartText[-1],$i),1).'</code> ".';
      }
    }

  } #end show default hints

  #HTML hints
  if($showHTML) {
    $curCat = $showCat ? '(basic HTML) ' : '';

    #HTML tags in links
    $c='';
    foreach(@wuPartLink) {
      next unless defined $_;
      $i = (($i=index($_,'|'))==-1) ? $_ : substr($_,0,$i);	#only care about part that links, not display
      if(defined($i) and $i =~ /<.*?>/) {
        $c.=', ' if length($c);
        $c.='" <code>'.$APP->encodeHTML($i,1).'</code> "';
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
        For example, to show the symbol '.($i=$APP->encodeHTML($1,1)).' enter it as: " <code>'.$APP->encodeHTML($i).'</code> ".';
    }

    if($writeup =~ /\s([\[\]])\s/) {
      push @problems, $curCat.'On Everything, the square brackets, &#91; and &#93; have a special meaning - they form links to other nodes. If you want to just display them, you will have to use an HTML entity. To show an open square bracket &#91; type in " <code>&amp;#91;</code> ". To show a close square bracket &#93; type in " <code>&amp;#93;</code> ". If you already know this, and are wondering why you\'re seeing this message, you probably accidently inserted a space at the very '.($1 eq '[' ? 'start' : 'end').' of a link.';
    }

    #no closing semicolon on entity
    if($writeup =~ /\s&(#?\w+)\s/) {
      push @problems, $curCat.'All HTML entities should have a closing semicolon. You entered: " <code>'.($i='&amp;'.$APP->encodeHTML($1)).'</code> " but the correct way is: " <code>'.$i.';</code> ".';
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
    my %problemCount = ();	#key is problem description, value is number of times

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

  $str = '<p><big><strong>Hints!</strong></big> (choose which writeup hints display in your <a href='.urlGen({'node'=>'Settings','type'=>'superdoc'}).'">Settings</a>)</p><p>'.$str.'</p>';

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

  my $lastnode = $$NODE{node_id};
  $lastnode = $$NODE{parent_e2node} if $$NODE{type}{title} eq 'writeup';
  $lastnode = $query->param("lastnode_id")||0 if $$NODE{title} eq 'Findings:' && $$NODE{type}{title} eq 'superdoc';

  my $e2 = $APP->buildNodeInfoStructure($NODE, $USER, $VARS,$query);

  $e2->{lastnode_id} = $lastnode;

  my $cookie = undef;
  foreach ('fxDuration', 'collapsedNodelets', 'settings_useTinyMCE', 'autoChat', 'inactiveWindowMarker'){
    if (!$APP->isGuest($USER)){
      $$VARS{$_} = $cookie if($cookie = $query->cookie($_));
      delete $$VARS{$_} if(defined($cookie) and $cookie eq '0');
    }
    $e2->{$_} = $$VARS{$_} if ($$VARS{$_});
  }

  $e2->{collapsedNodelets} ||= "";
  $e2->{collapsedNodelets} =~ s/\bsignin\b// if($query->param('op') and $query->param('op') eq 'login');


  if($e2->{user}->{developer} and defined($VARS->{nodelets}) and $VARS->{nodelets} =~ /836984/)
  {
    my $edev = getNode("edev","usergroup");
    my $page = Everything::HTML::getPage($NODE, scalar($query->param("displaytype")));
    my $page_struct = {node_id => $page->{node_id}, title => $page->{title}, type => $page->{type}->{title}};
    $e2->{developerNodelet} = {page => $page_struct, news => {weblog_id => $edev->{node_id}, weblogs => $APP->weblogs_structure($edev->{node_id})}}; 
  }

  $e2 = JSON->new->encode($e2);

  my $libraries = qq'<script src="https://code.jquery.com/jquery-1.11.1.min.js" type="text/javascript"></script>';

  unless ($APP->isGuest($USER)){
      $libraries .= qq|<script src="https://ajax.googleapis.com/ajax/libs/jqueryui/1.11.1/jquery-ui.min.js" type="text/javascript"></script>|;
  }
  $libraries .= qq|<script src="|.$APP->asset_uri("legacy.js").qq|" type="text/javascript"></script>|;
  $libraries .= qq|<script src="|.$APP->asset_uri("react/main.bundle.js").qq|" type="text/javascript"></script>|;
  return qq|
    <script type='text/javascript' name='nodeinfojson' id='nodeinfojson'>
      e2 = $e2;
    </script>
    $libraries|;
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

  return "" if $APP->isGuest($USER);
  return "" unless $$NODE{type}{title} eq 'e2node';

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
  my $R = $$USER{in_room};
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

  return if $APP->isSuspended($NODE,"homenodepic");
  return "Not in production" unless $Everything::CONF->environment eq "production";
  my $s3 = Everything::S3->new('homenodeimages');
  return "Could not generate S3 object" unless $s3;

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
       my $outfile;
       open $outfile, ">","$tmpfile";
       print $outfile $buf;
       close $outfile;
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

    unless( $s3->upload_file($basename,$tmpfile, { content_type => $content} ) )
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
      $row .="https://s3.amazonaws.com/static.everything2.com/broke.gif";
    } else {
      $row .="https://s3.amazonaws.com/static.everything2.com/full.gif";
    }
    $row.="></td></tr>";
    $rows = $row.$rows;
  }

  $str.=$rows;
  return $str."</table>";
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

  my $str = "";
  $str = ' instant ajax chatterbox_chatter:#' if $query and $query -> param('ajaxTrigger') and defined $query->param('changeroom')	and $query->param('changeroom') != $$USER{in_room};
  my $RM = getNode('e2 rooms', 'nodegroup');
  my @rooms = @{ $$RM{group}  };
  my @aprrooms = ();
  my %aprlabel = ();
  my ($nodelet) = @_ ;
  $nodelet =~ s/ /+/g;

  ## no critic RequireCheckingReturnValueOfEval
  foreach(@rooms) {
    my $R = getNodeById($_);
    next unless eval($$R{criteria});
    if(defined $query->param('changeroom') and $query->param('changeroom') == $_ and $$USER{in_room} != $_)
    {
      $APP->changeRoom($USER, $R);
    }

    push @aprrooms, $_;
    $aprlabel{$_} = $$R{title};
  }
  ## use critic (RequireCheckingReturnValueOfEval)

  return unless @aprrooms;

  push @aprrooms, '0';
  $aprlabel{0}='outside';

  if(defined $query->param('changeroom') and $query->param('changeroom') == 0)
  {
    $APP->changeRoom($USER, 0);
  }

  my $isCloaker = $APP->userCanCloak($USER);
  if($query->param('sexiscool') and $isCloaker)
  {
    if($query->param('cloaked'))
    {
      $APP->cloak($USER, $VARS);
    } else {
      $APP->uncloak($USER, $VARS);
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
  $str.=' '.htmlcode('createroom').q|<br />|;

  if(my $suspensioninfo = $APP->isSuspended($USER,"changeroom"))
  {
    if(defined($suspensioninfo->{ends}) and $suspensioninfo->{ends} != 0)
    {
      $str.='You are locked here for '.($APP->convertDateToEpoch($suspensioninfo->{ends})-time).' seconds.';
    }else{
      $str.='You are locked here indefinitely.';
    }
  }else{

    $str.='<br>';
    $str.=$query->popup_menu(-name=>'changeroom', Values=>\@aprrooms, default=>$$USER{in_room}, labels=>\%aprlabel,class=>$ajax."changeroom=/$nodelet");
    $str.=$query->submit('sexiscool','go');
    $str.='</form></div>';
  }
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

  return unless $APP->getLevel($USER) >= $Everything::CONF->create_room_level;
  my $cr = getId(getNode('create room','superdoc'));
  return '<span title="create a new room to chat in">'. linkNode($cr,'create',{lastnode_id=>0}). '</span>';
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

  my $csr = $DB -> sqlSelectMany(
    'links.to_node, note.firmlink_note_text',
    'links
    LEFT JOIN firmlink_note AS note
      ON note.from_node = links.from_node
      AND note.to_node = links.to_node',
    "links.linktype = $firmlinkId
      AND links.from_node = $$currentnode{node_id}");

  my @links = ();

  if($csr) {
    while(my $row = $csr->fetchrow_hashref()) {
      my $linkedNode = getNodeById($row->{to_node});
      my $text = $row->{firmlink_note_text};
      push @links, { 'node' => $linkedNode, 'text' => $text };
    }
  }

  my $str = '';
  foreach(sort {lc($$a{node}->{title}) cmp lc($$b{node}->{title})} @links)
  {
    my ($linkedNode, $linkText) = ($$_{node}, $$_{text});
    $linkText="" unless(defined($linkText));
    $str .=' , ' if $str;
    $str .= $query->checkbox('cutlinkto_'.$$linkedNode{node_id}, 0, '1', '') if $cantrim;
    $str .= linkNode($linkedNode);
    $str .= $APP->encodeHTML(" $linkText") if $linkText ne '';
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

  foreach (@{$Everything::CONF->maintenance_nodes} )
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
  my $qh = $dbh->prepare($sqlStr);
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
    $uname = $APP->encodeHTML($uname);
    return "<strong>$uname</strong> doesn't seem to exist on the system!" unless $U;
  }

  $query->param('DEBUGignoreUser', 'tried to unignore '.$$U{title});
  return "$$U{title} unignored";

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

  my $lastnodeId = $query->param('softlinkedFrom');
  $lastnodeId ||= $query -> param('lastnode_id') unless $APP->isGuest($USER);

  my $lastnode = undef; 
  $lastnode = getNodeById($lastnodeId) if defined $lastnodeId;
  my $default = undef; $default = $$lastnode{title} if $lastnode;

  my $str = $query->start_form(
    -method => "GET"
    , -action => $query->script_name
    , -id => 'search_form'
    , -role => 'form'
    ).
    q|<div class="form-group"><div class="has-feedback has-feedback-left">|.
    $query->textfield(-name => 'node',
      value => $default,
      force => 1,
      -class => 'form-control',
      -id => 'node_search',
      -placeholder => 'Search',
      -size => 28,
      -maxlength => 230).qq|<i class="glyphicon glyphicon-search form-control-feedback"></i></div>|;

  my $lnid = undef;
  $lnid = $$NODE{parent_e2node} if $$NODE{type}{title} eq 'writeup' and $$NODE{parent_e2node} and getNodeById($$NODE{parent_e2node});
  $lnid ||= getId($NODE);

  $str.='<input type="hidden" name="lastnode_id" value="'.$lnid.'">';
  $str.='<input type="submit" name="searchy" value="search" id="search_submit" title="Search within Everything2" class="btn btn-default">';


  $str.=qq|<span id="searchbtngroup">|;
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

  $str.=qq|</span>|; #searchbtngroup
  return $str . "\n</div></form>";
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
  return if $APP->isSuspended($NODE,'homenodepic');
  return unless $$NODE{imgsrc};
  my $imgsrc = $$NODE{imgsrc};
  $imgsrc = "$$NODE{title}";
  $imgsrc =~ s/\W/_/g;
  $imgsrc = "/$imgsrc" if ($imgsrc !~ /^\//);
  return '<img src="https://s3-us-west-2.amazonaws.com/hnimagew.everything2.com'.$imgsrc.'" id="userimage">';
}

sub showchatter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $json = {};
  my $jsoncount = undef; $jsoncount = 1 if shift;
  my $nochat = "";

  $nochat = 'If you '.linkNode($Everything::CONF->create_new_user,
    'register',{lastnode_id=>0}).', you can talk here.' if $APP->isGuest($USER);

  ### Check to see if they're suspended for having an unverified email address

  my $sushash = undef;
  $sushash = $DB->sqlSelectHashref("suspension_sustype", "suspension", "suspension_user=$$USER{node_id} and suspension_sustype='1948205'") unless $nochat;

  $nochat = "<strong>You need to ".linkNode(getNode('verify your email account','superdoc'))." before you can talk in public here.</strong>" if $sushash && $$sushash{suspension_sustype};


  if(!$nochat && $$VARS{publicchatteroff})
  {
    if(defined($query->param('RemoveEarPlugs')) and $query->param('RemoveEarPlugs') eq '1')
    {
      delete $$VARS{publicchatteroff};
    } else {
      $nochat = '<em>your earplugs are in ('.linkNode($NODE,'remove them',{'RemoveEarPlugs'=>1, -class => "ajax chatterbox:updateNodelet:Chatterbox"}).')</em>';
    }
  }

  if ($nochat)
  {
    $nochat = qq'<p id="chat_nochat">$nochat</p>';
    return $nochat unless $jsoncount;
    return { '1' => {value => $nochat, id => 'nochat'} };
  }

  my $useBorgSpeak = 0;
  my $messagesToShow = 25;
  my $messageInterval = 360; #in seconds, how long room messages remain

  my $ignorelist = $DB->sqlSelectMany('ignore_node', 'messageignore', 'messageignore_id='.$$USER{user_id});
  my @list = ();
  while (my ($u) = $ignorelist->fetchrow)
  { 
    push @list, $u;
  }

  my $ignoreStr = join(", ",@list);

  my $wherestr = "for_user=0 " ;
  $wherestr .= "and tstamp >= date_sub(now(), interval $messageInterval second)" unless $Everything::CONF->environment ne "production" && !$$USER{in_room};
  $wherestr .= ' and room='.$$USER{in_room};
  $wherestr .= " and author_user not in ($ignoreStr)" if $ignoreStr;

  my $csr = $DB->sqlSelectMany('*', 'message use index(foruser_tstamp) ', $wherestr, "order by tstamp desc limit $messagesToShow");

  if($csr->rows == 0)
  {
    my $borgspeak = '<div id="chat_borgspeak">'.htmlcode('borgspeak',$useBorgSpeak).'</div>';
    return $borgspeak unless $jsoncount;
    return { '1' => {value => $borgspeak, id => 'borgspeak'} };
  }

  my $valid = getVars(getNode('egg commands','setting'));
  my $UID = getId($USER) || 0;
  my $isEDev = $APP->isDeveloper($USER, "nogods");

  my ($str, $aid, $flags, $userLink, $userLinkApostrophe, $text) = ("","","","","","");

  my $maxLen = htmlcode('chatterSplit');

  my %fireballs = (
    fireball => 'BURSTS INTO FLAMES!!!' ,
    conflagrate => 'CONFLAGRATES!!!' ,
    immolate => 'IMMOLATES!!!' ,
    singe => 'is slightly singed. *cough*' ,
    explode => 'EXPLODES INTO PYROTECHNICS!!!' ,
    limn => 'IS LIMNED IN FLAMES!!!' ) ;

  my $sc = sub{
    qq'<span style="font-variant:small-caps">$_[0]</span>' ;
  };

  my @msgs = reverse @{ $csr->fetchall_arrayref( {} ) };

  foreach my $MSG (@msgs)
  {
    my $usermessage = undef;
    $aid = $$MSG{author_user} || 0;
    $text = $$MSG{msgtext};

    $text = $APP->escapeAngleBrackets($text);

    #Close dangling square brackets
    my $numopenbrackets = ($text =~ tr:\[::);
    my $numclosebrackets = ($text =~ tr:\]::);
    while($numclosebrackets < $numopenbrackets)
    {
      $text .= "]";
      $numclosebrackets++;
    }

    $text = parseLinks($text,0,1);

    my $userTitle = getNodeById($aid, 'light')->{'title'};
    $userTitle =~ s/ /_/g; # replace spaces with underscores in username
    $userLink = "<span class='chat_user chat_$userTitle'>". linkNode($aid) . "</span>";
    $userLinkApostrophe = "<span class='chat_user chat_$userTitle'>". linkNode($aid, getNode($aid)->{title} . "'s") . "</span>";

    if (htmlcode('isSpecialDate','halloween'))
    {
      my $aUser = getNodeById($aid, 'light');
      my $costume = ''; $costume = getVars($aUser)->{costume} if (getVars($aUser)->{costume});
      if ($costume gt '')
      {
        my $halloweenStr = $$aUser{title}."|".$APP->encodeHTML($costume);
        $userLink = linkNodeTitle($halloweenStr);
      }
    }

    if($$VARS{powersChatter})
    {
      my $isChanop = $APP->isChanop($aid, "nogods");
      $flags = '';

      if($APP->isAdmin($aid) && !$APP->getParameter($aid,"hide_chatterbox_staff_symbol") )
      {
        $flags .= '@';
      } elsif($APP->isEditor($aid, "nogods") && !$APP->getParameter($aid,"hide_chatterbox_staff_symbol")){
        $flags .= '$';
      }

      $flags .= "+" if $isChanop;
      $flags .= '%' if $isEDev;
      if(length($flags))
      {
        $flags = '<small>'.$flags.'</small> ';
      }
    }

    if ( $text =~ /^\/me(\b)(.*)/i )
    {
      $usermessage = '<i>' . $userLink . $1 . $2 . '</i>';
      # What do you mean, \me's code is broken? -- eien_meru
    } 
    elsif ( $text =~ /^\/me\'s\s(.*)/i )
    {
      #Attempt to match this one before matching the AFD2007 commands.
      $usermessage = '<i>' . $userLinkApostrophe . ' ' . $1 . '</i>';
    }
    elsif ( $text =~ /^\/sings?\b\s?(.*)/i )
    { 
      my @notesarray = ("&#9835;", "&#9834;", "&#9835;&#9834;", "&#9834;&#9835;");
      $usermessage = "&lt;$userLink&gt; <i> $notesarray[int(rand(4))] $1 $notesarray[int(rand(4))]</i>";
    }
    elsif ($text =~ /(^\/whisper)(.*)/i)
    { 
      ##any other names by which you should whisper?
      $usermessage = '<small>&lt;' . $userLink .'&gt; ' . $2 . '</small>'
    }
    elsif ($text =~ /(^\/death)(.*)/i)
    { 
      $usermessage = '&lt;' . $userLink .'&gt; ' . &$sc($2);
    }
    elsif ( $text =~ /^\/rolls(.*)/i )
    {
      ### dice rolling
      if ($text =~ /^\/rolls 1d2 &rarr; 1/i)
      { 
        $usermessage = &$sc( $userLink . ' flips a coin &rarr; heads' );
      }
      elsif ($text =~ /^\/rolls 1d2 &rarr; 2/i)
      {
        $usermessage = &$sc( $userLink . ' flips a coin &rarr; tails');
      }
      else 
      { 
        $usermessage = &$sc( $userLink . ' rolls ' . $1 );
      }
    }
    elsif ( $text =~ /^\/(fireball|conflagrate|immolate|singe|explode|limn)s?\s(.*)/i )
    {
      ### fireball messages
      $usermessage = &$sc( $userLink . ' fireballs ' . $2 ).'...<br><i>' . linkNodeTitle($2) . " $fireballs{$1}</i>";
    }
    elsif ( $text =~ /^\/sanctify?\s(.*)/i )
    {
      ### Sanctify command
      $usermessage = &$sc( $userLink . ' raises the hand of benediction...').'<br><i>' . linkNodeTitle ($1) . ' has been SANCTIFIED!</i>';
    }
    elsif ( $text =~ /^\/(\S*)\s+(.*)/ && $$valid{lc($1)})
    { 
      #Case insensitive match
      ### normal egg message

      my $target = $2;
      (my $eggStr = $$valid{$1}) =~ s/( ~|$)/ $target/;
      $usermessage = &$sc( $userLink . ' ' . $eggStr ).'!';
    }

    $usermessage ||= '&lt;' . $userLink . '&gt; ' . $text;
    $usermessage = qq'<div class="chat" id="chat_$$MSG{message_id}">$flags$usermessage</div>';
    unless ($jsoncount)
    {
      $str.="$usermessage\n";
    } else {
      $$json{$jsoncount} = {
        value => $usermessage,
        id => $$MSG{message_id}
      };
      $jsoncount++;
    }
  }

  return $str unless $jsoncount;
  return $json;
}

sub showmessages
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($maxmsgs,$showOpts) = @_;

  #display options
  $showOpts ||= '';

  my $json = {};
  my $jsoncount = undef; 
  $jsoncount = 1 if $showOpts =~ /j/;

  my $noreplylink = {getId(getNode("klaproth","user")) => 1};

  my $showD = $$VARS{pmsgDate} || (index($showOpts,'d')!=-1); #show date
  my $showT = $$VARS{pmsgTime} || (index($showOpts,'t')!=-1); #show time
  my $showDT = $showD || $showT;
  my $showArc = index($showOpts,'a')!=-1;      #show archived messages (usually don't)
  my $showNotArc = index($showOpts,'A')==-1;   #show non-archive messages (usually do)
  return unless $showArc || $showNotArc;
  my $showGroup = index($showOpts,'g')==-1;    #show group messages (usually do)
  my $showNotGroup = index($showOpts,'G')==-1; #show group messages (usually do)
  my $canSeeHidden = $APP->isEditor($USER);
  return unless $showGroup || $showNotGroup;

  return if $APP->isGuest($USER) ;

  my $showLastOnes = ! ($$VARS{chatterbox_msgs_ascend} || 0); 

  if($maxmsgs =~ /^(.)(\d+)$/)
  {
    #force oldest/newest first
    $maxmsgs=$2;
    if($1 eq '-')
    {
      $showLastOnes=1;
    } elsif($1 eq '+') {
      $showLastOnes=0;
    }
  }

  $maxmsgs ||= 10;
  $maxmsgs = 100 if ($maxmsgs > 100);

  my $order = $showLastOnes ? 'DESC' : 'ASC';
  my $limits = 'for_user='.getId($USER);
  my $totalMsg = $DB->sqlSelect('COUNT(*)','message',$limits); #total messages for user, archived and not, group and not, from all users
  my $filterUser = $query->param('fromuser');
  if($filterUser)
  {
    $filterUser = getNode($filterUser, 'user');
    $filterUser = $filterUser ? $$filterUser{node_id} : 0;
  }

  $limits .= ' AND author_user='.$filterUser if $filterUser;

  my $filterMinor = ''; #things to only filter for display, and not for the "X more in inbox" message

  unless($showGroup && $showNotGroup)
  {
    $filterMinor .= ' AND for_usergroup=0' unless $showGroup;
    $filterMinor .= ' AND for_usergroup!=0' unless $showNotGroup;
  }

  unless($showArc && $showNotArc)
  {
    $filterMinor .= ' AND archive=0' unless $showArc;
    $filterMinor .= ' AND archive!=0' unless $showNotArc;
  }

  my $csr = $DB->sqlSelectMany('*', 'message', $limits . $filterMinor, "ORDER BY  message_id $order LIMIT $maxmsgs");
  my $UID = getId($USER) || 0;
  my $isEDev = $APP->isDeveloper($USER);

  my $aid = undef;  #message's author's ID

  my $msgauthor = undef; #message's author; have to do this in case sender has been deleted (!)
  my $ugID = undef;
  my $UG = undef;
  my $flags = undef;
  my $userLink = undef;

  #UIDs for Virgil, CME, Klaproth, and root.
  my @botlist = qw(1080927 839239 952215 113);
  my %bots = map{$_ => 1} @botlist;

  my $string = "";
  my @msgs = @{ $csr->fetchall_arrayref( {} ) };
  @msgs = reverse @msgs if $showLastOnes;
  foreach my $MSG (@msgs)
  {
    my $text = $$MSG{msgtext};
    #Bots, don't escape HTML for them.
    unless( exists $bots{$$MSG{author_user}} )
    {
      $text = $APP->escapeAngleBrackets($text);
    }

    $text =~ s/\[([^\]]*?)$/&#91;$1/; #unclosed [ fixer
    my $timestamp = $$MSG{tstamp};
    $timestamp =~ s/\D//g;
    my $str = qq'<div class="privmsg timestamp_$timestamp" id="message_$$MSG{message_id}">';

    $str.= "<span class=\"deleteBox\" title=\"Check this box and hit Talk to delete this message\">";
    $str.= $query->checkbox('deletemsg_'.$$MSG{message_id}, '', 'yup', ' ');
    $str.= "</span>";

    $aid = $$MSG{author_user} || 0;
    if($aid)
    { 
      $msgauthor = getNodeById($aid) || 0;
    } else { 
      undef $msgauthor;
    }

    my $authorVars = undef;
    $authorVars = getVars($msgauthor) if($msgauthor);

    my $name = $msgauthor ? $$msgauthor{title} : '?';
    $name =~ tr/ /_/;
    $name = $APP->encodeHTML($name);

    if($$VARS{showmessages_replylink} and not $$noreplylink{$$MSG{author_user}}){
      my $jsname = $name;
      # This is an incredibly stupid hack. Because the htmlcode dispatcher is trying to handle teplate logic, we get this bad behavior
      #  pass in a harmless undef to keep the htmlcode function from mangling the string
      $jsname=htmlcode("eddiereply", $text, undef) if $jsname eq "Cool_Man_Eddie";

      $jsname =~ s/"/&quot;/g;
      $jsname =~ s/'/\\'/g;
      $str.= qq!<a href="javascript:e2.startText('message','/msg $jsname ')" title="Reply to $jsname" class="action" style="display:none;">(r)</a>!;
    }

    $ugID = $$MSG{for_usergroup};
    $UG = $ugID ? getNodeById($ugID) : undef;

    if($$VARS{showmessages_replylink} and defined($UG) and not $$noreplylink{$$MSG{author_user}})
    {
      my $grptitle = $$UG{node_id}==$UID ? '' : $$UG{title};
      # Grmph. -- wharf
      $grptitle =~ s/ /_/g;
      $grptitle =~ s/"/&quot;/g;
      $grptitle =~ s/'/\\'/g;
      # Test for ONO. This is moderately cheesy because the message text
      # could start with "ONO: ", but that's rare in practice. The table
      # doesn't track ONOness, so the text is all we've got.
      my $ono ='';
      $ono = '?' if $text =~ /^O[nN]O: /;
      $str.= qq!<a href="javascript:e2.startText('message','/msg$ono $grptitle ')" title="Reply to group" class="action" style="display:none;">(ra)</a>!;
    }

    $str.=' ';

    if($showDT)
    {
      my $tsflags = 128; # compact timestamp
      $str .= '<small class="date">';
      $tsflags |= 1 if !$showT; # hide time 
      $tsflags |= 2 if !$showD; # hide date
      $str .= htmlcode('parsetimestamp', "$$MSG{tstamp},$tsflags");
      $str .= '</small> ';
    }

    $str .= '(' . linkNode($UG) . ') ' if $ugID;

    #N-Wing probably doing too much work...
    #changes literal '\n' into HTML breaks (slash, then n; not a newline)
    $text =~ s/\s+\\n\s+/<br>/g;

    if ($$VARS{chatterbox_authorsince} && $msgauthor && $authorVars)
    {
      $str .= '<small>('. htmlcode('timesince', $msgauthor->{lasttime}, 1). ')</small> ' if (!$$authorVars{hidelastseen} || $canSeeHidden);
    }

    if($$VARS{powersMsg})
    {
      # Separating mere coders from the gods...
      my $isCommitter = $APP->inUsergroup($aid,'%%','nogods');
      my $isChanop = $APP->isChanop($aid,"nogods");

      $flags = '';
      if($APP->isAdmin($aid) && !$APP->getParameter($aid,"hide_chatterbox_staff_symbol"))
      {
        $flags .= '@';
      } elsif($APP->isEditor($aid, "nogods") && !$APP->isAdmin($aid) && !$APP->getParameter($aid,"hide_chatterbox_staff_symbol")){
        $flags .= '$';
      }

      $flags .= '*' if $isCommitter;

      $flags .= '+' if $isChanop;

      $flags .= '%' if $isEDev && $APP->isDeveloper($aid);
      if(length($flags))
      {
        $flags = '<small>'.$flags.'</small> ';
        $str .= $flags;
      }
    }

    $userLink = $msgauthor ? linkNode($msgauthor) : '?';

    $str.='<cite>'.$userLink.' says</cite> '.parseLinks($text,0,1);
    $str.="</div>";

    unless ($jsoncount)
    {
      $string.="$str\n";
    } else {
      $$json{$jsoncount} = {
        value => $str,
        id => $$MSG{message_id},
        timestamp => $timestamp
      };
      $jsoncount++;
    }
  }

  if($totalMsg)
  {
    my $MI_node = getNode("Message Inbox", "superdoc");
    my $str = qq'<p id="message_total$totalMsg" class="timestamp_920101106172500">(you have '.linkNode($MI_node,"$totalMsg private messages").')</p>';
    unless ($jsoncount)
    {
      $string.="$str\n";
    } else {
      $$json{$jsoncount} = {
        value => $str,
        id => "total$totalMsg", # will be replaced if number changes
        timestamp => '920101106172500' # keep at bottom. 90,000 years should be enough
      };
    }

  }

  return $string unless $jsoncount;
  return $json;
}

sub eddiereply
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $text = shift;
  my $splitStr1='Hey, ';
  my $splitStr2=' just cooled';
  my $splitStr3=' just \[E2 Gift'; # Cater for C! gifts notifications - BlackPawn
  my @tempsplit = split($splitStr1,$text);

  unless($tempsplit[1])
  {
    return "Cool_Man_Eddie";
  }

  my $coolStr = $tempsplit[1];

  my @coolsplit= split(/$splitStr2/,$tempsplit[1]);
  if ($coolsplit[0] eq $coolStr)
  {
    @coolsplit= split(/$splitStr3/,$tempsplit[1]);
  }

  my $eddie = $coolsplit[0];

  # This is a message type that eddiereply can't handle;
  unless(defined($eddie))
  {
    return "Cool_Man_Eddie";
  }
  $eddie =~ s/\[user\]//g;
  $eddie =~ s/\[//g;
  $eddie =~ s/ /_/g;
  $eddie =~ s/\]//g;
  return $eddie;
}

# returns if current server time matches the given day
# parameter: case insensitive string(s) of date(s) - if more than 1, then any matches counts as a success
# if no date given, or date not found, returns 0
#
sub isSpecialDate
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($d) = @_;
  my $dt = DateTime->now( time_zone => "UTC" );
  my $year = $dt->year();
  my $mday = $dt->mday();
  my $mon = $dt->month();
  my $hour = $dt->hour();


  $d = "\L$d"; #case insensitive
  my $y = ($d =~ /(\d+)$/) ? $1 : 0; #try to get the year

  $mon -= 1;
  # Note that $mon = month - 1, January is 0, December is 11

  if($d =~ /^afd/) {
    return '1' if ($mon==3 and $mday==1 and ($y?$y==$year:1));
  } elsif($d =~ /^halloween/) {
    return '1' if ($mon==9 and $mday==31 and ($y?$y==$year:1));
  } elsif($d =~ /^xmas/) {
    return '1' if ($mon==11 and $mday==25 and ($y?$y==$year:1));
  } elsif($d =~ /^nye/) {
    return '1' if ($mon==11 and $mday==31 and ($y?$y==$year:1));
  } elsif($d =~ /^nyd/) {
    return '1' if ($mon==0 and $mday==1 and ($y?$y==$year:1));
  }

  return 0;
}

#
sub nodeletsection
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($nlAbbrev, $nlSection, $altTitle, $linkTo, $styleTitle, $styleContent) = @_;

  $altTitle ||= $nlSection;
  $altTitle = linkNodeTitle($linkTo.'|'.$altTitle) if($linkTo);

  my $isGuest = $APP->isGuest($USER);
  my $param = $nlAbbrev.'_hide'.$nlSection;

  my $v = undef;
  if (not $isGuest and (defined ($v=$query->param($param))) )
  {
    if($v)
    {
      $$VARS{$param}=1;
    } else {
      delete $$VARS{$param};
    }
  }

  my $showContent = undef;
  $showContent = 1 unless $$VARS{$param};
  my $plusMinus = '<tt> '.( $isGuest ? '*' : ($showContent ? '-' : '+') ).' </tt>';
  my $sectionId = $nlAbbrev.'section_'.$nlSection ;
  my $args = join(',',@_);
  $args =~ s/ /+/;

  my ($s, $closeLink) = ('','');
  ($s, $closeLink) = ('[<a style="text-decoration: none" class="ajax '.$sectionId.
    ':nodeletsection:'.$args.'" href=' .
    urlGen({node_id=>$NODE->{node_id}, $param=>($showContent ? '1' : '0')})
    . ' title="' . ($showContent ? 'collapse' : 'expand') . '">', '</a>]') unless $isGuest;

  $altTitle = " <strong>$altTitle</strong>";
  if($styleTitle && $styleTitle =~ /^[fF]/)
  {
    #full style: [ Title + ]
    $s .= $altTitle.$plusMinus.$closeLink;
  } else {
    #classic style: [ + ] Title
    $s .= $plusMinus.$closeLink.$altTitle;
  }

  my $content = "";
  if($showContent)
  {
    $content = htmlcode($sectionId);
    $content = "" if not defined($content);
    $content = qq'<div class="sectioncontent">\n$content\n</div>\n';
  }

  return qq'<div id="$sectionId" class="nodeletsection"><div class="sectionheading">$s</div>\n$content</div>\n';
}

# This functionality might go away
#
# pass which macro name to "run"
# $$VARS{chatmacro} should contain the macro's text (yes, this is a bit clunky, but passing complex arguments via htmlcode is a pain)
# $$VARS{chatmacro_NAME} where NAME is the macro's name should contain the actual macro
# returns: parsed macro text (used for debugging)
#
sub doChatMacro
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $whichMacro = $_[0];
  my $sep = "\n";
  my $uid = getId($USER);
  my $uname = $$USER{'title'};
  $uname =~ s/ /_/g;

  if($whichMacro !~ /^[A-Za-z0-9_\-]+$/)
  {
    return '"' . $whichMacro . '" isn\'t a valid macro name' . $sep;
  }

  my $macroFull = undef;
  unless( $macroFull = $$VARS{'chatmacro_'.$whichMacro} )
  {
    return '"' . $whichMacro . '" doesn\'t exist' . $sep;
  }

  my $origSendTo = $query->param('sendto');
  my $origMessage = $query->param('message');
  my $str = '';
  my @args = split('\s+',$$VARS{'chatmacro'});
  unshift @args, $uname;

  #loop through each line of the macro
  my $result = undef;
  my @lineParts = ();
  my @macroLines = split(/\n/, $macroFull);
  foreach my $line (@macroLines)
  {
    next if $line=~/^$/;
    next if $line=~/^#/;
    next unless $line=~/^\/say\s+(.*?)$/;
    $line = $1;

    #loop through each part of the line, looking for special symbols
    @lineParts = split('\s+', $line);

    $result = '';
    foreach my $part (@lineParts) {
      if($part =~ /^\$(.*)/)
      { 
        #starts with $
	my $r = $1;
	if($r =~ /^\d+\+?$/)
        { 
          #numbers with optional + at end
          if(substr($r,-1,1) eq '+')
          {
            $r = substr($r, 0, -1);
            $result .= join(' ', @{@args}[$r..$#{@args}]); #tye on PM says: @{$aRef}[$n..$#{$aRef}]
          } else {
            $result .= $args[$r];
          }
        } else {
          $result .= $part;
        }
      } else {
        $result .= $part;
      }

      $result .= ' ';

    }

    $result =~ s/^\s+//;
    $result =~ s/\s+$//;

    # $DB->sqlInsert('message', {msgtext=>'DEBUG: using line result: }'.$result.'{', author_user=>$uid, for_user=>$uid});

    $query->param(-name=>'sendto', -value=>'');
    $query->param(-name=>'message',-value=>$result);

    if(my $delegation = Everything::Delegation::opcode->can("message"))
    {
      $str .= 'eval='.$delegation->($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP); 
    }

    $str .= $result . $sep;

  }

  $query->param(-name=>'sendto', -value=>$origSendTo);
  $query->param(-name=>'message',-value=>$origMessage);

  return $str;
}

sub episection_advice
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '<ul>'.
    '<li>'.linkNodeTitle('E2 Quick Start|Quick Start').'</li>'.
    '<li>'.linkNodeTitle('Everything2 Help').'</li>'.
    '<li>'.linkNodeTitle('E2 Mentoring Sign-Up').'</li>'.
    '</ul>';
}

sub episection_ces
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my (undef,undef,undef,$mday,$mon,$year) = localtime(time);
  $year += 1900; #stupid Perl
  my @months = qw(January February March April May June July August September October November December);
  my $curLog = '[Editor Log: '.$months[$mon]." $year]";

  # Link The Oracle sent with the username iff displaying a homenode
  my $oraclecode = "";
  $oraclecode = $query -> li(linkNode(getNode('The Oracle', 'oppressor_superdoc'), "The Oracle", {the_oracle_subject => $$NODE{title}}))if $$NODE{type}{title} eq 'user';

  return parseLinks("<ul>
    <li>[E2 Editor Doc]</li>
    <li>[Content Reports]</li>
    <li>[Drafts for review[superdoc]]</li>
    <li>[25] | [Everything New Nodes]</li>
    <li>[E2 Nuke Request]</li>
    <li>[Nodeshells Marked For Destruction|Nodeshells]</li>
    <li>[Recent Node Notes]</li>
    <li>[Your insured writeups]</li>
    <li>".linkNode(getNode("Node Parameter Editor","oppressor_superdoc"),"Parameter Editor", {for_node => $$NODE{node_id}})."</li>
    <li>[Blind Voting Booth]</li>
    <li>[usergroup discussions|Group discussions]</li>
    <li>$curLog</li>$oraclecode</ul>");
}

# originally by [|site=pm&type=user|vroom] at [|site=pm&type=htmlcode|timesince]
# updated to include fractional resolution
# last update: Wednesday, July 13, 2005
#
sub timesince
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($timestamp,$shortMode,$fractionalResolution) = @_;

  return "?" unless $timestamp;
  $fractionalResolution = 10 unless (defined $fractionalResolution) && $fractionalResolution;	#10 shows ___._

  my ($d, $t) = split(' ',$timestamp);
  my ($hour, $min, $sec) = split(':',$t);
  my ($year, $month, $day) = split('-',$d);

  $shortMode = "" if not defined($shortMode);
  my $noHTML = $shortMode =~ m/nohtml/i;

  return '?' unless int($month) && int($year) && int($day);
  return '?' unless $year > 1990 && $year < 2100; #sanity
  my $last_here = timegm($sec, $min, $hour, $day, $month-1, $year);

  my $SECOND = 1;
  my $MINUTE = 60;
  my $HOUR = 3600;
  my $DAY = 24 * $HOUR;
  my $WEEK = 7 * $DAY;
  my $MONTH = 30.4375 * $DAY; #approx (30.4375==365.25/12)
  my $YEAR = 365.25 * $DAY; #approx

  # Lord Brawl removed the +3600 for Standard Time on 18 Dec 2005, 
  # and again on 29 Oct 2006. 
  # Put it back in April... $last_here + 3600 + 95; 
  my $difference = time - $last_here + 10; #+/- constant is a hack (+3600 during daylight savings time) (even more fun, varies per web server)
  if (!$noHTML) {
    return '<em title="timesince:'.$difference.'">now!</em>' if $difference<0;
    return '<em>now</em>' if $difference==0;
  } else {
    return '*now*' if $difference <= 0;
  }

  my @params = ();

  if($difference >= $YEAR)
  {
    push @params, $YEAR, ($shortMode ? ('y','y') : ('year', 'years'));
  } elsif($difference >= $MONTH) {
    push @params, $MONTH, ($shortMode ? ('mon','mon') : ('month', 'months'));	#FIXME?
  } elsif($difference >= $WEEK) {
    push @params, $WEEK, ($shortMode ? ('wk','wk') : ('week', 'weeks'));
  } elsif($difference >= $DAY) {
    push @params, $DAY, ($shortMode ? ('d','d') : ('day', 'days'));	#FIXME?
  } elsif($difference >= $HOUR) {
    push @params, $HOUR, ($shortMode ? ('hr','hr') : ('hour', 'hours'));
  } elsif($difference >= $MINUTE) {
    push @params, $MINUTE, ($shortMode ? ('min','min') : ('minute', 'minutes'));	#FIXME?
  } else {
    push @params, $SECOND, ($shortMode ? ('s','s') : ('second', 'seconds'));
  }

  #assume $difference is positive
  #my $lapse = int($difference / $params[0] + 0.5);
  my $lapse = int(($difference / $params[0]) * $fractionalResolution + 0.5)/$fractionalResolution;

  #my $str = sprintf('%d %s', $lapse, $params[$lapse==1 ? 1 : 2]);
  my $str = $lapse . ' ' . $params[$lapse==1 ? 1 : 2];
  $str .= ' ago ' unless $shortMode;

  return $str;
}

sub addfirmlink
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $RECURSE = 1;
  return unless $APP->isEditor($USER);

  $query->delete('op');

  return htmlcode('openform')
    .'<fieldset><legend>Firmlink</legend>'
    . htmlcode('verifyRequestForm', 'firmlink')
    . $query->hidden(-name => "op", -value => "firmlink")
    . $query->hidden(-name => "firmlink_from_id", -value => $$NODE{node_id})
    .'<label>Firmlink node to: '
    .  $query->textfield(-name => 'firmlink_to_node')
    .'</label>'
    .'<br>'
    .'<label>With (optional) following text: '
    .  $query->textfield(-name => 'firmlink_note_text')
    .'</label>'
    .'<br>'
    . $query->submit(-value => "Firmlink")
    .'</fieldset>'
    .'</form>';

}

sub writeupcools
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $N ) = @_ ;
  $N = $NODE unless $N ;
  getRef( $N );
  return "" unless(defined($N));

  my $nr = getNode('node row', 'superdoc')->{node_id};

  my $str = undef;
  my $coollink = "";
  my $coolnum = undef;
  my $coolers = "";

  if ( not $DB->sqlSelect('linkedby_user', 'weblog', "weblog_id=$nr and to_node=$$N{node_id} and removedby_user=0")
    and ( $$VARS{cools} && $$VARS{cools} > 0 )
    and ($$N{author_user} != $$USER{user_id})
    and not $DB->sqlSelect( '*', 'coolwriteups', "coolwriteups_id=$$N{node_id} and cooledby_user=$$USER{node_id}" ) )
  {
    my $author = undef; $author = getNodeById( $$N{ author_user } ) unless(defined($$VARS{anonymousvote}) and $$VARS{anonymousvote} == 1);
    if ($author)
    {
      $author = $author -> {title};
      $author =~ s/[\W]/ /g;
      $author .= "'s";
    } else {
      $author = 'this';
    }

    my $op = $$VARS{coolsafety} ? 'confirmop' : 'op'  ;
    $coollink = '<b>'.linkNode( $NODE , 'C?' , { $op=>'cool', cool_id=>$$N{ node_id }, lastnode_id => 0 ,
      -title => "C! $author writeup" , -class => "action ajax cools$$N{node_id}:writeupcools:$$N{node_id}" }).'</b>';
  }

  my $nc = $$N{cooled} ; #num C!s, quick check
  if ( $nc ){
    $coollink = " &#183; $coollink" if $coollink ;
    $coolnum = $nc.' <b>C!</b>'.( $nc==1 ? '' : 's' ) ;

    my $csr = $DB->sqlSelectMany('cooledby_user', 'coolwriteups', 'coolwriteups_id='.$$N{ node_id },'order by tstamp ASC');
    return "(Can't get C!s)" unless $csr;

    my $count = undef;
    unless($nc==($count=$csr->rows))
    {
      #stored count in WU and table differ
      #update WU info - force get, to ensure we have updated version
      $N = getNodeById( $$N{ node_id } , 'force' ) ;
      if ( $N && $$N{ cooled } != $count )
      {
        $$N{ cooled } = $count ;
        updateNode( $N , -1 ) ;
      }

      $nc=$count;
    }

    $count = 0 ;
    my @people = () ;
    my @coolers = @{ $csr -> fetchall_arrayref( {} ) } ;
    foreach ( @coolers )
    {
      ++$count ;
      my $CG = getNodeById( $$_{ cooledby_user } ) ;
      my $t = ( $CG ? linkNode( $CG ) : '?' ) ;
      if ( $$CG{user_id} == $$USER{ user_id } )
      {
        push @people, '<strong>'.$t.'</strong> (#'.$count.')' ;
      } else {
        push @people, $t;
      }
    }

    $csr->finish;

    $coolers .= join( ', ' , @people ) ;
    $coolers =~ s/((?:.*?,){5})/$1<br>/g ;
  }

  $query->param( 'showwidget' , 'showCs'.$$N{ node_id } ) if $query->param('op') eq 'cool' and $query->param('cool_id') == $$N{ node_id } ;

  return '<span id="cools'.$$N{node_id}.'" class="cools">'.htmlcode( 'widget' , '<small>This writeup has been cooled by: &nbsp;</small><br>
    '.$coolers , 'span ' , $coolnum , { showwidget => 'showCs'.$$N{ node_id } , -title => 'show who gave the C!s' , -closetitle => 'hide cools' } ) .
    $coollink.'</span>' ;
}

sub usercheck
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($givenTitle) = @_;

  return if($$NODE{type_nodetype} != getId(getType('e2node')) && !defined $givenTitle);

  my $checkedTitle = $$NODE{title};
  $checkedTitle = $givenTitle if defined $givenTitle;
  my @grp = getNodeWhere({ 'title' => $checkedTitle});
  my $retstr = '';
  return $retstr unless(@grp > 1);

  my @outstr = ();
  foreach my $n (@grp)
  {
    next if($$n{node_id} == $$NODE{node_id});
    next if(defined $givenTitle && $$n{type}{title} eq 'e2node');
    next if(defined $givenTitle && $$n{type}{title} eq 'node_forward');
    next unless canReadNode($USER, $n) and $$n{type}{title} ne 'draft';
    my $tmp = linkNode($n, $$n{type}{title});

    if($$n{type}{title} eq 'user')
    {
      #getNodeWhere gives partial node results
      $n = getNodeById($n->{node_id});
      my $tousr = undef;
      my $ptr = undef;
      if($n->{message_forward_to})
      {
        $tousr = getNodeById($n->{message_forward_to});
      }
      $tmp .= ' (message alias for '.linkNode($tousr).')' if($tousr);
   }
   push @outstr, $tmp;
  }

  return $retstr unless @outstr > 0;

  $retstr = '("'.$checkedTitle.'" is also a: ';
  $retstr .= join(', ',@outstr);
  my $id = "isalso";
  $id .= "forward" if defined $givenTitle;
  return "\t".'<div class="topic" id="' . $id . '">'.$retstr.'.)</div>';
}

sub linkGroupMessages
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # just call this in a usergroup page
  # optional argument: user name to /msg to join the group; this should already have any spaces converted into underlines
  # this will create a link to 'usergroup message archive' with the current group already selected

  my $msgJoin = $_[0];

  unless( Everything::isApproved($USER, $NODE) )
  {
    return 'How about logging in?' if $APP->isGuest($USER);
    return 'You aren\'t a member of this usergroup.'.($msgJoin && length($msgJoin) ? ' To join, <tt>/msg '.$msgJoin.'</tt> .' : '');
  }

  my $gid=$$NODE{node_id};
  return 'Ack! Unable to find group ID!' unless $gid;
  my ($num)=$DB->sqlSelect('COUNT(*)','message','for_user='.$gid.' AND for_usergroup='.$gid);

  return '<a href='.urlGen({'node'=>'usergroup message archive', 'type'=>'superdoc', 'viewgroup'=>$$NODE{title}}).'>'.$num.'</a> message'.($num==1?' has':'s have').' been sent to this group.';
}

sub statsection_personal
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = undef;

  #pass 2 args: category and value
  local *genRow = sub {
    return '<div><span class="var_label">' . $_[0] . ': </span><span class="var_value">' . $_[1] . "</span></div>\n";
  };

  $str .= genRow('XP',$$USER{experience});
  $str .= genRow('Writeups',$$VARS{numwriteups});

  my $lvl = $APP->getLevel($USER)+1;
  my $LVLS = getVars(getNode('level experience', 'setting'));
  my $WRPS = getVars(getNode('level writeups', 'setting'));

  my $expleft = 0;
  $expleft = $$LVLS{$lvl} - $$USER{experience} if exists $$LVLS{$lvl};

  my ($numwu, $wrpleft) = (undef, undef);
  $$VARS{numwriteups} ||= 0;
  $numwu = $$VARS{numwriteups};
  $wrpleft = ($$WRPS{$lvl} - $numwu) if exists $$WRPS{$lvl};

  $str .= genRow('Level',$APP->getLevel($USER));
  if ($expleft > 0)
  {
    $str .= genRow('XP needed',$expleft);
  } else {
    $str .= genRow('WUs needed',$wrpleft);
  }

  if (!$$VARS{GPoptout})
  {
    $str .= genRow('GP', $$USER{GP});
  }

  return '<div>'.$str.'</div>';
}
 
# customized display of writeup information
# pass (optional) writeup ID, (optional) things to show
# This monster is exactly why we need templates
#
sub displayWriteupInfo
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  #
  # setup
  #

  #parameters
  my ($WRITEUP) = @_;
  $WRITEUP ||= $NODE;
  return 'Ack! displayWriteupInfo: Can\'t get writeup '.$WRITEUP unless getRef $WRITEUP;

  my $nID = getId($NODE);
  my $wuID = getId $WRITEUP;

  #constants
  my $UID = getId($USER);
  my $isGuest = $APP->isGuest($USER);
  my $isRoot = $APP->isAdmin($USER);
  my $isCE = $APP->isEditor($USER);
  my $aid = $$WRITEUP{author_user} || 0;
  my $wuAuthor = getNodeById($aid) || undef;
  my $isMine = (!$isGuest) && ($aid==$UID);
  my $isDraft = ($$WRITEUP{type}{title} eq 'draft');
  my $authorIsBot = (defined $wuAuthor) && (($wuAuthor->{title} eq 'Webster 1913'));	#FIXME: get (cached) bot setting
  my $v=getVars($wuAuthor);

  #client-side error
  local *userWarn = sub {
    return '<small title="displayWriteupInfo (htmlcode)">!!! ' . $_[0] . ' !!!</small>';
  };


  #parameters again

  my $inHeader = undef;	#true=before WU text, false=after WU text (note: we use a slightly bad way of determining if we're in the header or footer)
  my $fnName = undef;	#name of current function
  #lookup table of user-entered function to actual function to run
  #	by default, function return values are cached
  #	a function may override the default caching by setting $infofunctions->{$fnName} to the string that should be used for future calls instead
  my $infofunctions = undef;
  my $CACHE_NAME = 'cache_displayWriteupInfo_'.$wuID;

  if( (exists $PAGELOAD->{$CACHE_NAME}) && (defined $PAGELOAD->{$CACHE_NAME}) )
  {
    $inHeader=0;
    $infofunctions = $PAGELOAD->{$CACHE_NAME};
  } else {
    $inHeader=1;
    $infofunctions = {
      'type'=>\&info_wutype,
      'kill'=>\&info_kill,
      'draftstatus'=>\&draftstatus,
      'vote'=>\&info_vote,
      'cfull'=>\&info_c_full,
      'cshort'=>\&info_c_short,
      'dtcreate'=>\&info_dt_create,
      'author'=>\&info_author,
      'authoranon'=>\&info_author_anon,
      'pseudoanon'=>\&info_author_pseudo,
      'typeauthorprint'=>\&info_typeauthor,
      'notnew'=>\&info_hidden,	#original name
      'hidden'=>\&info_hidden,	#name that makes more sense
      'length'=>\&info_length,
      'sendmsg'=>\&sendMessage,
      'social'=>\&showBookmarks,
      'hits'=>\&info_hits,
      'addto'=>\&info_addto,
      'cats'=>\&info_cats,
      'audio'=>\&audio,
      'music'=>\&music,
      'nothing'=>\&info_nothing,
    };
    $PAGELOAD->{$CACHE_NAME} = $infofunctions;
  }

  #determine things to display
  my @showThings = ();
  #use user vars, if set, or default
  if($inHeader)
  {
    #header
    if ($$VARS{wuhead})
    {
      @showThings = split(/\s*,\s*/, $$VARS{wuhead});
    } else {
      #no settings given, so use default header, which is mostly "classic"
      @showThings = ('c:type','c:author','c:hits', 'r:dtcreate');
    }
  } else {
    #footer
    if ($$VARS{wufoot}){
      @showThings = split(/\s*,\s*/, $$VARS{wufoot});
    } else {
      @showThings = ('l:kill','c:vote');
      push @showThings,('c:cfull') unless (exists $$VARS{wuhead} && ($$VARS{wuhead}=~'cfull'||$$VARS{wuhead}=~'cshort'));
      push @showThings,('c:sendmsg','c:addto','r:social');
    }
  }

  # Why is this in a closure?
  {
    #my $max = 16; #don't let user go nuts
    my $max = 50;	#don't let the user go too nuts (we cache now, so repeating something several times doesn't really matter)
    @showThings = @showThings[0..$max-1] if scalar(@showThings)>$max;
  }

  my $t = undef;	#temporary values that subs can use

  #display constants
  my %tDataOpen = (
    'l'=>'<td style="text-align:left" class="',
    'c'=>'<td class="',
    'r'=>'<td  style="text-align:right" class="',
  );

  my $tDataClose = '</td>';
  my $tRowOpen = '<table border="0" cellpadding="0" cellspacing="0" width="100%"><tr class="';
  my $tRowClose = "</tr></table>\n";

  # subs
  #

  #links to the current WU, showing the given text
  #does NOT create softlink, since they are useless between e2node and writeup
  local *linkWU = sub {
    my ($txt) = @_;
    $txt = $WRITEUP->{title} || '???' unless (defined $txt) && length($txt);
    return linkNode($WRITEUP,$txt);
  };

  local *info_authorsince = sub {
    #not if bot or $VARS
    return if $authorIsBot;
    return if $$VARS{info_authorsince_off};
    return if $$v{hidelastseen} && !$isCE;
    return unless $wuAuthor;
    return " " if $isGuest;
    my $lastTime = $$wuAuthor{lasttime};
    my $lastTimeTitle = htmlcode('timesince', $lastTime, "noHTML");
    my $lastTimeText = htmlcode('timesince', $lastTime, "short");
    return ''
      . qq[<small title="Author last logged in $lastTimeTitle">]
      . "($lastTimeText)"
      . "</small>";
  };

  local *info_wutype = sub {
    return linkWU('<b>Draft</b>') if $isDraft;
    $t = $$WRITEUP{wrtype_writeuptype} || 0;
    return userWarn(linkWU('bad WU type: 0')) unless $t;
    getRef $t;
    return userWarn(linkWU('bad WU type: '.$$t{node_id})) unless $t;
    return userWarn(linkWU('0 length WU type title: '.$$t{node_id})) unless length($$t{title});
    return '<span class="type">('.linkWU($$t{title}).')</span>';
  };

  local *info_kill = sub {
    $infofunctions->{$fnName} = '';
    return htmlcode("$$WRITEUP{type}{title}tools", $wuID) if $isCE or $isMine or $isDraft;
  };

  local *info_vote = sub {
    return htmlcode('ilikeit',$wuID) if $APP->isGuest($USER);
    $t = htmlcode('voteit',$wuID,2);
    return '' unless $t;
    $infofunctions->{$fnName} = '';
    return '<small>'.$t.'</small>';
  };

  local *info_c_full = sub {
    unless ( not $APP->isGuest($USER) or ($query->param('showwidget') and ($query->param('showwidget') eq 'showCs'.$$WRITEUP{node_id} )))
    {
      return '' unless $$WRITEUP{cooled} ;
      return linkNode($NODE, $$WRITEUP{cooled}.' <b>C!</b>'.( $$WRITEUP{cooled}==1 ? '' : 's' ),
        { showwidget=>'showCs'.$$WRITEUP{node_id}, lastnode_id => 0 , -title => $$WRITEUP{cooled}.' users found this writeup COOL' ,
        -class => "action ajax cools$wuID:writeupcools:$wuID" ,
        -id => "cools$wuID" } );
    }

    return htmlcode('writeupcools',$wuID);
  };

  local *info_c_short = sub {
    $$VARS{wuhead} =~ s/cshort/cfull/;
    $$VARS{wufoot} =~ s/cshort/cfull/;
    return info_c_full();
  };

  local *info_dt_create = sub {
    return '<small class="date" title="'.htmlcode('parsetimestamp', $$WRITEUP{publishtime} || $$WRITEUP{createtime}, 4).'" >'.htmlcode('parsetimestamp', $$WRITEUP{publishtime} || $$WRITEUP{createtime}).'</small>';
  };

  local *info_author = sub {
    my $anon = undef;
    $anon = 'anonymous' unless (not $VARS->{anonymousvote}) or $isMine or $authorIsBot or $APP->hasVoted($WRITEUP, $USER) or $isDraft;
    if ($VARS->{anonymousvote} && $anon)
    {
      return '(anonymous)' . ($isCE?' '.info_authorsince():'');
    }

    if(defined $wuAuthor)
    {
      my $authorLink = linkNode( $wuAuthor , $anon , { lastnode_id => 0 , -class => 'author' } ) ;
      $authorLink = '<s>'.$authorLink.'</s>' if $isCE && !$authorIsBot && (exists $wuAuthor->{acctlock}) && ($wuAuthor->{acctlock});
      return 'by <a name="'.$wuAuthor->{title}.'"></a><strong>' . $authorLink . '</strong> ' . (( !$anon ? info_authorsince():'')||"");
    } else {
      return '<em>unable to find author '.$aid.'</em>';
    }
  };

  # FIXME: direct links to writeups won't work if author is anonymous
  local *info_author_anon = sub {
    $$VARS{anonymousvote} = '1';
    $$VARS{wuhead} =~ s/authoranon/author/;
    $$VARS{wufoot} =~ s/authoranon/author/;
    return &info_author();
  };

  local *info_author_pseudo = sub {
    $$VARS{anonymousvote} = '2';
    $$VARS{wuhead} =~ s/pseudoanon/author/;
    $$VARS{wufoot} =~ s/pseudoanon/author/;
    return &info_author() ;
  };

  local *info_typeauthor = sub {
    return &info_wutype() . ' ' . &info_author();
  };

  local *info_hidden = sub {
    return unless $isCE || $isMine;
    my $disp = '<small>(' . ($$WRITEUP{notnew} ? 'hidden' : 'public') . ')</small>';
    $infofunctions->{'notnew'} = $infofunctions->{'hidden'} = $disp;
    return $disp;
  };

  local *info_length = sub {
    #most of these counts are rough,
    #and can be fooled rather easily;
    #however, it isn't worth taking
    #the CPU time to find exact values

    my $wdt = $APP->breakTags($$WRITEUP{doctext}) || '';
    my $c = 0;	#count

    #paragraphs - could be off by one if <p> incorrectly used to end a paragraph instead of to start one
    while($wdt =~ /<[Pp][>\s]/g)
    {
      #weak paragraph count
      ++$c;
    }
    $c=1 if !$c;
    $t = $c.' <abbr title="approximate paragraphs">' . ($VARS->{noCharEntities} ? 'p' : '&para;') . '</abbr>, ';

    #if we want to burn CPU, we could count sections - p, blockquote, ul, ol, hr, anything else - as separators

    #now only deal with plain text
    $wdt =~ s/\<.+?\>//gs;

    #sentences
    $c = ($wdt =~ tr/.!?//);
    $t .= $c.' <abbr title="approximate sentences">s</abbr>, ' if $c;

    #words
    $c=0;
    while($wdt =~ /\w+/g)
    {
      ++$c;
    }

    $t .= $c.' <abbr title="approximate words">w</abbr>, ' if $c;
    # $t .= (($wdt =~ s/\W+/ /gs)||0).' w, ';

    $t .= length($$WRITEUP{doctext}) . ' <abbr title="characters">c</abbr>';

    return $t;
  };


  local *info_hits = sub {
    return "";
    # my $hitStr; # This is a kludgy way to do this, but it seems efficient - Oo.
    # (my $y,my $m,my $d) = split /-/, $$WRITEUP{createtime};
    # my $dateval = $d+31*$m+365*$y; 
    # if ($dateval > 733253 )
    # {
    #   $hitStr='publication';
    # }else { 
    #   $hitStr='23rd October 2008';
    # }

    # my $hitshits=$DB->sqlSelect("hits","node","node_id=$wuID"); # $$WRITEUP{hits} ?
    # return qq'<span title="hits since $hitStr according to the node table">Hits: $$WRITEUP{hits}</span>';
  };


  local *info_nothing = sub {
    return;
  };

  local *info_addto = sub {
    return '' if $query->param('showwidget') and $query->param('showwidget') eq 'addto'.$$WRITEUP{ node_id } ; #noscript: widget is in page header
    my $str = undef;
    unless ($isDraft)
    {
      $str = htmlcode('categoryform', $WRITEUP, 'writeupform');
      $str .= htmlcode('weblogform', $WRITEUP, 'writeupform') if $$VARS{can_weblog};
    }

    if ($str)
    {
      my $author = getNodeById( $$WRITEUP{ author_user } ) ;
      $author = $author->{ title } if $author ;
      $author =~ s/[\W]/ /g ;

      my $target = $query->param( 'target' );
      $target = 0 if not defined($target);
      my $nid = $query->param( 'nid' );
      $nid = 0 if not defined($nid);

      my $op = $query->param( 'op' );
      $op = "" if not defined($op);
      
      $query->param( 'showwidget' , 'addto'.$$WRITEUP{ node_id } ) if(
        $op eq 'weblog' and $target == $$WRITEUP{ node_id } or
        $op eq 'category' and $nid == $$WRITEUP{ node_id });

      $str = htmlcode( 'widget' , '
        <small>'.htmlcode( 'bookmarkit' , $WRITEUP , "Add $author"."'s writeup to your E2 bookmarks" ).'</small>
        <hr>'.$str , 'span' , 'Add to&hellip;' ,
        { showwidget => 'addto'.$$WRITEUP{ node_id } ,
        '-title' => "Add $author"."'s writeup to your bookmarks, a category or a usergroup page" ,
        '-closetitle' => 'hide addto options' ,
        node => $WRITEUP , addto => 'noscript' } ) ;
    } else {
      $str = '<small>'.htmlcode( 'bookmarkit' , $WRITEUP , 'bookmark' ).'</small>' ;
    }

    return "<span class=\"addto\">\n$str\n</span>"
  };

  local *info_cats = sub {
    return htmlcode('listnodecategories', $$WRITEUP{ node_id });
  };

  local *music = sub {
    return ''
      . '<button title="Add additional World Cup content"'
      . ' onClick="flatify(this);return false;">'
      . '<img src="https://s3.amazonaws.com/static.everything2.com/futbol.png">'
      . '</button>';
  };

  local *audio = sub {
    my $audioStr = undef;
    my $recording=$DB->sqlSelectHashref("*", "recording", "recording_of=$wuID");
    if (exists ($$recording{link}))
    {
      $audioStr="<a href='".$$recording{link}."'>mp3</a>";
    } else {
      my $GROUP = getNode('podpeople','usergroup');
      my $id = getId($USER);
      if (grep {/^$id$/} @{ $$GROUP{group} })
      {
        $audioStr.='<a href=' . urlGen({node => $WRITEUP->{title}.' mp3',type => 'recording',op => 'new',displaytype => 'edit','recording_recording_of' => $wuID,
          'recording_read_by' => $$USER{user_id},}) .'>Add mp3</a>';
      }
    }

    return $audioStr;
  };

  local *showBookmarks = sub {
    return '' if $$v{nosocialbookmarking} || $$VARS{nosocialbookmarking};
    return htmlcode('socialBookmarks',$wuID);
  };


  #TODO? checkbox to have anonymous? maybe just for certain people?
  my $msgreport = "";
  local *sendMessage = sub {
    $infofunctions->{$fnName} = '';
    return if $isGuest;
    my $queryid = 'msg_re'.$$WRITEUP{node_id} ;
    $msgreport = qq'<a id="sent$queryid"></a>' ;
    if( $$WRITEUP{author_user}!=$$USER{user_id} && $$VARS{borged} )
    {
      return '(you may not talk now)' ;
    } elsif( $query->param( $queryid ) ){
      $msgreport = htmlcode('writeupmessage', $queryid, $WRITEUP) ;
    }
    my $nN = "";
    $nN = $query->checkbox(-name=>'nn'.$queryid, value=>$$WRITEUP{node_id}, label=>'NN ', title=>'check to record this message as a node note') if $isCE;
    return $nN.$query->checkbox( -name=>'cc'.$queryid, value=>'1', label=>'CC ',
      title=>'check to send a copy of this message to yourself' )
      . $query->textfield( -name => $queryid, size => 20 , maxlength => 1500 , 	#1530=255*6
      class => 'expandable ajax '."sent$queryid:writeupmessage?$queryid=/&cc$queryid=/&nn$queryid=/:$queryid,$$WRITEUP{node_id}" ,
      title => "send a comment to the $$WRITEUP{type}{title}'s author" ) ;
  };

  #
  # main
  #

  #build result
  my $str = '';

  my $s = undef; #which Sub to call
  my $r = undef; #Result of sub call
  my $align= undef ; #alignment
  my $curRow = '';
  my $anyGoodCells = 0;
  #TODO allow multiple things in a table cell
  foreach my $k (@showThings)
  {
    $fnName = $k;
    $align = $tDataOpen{l}."wu_$fnName\">";
    if($fnName eq '\n')
    {
      #literal characters '\' and 'n', not newline
      if($anyGoodCells)
      {
        $str .= $tRowOpen;
        $str .= ($inHeader?'wu_header"':'wu_footer"').">";
        $str .= $curRow . $tRowClose;
      }
  
      $curRow = '';
      $anyGoodCells = 0;
      next;

    } elsif($fnName =~ /^(.):(.+)$/) {
      #calling a function
      $fnName = $2;
      $align = ($tDataOpen{$1}."wu_$fnName\">") || $align;
    }

    next if(length($fnName)==0 or
      $fnName eq 'kill' and not $isDraft and not $isMine and not $isCE or
      $isDraft and $fnName !~ /^(?:type|author|dtcreate|kill|length|sendmsg|addto|nothing|draftstatus)$/);

    unless( (exists $infofunctions->{$fnName}) && (defined $infofunctions->{$fnName}) )
    {
      $curRow .= $align.'<small>(unknown value: "'.$APP->encodeHTML($fnName).'"; see '.linkNodeTitle('Settings').')</small>'.$tDataClose unless $s;
      next;
    }

    $s = $infofunctions->{$fnName};
    if( (ref $s) eq 'CODE' )
    {
      #compute result
      #$query->param('debug'.$wuID.$fnName.($inHeader?'head':'foot').int(rand(99)), 'uncached');
      $r = &$s();
      $r = '' if !defined $r;
      if( (defined $infofunctions->{$fnName}) && (ref $infofunctions->{$fnName}) eq 'CODE' )
      {
        if( !exists $infofunctions->{'!'.$fnName})
        {
          #2007-12-05 for kthejoker
          #the function is letting us handle caching
          $infofunctions->{$fnName} = $r;
        }
      }
    } else {
      #$query->param('debug'.$wuID.$fnName.($inHeader?'head':'foot').int(rand(99)), 'cached');
      #use cached result
      $r = $s;
    }

    $curRow .= $align . $r . $tDataClose."\n";
    if ($r)
    {
      $anyGoodCells = 1;
    }
  }

  if ($anyGoodCells)
   {
    $str .= $tRowOpen . ($inHeader?'wu_header"':'wu_footer"').">". $curRow . $tRowClose;
  }

  $str .= $msgreport ;

  unless ($inHeader)
  {
    #not showing anything about this writeup anymore, so delete cache
    delete $PAGELOAD->{$CACHE_NAME};
  }

  return $str;

}

sub displayUserText
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $txt = $NODE->{doctext};
  my $APRTAGS = getNode('approved html tags', 'setting');
  $txt = $APP->breakTags($APP->htmlScreen($txt, getVars($APRTAGS)));
  $txt = parseLinks($txt) unless($query->param("links_noparse"));
  return $txt;
}

sub customtextarea
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  #This takes one of two inputs.
  #If it takes a zero or is blank, then the style is going to be in "#rows,#cols" 
  # format for the HTMLcode formatting
  #If it takes a one, it will be in 'rows="#" cols="#"' format

  my ($dispopt) = @_;
  $dispopt ||= 0;

  my $rowval = 20;
  my $colval = 60;

  if($VARS->{textareaSize})
  {
    if($$VARS{textareaSize} == 1)
    {
      $rowval = 30;
      $colval = 80;
    }elsif($$VARS{textareaSize} == 2)
    {
      $rowval = 50;
      $colval = 95
    }
  }

  if (wantarray)
  {
    return (-rows => $rowval, -cols => $colval);
  } else {
    return 'rows="'.$rowval.'" cols="'.$colval.'" ' if($dispopt == 1);
    return "$rowval,$colval"; #if($dispopt == 0);
  }

}

sub rtnsection_cwu
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # ReadThis - C! writeups
  my $str = "<ul class='linklist'>\n";
  my $csr = $DB->sqlSelectMany("distinct coolwriteups_id", "coolwriteups", "", "order by tstamp desc limit 15");

  map {
    my $wu = getNodeById $$_{coolwriteups_id};
    my $parent = getNodeById $$wu{parent_e2node};
    my $author = getNodeById $$wu{author_user};
    $author = $$author{title} if $author ;
    $str .= '<li>'.linkNode($parent, '', {'#' => $author, lastnode_id => 0})."</li>\n";
  } @{$csr -> fetchall_arrayref({})};

  $csr->finish();

  return "$str</ul>\n";
}

sub rtnsection_nws
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if ( $APP->isGuest($USER) );
  my $str = '<ul class="linklist">';
  my $csr = $DB->sqlSelectMany('*', 'weblog, node', 'weblog_id=165580 && removedby_user=0 and to_node = node_id', 'ORDER BY linkedtime DESC LIMIT 4');
 
  while(my $row = $csr->fetchrow_hashref()){
    my $newsitem = getNodeById($$row{node_id});
    next unless($newsitem);
    $str .= '<li>'.linkNode($newsitem, $$newsitem{title}, {lastnode_id=>0}).'</li>';
  }

  $str .= '</ul>';

  $csr->finish();
  return $str;
}

sub rtnsection_edc
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # ed Cools - See [ReadThis]

  my $str = '<ul class="linklist">';
  my $poclink = getId(getNode('coollink', 'linktype'));
  my $pocgrp = getNode('coolnodes', 'nodegroup')->{group};
  my $count = 0;

  foreach(reverse @$pocgrp)
  {
    last if($count >= 5);
    $count++;

    next unless($_);

    my $csr = $DB->{dbh}->prepare('SELECT * FROM links WHERE from_node=? AND linktype=? LIMIT 1');
    $csr->execute(getId($_), $poclink);

    my $coolref = $csr->fetchrow_hashref;

    next unless($coolref);
    $coolref = getNodeById($$coolref{from_node});
    next unless($coolref);
    $str .= '<li>'.linkNode($coolref,$$coolref{title}, {lastnode_id => 0}).'</li>';

    $csr->finish();
  }

  $str.='</ul>';
  return $str;
}

sub nodenote
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);
  return if($$VARS{hidenodenotes});

  my $N = my $onlyMe = shift;
  getRef $N if $N;
  $N ||= $NODE;

  my $notelist = undef;

  if ($$N{type}{title} eq 'writeup' && !$onlyMe)
  { 
    #include e2node & other wus
    $notelist = $DB->sqlSelectMany(
      'nodenote.notetext, nodenote.nodenote_id, nodenote.nodenote_nodeid, nodenote.noter_user, nodenote.timestamp'
      , 'nodenote'
      , "nodenote_nodeid = $$N{node_id}"
      . " OR nodenote_nodeid = $$N{parent_e2node}"
      . " ORDER BY nodenote_nodeid, timestamp");
  } elsif ($$N{type}{title} eq 'e2node') { 
    # include writeups
    $notelist = $DB->sqlSelectMany(
      'nodenote.notetext, nodenote.nodenote_id, nodenote.nodenote_nodeid, nodenote.noter_user, nodenote.timestamp, node.author_user'
      , 'nodenote'
      . " LEFT OUTER JOIN writeup ON writeup.writeup_id = nodenote_nodeid"
      . " LEFT OUTER JOIN node ON node.node_id = writeup.writeup_id"
      , "nodenote_nodeid = $$N{node_id}"
      . " OR writeup.parent_e2node = $$N{node_id}"
      . " ORDER BY nodenote_nodeid, timestamp");
  } else {
    $notelist = $DB->sqlSelectMany(
      'nodenote.notetext, nodenote.nodenote_id, nodenote.nodenote_nodeid, nodenote.noter_user, nodenote.timestamp'
      , 'nodenote'
      , "nodenote_nodeid = $$N{node_id}"
      . " ORDER BY timestamp");
  }

  my $makeNoteLine = sub {
    my $notetext = shift;
    my $delbox = $$notetext{noter_user} ? $onlyMe ? ' * '
      : qq'<input type="checkbox" name="deletenote_$$notetext{nodenote_id}", value="1">'
      : ' &bull; '; # if no user it's a system note
    return "<p>$delbox"
      . htmlcode('parsetimestamp', $$notetext{timestamp}, 129 - !$$notetext{noter_user})
      . ' ' . parseLinks($$notetext{notetext})
      . '</p>';
  };

  my $noteCount = 0;
  my $finalstr = "";
  my $notetext = undef;
  $notetext = $notelist->fetchrow_hashref if $notelist;

  while ($notetext)
  {
    my $currentNodeId = $$notetext{nodenote_nodeid};
    my $currentAuthor = $$notetext{author_user};

    $finalstr .= '<hr>' if $noteCount != 0;

    if ($currentNodeId != $$N{node_id} && !$onlyMe)
    {
      $finalstr .= '<b>'.linkNode($currentNodeId).'</b>';
      $finalstr .= ' by '.linkNode($currentAuthor) if $$N{type}{title} eq 'e2node';
    }

    while ($notetext && $$notetext{nodenote_nodeid} == $currentNodeId)
    {
      $finalstr .= &$makeNoteLine($notetext);
      $noteCount++;
      $notetext = $notelist->fetchrow_hashref;
    }
  }

  return $finalstr ? $query -> div({style => 'white-space:normal'}, $finalstr) : '' if $onlyMe;
  my $form = qq'<p align="right">
    <input type="hidden" name="ajaxTrigger" value="1" class="ajax nodenotes:nodenote">
    <input type="hidden" name="notefor" value="$$N{node_id}">
    <input type="hidden" name="op" value="nodenote">
    <input type="text" name="notetext" maxlength="255" size="22" class="expandable"><br>
    <input type="submit" value="(un)note">
    </p>';
			
  return '<div class="nodelet_section" id="nodenotes">
    <h4 class="ns_title">Node Notes <em>('.$noteCount.')</em></h4>'.htmlcode('openform')."\n\t\t".$finalstr."\n\t\t".$form.'
    </form></div>';
}

sub admin_toolset
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isAdmin($USER);

  my $currentDisplay = $query->param("displaytype") || "display";
  my $nt = $$NODE{type}{title};

  my $newStr = $query -> h4({class => 'ns_title'}, 'Node Toolset');

  if ($query -> param('showcloner')){
    $newStr .= $query -> start_form(action => $APP->urlGenNoParams(
      getNode('node cloner', 'restricted_superdoc'), 'noquotes'))
      .$query -> fieldset($query -> legend('Clone node')
      .$query -> hidden('srcnode_id', $$NODE{node_id})
      .$query -> label('New title:' .$query -> textfield(-name => 'newname'
      , -title => 'name for cloned node'))
      .$query -> submit('ajaxTrigger', 'clone') # don't ajaxify this form...
      ).$query -> end_form .'<ul>';
  }else{
    $newStr .= '<ul>'
      .$query -> li(linkNode($NODE, 'Clone Node...', {
      showcloner => 1
      , -class => 'ajax mcadmintools:admin+toolset' }));
  }

  $newStr .= $query -> li(linkNode($NODE,"Display Node"))	if ($currentDisplay ne 'display');

  if ($currentDisplay ne 'edit' && $currentDisplay ne 'viewcode')
  {
    if ($nt eq'nodelet' || $nt =~ 'superdoc')
    {
      $newStr .= $query -> li(linkNode($NODE,"Edit Code",{displaytype => "viewcode"}));
    } else {
      $newStr .= $query -> li(linkNode($NODE,"Edit Node",{displaytype => "edit"}));
    }
  }

  if ($currentDisplay ne 'help')
  {
    if ($DB->sqlSelectHashref("*", "nodehelp", "nodehelp_id=$$NODE{node_id}"))
    {
      $newStr .= $query -> li(linkNode($NODE,"Node Documentation",{displaytype => "help"}));
    } else {
      $newStr .= $query -> li(linkNode($NODE,"Document Node?",{displaytype => "help"}));
    }
  }

  my $spacer = "<li style='list-style: none'><br></li>";
  my $direWarning = ""; $direWarning = ' (<strong>writeup:</strong> only nuke under exceptional circumstances.
    Removal is almost certainly a better idea.)' if $nt eq 'writeup';

  $newStr .= $spacer.$query -> li(
    $query -> a({ href => "/?confirmop=nuke&node_id=$$NODE{node_id}", class => 'action'
    , title => 'nuke this node' }, 'Delete Node'))
    .$direWarning
    .$spacer if canDeleteNode($USER, $NODE) and $nt ne 'draft' and $nt ne 'user';

  if ($nt eq 'user')
  {
    my $verify = htmlcode('verifyRequestHash', 'polehash');

    $newStr .= $spacer
      .$query -> li(linkNode(getNode('The Old Hooked Pole', 'restricted_superdoc')
      , 'Detonate noder'
      , {%$verify
      , detonate => 1
      , notanop => 'usernames'
      , confirmop => $$NODE{title}
      , -title => 'delete user account if safe, otherwise lock it'
      , -class => 'action'}))
      .$query -> li(linkNode(getNode('The Old Hooked Pole', 'restricted_superdoc')
      , 'Smite Spammer'
      , {%$verify
      , smite => 1
      , notanop => 'usernames'
      , confirmop => $$NODE{title}
      , removereason => 'smiting spammer'
      , -title => 'detonate this noder, blank their homenode, blacklist their IP where appropriate'
      , -class => 'action'}))
      .$spacer
      .$query -> li(linkNode($NODE, 'bless', { op=>'bless', bless_id=>$$NODE{node_id}}))
      .$query -> li(linkNode($NODE, 'bestow 25 votes', { op=>'bestow', bestow_id=>$$NODE{node_id} }))
      .$query -> li(linkNode(getNode('bestow cools', 'restricted_superdoc'), 'bestow cools', {'myuser' => $$NODE{title}}))
      .$query -> li(linkNode(getNode('Node Forbiddance','restricted_superdoc'), 'forbid', { forbid => $$NODE{node_id}}));

    if ($$NODE{acctlock})
    {
      $newStr .=$query -> li(linkNode($NODE, 'Unlock Account', { op=>'unlockaccount', lock_id=>$NODE->{node_id} }));
    } else {
      $newStr .= $query -> li(linkNode($NODE, 'Lock Account', {op=>'lockaccount', lock_id=>$NODE->{node_id}}));
    }
  } elsif($nt eq 'writeup' && $$VARS{nokillpopup}) {
    # mauler and riverrun don't get a writeup admin widget:
    $newStr .= $query -> li(linkNode(getNode('Magical Writeup Reparenter', 'superdoc')
      , 'Reparent&hellip;'
      , {old_writeup_id => $NODE->{node_id}}))
      .$query -> li(linkNode(getNode('Renunciation Chainsaw', 'oppressor_superdoc')
      , 'Change author&hellip;'
      , {wu_id => $NODE->{node_id}}));
  }

  $newStr .= '</ul>';

  return $query -> div({id => 'mcadmintools', class => 'nodelet_section'}, $newStr);
}

sub nwuamount
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '' if ( $APP->isGuest($USER) );
  my ($nodelet,$noAdminNoJunkOption) = @_ ;
  $nodelet ||= 'New Writeups';
  $nodelet =~ s/\s/+/g;
  my $nodeletId = lc($nodelet) ;
  $nodeletId =~ s/\W// ;
  my $ajax = "ajax $nodeletId:updateNodelet?op=/&nw_nojunk=/&amount=/:$nodelet" ;

  my @amount = (1, 5, 10, 15, 20, 25, 30, 40);
  $$VARS{num_newwus} ||= 15 ;

  my $str = htmlcode('openform');

  $str.="\n\t<input type='hidden' name='op' value='changewucount'>";
  $str .= $query -> popup_menu( -name=>'amount', Values=>\@amount, default=>$$VARS{num_newwus}, class=> $ajax ) ;
  $str.="\n\t".$query->submit("lifeisgood","show");
  $str.="\n\t".$query->checkbox(-name=>"nw_nojunk", checked=>$$VARS{nw_nojunk}, value=>'1', label=>"No junk", class=>$ajax) if(not $noAdminNoJunkOption and $APP->isEditor($USER));
  $str.="\n".$query->end_form;
  return $str;
}

# sends a private message
#
# usage, examples, etc. in this node's "help" view:
#  ?node=sendPrivateMessage&type=htmlcode&displaytype=help
#
# TODO error condition for certain alias (me, I, anything else?) (maybe just hardcode in here, if a few)
# TODO if target is bot (use bot setting), see if they have a special htmlcode (probably best to run after did everything else)
#
# big big big big TODO: put this info into help displaytype ALSO 
# massive like OMG semi-trailer-truck-sized TODO: recode website; take tea when done
# big TODO:
#	How do we want to handle don't-send-to-self and auto-archive-when-sending-to-self ?
#	I've had 2 false starts that are specific to single-target, pseudo-group, and usergroup, but are pretty clumsy
#	I'm now thinking maybe doing something like msg-ignore: user can specify groups to do certain things to.
#
# thought #2: instead of making another table, since this is all user-based, we can just throw things into VARS
#	maybe: 'automsgsend_###' where ### is node_id of recipient (group or usergroup)
#	if multiple cases match, do one that keeps the most
#	bits:
#		0    1      if NOT set, ignore everything else, and use default settings
#		1-2  2,4,6  0=default, 2=always CC self, 4=never get self, 6=reserved
#		4    8      set archived flag, if happens to get message
#
# another thought: maybe change 'archive' field into 'folder' field; needs more thought: who create? who view? etc.
#
sub sendPrivateMessage
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  #
  #parameters setup, part 1 of 2
  #

  my $params = shift;
  my $showWhatSaid = $params->{show_said};

  #
  #constants and global vars setup, part 1 of 2
  #

  my $UID = $USER->{node_id} || 0;

  return '' if $APP->isGuest($USER);
  return '' if $USER->{title} eq 'everyone';
  return 'Nothing to send: no message was given.' unless $params->{message};
  my $msg = $APP->messageCleanWhitespace($params->{message});
  return 'Nothing to send: message only consists of "whitespace" characters (for example, a space).' unless length($msg);

  my $cachedTitles = undef;
  my $cachedIDs = undef;

  #failure warning messages
  #these are always sent to the current user (which is not neccessarily the author we say the message is from)
  my @problems = ();
  #
  # subroutines
  #

  # returns if a parameter is set to 1 or not
  # if the given parameter exists and equals '1', then true is returned
  # any other condition will return false

  local *boolParam = sub {
    return (defined $_[0]) && (exists $params->{$_[0]}) && (defined $params->{$_[0]}) && ($params->{$_[0]} eq '1');
  };

  # gets a user or usergroup
  # pass ($title) to get based on title (respecting message deliver forwards)
  # pass ($id, 1) to get based on node ID
  # passed username should NOT be escaped
  ## this tries really hard to deal with names with spaces and/or underscores, and should get them, no matter how they are set up
  #note: do NOT optimize this to use the light-get, since then usergroups wouldn't have their group members loaded (this may be no longer true - does the UG auto code deal with this properly?)
  # updated: 2002.11.10.n0

  local *getCached = sub {
    my ($ident,$isNumeric) = (@_[0,1]);

    $isNumeric ||= 0;
    return unless defined($ident) && length($ident);

    my $N = undef;

    #get by ID
    if($isNumeric)
    {
      return unless $ident =~ /^(\d+)$/;
      $ident=$1;
      return $cachedIDs->{$ident} if exists $cachedIDs->{$ident};
      $N=getNodeById($ident);
      if(!$APP->isUserOrUsergroup($N))
      {
        undef $N;
      }

      if($N->{message_forward_to})
      {
        $N = getNodeById($N->{message_forward_to});
      }

      if((defined $N) && (exists $N->{title}) && length($N->{title}))
      {
        $cachedTitles->{$N->{title}} = $N;
      }

      $cachedIDs->{$ident} = $N;

      #get by title
    } else {
      if(exists($cachedTitles->{$ident}))
      {
        return $cachedTitles->{$ident} if exists $cachedTitles->{$ident};
      }
      # given title isn't cached, so find it
      # a forward address takes precedence over a real user

      my $forwarded = $ident;
      $N = getNode($forwarded,"usergroup") || getNode($forwarded,"user") || undef;
      unless($N)
      {
           $forwarded =~ s/_/ /g;
           $N = getNode($forwarded,"usergroup") || getNode($forwarded,"user") || undef;
      }

      unless($N)
      {
         # sendPrivateMessage getCached couldn't find object for forwarded, bailing
         return;
      }

      if($N->{message_forward_to})
      {
        $forwarded = $N->{title};
        $N = getNodeById($N->{message_forward_to});
      }

      # on 2002.11.09.n5, removed space-and-underscore-in-name code; see displaytype=help for more information
      # found (or didn't find), so cache title and possibly forward
      # note: $N may be invalid, but we're still caching the miss-hit, so we don't try getting it again

      $cachedIDs->{$N->{node_id}} = $N if defined $N;
      $cachedTitles->{$ident} = $N;
      $cachedTitles->{$forwarded} = $N;
    }

    return $N;
  };

  # returns a list ref of items in a given parameter
  # if a given parameter (in $param) is invalid, an empty list ref is returned
  # otherwise, a list ref of all items is returned

  local *getParamList = sub {
    my $p=$_[0];
    my @l = ();
    if( (defined $p) && (exists $params->{$p}) && (defined $params->{$p}) )
    {
      $p=$params->{$p};
      my $r=ref $p;
      if($r eq '')
      {
        @l = ($p);
      } elsif($r eq 'SCALAR') {
        @l = ($$p);
      } elsif($r eq 'ARRAY') {
        return $p;
      } elsif($r eq 'HASH') {
        @l = keys(%$p);
      }
    }
    return \@l;
  };


  #
  # main function
  #

  # determine author
  # note: in most cases, we'll just skip to the last 'unless' to use current user

  my $aid = $params->{author_id};
  if((defined $aid) && length($aid) && $aid && ($aid =~ /^(\d+)$/))
  {
    $aid = getNodeById($1,'light') || undef;	#note that this allows any node to /msg user
    $aid = (defined $aid) ? $aid->{node_id} : undef;
  } else {
    undef $aid;
  }

  unless(defined $aid)
  {
    #don't know author ID, so try to get author name
    $aid = $params->{author};
    if((defined $aid) && length($aid))
    {
      $aid = getCached($aid) || undef;
      $aid = (defined $aid) ? $aid->{node_id} : undef;
    }
  }

  unless(defined $aid)
  {
    #don't know author's title, either, so just use current user
    $aid = $UID;
  }


  # determine node message is about
  # note: if message table is expanded to include something like 'about_node', this section can be mostly removed

  my $aboutNode = $params->{renode_id};
  if((defined $aboutNode) && length($aboutNode) && $aboutNode && ($aboutNode=~/^(\d+)$/))
  {
    $aboutNode = getNodeById($1,'light') || undef;
    if(defined $aboutNode)
    {
      $aboutNode = length($aboutNode->{title}) ? $aboutNode->{title} : 'id://'.$aboutNode->{node_id};
    }
  } else {
    undef $aboutNode;
  }

  unless(defined $aboutNode)
  {
    $aboutNode=$params->{renode};
    if((defined $aboutNode) && length($aboutNode) && ($aboutNode=~/^(.+)$/))
    {
      $aboutNode=length($1) ? $1 : undef;
    } else {
      undef $aboutNode;
    }
  }

  # determine time to say message was sent
  my $sendTime = $params->{renode_id};
  if((defined $sendTime) && ($sendTime =~ /^(\d{14,})$/))
  {
    #Y10K compliant
    $sendTime = $1;
  } else {
    undef $sendTime;
  }

  # determine which usergroup to say message was from
  my $fromGroup = $params->{fromgroup_id};
  if( (defined $fromGroup) && length($fromGroup) && $fromGroup && ($fromGroup=~/^(\d+)$/) )
  {
    $fromGroup = getNodeById($1,'light') || undef;
    if(defined $fromGroup)
    {
      $fromGroup = $fromGroup->{node_id};
    }
  } else {
    $fromGroup = 0;
  }

  unless($fromGroup)
  {
    if((defined $fromGroup) && length($fromGroup) && ($fromGroup=~/^(.+)$/))
    {
      if(length($1))
      {
        $fromGroup=getCached($1);
        $fromGroup = (defined $fromGroup) ? $fromGroup->{node_id} : 0;
      } else {
        $fromGroup=0;
      }
    } else {
      $fromGroup=0;
    }
  }

  #
  # determine recipient(s)
  #

  # determine who is online

  my %onlines = ();
  my $onlineOnly = boolParam('ono');

  if($onlineOnly)
  {
    # ripped from message (opcode)
    my $csr = $DB->sqlSelectMany('member_user', 'room', '', '');
    while(my ($ol) = $csr->fetchrow)
    {
      $onlines{$ol}=1;
    }
    $csr->finish;
  }

  #determine which groups get a copy sent to themselves
  my $ccGroups = boolParam('ccgroup');

  my $countUserAll = 0;	#count of users we tried to /msg, including those ignoring us
  my $countUserGot = 0;	#count of users that got our message
  my $countGroupGot = 0;	#count of groups that got our message
  
  # users who blocked us; key is user ID, value is 0 if blocked, 1 if possibly blocked (happens ignoring the usergroup, but could still get msg via another usergroup)
  #  after trying to send to everybody, anything with value of 1 is added to $countUserAll
  my %blockers = ();

  my %groups = ();	#groups that get a message; key is group ID, value is -1 if user isn't allowed to send there, 0 if usergroup doesn't get message (but people in it do), higher than 0 means the usergroup also gets the message
  my %users = ();	#users that get a message; key is user ID, value is group they're in (or 0 for none) (or -1 to not send to them)

  # %users is a hash so if multiple usergroups are messaged, the user will get a group message for a group they're in, instead of potentially a group they aren't in


  # returns a value in $VARS->{_argument_}, constrained to the given values
  # parameters are all required:
  #	value to get value of in VARS
  #	default value to return, if value is not in VARS hash, or value is not one of the given values
  #	list or list ref of valid values
  # returns if all arguments aren't supplied
  # created: 2002.06.15.n6
  # updated: 2002.06.15.n6

  # TODO move into npbutil, after it is cleaned a bit
  # TODO bool version also for npbutil

  local *getVarsValue = sub {
    my ($varsKey, $defaultVal, @allowedValues) = @_;
    return unless (defined $varsKey) && length($varsKey);

    # possibly change list ref into list
    if( (scalar(@allowedValues)==1) && ((ref $allowedValues[0]) eq 'ARRAY') )
    {
      @allowedValues = @{$allowedValues[0]};
    }

    # determine what to return
    return $defaultVal unless exists $VARS->{$varsKey};
    my $val = $VARS->{$varsKey};
    foreach(@allowedValues)
    {
      return $val if $_ eq $val;
    }

    return $defaultVal;

  };


  #
  # flag recipients
  #


  # adds a user to the list to get the message (or not get message)
  # pass user object and optionally group ID (if no group is passed, defaults to no group)
  # included in things this functions does:
  #  all checks for where a user would not get a message: online-only, ignoring user, ignoring group
  #  finding (and possibly increasing) the msg group level
  # updated: 2002.11.09.n6

  local *addUser = sub {
    my ($userObj, $groupID) = @_[0,1];
    return unless defined $userObj;
    $groupID = (defined $groupID) ? $groupID : 0;
    my $uid = $userObj->{node_id};

    if(exists $users{$uid})
    {
      # user is already getting message
      return if $users{$uid}==-1;	#user doesn't want message

      # if this is a group message, see if user knows it is from a group
      if($groupID && ($users{$uid}==0))
      {
        # user doesn't know this is from a group, so say it is
        $users{$uid}=$groupID;
      }
      # note: should always be true, but just in case
    } else {
      #user isn't set to get/not get a message

      # check for ignoring author
      if( $APP->userIgnoresMessagesFrom($uid, $aid) )
      {
        $users{$uid}=-1;
        $blockers{$uid}=0;
        ++$countUserAll;
        return;
      }

      # check for online only
      # this check should be before ignore-usergroup test; otherwise, the blocked-user message incorrectly includes people who are just ignoring OnO messages
      if($onlineOnly && !exists $onlines{$uid})
      {
        # message is online-only and the recipient isn't online
        # see if they want the message anyway
        # TODO? cache this?

        my $v = getVars($userObj);
        unless( $v->{getofflinemsgs} )
        {
          # user doesn't want ONO messages, and this msg was ONO, so block them from getting the message (to prevent having to look up their VARS again)
          $users{$uid}=-1;
          return;
        }
      }

      # check for ignoring usergroup
      #  The proper thing to do isn't clear when the recipient user is in
      #  several of the usergroups this message is going to, and the
      #  recipient is ignoring some groups, but not others. We could either
      #  block the message if ANY of the usergroups are ignored, or block if
      #  ALL of the usergroups are ignored. The latter case is done here;
      #  this means there is a lower chance you'll miss a message you meant
      #  to get, although there is a higher chance you'll get a message you
      #  did not want.

      if($groupID)
      {
        $blockers{$uid}=$groupID;	#non-zero means may still get message
        # don't mark as send-message, but also don't mark as do-not-send-at-all
        return if( $APP->userIgnoresMessagesFrom($uid, $groupID) );
        # note: countUsersAll is not adjusted here, so it doesn't count the same recipient twice; it is added later ("deal with people who blocked")
      }

      # passed all checks, so allow message to be sent to user
      delete $blockers{$uid};	#if blocked from 1 usergroup, but got anyway, forget that we tried to block
      ++$countUserAll;
      ++$countUserGot;
      $users{$uid}=$groupID;
    }
  };

  # adds a user or usergroup to get a message (or not get the message)
  # pass user or usergroup object
  # updated: 2004.12.12.n0 (Sunday, December 12, 2004)

  local *addRecipient = sub {
    my $u = $_[0];
    return unless defined $u;
    my $i=$u->{node_id};

    if( $APP->isUsergroup($u) )
    {
      if(exists $groups{$i})
      {
        # already did this group, don't bother with again
        next;
      }
         
      unless($APP->inUsergroup($USER, $u) )
      { 
        push @problems, 'You are not allowed to message the ['.$u->{title}.'] usergroup.';
        $groups{$i}=-1;
        return;
      }

      # all checks pass, so send /msg to group and members
      ++$countGroupGot;

      # see if usergroup itself gets a copy
      if($ccGroups)
      {
        # htmlcode caller forced groups to get
        $groups{$i} = $i;
      } else {
        $groups{$i} = ($APP->getParameter($i, 'allow_message_archive') ) ? $i : 0;	#see if group gets a copy
      }

      # loop though all users
      foreach( @{$DB->selectNodegroupFlat($u)} )
      {
        addUser($_, $i);
      }

    } else {
      addUser($u);

    }
  };

  # invalid node titles, aliases, and node IDs
  #  key is invalid item
  #  value is always 1

  my %invalidIDs = ();
  my %invalidNames = ();

  # for each recipient, either:
  #  add to send list
  #  reject for some reason (examples: permission denied, online-only)
  #  add to invalid item list

  # this is the only place where recipients are added to the list to be messaged
  my $n = undef;
  foreach( @{getParamList('recipient_id')} )
  {
    $n = getCached($_,1);
    if(defined $n)
    {
      addRecipient($n);
    } else {
      $invalidIDs{$_}=1;
    }
  }

  foreach( @{getParamList('recipient')} )
  {
    $n = getCached($_);
    if(defined $n)
    {
      addRecipient($n);
    } else {
      $n = $_;
      $n =~ tr/ /_/;
      $invalidNames{$n}=1;
    }
  }

  # deal with people who blocked
  my @whoBlocked = ();	#users who blocked sender, and not because blocking the group (listing all the group blockers could get large fast)
  my $numBlocked = scalar(keys(%blockers));
  my $numBlockedGroup = 0;	#number of messages blocked because blocking usergroup
  foreach(keys(%blockers))
  {
    if($blockers{$_}==0)
    {
      # blocking sender
      push(@whoBlocked, getCached($_,1));
    } else {
      # blocking usergroup(s)
      ++$countUserAll; #not done in addUser, so do it now
      ++$numBlockedGroup;
    }
  }
  my $blockedInfoMethod = getVarsValue('informmsgignore', 0, 0,1,2,3);	#0=inform via msg, 1=inform in 'you said "blah"' area in chatterbox, 2=inform both ways, 3=don't inform

  if($numBlocked && ($blockedInfoMethod==0 || $blockedInfoMethod==2))
  {
    # inform via a msg
    my $bMessage = 'You were blocked by '.$numBlocked.' user'.($numBlocked==1?'':'s').' total';
    my @bReason = ();
    push(@bReason, $numBlockedGroup.' ignored the usergroup(s)') if $numBlockedGroup;
    push(@bReason, scalar(@whoBlocked).' ('.join(', ', map { '[' . $_->{title} . ']' } @whoBlocked).') ignored you') if scalar(@whoBlocked);
    $bMessage .= ': '.join(', ', @bReason) if scalar(@bReason);	#note: should always be true, but just in case
    $bMessage .= '.';
    push(@problems, $bMessage);
  }

  # when sending a message and we aren't a recipient, but we get it anyway, pick one of the normal recipients to be the for_usergroup
  #  if the message was sent to any usergroups, pick one of those
  #  otherwise, pick a random user
  #  in either case, this will return the node_id of the choosen node for for_usergroup
  # created: 2002.07.28.n0
  # updated: 2002.12.02.n1

  local *pickRandomForGroup = sub {
    #first try a random group
    foreach(keys(%groups))
    {
      if($_ >= 0) { return $_; }	#if -1, then that group didn't get the message
    }

    #not sending to any groups, so pick a random user besides the sending user
    foreach(keys(%users))
    {
      return $_ unless $_==$UID;	#yourself as a group is rather annoying
    }

    return 0; # note: should always be true, but just in case
  };


  # special case sender getting msg
  if(boolParam('ccself'))
  {
    # set the for-group as just a random recipient of the message
    # this is far from perfect, but there isn't a way to store all recipients, so this will have to do
    # done here, and not relied upon at the actual msg-send part so we try to not get ourselves as the for-group we're sending to

    # if sending to at least 1 group, try to make that the from group

    # since we aren't sending to any groups, pick a random person
    unless(exists $users{$UID})
    {
      $users{$UID} = pickRandomForGroup() || $UID;	#extra OR is for very rare case so user still gets CC-to-self message when nobody gets message (such as everybody is blocking sender)
    }
  }

  # add things to message
  if($onlineOnly)
  {
    # say ONO even for CCed to self message as a reminder of how it was sent
    $msg = 'OnO: ' . $msg;
  }

  if(defined $aboutNode)
  {
    # maybe FIXME: add another field to message table, although this wouldn't be used much (just for WU title area)
    $msg = 're ['.$aboutNode.']: '.$msg;
  }

  # construct invalid recipients message
  my $s = '';
  my @badIDs = sort { ($a<=>$b) || ($a cmp $b) } keys(%invalidIDs);
  if($n=scalar(@badIDs))
  {
    $s = 'Node ID' . ($n==1
      ? ' ' . $badIDs[0] . ' is not a valid user or usergroup ID.'
      : 's ' . join(', ', @badIDs) . ' are not valid user or usergroup IDs.');
  }

  my @badNames = sort { $a cmp $b } keys(%invalidNames);
  if($n=scalar(@badNames))
  {
    $s .= ' ' if length($s);
    if($n==1)
    {
      $s .= $APP->encodeHTML($badNames[0]) . ' is not a valid user or usergroup name or alias.';
    } else {
      $s .= $APP->encodeHTML(join(@badNames)) . ' are not valid user or usergroup names or aliases.';
    }
  }

  if(length($s))
  {
    push(@problems, $s . ' You tried to say: \\n ' . $APP->encodeHTML($msg));	#slash, then 'n', not newline
  }


  #
  # finally send the message
  #

  my @getters = ();	#groups and users that got message

  # send to groups archive
  foreach my $i (keys(%groups))
  {
    next if $groups{$i}<0;	#negative indicates user isn't allowed to send to group

    push(@getters, $i);	#count as 1 for group
    next if $groups{$i}==0;

    $DB->sqlInsert('message',{'msgtext' => $msg,'author_user' => $aid,(defined($sendTime)?('tstamp' => $sendTime):()),
      'for_user' => $i,
      'for_usergroup' => $i,	#don't bother with ($i || $fromGroup) since $i is never going to be 0
    });
  }

  # send to users
  my $forUG = undef;
  my $isArchived = undef;
  foreach my $i (keys(%users))
  {
    next if $users{$i}<0;
    $forUG=$users{$i};
    if($i==$UID)
    {
      # the for-group is really just a random recipient of the message
      # this is far from perfect, but there isn't a way to store all recipients, so this will have to do
      # if the msg was forced-gotten, then this was already done; but this is for the normal case

      $forUG ||= pickRandomForGroup();
    }
    $isArchived=0;
    $forUG ||= $fromGroup;

    push(@getters, $i) if $users{$i}==0; # only list people that aren't in a UG (otherwise, UG recipient list would be quite large)

    $DB->sqlInsert('message',{
      'msgtext' => $msg,
      'author_user' => $aid,
      (defined($sendTime)?('tstamp' => $sendTime):()),
      'for_usergroup' => ((defined $forUG)?($forUG):(0)),
      'for_user' => $i,
      'archive' => $isArchived,
    });

    # message_id is auto
    # room is 0
  }

  # inform user of any problems
  #  since these are sent back to the sending user, increase the maximum message length

  if(scalar(@problems))
  {
    my $rootUser = getNode('root','user','light') || undef;
    $rootUser = (defined $rootUser) ? ($rootUser->{node_id} || 0) : 0;
    foreach my $prob (@problems)
    {
      $DB->sqlInsert('message',{
        'msgtext' => $prob,
        'author_user' => $rootUser,
        'for_user' => $UID,	#the actual user gets the error(s), not the author we say is sending the message
      });
    }
  }

  # link to groups and users that were messaged
  # parameters: node_id of user, optional alternate text to display

  local *linkU = sub {
    my $id = $_[0];
    my $altDisp = $_[1] || undef;
    return '<em title="sendPrivateMessage (htmlcode)">!!! nobody !!!</em>' unless $id;
    return linkNode($id, ((defined $altDisp) ? $altDisp : getCached($id,1)->{title}));
  };


  #
  # sent /msg information
  #

  # if multiple messages sent at same time (such as through the WU header area), find the query param to use
  my $qpm = 'sentmessage';
  if( defined $query->param($qpm) )
  {
    my $i=0;
    while(defined $query->param($qpm.$i) )
    {
      ++$i;
    }
    $qpm=$qpm.$i;
  }

  # UIDs for Virgil, CME, Klaproth, and root.
  my @botlist = qw(1080927 839239 952215 113);
  my %bots = map{$_ => 1} @botlist;

  # escape for sender's display
  # Bots, don't escape HTML for them.
  unless( exists $bots{$aid} )
  {
    $msg = $APP->escapeAngleBrackets($msg);
    $msg = parseLinks($msg,0,1);
  }

  my $m = undef;
  if ( $aid==$UID)
  {
    $m = 'you said "' . $msg . '"';
    unless(scalar(@getters))
    {
      $m .= ' to nobody';
    } else {
      # TODO allow only certain recipients to not be shown

      # TODO loop though list anonrecipient, create hash, foreach loop
      #  checks hash to see if that recipient is anonymous

      # TODO recode entire engine
      my $anonRecipient = boolParam('anonrecipient');
      foreach (@getters)
      {
        $_ = ($anonRecipient) ? linkU($_,'?') : linkU($_);
      }
      $m .= ' to ' . join(', ', @getters);
    }
    $m .= ' (sent ';
    $m .= ' to '.$countUserGot.' noder'.($countUserGot==1?'':'s');
    $m .= ' and '.$countGroupGot
      .' group'.($countGroupGot==1?'':'s') unless $countGroupGot==0;

    if ($numBlocked)
    {
      # note: should always be true, but just in case
      $m .= ' (You were blocked by '.$numBlocked.' user'.($numBlocked==1?'':'s').' total';

      if ( $blockedInfoMethod==1 || $blockedInfoMethod==2 )
      {
        # inform who blocked
        my @bReason = ();

        push(@bReason, $numBlockedGroup.' ignored the usergroup(s)') if $numBlockedGroup;

        if (scalar(@whoBlocked) )
        {
          push(@bReason, scalar(@whoBlocked).' ('.join(', ', 
            map { linkU($_->{node_id}, $_->{title}) } @whoBlocked)
            .') ignored you') ;
        }

        # note: should always be true, but we haven't actually thought it through
        $m .= ': '.join(', ', @bReason) if scalar(@bReason);
      }

      $m .= '.)';
    }
  
    $m .= ')';                    # Dear sweet christ

    # Save a copy of the sent message notice into the sender's outbox (message_outbox table)
    #
    #   It would be useful to have this entry link back to the matching message in the "inbox"
    #   message table. However, what constitutes the matching message is ambiguous in scenarios
    #   where the message is delivered to multiple recipients (such as sent to a group, multiple
    #   users, etc) since an "inbox" table record is created for (and owned by) each recipient
    #   and none are distinctly a master. So for now no link is created.
    #
    $DB->sqlInsert('message_outbox',{
       'msgtext'     => $m,
       'author_user' => $aid,
       (defined($sendTime)?('tstamp' => $sendTime):()),
    });

  } else {
    $m = "You triggered a message from "
      .linkNode($aid)
      ." that reads \"$msg\"";
  }

  $query->param($qpm,$m);	#inform in chatterbox
  return $showWhatSaid ? $m : undef;
}

# Moving straight into the model
# and being exported quickly through the controller
#
sub formxml
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $ntype = getNodeById($$NODE{type_nodetype});
  return "" unless $ntype;

  my $hcode = "formxml_".$$ntype{title};
  return "<info>No valid specific conversion for this type</info>\n" unless(getNode($hcode,"htmlcode"));
  return htmlcode($hcode);
}

sub formxml_user
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";

  $str.="<doctext>";
  $str.=$APP->encodeHTML(htmlcode("displayUserText")) unless $query->param("no_doctext");
  $str.="</doctext>\n";

  my $vars = getVars($NODE);

  # the DTD needs updating to deal with the added stuff
  # oh, and, this is probably horribly broken. sorry, i don't /do/ perl.

  $str.="<experience>".$$NODE{experience}."</experience>\n";
  $str.="<lasttime>".$$NODE{lasttime}."</lasttime>\n";
  $str.="<level value=\"".$APP->getLevel($NODE)."\">".$$vars{level}."</level>\n";

  $str.="<writeups>";
  if (defined $$vars{numwriteups})
  {
    $str.=$$vars{numwriteups}; 
  }
  $str.="</writeups>";

  $str.="<image>";
  if (defined $$NODE{imgsrc})
  {
    $str.=$$NODE{imgsrc};
  }
  $str.="</image>\n";

  if (defined $$vars{cools})
  {
    $str.="<cools>".$$vars{coolsspent}."</cools>";
  }

  $str.="<lastnoded>\n";

  if (!$$vars{hidelastnoded})
  {
    my $n = $$NODE{title};
    if (!(($n eq 'EDB') || ($n eq 'Klaproth') || ($n eq 'Cool Man Eddie') || ($n eq 'Webster 1913')))
    {
      my $ln = getNodeById($$vars{lastnoded});
      if ($ln)
      {
        $ln = getNodeById($$ln{parent_e2node});
        $str.="<e2link node_id=\"$$ln{node_id}\">".$APP->encodeHTML($$ln{title})."</e2link>\n";
      }
    }
  }

  $str.="</lastnoded>\n";

  $str.="<userstrings>\n";
  $str.="  <mission>".$APP->encodeHTML($$vars{mission})."</mission>\n";
  $str.="  <specialties>".$APP->encodeHTML($$vars{specialties})."</specialties>\n";
  $str.="  <motto>".$APP->encodeHTML($$vars{motto})."</motto>\n";
  $str.="  <employment>".$APP->encodeHTML($$vars{employment})."</employment>\n";
  $str.="</userstrings>\n";

  $str.="<groupmembership>\n";
  my @groups = ();
  my $U = getId($NODE);
  push( @groups, getNode('gods', 'usergroup')) if $APP->isAdmin($U);
  push( @groups, getNode('Content Editors', 'usergroup')) if($APP->isEditor($U,"nogods") and not $APP->isAdmin($U));
  push( @groups, getNode('edev', 'usergroup')) if $APP->isDeveloper($U);

  # There probably aren't too many usergroups with names that need to be encoded, but this will stop the errors before they occur.
  $str.= "<e2link node_id=\"$$_{node_id}\">".$APP->encodeHTML($$_{title})."</e2link>\n" foreach(@groups);

  $str.="</groupmembership>\n";

  $str.="<bookmarks>\n";
  my $linktype = getId(getNode('bookmark', 'linktype'));
  my $csr = $DB->sqlSelectMany('to_node', 'links', "from_node=$$NODE{node_id} and linktype=$linktype");
  while (my $ROW = $csr->fetchrow_hashref())
  { 
    my $bm = getNodeById($$ROW{to_node}, 'light');
    $str.="  <e2link node_id=\"$$bm{node_id}\">".$APP->encodeHTML($$bm{title})."</e2link>\n";
  }

  $str.="</bookmarks>\n";
  return $str;
}

sub xmlheader
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str="";
  $str .= "<node node_id=\"$$NODE{node_id}\" createtime=\"".
    ($$NODE{publishtime}||$$NODE{createtime})
    ."\" type_nodetype=\"$$NODE{type_nodetype}\"".htmlcode("schemalink", "$$NODE{type_nodetype}").">\n";
  my $ntype = getNodeById($$NODE{type_nodetype});
  $str.="<type>".$APP->encodeHTML($$ntype{title})."</type>\n" if $ntype;
  $str.="<title>".$APP->encodeHTML($$NODE{title})."</title>\n";
  my $crby = $$NODE{createdby_user} || $$NODE{author_user} || 0;
  $crby=getNodeById($crby);
  $str.="<author user_id=\"$$crby{node_id}\">".$APP->encodeHTML($$crby{title})."</author>\n";
  return $str;
}

sub xmlfooter
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "</node>";
}

sub formxml_e2node
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $grp = $$NODE{group};
  my $str = "";
  $str.= htmlcode("xmlfirmlinks", "$$NODE{node_id}");
  $str.= htmlcode("xmlwriteup","$_") foreach(@$grp);
  $str.= "<softlinks>\n".htmlcode("softlink", "xml")."</softlinks>\n";
  $str.= "<nodelock>".$APP->encodeHTML(htmlcode('nopublishreason', $USER, $NODE))."</nodelock>";
  $str.= htmlcode("xmlnodesuggest");
  return $str;
}

#
# Seriously get rid of the node row stuff
#
sub xmlwriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($WRITEUPID) = @_;

  my $wu = getNodeById($WRITEUPID);
  return unless $wu;
  return unless($$wu{type_nodetype} == getId(getType('writeup')));

  my $str = "";

  my $nr = getId(getNode("node row", "superdoc"));
  my $marked = (($DB->sqlSelect('linkedby_user', 'weblog', "weblog_id=$nr and to_node=$$wu{node_id}"))?(1):(0));

  $str .= "<writeup node_id=\"$$wu{node_id}\" createtime=\"$$wu{publishtime}\" ";
  $str .= "type_nodetype=\"$$wu{type_nodetype}\" marked=\"$marked\">\n";
  my $ntype = getNodeById($$wu{wrtype_writeuptype});

  my $parent = getNodeById($$wu{parent_e2node});
  # see [Drum & Bass] (using displaytype=xmltrue) 
  # to see the problem
  $str.="<parent><e2link node_id=\"$$parent{node_id}\">".$APP->encodeHTML($$parent{title})."</e2link></parent>" if($parent);

  $str.="<writeuptype>".$$ntype{title}."</writeuptype>\n" if $ntype;

  if($APP->hasVoted($wu, $USER) || $$wu{author_user} == $$USER{node_id})
  {
    my $up = $DB->sqlSelect("count(*)", "vote", "vote_id=$$wu{node_id} AND weight=1");
    my $dn = $DB->sqlSelect("count(*)", "vote", "vote_id=$$wu{node_id} AND weight=-1");
    my $cast = $DB->sqlSelect("weight", "vote", "vote_id=$$wu{node_id} AND voter_user=$$USER{user_id}");
    $str.="<reputation up=\"$up\" down=\"$dn\" cast=\"$cast\">$$wu{reputation}</reputation>\n";
  }

  my $coolcsr = $DB->sqlSelectMany("cooledby_user", "coolwriteups", "coolwriteups_id=$$wu{node_id} order by tstamp ASC");

  $str.="<cools>\n";

  while(my $coolrow = $coolcsr->fetchrow_hashref())
  {
    my $usr = getNodeById($$coolrow{cooledby_user});
    next unless $usr;
    $str.=" <e2link node_id=\"$$usr{node_id}\">".$APP->encodeHTML($$usr{title})."</e2link>\n";
  }

  $str.="</cools>\n";
  $str.="<title>".$APP->encodeHTML($$wu{title})."</title>\n";

  my $au = getNodeById($$wu{author_user});
  $str.="<author user_id=\"$$au{node_id}\">".$APP->encodeHTML($$au{title})."</author>\n";
  $str.="<doctext>";
  $str.=$APP->encodeHTML(($query->param('links_noparse') == 1)?($$wu{doctext}):(parseLinks($$wu{doctext}))) unless($query->param("no_doctext"));
  $str.="</doctext>\n";
  $str.="</writeup>\n";
  return $str;
}

sub xmlfirmlinks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($nid) = @_;
  my $csr = $DB->sqlSelectMany("*","links","linktype=".getId(getNode('firmlink', 'linktype'))." AND from_node=$nid");
  my $str = "<firmlinks>\n";

  while(my $ROW = $csr->fetchrow_hashref)
  {
    my $n = getNodeById($$ROW{to_node});
    next unless $n;
    $str.="  <e2link node_id=\"$$n{node_id}\">".$APP->encodeHTML($$n{title})."</e2link>\n";
  }

  $str.="</firmlinks>\n";
  return $str;
}

sub formxml_writeup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  $str.= htmlcode("xmlfirmlinks", "$$NODE{parent_e2node}");
  $str.= htmlcode("xmlwriteup","$$NODE{node_id}");
  $str.= "<softlinks>\n".htmlcode("softlink", "xml")."</softlinks>\n";
  return $str;
}

sub schemalink
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($schemafor) = @_;
  my $noderef = getNodeById($schemafor);
  my $row = $DB->sqlSelect("*", "xmlschema", "schema_extends=$$noderef{node_id}");
  $row = $DB->sqlSelect("schema_id", "xmlschema", "schema_extends=0") unless($row);

  return " xmlns=\"https://www.everything2.com\" xmlns:xsi=\"https://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"https://www.everything2.com/?node_id=$row\" ";
}

sub schemafoot
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "</xs:schema>";
}

sub formxml_superdoc
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "" if (($query->param("no_superdocs") == 1) || ($query->param("no_findings") == 1 && $$NODE{node_id} == $Everything::CONF->search_results));

  my $grp = $$NODE{group};
  my $str = "";
  $str.="<superdoctext>\n";
  my $txt = $$NODE{doctext};
  $txt = parseCode($txt);
  $txt = parseLinks($txt) unless($query->param("links_noparse") == 1 or $$NODE{type_title} eq "superdocnolinks");
  $str.= $APP->encodeHTML($txt);
  $str.="</superdoctext>\n";
  return $str;
}

sub xmlnodesuggest
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $retstr = "<sametitles>";
  my @grp = getNodeWhere({ 'title' => $$NODE{title}});
  foreach(@grp)
  {
    my $n = $_;
    next unless canReadNode($USER, $n);
    next if($$n{node_id} == $$NODE{node_id});
    my $tmp = "<nodesuggest type=\"$$n{type}{title}\">";
    $tmp.= '<e2link node_id="'.$$n{node_id}.'">'.$APP->encodeHTML($$n{title}).'</e2link>';

    if($$n{type}{title} eq 'user')
    {
      $n = getNodeById($n->{node_id});
      my $ptr = undef;
      my $tousr = undef;

      if($n->{message_forward_to})
      {
        $tousr = getNodeById($n->{message_forward_to});
      }
     $tmp .= '<useralias><e2link node_id="'.$$tousr{node_id}.'">'.$APP->encodeHTML($$tousr{title}).'</e2link></useralias>';
    }

    $tmp .= "</nodesuggest>";
    $retstr.=$tmp;
  }

  $retstr.="</sametitles>";
  return $retstr;
}

# screens notelet text
# reads "raw" and writes "screened"
#
sub screenNotelet
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $work = $VARS->{'noteletRaw'} || $VARS->{'personalRaw'};
  delete $VARS->{'personalRaw'};

  my $UID = getId($USER) || 0;
  # not filtering, since only shown for user that enters the stuff anyway

  ##only allow certain HTML tags through
  #my $HTMLS = getVars(getNode('approved HTML tags','setting'));

  ##allow a few other tags and attributes
  ##TODO? others?
  #$HTMLS->{'table'} = 'border,cellpadding,cellspacing';
  #$HTMLS->{'th'} = $HTMLS->{'tr'} = $HTMLS->{'td'} = 1;

  #TODO? allow eds to psuedoExec
  #TODO? allow admins to have normal code

  #$work =~ s/\<!--.*?--\>//gs;	#$APP->htmlScreen messes up comments
  #$work = $APP->htmlScreen($work, $HTMLS);	#we may get rid of this later

  unless($VARS->{noteletKeepComments})
  {
    $work =~ s/<!--.*?-->//gs;
  }

  # length is limited based on level
  my $maxLen = $APP->getLevel($USER) || 0;
  $maxLen *= 100;
  if($maxLen>1000)
  {
    $maxLen=1000;
  } elsif($maxLen<500) {
    $maxLen=500;
  }

  # power has its privileges
  # this is in [Notelet Editor] (superdoc) and [screenNotelet] (htmlcode)
  if($APP->isAdmin($USER))
  {
    $maxLen = 32768;
  } elsif( $APP->isEditor($USER) ) {
    $maxLen += 100;
  } elsif($APP->isDeveloper($USER) ) {
    $maxLen = 16384; #16k ought to be enough for everyone. --[Swap]
  }

  if(length($work)>$maxLen)
  {
    $work=substr($work,0,$maxLen);
  }

  # N-Wing added 2003.08.20.n3 to deal with an unclosed comment
  # preventing a user from editing the notelet later
  if($work =~ /^(.*)<!--(.+?)$/s)
  {
    my $preLastComment = $1;
    my $postLastComment = $2;
    if($postLastComment !~ /-->/s)
    {
      # oops, unclosed comment; display it instead
      $work = $preLastComment . '<code>&lt;!--</code>' . $postLastComment;
    }
  }

  delete $VARS->{'personalScreened'};	#old way
  if(length($work))
  {
    $VARS->{'noteletScreened'} = $work;
  } else {
    delete $VARS->{'noteletScreened'};
  }

  return;

}

sub formxml_usergroup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $txt = parseCode($$NODE{doctext});
  my $str = "";
  $txt = parseLinks($txt) unless($query->param("links_noparse"));
  $txt = $APP->encodeHTML($txt);
  $str.="<description>\n";
  $str.=$txt unless($query->param("no_descrip"));
  $str.="</description>\n";
  $str.="<weblog>\n";

  if($DB->isApproved($USER, $NODE))
  {
    my $csr = $DB->sqlSelectMany("*", "weblog", "removedby_user=0 and weblog_id=$$NODE{node_id} order by tstamp DESC");

    while(my $row = $csr->fetchrow_hashref)
    {
      my $n = getNodeById($$row{to_node});
      next unless($n);
      $str.="<e2link node_id=\"$$n{node_id}\">$$n{title}</e2link>";
    }
  }

  $str.="</weblog>\n";
  $str.="<usergroup>\n";
  foreach(@{$$NODE{group}})
  {
    my $n = getNodeById($_);
    $str.= "<e2link node_id=\"$$n{node_id}\">$$n{title}</e2link>";
  }

  $str.="</usergroup>\n";
  return $str;
}

# VARS combo box
# safely allows a user to set a value in their $VARS via an uneditable combo box
#
# parameters:
#   $key - which element is being changed; $VARS->{$key}
#   $flags - bitwise flags:
#      1 = separate 0 and undef - by default, a value of 0 will delete $VARS->{$key}; if this is set, the actual value of 0 will be stored; also note that there isn't a way to delete the key if changed
#   @elements - elements of list:
#      even indices is value, odd indices is what to display
#
# examples:
#   show small, medium, large, which will be set in $VARS->{editsize}
#   [{varsComboBox:editsize,0, 0,small (default),1,medium,2,large}]
#
# created: 2002.05.10.n5
# updated: 2002.06.20.n4 by N-Wing
#
sub varsComboBox
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($key, $flags, @elements) = @_;
  return "" if $APP->isGuest($USER);

  local *oops = sub {
    return '<span border="solid black 1px;" title="varsComboBox">!!! '.$_[0].' !!!</span>';
  };


  #
  # deal with parameters
  #

  return oops('no $VARS key given') unless defined $key;
  return oops('invalid $VARS key given') unless $key =~ /(\w+)/;
  $key = $1;

  $flags = (defined $flags) ? $flags+0 : 0;
  my $separate0 = $flags & 1;

  # if($elements[0] and ref $elements[0] eq "ARRAY")
  # {
  #        @elements = @$elements[0];
  # }

  unless(scalar(@elements)) {
    return oops('no values given');
  }

  return oops('no elements given') if scalar(@elements)==0;
  return oops('missing final value') if (scalar(@elements)%2)==1;


  #
  # values/labels setup
  #

  my @values = ();
  my %labels = ();
  # can't just do something like %labels = @elements; because then we'd loose our order

  while(scalar(@elements))
  {
    my $k = shift(@elements);
    return oops('@elements key #'.scalar(@values).' (index #'.(scalar(@values)<<1).') invalid') unless $k =~ /(-?[\w]+)/;
    $k=$1;
    return oops('key "'.$APP->encodeHTML($k,1).'" already exists; value is "'.$labels{$k}.'"') if exists $labels{$k};
    my $v = shift(@elements);

    push(@values, $k);
    $labels{$k} = $v;
  }

  if(!exists $labels{0})
  {
    push(@values, 0);
    $labels{0} = '0 (default)';
  }

  my $curDefault = undef;

  #
  # possibly change VARS
  #

  my $qp = 'setvars_'.$key;
  if(defined $query->param($qp))
  {
    my $newVal = $query->param($qp);
    if(exists $labels{$newVal})
    {
      # only allow a value explicitly given as allowed
      if($newVal eq '0')
      {
        # special case 0: do we delete or actually set
        if($separate0)
        {
          $VARS->{$key} = 0;
        } else {
          delete $VARS->{$key};
        }
      } else {
        $VARS->{$key} = $newVal;
      }
    }
  }


  #
  # display combo box
  #

  my $curSel = (exists $VARS->{$key}) ? $VARS->{$key} : 0;
  if(!exists $labels{$curSel})
  {
    push(@values, $curSel);
    $labels{$curSel} = $curSel
  }

  $labels{$curSel} = '* '.$labels{$curSel};

  return $query->popup_menu($qp, \@values, $curSel, \%labels);
}

# message field: provides a text field to send a message to a user(group)
#
# arguments:
#  $mfuID - msgfield unique identifier, or special value of 0 or blank to indicate no more
#  $flags - bitwise flags:
#    1 = no CC box
#    2 = do NOT show what was said here
#  $aboutNode - node_id the message is about
#  @tryRecipients - ID(s) of user(group)(s) to send message to
#
# if $mfuID is blank, this uses (a) hidden parameter(s) to know who to send the message(s) to;
# otherwise, the hidden parameter(s) are ignored for normal message sending
#
# created: 2002.06.22.n6
# updated: 2002.07.30.n2
#
sub msgField
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($mfuID, $flags, $aboutNode, @tryRecipients) = @_;

  my $UID = $USER->{node_id}||0;
  return if $APP->isGuest($USER);

  # gives information in HTML that an error occured; hovering the mouse over the message yields more information
  # created: 2002.06.22.n6
  # updated: 2002.07.07.n0

  local *oops = sub {
    my $arg = 'msgField (htmlcode): ' . ($_[0] || 'unknown error');
    $arg =~ s/&/&amp;/gs;
    $arg =~ s/</&lt;/gs;
    $arg =~ s/>/&gt;/gs;
    $arg =~ s/"/&quot;/gs;
    $arg =~ s/\[/&#91;/gs;
    $arg =~ s/\]/&#93;/gs;
    return '<span border="solid black 1px;" title="' . $arg . '">Sorry, a server error occured. This is likely only a temporary glitch, and things will soon be working properly again.</span>';
  };


  #
  # deal with parameters
  #

  my $doNormalSend = (defined $mfuID) && length($mfuID) && ($mfuID !~ /^\s*0\s*$/);
  undef $mfuID unless $doNormalSend;


  # find bitwise flags
  $flags = (defined $flags) && length($flags) && ($flags=~/([1-9]\d*)/) ? $1 : 0;
  my $showCC = !($flags & 1);
  my $showSaid = ($flags & 2) ? 0 : 4;	#values wanted by sendPrivateMessage

  # node message is about
  $aboutNode = (defined $aboutNode) && length($aboutNode) && ($aboutNode=~/([1-9]\d*)/) ? $1 : 0;

  # find message recipient(s)
  my %recipients = ();
  my @getters = ();

  # finds recipients based on given list @tryRecipients (global since htmlcodes seem to get a bit weird with parameter passing sometimes)
  # returned list in @getters has no duplicates, and are all postive integers
  # real returned value is how many are in new list, equal to scalar(@getters)
  # created: 2002.07.14.n0
  # updated: 2002.07.14.n0

  local *validRecipients = sub {
    @getters=();
    return 0 unless scalar(@tryRecipients);
    my %localrecipients = ();
    foreach(@tryRecipients)
    {
      if(/([1-9]\d*)/)
      {
        $localrecipients{$_}=1;
      }
    }
    return scalar(@getters = keys(%localrecipients));
  };

  if($doNormalSend)
  {
    return oops('must give at least one valid recipient ID') unless validRecipients();
    $showCC=0 if exists $recipients{$UID};	#no point in CC box if already going to /msg self
  }


  #
  # other setup
  #

  my $str='';
  my $nameTxt = undef;	#text field
  my $nameCC = undef;	#CC checkbox

  #
  # send message(s)
  #

  # tries to send a message
  #  set global vars $nameTxt and $nameCC before calling
  # created: 2002.07.06.n6
  # updated: 2002.07.22.n1

  my $MAXLEN=12345;	#my luggage combination
  local *trySend = sub {
    return unless defined $query->param($nameTxt);
    my $t = undef;
    return unless length($t=$query->param($nameTxt));
    if(length($t)>$MAXLEN)
    {
      $t=substr($t,0,$MAXLEN);
    }

    my $doCC = (defined $query->param($nameCC)) && ($query->param($nameCC) eq '1') ? 1 : 0;

    $t = htmlcode('sendPrivateMessage', { 'recipient_id' => \@getters, 'message' => $t, 'ccself' => $doCC, 'renode_id' => $aboutNode, 'show_said' => $showSaid});
    $str .= $t . "<br />\n" if (defined $t) && length($t);

    $query->delete($nameTxt);
    return;
  };

  if($doNormalSend) {
    # send message as normal
    $nameTxt = $mfuID.'_msgfieldmsg';
    $nameCC = $mfuID.'_msgfieldcc';
    trySend();
  } else {
    # send whatever messages are left
    my @origParams = $query->param();
    my $base = undef;
    my $getters = undef;
    foreach(@origParams)
    {
      next unless /^(.+?)_msgfieldmsg$/;
      $base=$1;
      $getters = $base.'_msgfieldget';
      if( (defined $query->param($getters)) && length($getters=$query->param($getters)) )
      {
        @tryRecipients = split(',',$getters);
        next unless validRecipients();	#no valid things to send to
      } else {
        # don't know who to send to
        next;
      }

      $nameTxt = $base . '_msgfieldmsg';
      $nameCC = $base . '_msgfieldcc';
      trySend();
    }
  }

  return $str unless $doNormalSend;

  #
  # create form / display field
  #

  $str .= $query->hidden($mfuID.'_msgfieldget', join(',', @getters));	#used when doing "cleanup" send
  if($showCC)
  {
    $str .= $query->checkbox($nameCC,'','1','CC').' ';
  }
  $str .= $query->textfield(-name=>$nameTxt, value=>'', size=>24, class=>'expandable');

  #
  # cleanup and return
  #

  return $str;
}

# returns the date and time, in long format
#
# parameter:
#  $useTime - the time to use (in seconds); if not set, uses current time
#  $showServer - if set, uses the server's time, instead of the user's time offset
#
# created: 2002.09.07.n6
# updated: 2007-07-26(4)
# TODO also have a "short" format, and optionally show just date or time
# TODO localization:
#  local language - really best if we load common localization strings before we even parse the pages
#  local format (just Gregorian month, day, and year, unless we can figure a safe way of combining a date/time module and potentially dangerous user input)
#
sub DateTimeLocal
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($useTime, $showServer) = @_;

  my $calcTime = defined($useTime) && length($useTime) ? $useTime : time;
  if(!$showServer && $VARS->{'localTimeUse'})
  {
    $calcTime += $VARS->{'localTimeOffset'} if exists $VARS->{'localTimeOffset'};
    #add 1 hour = 60 min * 60 s/min = 3600 seconds if daylight savings
    $calcTime += 3600 if $VARS->{'localTimeDST'};	#maybe later, only add time if also in the time period for that - but places have different daylight saving time start and end dates
  }

  my @months = qw(January February March April May June July August September October November December);
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($calcTime);
  my $result = ('Sun','Mon','Tues','Wednes','Thurs','Fri','Satur')[$wday].'day, ' . $months[$mon] . ' ' . $mday . ', ' . (1900+$year) . ' at ';

  my $showAMPM='';
  if($VARS->{'localTime12hr'})
  {
    if($hour<12)
    {
      $showAMPM = ' AM';
      $hour=12 if $hour==0;
    } else {
      $showAMPM = ' PM';
      $hour -= 12 unless $hour==12;
    }
  }

  # $hour = '0'.$hour if length($hrs)==1;	#leading 0 looks ugly
  $min = '0'.$min if length($min)==1;
  $sec = '0'.$sec if length($sec)==1;	
  $result .= $hour.':'.$min.':'.$sec;
  $result .= $showAMPM if length($showAMPM);

  # $result .= sprintf('%02d:%02d:%02d',$hour,$min,$sec);

  return $result;
}

# returns a navigation bar containing available settings superdocs
#
sub settingsDocs
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $DISP = 'navbardisp';

  # settings to link to:
  #  a title by itself will just link to that node, of type 'superdoc'
  #  a hash ref is special:

  my @allSettings = (
    'Settings',
    'Advanced Settings'
  ) ;

  push @allSettings, 'Admin Settings' if $APP->isEditor($USER);
  push @allSettings ,(
    'Nodelet Settings',
    {$DISP=>'Profile', 'node_id'=>$$USER{node_id}, 'displaytype'=>'edit'});


  my $lcnt = lc($$NODE{title});
  foreach(@allSettings)
  {
    if(UNIVERSAL::isa($_,'HASH'))
    { 
      # doing fancy stuff - giving specific parameters for link
      # this is way overkill, but this allows us to easily maintain the settings list
      my $show = (exists $_->{$DISP}) ? $_->{$DISP} : (exists $_->{'node'}) ? $_->{'node'} : (exists $_->{'node_id'}) ? 'node_id='.$_->{'node_id'} : '(Something)';
      delete $_->{$DISP};
      $_->{'type'}='superdoc' unless (exists $_->{'type'}) || (exists $_->{'node_id'});

      if( ((exists $_->{'node_id'}) && ($_->{'node_id'}==$$NODE{'node_id'})) || ((exists $_->{'node'}) && ($_->{'node'} eq $$NODE{'title'})) )
      {
        # probably on the given node, so don't link it
        $_ = '<strong>'.$show.'</strong>';
      } else {
        # probably not on node, so link it
        $_ = '<a href='.urlGen($_).'>'.$show.'</a>';
      }

    } else {
      # straight-forwards superdoc and given the title
      if($lcnt eq lc($_))
      {
        # on this setting, so don't link it
        $_ = '<strong>'.$_.'</strong>';
      } else {
        # not on node, so link it
        $_ = '<a href='.urlGen({'node'=>$_,'type'=>'superdoc'}).'>'.$_.'</a>';
      }
    }
  }

  return '<div class="settingsdocs">&ndash; &nbsp;' . join(' &#183; ', @allSettings) . ' &nbsp; &ndash;</div>';
}

sub formxml_room
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $entrance="0";
  if(eval($$NODE{criteria}) and not $APP->isGuest($USER))
  {
    $entrance=1;
    $APP->changeRoom($USER, $NODE);
  }
  my $str = "<canenter>".$entrance."</canenter>\n";
  $str.="<description>".$APP->encodeHTML(($query->param("links_noparse"))?($$NODE{doctext}):(parseLinks($$NODE{doctext})))."</description>";
  return $str;
}

sub formxml_superdocnolinks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return htmlcode("formxml_superdoc");
}

sub statsection_advancement
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";

  #pass 2 args: category and value
  local *genRow = sub {
    return '<div><span class="var_label">' . $_[0] . ': </span><span class="var_value">' . $_[1] . "</span></div>\n";
  };

  my $hv = getVars(getNode("hrstats", "setting"));
  my $IQM = (($$USER{merit})?($$USER{merit}):(0));

  $str .= genRow('Merit', sprintf('%.2f', $IQM || 0));
  $str .= genRow('LF', sprintf('%.4f', $APP->getHRLF($USER) || 0));
  $str .= genRow("Devotion", int(($$VARS{numwriteups} * $$USER{merit}) + .5));
  $str .= genRow("Merit mean",$$hv{mean});
  $str .= genRow("Merit stddev", $$hv{stddev});

  return "<div>".$str."</div>";
}

sub orderlock
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  my $N = getNodeById($query->param('node_id'));

  return unless $N;
  return unless $$N{type}{title} eq "e2node";

  if($query->param("unlock")){
    $N->{orderlock_user} = 0;
  }else{
    $N->{orderlock_user} = $USER->{node_id};
  }

  updateNode($N, -1);
  return;
}

#
# possibly forms a link to external web site
# URL must start with the protocol, http:// or https://
#
# used by 'Nothing Found' and 'Findings:'
#
sub externalLinkDisplay
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $testURL = $_[0];
  $testURL =~ s/&#39;/'/g;
  $testURL =~ s/&#44;/,/g;

  my $protocol = undef;
  my $domain = undef;
  my $relAddress = undef;

  if($testURL =~ /^(https?):\/\/([^\/]+)(\/.*)?$/)
  {
    $protocol = $1;
    $domain = $2;
    $relAddress = $3 || '';
  } else {
    return '';
  }

  my $i = undef;

  # chop off any CGI parameters
  #  can't just test for everything2.com, org, etc., because there are
  #  many ways to create an address (example: IP address) that could
  #  slip by our tests; to be safe, just remove all the parameters

  # N-Wing is disabling this for now (2005 March 12), because kthejoker
  #  thinks is annoying and won't be a problem. So blame k. if
  #  things go badly. :) (On a more serious note, if people *do*
  #  start doing bad things, just uncomment the next two lines.)
  #  $i = index($relAddress, '?');
  #  $relAddress = substr($relAddress,0,$i) if $i != -1;

  # construct URL
  my $fullURL = $protocol . '://' . $domain;
  if(length($relAddress)==0)
  {
    $fullURL .= '/';
  } else {
    $fullURL .= $relAddress;
  }

  $fullURL = join('', split('"', $fullURL));	#remove double quotes

  # create link
  my $str = '<a href="' . $fullURL . '" class="external">' . $APP->encodeHTML($fullURL, 1) . '</a>';
  return $str;
}

sub chatterSplit
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $maxLen = ((exists $VARS->{splitChatter}) && (defined $VARS->{splitChatter}) && ($VARS->{splitChatter}=~/^([1-9]\d*)$/)) ? $1 : 0;
  $maxLen += 0;
  if($maxLen<1)
  {
    $maxLen=20;	#default width
  } elsif($maxLen>999) {
    $maxLen=999;
  }
  return $maxLen;
}

sub isdaylog
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($NID) =@_;
  getRef($NID);
  return 0 unless $$NID{type}{title} eq 'e2node';

  my $isDaylog=0;
  my $daylogTitle=$$NID{title};
  my @months = ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');

  foreach (@months)
  {
    if ($daylogTitle =~ /$_\s\d+,\s\d+/) {$isDaylog=1; last;}
  }

  return $isDaylog;
}

sub softlock
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);
  my $defaultreason="";

  if($query->param('nodeunlock'))
  {
    $defaultreason = $DB->sqlSelect("nodelock_reason", "nodelock", "nodelock_node=$$NODE{node_id}");
    $DB->sqlDelete("nodelock","nodelock_node=$$NODE{node_id}");
  }

  if($query->param('nodelock'))
  {
    $DB->sqlInsert("nodelock", {
      nodelock_reason => $query->param('nodelock_reason'),
      nodelock_user => $$USER{user_id},
      nodelock_node => $$NODE{node_id}}
      ) unless ($DB->sqlSelectHashref("*", "nodelock", "nodelock_node=$$NODE{node_id}"));
  }

  my $nodelock = $DB->sqlSelectHashref("*", "nodelock", "nodelock_node=$$NODE{node_id}");
  my $str =htmlcode('openform').'<fieldset><legend>Node lock</legend>';

  if($nodelock)
  {
    my $locker = getNodeById($$nodelock{nodelock_user});
    $str .= '(Locked by '.linkNode($locker, $$locker{title}).qq')<input type="hidden" name="nodeunlock" value="$$NODE{node_id}"><input type="submit" value="Unlock this e2node">';
  } else {
    $str .= qq'Lock this node because: <input type="hidden" name="nodelock" value="$$NODE{node_id}">
      <input type="text" size="60" class="expandable" name="nodelock_reason" value="">
      <input type="submit" value="Lock">';
  }

  $str .='</fieldset></form>';
  return $str;
}

sub atomiseNode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $host = $ENV{HTTP_HOST} || $Everything::CONF->canonical_web_server || "everything2.com";
  $host = "http://$host" ;

  my $atominfo = sub {
    my $N = shift ;
    my $url = $host . urlGen({ }, 'noQuotes', $N) ;
    my $author = getNodeById( $$N{author_user} ) ;
    my $authorurl = $host . $APP -> urlGenNoParams($author, 'no quotes') ;
    my $timestamp = $$N{publishtime} || $$N{createtime};
    $timestamp =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;
    $timestamp = sprintf ("%04d-%02d-%02dT%02d:%02d:%02dZ", $1, $2, $3, $4, $5, $6);
	
    return '<title>' . $APP->encodeHTML($$N{title}) . '</title>' .
      '<link rel="alternate" type="text/html" href="' . $url . '"/>' .
      '<id>' . $url . '</id>' .
      '<author>' .
      '<name>' . $$author{ title } . '</name>' .
      '<uri>' . $authorurl . '</uri>' .
      '</author>' .
      '<published>'. $timestamp . '</published>' .
      '<updated>'. $timestamp . '</updated>' ;
  };

  my ( $input , $length ) = @_ ;
  $length ||= 1024 ;
  return htmlcode( 'show content' , $input , "xml <entry> atominfo, $length" , ( atominfo => $atominfo) ) ;
}

sub userAtomFeed
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($foruser) = @_;
  return unless $foruser;

  $foruser =~ s/&#39;/'/g;
  my $u = getNode($foruser, 'user');
  return unless $u;

  my $csr = $DB->sqlSelectMany('node.node_id, publishtime',
    'node JOIN writeup on node_id=writeup_id',
    'author_user=' . getId($u) .
    ' order by publishtime desc limit 6');

  # this is so we have the first result for the timestamp
  my $row = $csr->fetchrow_hashref;
  return unless $row;
  my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
  $str .= "<feed xmlns=\"http://www.w3.org/2005/Atom\" xml:base=\"http://everything2.com/\">\n";
  $str .= "    <title>" . $foruser . "'s New Writeups</title>\n";
  $str .= "    <link rel=\"alternate\" type=\"text/html\" href=\"http://everything2.com/index.pl?node=Everything%20User%20Search&amp;usersearch=" . $foruser . "\" />\n";
  $str .= "    <link rel=\"self\" type=\"application/atom+xml\" href=\"?node=New%20Writeups%20Atom%20Feed&amp;type=ticker&amp;foruser=" . $foruser . "\" />\n";
  $str .= "    <id>http://everything2.com/?node=New%20Writeups%20Atom%20Feed&amp;foruser=" . $foruser . "</id>\n";

  my $timestamp = $$row{publishtime};   
  $timestamp =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/;
  $timestamp = sprintf ("%04d-%02d-%02dT%02d:%02d:%02dZ", $1, $2, $3, $4, $5, $6);
   
  $str .= "    <updated>$timestamp</updated>\n";

  do {
    $str .= htmlcode('atomiseNode', $$row{node_id});
  } while($row = $csr->fetchrow_hashref);

  $str.="</feed>\n";
  return $str;
}

sub ignoreUser
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
  if($U)
  {
    return if $$U{title} eq 'EDB';
    unless($DB->sqlSelect('*', 'messageignore', "messageignore_id=$$USER{node_id} and ignore_node=$$U{node_id}"))
    {
      $DB->sqlInsert('messageignore', { messageignore_id => getId($USER), ignore_node => $$U{node_id}});
    } else {
      return 'already ignoring '.$$U{title};
    }
  } else {
    $uname = $APP->encodeHTML($uname);
    return "<strong>$uname</strong> doesn't seem to exist on the system!" unless $U;
  }

  $query->param('DEBUGignoreUser', 'tried to ignore '.$$U{title});
  return "$$U{title} ignored";
}

# TODO: Make this JSON
#
sub ajaxVar
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($name, $value) = @_;

  my $idList = '[,\\d]*' ;
  my $nameList = '[!,\\w]*' ;
  my $nodeId = '\\d*' ;

  my %valid = (
    collapsedNodelets => $nameList ,
    nodetrail => $idList ,
    current_nodelet => $nodeId
  );

  my $test = $valid{$name};

  return 'invalid name' unless $test ;
  return 'invalid value' unless($value =~ /^($test|0)$/ or not $value);

  my $oldVal = $$VARS{$name}||'0';

  if ($value gt '')
  {
    if ($value eq '0')
    {
      delete $$VARS{$name};
    }
    $$VARS{$name} = $value;
  }

  my $retval = $$VARS{$name}||'0';
  return "{name: '$name', value: '$retval', oldval: '$oldVal'}";

}

sub favorite_noder
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $class = "ajax favoritenoder:favorite_noder" ;

  # TODO: Do not hardcode node_ids
  if ($$NODE{type_nodetype} == 15)
  {
    my $nid = $$NODE{node_id};
    my $favlinktype = getId(getNode('favorite','linktype'));
    my $favnoder = $DB->sqlSelect('to_node','links',"from_node=$$USER{node_id} AND to_node=$nid AND linktype=$favlinktype");
    my $username = $$NODE{title} ;
    $username =~ s/"/&quot;/s ;
    $username =~ s/>/&gt;/s ;

    if ($favnoder)
    {
      return linkNode($nid,"unfavorite!",
        { op => "unfavorite",
          fave_id => $NODE -> {node_id},
          -title => "stop notification of new writeups by $username",
          -id => 'favoritenoder',
          -class => $class ,
        }) ;
    } else {
      return linkNode($nid,"favorite!",
        { op => "favorite",
          fave_id => $NODE -> {node_id},
          -title => "get notification of new writeups by $username",
          -id => 'favoritenoder',
          -class => $class ,
        });
    }
  }
}

sub updateNodelet
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($nodelet) = @_;
  return unless $nodelet;

  $nodelet = getNode($nodelet,'nodelet');
  return unless $nodelet;
  return insertNodelet($nodelet);
}

sub hasAchieved
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($ACH, $user_id, $force) = @_;

  getRef $ACH;
  $ACH ||= getNode($_[0], 'achievement');
  return 0 unless $ACH;

  $user_id ||= $$USER{user_id};
  return unless getNodeById($user_id)->{type}{title} eq 'user';

  $force = undef unless( defined($force) and ($force == 1));

  return 1 if $DB->sqlSelect('count(*)'
    , 'achieved'
    , "achieved_user=$user_id
    AND achieved_achievement=$$ACH{node_id} LIMIT 1");

  return 0 unless $$ACH{achievement_still_available};

  my $result = $force || evalCode("my \$user_id = $user_id;\n$$ACH{code}", $NODE);

  if ($result == 1)
  {
    $DB->sqlInsert("achieved",{achieved_user => $user_id, achieved_achievement => $$ACH{node_id}});

    my $notification = getNode("achievement","notification")->{node_id};
    if ($$VARS{settings} && from_json($$VARS{settings})->{notifications}->{$notification})
    {
      htmlcode('addNotification', $notification, $user_id, {achievement_id => $$ACH{node_id}});
    }
  }

  return $result;
}

sub show_node_forward
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "" unless ($query && defined $query->param('originalTitle'));

  my $originalTitle = $query->param('originalTitle');
  my $encodedTitle = $APP->encodeHTML($originalTitle);
  my $forwardNode = getNode($originalTitle, 'node_forward', 'light');
  my $alsoStr = htmlcode('usercheck', $originalTitle);
  my $editStr = "";

  if ($APP->isEditor($USER) && $forwardNode) {
    $editStr = " ". linkNode($forwardNode, "(edit forward)", {displaytype => 'edit'});
  }

  return '<div class="forward">' . "Redirected from <em>$encodedTitle</em>$alsoStr$editStr". '</div>';
}

sub achievementsByType
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($aType, $user_id, $debug) = @_;
  return unless $aType;

  $user_id ||= $$USER{user_id};

  my @achList = getNodeWhere({achievement_type => $aType}, 'achievement', 'subtype, title ASC');
  return unless @achList;

  my $str = undef;
  my $finishedgroup = '';

  foreach my $a (@achList)
  {
    # forget about blah100 if we haven't got blah050:
    next if $$a{subtype} && $$a{subtype} eq $finishedgroup;

    my $result = htmlcode('hasAchieved', $a, $user_id);
    $finishedgroup = ($$a{subtype} || '') unless $result;

    $str.=linkNode($a)." - $result<br>" if $debug;
  }

  return $str;
}

sub statsection_fun
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = undef;

  # pass 2 args: category and value
  local *genRow = sub {
    return '<div><span class="var_label">' . $_[0] . ': </span><span class="var_value">' . $_[1] . "</span></div>\n";
  };

  $str .= genRow('Node-Fu',sprintf('%.1f', $$USER{experience}/$$VARS{numwriteups})) if ($$VARS{numwriteups});
  $str .= genRow('Golden Trinkets',$$USER{karma});
  $str .= genRow('Silver Trinkets',$$USER{sanctity});
  $str .= genRow('Stars',$$USER{stars});
  $str .= genRow('Easter Eggs',$$VARS{easter_eggs});
  $str .= genRow('Tokens',$$VARS{tokens});
  return '<div>'.$str.'</div>';

}

sub editor_homenode_tools
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $isRoot = $APP->isAdmin($USER);
  my $isEditor = $APP->isEditor($USER);
  my $targetVars = getVars $NODE;
  my $iph = getNode('IP Hunter', 'restricted_superdoc');
  my $oracle = getNode('The Oracle', 'oppressor_superdoc');
  my $ipblacklist = getNode('IP Blacklist', 'restricted_superdoc');

  # not sports illustrated!
  my $SI = getNode("Suspension Info", "superdoc");
  my $str = linkNode($SI, "Suspensions", {"lookup_user" => $$NODE{node_id}});

  if($isRoot){
    my @addrs = split /\s*,\s*/, $$targetVars{ipaddy};
    $str.= "\n - ".linkNode($oracle, "The Oracle", {the_oracle_subject => $$NODE{title}}).' - '.linkNode($NODE,'editvars',{displaytype=>'editvars'}) . '<br />';
    $str.= "\nIP Hunt: ".linkNode($iph, 'by name', {hunt_name => $$NODE{title}});
    if (scalar @addrs)
    {
      $str.= ' or ';
      map {
        my $ip = $APP->encodeHTML($_);
        $str.= "<br>\n"
        . linkNode($iph, 'by IP', {hunt_ip => $ip})
        . " ($ip <small>"
        . htmlcode('ip lookup tools', $ip)
        . "</small>)"
        . '&nbsp;'
        . linkNode($ipblacklist, "Blacklist IP?", {'bad_ip' => $ip} );
      } @addrs;
    }
  } elsif ($isEditor) {
    $str.= "\n - ".linkNode($oracle, "The Oracle", {the_oracle_subject => $$NODE{title}}) . "<br />\n";
  }

  $str.= "<br />reCAPTCHAv3 Score: ".$targetVars->{recaptcha_score}."<br />\n" if exists($targetVars->{recaptcha_score});
  return $str;
}

# TODO: Recheck all of these branches for e2node once e2nodes are in templates

sub page_header
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # let page inject stuff into the header:
  my ($str,$after) = ("","");
  ($str,$after) = split /<!--.*?-->/, $PAGELOAD->{pageheader} if($PAGELOAD->{pageheader});

  my $ntypet = $$NODE{type}{title};
  if ( $ntypet eq 'e2node' or $ntypet eq 'writeup' )
  {
    $str .= htmlcode( 'createdby' )."\n" if $ntypet eq 'e2node' ;
    $str .= htmlcode( 'firmlinks' )."\n" ;
    $str .= htmlcode( 'usercheck' )."\n" if $ntypet eq 'e2node' ;
  }

  if ($ntypet eq 'e2node' || $ntypet eq 'superdoc' || $ntypet eq 'superdocnolinks' || $ntypet eq 'document')
  {
    my $COOLLINK = getNode('coollink','linktype') -> {node_id};
    $PAGELOAD->{edcoollink} = $DB->sqlSelectHashref('to_node', 'links', 'from_node='.$$NODE{node_id}.' and linktype='.$COOLLINK.' limit 1') ;
    $str .= '<div id="cooledby"><strong>cooled by</strong> '.linkNode($PAGELOAD->{edcoollink}->{to_node})."</div>\n" if $PAGELOAD->{edcoollink} ;
  }

  $str .= htmlcode( 'confirmop' ) if $query -> param( 'confirmop' ) ;
  $str .= htmlcode('page actions') unless $APP->isGuest($USER) ;

  if($APP->can_category_add($NODE))
  {
    $str .= htmlcode('listnodecategories') unless defined $PAGELOAD->{e2nodeCategories}; # i.e. unless writeups have already listed any page categories
  }

  return qq'<div id="pageheader">
    <h1 class="nodetitle">$$NODE{title}</h1>\n\t'.
    htmlcode( 'show_node_forward' ) . "$str $after</div>" ;
}

sub writeuptools
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N, $open) = @_;
  getRef $N;

  return htmlcode('drafttools', @_) if $$N{type}{title} eq 'draft';

  my $isEditor = $APP->isEditor($USER);
  my $isMine = ($$N{author_user} == $$USER{node_id});
  return unless $isMine or $isEditor;

  my ($linktext , $linktitle, $hide, $insure, $insured, $remove, $reassign, $nodenotes) = (undef,undef,undef,undef,undef,undef,undef,undef);

  my $n = $$N{node_id};
  my $id = 'adminheader'.$n ;
  my $ajax = "ajax $id:writeuptools:$n,1";

  my $author = getNodeById( $$N{author_user} );
  $author = $query -> escapeHTML($$author{title}) if $author;

  if ($$N{notnew})
  {
    $hide = 'Unhide';
    $linktitle .= 'Hidden';
    $linktext = 'H';
  }else{
    $hide = 'Hide';
    $linktitle .= 'Published';
    $linktext = 'P';
  }

  if ($isEditor and $$N{publication_status} and my $publisher = $DB->sqlSelect('publisher','publish',"publish_id = $n limit 1"))
  {
    $insured = 'Insured by '.($publisher ? linkNode($publisher) : '&#91;missing editor&#93;');
    $linktitle .= "; $insured";
    $linktitle =~ s/<.*?>//g;

    $linktext .= '&#183;I';
  }

  if ($isMine)
  {
    $remove = linkNode($N, 'remove writeup', {confirmop => 'remove', %{htmlcode('verifyRequestHash', 'remove')}, writeup_id => $n, writeup_parent_e2node => $$N{parent_e2node}
      # reattach to node
      , draft_publication_status => getId(getNode 'private', 'publication_status')
      , -class => "action" # no ajax: go to draft's own page
      , -title => 'remove this writeup and return it to draft status'
    });
  }elsif ($insured) {
    $insured .= ' ('.linkNode($NODE , 'undo', {confirmop=>'insure', ins_id => $n,
      -class => "action $ajax" ,
      -title => 'remove the insurance on this writeup'
      }).')';
  }else{
    $insure = linkNode($NODE, 'Insure', { op=>'insure', ins_id=>$n, -class=>"action $ajax" });
    my $authorForAjax = $author;
    $authorForAjax =~ s/ /+/g;

    $remove = $query -> small(
      $query->textfield(
        -name=>'removereason'.$n,
        class=>'expandable', size=> $$VARS{nokillpopup} ? 12 : 30,
        title=>"Reason for removing ${author}'s writeup"
	)
      )
      .$query->checkbox(
        -name => "removenode$n"
        , value => 1
        , checked => 0
        , label => $$VARS{nokillpopup} ? 'axe' : 'Remove writeup'
        , class => "replace ajax $id:drafttools?op=remove&removenode$n=1&removereason$n=/"
        ."&removereason$n=/#Reason+for+removing+${authorForAjax}'s+writeup:$n,1"
        , onclick => "if (this.checked) \$('#killbutton').click();" # for if no ajax
      );
  }

  # mauler and riverrun don't want a widget:
  return $query -> span({class => 'admin', id => $id}, $insured ? $insured : $insure.$remove) if $$VARS{nokillpopup};

  my @out = ();

  if ($isEditor)
  {
    $reassign = linkNode(getNode('Magical Writeup Reparenter', 'superdoc'), 'Reparent&hellip;', {old_writeup_id => $n})
      .' &nbsp; '
      .linkNode(getNode('Renunciation Chainsaw', 'oppressor_superdoc'), 'Change author&hellip;', {wu_id => $n});

    if ($nodenotes = htmlcode('nodenote', $n))
    {
      $linktext .= '&#183;N';
      $linktitle .= '; has nodenotes';
    }

    push @out, linkNode($NODE, "$hide writeup" , { op => lc($hide).'writeup', hidewriteup => $n , -class => "action $ajax"});

    push @out, $insure if $insure;
    @out = (join ' &#183; ', @out);
  }

  push @out, $insured if $insured;
  push @out, $remove if $remove;
  push @out, $reassign if $reassign;
  push @out, $nodenotes if $nodenotes;

  $query -> param( 'showwidget' , 'admin' ) if $open ;

  return $query -> span({class => 'admin', id => $id},
    htmlcode('widget', join('<hr>', @out), 'span', "<b>$linktext</b>", {showwidget => 'admin', -title => "$linktitle. Click here to show/hide admin options."}));

}

sub zenDisplayUserInfo
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @showThings = (
    'msgalias',
    'createtime',
    'last',
    'nwriteups',
    'recentwriteups',
    'level',
    'gp',
    'coolsspent',
    'mission',
    'specialties',
    'employment',
    'motto',
    'groups',
    'categories',
    'lastnoded',
    'presents',
    'draftshare',
    'manip',
    'msgme',
    'msgyou',
  );

  my @noHTMLSCREEN = ('nwriteups', 'coolsspent', 'level');

  # only works when called from a user node
  # FIXME? should we abort for locked users? maybe just certain things?
  return unless ($$NODE{type_nodetype}==getId(getType('user')));

  # constants
  my $UID = getId($USER);
  my $isGuest = $APP->isGuest($USER);
  my $nid = getId($NODE);
  my $isRoot = $APP->isAdmin($USER);
  my $isMe = (!$isGuest) && ($nid==$UID);
  my $isEd = $APP->isEditor($USER);
  my $isChanop = $APP->isChanop($USER);
  my $SETTINGS = getVars $NODE;

  # display
  my $textPre = '<dt>';
  my $textMid = '</dt><dd>';
  my $textPost = "</dd>\n";

  local *info_groups = sub {
    return if $$VARS{hidehomenodeUG} ;
    return (htmlcode('showUserGroups','') || "").(( $APP->isEditor($NODE) )?(" - ".linkNode(getNode("Editor Endorsements","superdoc"),"My Endorsements",{editor=>$$NODE{node_id}})):(''));
  };

  local *info_categories = sub {
    return if $$VARS{hidehomenodeUC} ;
    return htmlcode('showUserCategories');
  };

  local *info_msgalias = sub {
    my $tousr = undef;
    if($NODE->{message_forward_to})
    {
      $tousr = getNodeById($NODE->{message_forward_to});
    }

    return unless $tousr;
    return linkNode($tousr);
  };

  local *info_lastnoded = sub {
    return if $$VARS{hidelastnoded};
    my $n = $$NODE{title};
    return if ($n eq 'EDB') || ($n eq 'Klaproth') || ($n eq 'Cool Man Eddie') || ($n eq 'Webster 1913');

    my $lastnoded = getNodeById($$SETTINGS{lastnoded});
    return unless($lastnoded);
    my $parentnode = getNodeById($$lastnoded{parent_e2node});

    return linkNode($lastnoded, $$parentnode{title});
  };

  local *info_draftshare = sub {
    return if $isGuest;
    return linkNode(getNode('Drafts', 'superdoc'), 'Your drafts')
    if ($$USER{node_id} == $$NODE{node_id});
    return linkNode(getNode('Drafts', 'superdoc'), "$$NODE{title}'s drafts", {other_user => $$NODE{title}});
  };

  local *info_manip = sub {
    return unless $isEd || $isChanop;
    return htmlcode('editor homenode tools');
  };

  local *info_gp = sub {
    return if $isGuest;
    return unless($isMe or $isRoot);
    return if ((exists $$VARS{GPoptout})&&(defined $$VARS{GPoptout}));
    return $$NODE{GP};
  };

  local *info_recentwriteups = sub{
    return unless $$SETTINGS{showrecentwucount};
    my $recentwriteups = htmlcode('writeupssincelastyear',$nid);
    $recentwriteups = '<em>none!</em>' unless $recentwriteups; 
    return $recentwriteups;
  };

  local *info_msgme = sub {
    return if $$VARS{hidemsgme};
    return '<div id="userMessage">'.(htmlcode('messageBox',$$NODE{node_id},1) || "").'</div>';
  };

  local *info_msgyou = sub {
    return if $isGuest;
    return if $$VARS{hidemsgyou};
    return unless my $nummsgs = $DB->sqlSelect('count(*)', 'message', "for_user=$$USER{node_id} and author_user=$$NODE{node_id}");
    return linkNode(getNode('message inbox', 'superdoc'), "$nummsgs messages",{ fromuser => $$NODE{title} });
  };

  local *info_last = sub {
    return if $$SETTINGS{hidelastseen} && !$isEd;
    my $tmp = htmlcode('timesince',$$NODE{lasttime});
    $tmp = defined($tmp) ? (' ('.$tmp.')') : '';
    return htmlcode('parsetime','lasttime') . $tmp;
  };

  local *info_usersince = sub {
    my $tmp = htmlcode('timesince',$$NODE{createtime});
    $tmp = defined($tmp) ? (' ('.$tmp.')') : '';
    return htmlcode('parsetime','createtime') . $tmp;
  };

  local *info_presents = sub {
    return unless $isMe;
    return if $$VARS{hidevotedata};
    #thanks to epicenter nodelet, vote opcode, and {voting/experience system}
    my $v = $$USER{votesleft} || 0;
    my $c = $$VARS{cools} || 0;
    my $VOTES = getVars(getNode('level votes', 'setting')) || 0;
    my $COOLS = getVars(getNode('level cools', 'setting')) || 0;
    my $lvl = $APP->getLevel($USER) || 0;
    my $tV = $VOTES ? $$VOTES{$lvl} : 0; $tV = 0 if $tV eq 'NONE';
    my $tC = $COOLS ? $$COOLS{$lvl} : 0; $tC = 0 if $tC eq 'NONE';
    return '<strong>'.$v.'</strong><small> / '.$tV.'</small> votes &nbsp; | &nbsp; <strong>'.$c.'</strong><small> / '.$tC.'</small> C!s';
  };

  local *infoDefault = sub {
    my $k = $_[0] || '';
    my $v = $$SETTINGS{$k} ? $$SETTINGS{$k} : $$NODE{$k};
    $v = $APP->htmlScreen($v) unless(grep {/$k/} @noHTMLSCREEN);
    return parseLinks($v);
  };

  #titles of info things to display
  my %prettyTitles = (
    createtime=>'user since',
    last=>'last seen',
    nwriteups=>'number of write-ups',
    recentwriteups=>'number of write-ups within last year',
    level=>'level / experience',
    gp=>'GP',
    mission=>'mission drive within everything',
    specialties=>'specialties',
    employment=>'school/company',
    motto=>'motto',
    groups=>'member of',
    categories=>'categories maintained',
    lastnoded=>'most recent writeup',
    # msgme=>'/msg me',	#set for each user, below
    msgyou=>'/msgs from me',
    draftshare=>'things in progress',
    msgalias=>'is a messaging forward for',
    manip=>'manipulation',
    coolsspent=>'C!s spent',
    presents=>'your daily votes and C!s',
  );

  if($isMe)
  {
    $prettyTitles{msgme} = '/msg yourself';
    $prettyTitles{msgyou} = 'talking to yourself';
  } else {
    my $t=$$NODE{title};
    $t=~tr/ /_/;
    $prettyTitles{msgme} = 'Send private message to '.$$NODE{title};
  }

 my %specialDisplays = (
    msgalias=>\&info_msgalias,
    last=>\&info_last,
    groups=>\&info_groups,
    categories=>\&info_categories,
    recentwriteups=>\&info_recentwriteups,
    gp=>\&info_gp,
    msgme=>,\&info_msgme,
    msgyou=>,\&info_msgyou,
    presents=>\&info_presents,
    lastnoded=>\&info_lastnoded,
    draftshare=>\&info_draftshare,
    manip=>\&info_manip,
  );

  unless(($nid==220) ||($nid==322)) {	#hack around nate and hemos
    $specialDisplays{'createtime'} = \&info_usersince;
  }

  #build result
  my $str = '';
  my $locker = getNodeById($$NODE{acctlock});
  $str .= '<big><strong>Account locked</strong></big> by '.linkNode($locker).'<br>' if($APP->isEditor($USER) && $$NODE{acctlock} != 0);
  my $t = undef; #nice Title
  my $s = undef; #which Sub to call
  my $r = undef; #Result of sub call

  $str .=  qq'<dl id="userinfo">\n';

  foreach my $k (@showThings)
  {
    $t = $prettyTitles{$k} || $k;
    $s = $specialDisplays{$k} || \&infoDefault; #TODO generate function by title name, if doesn't exist, do default stuff
    $r = &$s($k);
    if($r) { $str .= $textPre . $t . $textMid . $r . $textPost; }
  }
  $str .=  "</dl>\n";

  return $str;

}

sub coolcount
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  
  my $user_id = shift;
  return $DB->sqlSelect("count(*)","coolwriteups JOIN node ON coolwriteups_id = node_id","author_user=$user_id and type_nodetype=117");
}

sub ilikeit
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if(not $APP->isGuest($USER) or $APP->isSpider());

  my ($WU) = @_;
  return unless(getRef($WU) and $$WU{type}{title} eq 'writeup');

  my $addr = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{REMOTE_ADDR} || undef;
  my $likeExists = $DB->sqlSelect("count(*)","likedit","likedit_ip = '$addr' and likedit_node=$$WU{node_id}");
  return " <b>Thanks!</b>" if $likeExists || 
    ( $query->param('op') eq 'ilikeit' && $query->param("like_id") == $$WU{node_id} );

  return linkNode($NODE,'I like it!', {confirmop => 'ilikeit', like_id => $$WU{node_id},
    -id => "like$$WU{node_id}",
    -class => "action ajax like$$WU{node_id}:ilikeit:$$WU{node_id}:",
    -title => 'send a message to the author telling them someone likes their work'} );

}

sub socialBookmarks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # returns a series of social bookmarking links.

  my ($targetNode, $includeTitles, $asList, $full) = @_;
  getRef $targetNode;
  $targetNode = $NODE unless $targetNode;
  my $titleNode = $targetNode;
  my $parentNode = undef;
  $parentNode = getNode($$targetNode{parent_e2node}) if $$targetNode{parent_e2node};
  $titleNode = $parentNode if $parentNode;
  my $bDontQuoteUrl = 1;
  my $url = "";
  $url = 'http://' . $1 if $ENV{HTTP_HOST} =~ /(?:.+?\.)($Everything::CONF->canonical_web_server)(?::\d+)/;
  $url = 'http://' . $Everything::CONF->canonical_web_server if $url eq '';
  $url .= urlGen({ }, $bDontQuoteUrl, $targetNode);
  my $title = $$titleNode{title};

  my $str = '';

  my @defaultNetworks = ('twitter', 'facebook', 'delicious', 'digg', 'stumbleupon', 'reddit');

  my @allNetworks = ('twitter', 'facebook', 'delicious', 'yahoomyweb', 'googlebookmarks', 'blinklist', 'magnolia', 'windowslive', 'digg', 'propellor', 'stumbleupon', 'technorati', 'newsvine', 'reddit');

  my @showNetworks = @defaultNetworks;
  @showNetworks = @allNetworks if $full;

  my $yahooTitle = $title;
  $yahooTitle =~ s/ /\+/g;

  my $twitterUrl = htmlcode('create short url', $targetNode); 

  my $deplussedUrl = $url;
  $deplussedUrl =~ s/[ \+]|%2B/%20/g;
  $deplussedUrl = CGI::escape($deplussedUrl);
  my $stumbleUrl = $deplussedUrl;
  my $diggUrl = $deplussedUrl;
  my $propellorUrl = $deplussedUrl;

  my $socialSites = {
    'delicious' => {
      posturl => 'http://del.icio.us/post'
        , params => { 'title' => $title, 'url' => $url }
        , classname => 'social_delicious'
        , listname => 'del.icio.us'
        , imagename => 'delicious.gif'
      },
    'facebook' => {
      posturl => 'http://www.facebook.com/share.php'
        , params => { 't' => $title, 'u' => $url }
        , classname => 'social_facebook'
        , listname => 'Facebook'
        , imagename => 'facebook.gif'
     },
    'yahoomyweb' => {
      posturl => 'http://myweb2.search.yahoo.com/myresults/bookmarklet'
        , params => { 't' => $yahooTitle, 'u' => $url }
        , classname => 'social_yahoo'
        , listname => 'Yahoo! Bookmarks'
        , imagename => 'yahoo_myweb.gif'
      },
    'googlebookmarks' => {
      posturl => 'http://www.google.com/bookmarks/mark'
        , params => { 'op' => 'edit', 'title' => $title, 'bkmk' => $url }
        , classname => 'social_googlebookmarks'
        , listname => 'Google Bookmarks'
        , imagename => 'google_bmarks.gif'
      },
    'googleplus' => {
      posturl => 'https://plus.google.com/share'
        , params => { 'title' => $title, 'url' => $url }
        , classname => 'social_googleplus'
        , listname => 'Google Plus'
        , imagename => 'google_bmarks.gif'
    },
    'blinklist' => {
      posturl => 'http://blinklist.com/blink'
        , params => { 't' => $title, 'u' => $url, 'v' => '2' }
        , classname => 'social_blinklist'
        , listname => 'BlinkList'
        , imagename => 'blinklist.gif'
    },
    'magnolia' => {
      posturl => 'http://ma.gnolia.com/bookmarklet/add'
        , params => { 'title' => $title, 'url' => $url }
        , classname => 'social_magnolia'
        , listname => 'ma.gnol.ia'
        , imagename => 'magnolia.gif'
    },
    'windowslive' => {
      posturl => 'https://favorites.live.com/quickadd.aspx'
        , params => { 'marklet' => 1, 'mkt' => 'en-us', 'title' => $title, 'url' => $url, "top" => 1 }
        , classname => 'social_windowslive'
        , listname => 'Windows Live'
        , imagename => 'windows_live.gif'
    },
    'digg' => {
      posturl => 'http://digg.com/submit'
        , params => { 'phase' => 2, 'title' => $title, 'url' => $diggUrl }
        , classname => 'social_digg'
        , listname => 'Digg'
        , imagename => 'digg.gif'
    },
    'propellor' => {
      posturl => 'http://www.propeller.com/story/submit/'
        , params => { 'title' => $title, 'url' => $propellorUrl }
        , classname => 'social_propellor'
        , listname => 'Propellor'
        , imagename => 'propellor-from-wide-submit.gif'
      },
    'netscape' => {
      posturl => 'http://www.netscape.com/submit/'
        , params => { 'T' => $title, 'U' => $url }
        , classname => 'social_netscape'
        , listname => 'Netscape'
        , imagename => 'netscape.gif'
        , discontinued => 'netscape became Propellor in Sep. 2007'
    },
    'stumbleupon' => {
      posturl => 'http://www.stumbleupon.com/submit'
        , params => { 'title' => $title, 'url' => $stumbleUrl }
        , classname => 'social_stumbleupon'
        , listname => 'StumbleUpon'
        , imagename => 'stumbleupon.gif'
    },
    'technorati' => {
      posturl => 'http://www.technorati.com/faves'
        , params => { 'add' => $url }
        , classname => 'social_technorati'
        , listname => 'Technorati'
        , imagename => 'technorati.gif'
    },
    'newsvine' => {
      posturl => 'http://www.newsvine.com/_wine/save'
        , params => { 'h' => $title, 'u' => $url }
        , classname => 'social_newsvine'
        , listname => 'Newsvine'
        , imagename => 'newsvine.gif'
    },
    'reddit' => {
      posturl => 'http://www.reddit.com/submit'
      , params => { 'title' => $title, 'url' => $url }
      , classname => 'social_reddit'
      , listname => 'Reddit'
      , imagename => 'reddit.gif'
    },
    'tailrank' => {
      posturl => 'http://tailrank.com/share/'
      , params => { 'title' => $title, 'link_href' => $url }
      , classname => 'social_tailrank'
      , listname => 'TailRank'
      , imagename => 'tailrank.gif'
      , discontinued => 'TailRank was discontinued in June 2009'
    },
    'twitter' => {
      posturl => 'http://twitter.com/home'
      , params => { 'status' => "$title - $twitterUrl" }
      , classname => 'social_twitter'
      , listname => 'Twitter'
      , imagename => 'twitter-a.gif'
     }
  };

  my $makeSocialLink = sub {
    my ($networkName, $localurl, $localtitle, $localincludeTitles, $showAsList) = @_;
    my $link = '';
    my $site = $$socialSites{$networkName};

    my $postUrl = $$site{posturl}. '?'. (join '&', map{ $_ . '=' . $$site{params}->{$_} } keys %{$$site{params}});

    $link =
    "<a href=\"$postUrl\""
      . ' title="' . $$site{listname} . '"'
      . ' target="_new" onClick="window.location=\''
      . urlGen(
        {
          'node_id'         => $$NODE{node_id}
          , 'op'            => 'socialBookmark'
          , 'bookmark_site' => $networkName
        }
        , $bDontQuoteUrl
      )
    . "'\">";

    my $bookmarkCode = "<div class=\"social_button social_$networkName\">" . $link . "</a></div>\n";
    $bookmarkCode .= $link . "$$site{listname}</a>\n" if $localincludeTitles;
    $bookmarkCode = "<li>\n\t$bookmarkCode</li>\n" if $showAsList;
    return $bookmarkCode;
  };

  $str .= join '', map { &$makeSocialLink($_, $url, $title, $includeTitles, $asList); } @showNetworks;
  $str = "<ul class=\"bookmarkList\">\n$str</ul>\n" if $asList;
  return $str;

}

sub epicenterZen
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if ( $APP->isGuest($USER) );

  my @thingys = ();
  my $votesLeftStr = "";

  my $isRoot = $APP->isAdmin($USER);
  my $isEd = $APP->isEditor($USER);

  my $c = $$VARS{cools} || 0;
  my $v = $$USER{votesleft} || 0;
  if($v !~ /^\d+$/)
  {
    $v = 0;
  }
  if (int $c || int $v)
  {
    if(int $c)
    { 
      push @thingys, '<strong id="chingsleft">'.$c.'</strong> C!'.($c>1?'s':'');
    }
	
    if(int $v)
    {
      push @thingys, '<strong id="votesleft">'.$v.'</strong> vote'.($v>1?'s':'');
    }
  }

  if (scalar(@thingys))
  {
    $votesLeftStr = "\n\n\t".'<span id="voteInfo">You have ' . join(' and ',@thingys) . ' left today.</span>';
  }

  my @xps = grep { /\S/ } ( htmlcode('shownewexp', 1), htmlcode('showNewGP', 1) );
  my $expStr = '';

  if (scalar @xps)
  {
    $expStr .= '<span id="experience">'. join(' | ', @xps). '</span>';
  }

  $expStr =~ s/<br ?\/?>/ | /g;

  my @ifys = ();
  push(@ifys, linkNode(getNode('chatterlight','fullpage'),'chat'));
  push(@ifys, linkNode(getNode('message inbox','superdoc'),'inbox'));

  my $opStr = join(" | ",@ifys);

  return "<div id='epicenter_zen'><span id='epicenter_zen_info'>
    ".linkNode($USER,0,{lastnode_id=>0})."
    | ".linkNode($NODE, 'Log Out', {op=>'logout'})."
    | ".linkNode($Everything::CONF->user_settings, 'Preferences',{lastnode_id=>0})."
    | ".linkNode(getNode('Drafts','superdoc'))."
    | ".linkNode(getNode('Everything2 Help','e2node'), 'Help')."
    | ".htmlcode('randomnode','Random')."
    </span>
    <br />
    $votesLeftStr<br />
    $expStr<br />
    <span id='epicenter_zen_commands'>
    $opStr
    </span>
    </div>";
}

sub borgspeak
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($useBorg) = @_;
  my $EDB = 100;

  if ($useBorg)
  {
    $EDB = int(rand(100));
  }

  my $response = '<i>and all is quiet...</i>';

  if($EDB<25)
  {
    my @borgspeak = (
      'grrrrr...', '/me hungry!', '/me smells blood',
      "$$USER{title} looks tasty.",
      '<i>you feel its eyes watching you</i>',
      '/me is watching you',
      '/me coughs politely and eats your soul',
      '/me tries to bite your toe',
      '/me starts eating your hair',
      '/me whispers the names of forgotten demons in your ear',
      "mmmm $$USER{title} food",
      '/me haunts your darkest nightmares',
      'me hungry!',
      "/me sniffs $$USER{title} appraisingly",
      "/me wants fresh noder flesh"
    );

    $response = $borgspeak[int(rand(@borgspeak))];

    my $edblink = linkNodeTitle('EDB');
    if($response =~ /\/me/)
    {
      $response =~ s/\/me /<i>$edblink /;
      $response .= '</i>';
    } else {
      $response = "&lt;$edblink&gt; " . $response;
    }
  }

  return $response;
}

sub addNotification
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return $APP->add_notification(@_);
}

sub verifyRequest
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # checks that the form was a real e2 one
  my ($prefix) = @_;

  my $seed = $query->param($prefix . '_seed');
  $seed = '' if not defined($seed);
  my $test = md5_hex($$USER{passwd} . ' ' . $$USER{email} . $seed);
  return (defined($query->param($prefix . '_nonce')) and $test eq $query->param($prefix . '_nonce')) ? 1 : 0;
}

sub verifyRequestForm
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # Generates the form fields used to verify the form submission. Pass a prefix.
  my ($prefix) = @_;
  my $rand = rand(999999999);
  my $nonce = md5_hex($$USER{passwd} . ' ' . $$USER{email} . $rand);

  return $query->hidden($prefix . '_nonce', $nonce) . $query->hidden($prefix . '_seed', $rand);
}

sub messageBox 
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($userID, $showCC, $messageID, $usergroupID, $failReasonRef) = @_;
  # This should probably be extended to include a possible topic

  my $dummyReason = undef;
  $failReasonRef = \$dummyReason unless $failReasonRef;

  if ($APP->isGuest($USER)) {
    $$failReasonRef = "You are not logged in.";
    return;
  } elsif ($VARS->{borged}) {
    $$failReasonRef = "You are borged and so may not talk now.";
    return;
    # The hidemsgme setting is only valid on homenodes, but this htmlcode is
    #  used elsewhere.  Presume a $messageId will be passed in other cases
  } elsif ($VARS->{hidemsgme} && !$messageID) {
    $$failReasonRef = "This user disabled the homenode message box.";
    return;
  }

  my $n = getNodeById($userID)->{title};
  if ($n eq 'EDB' || $n eq 'Klaproth' || $n eq 'Cool Man Eddie' || $n eq 'Guest User')
  {
    $$failReasonRef = "This user is a robot and can not receive your message.";
    return;
  }

  my $isMe=($$USER{node_id}==$userID);
  my $qp='msguser_'.$userID;
  my $str='';
  if(!$isMe && $$VARS{borged})
  {
    $str = '(you may not talk now)';
  } elsif($userID && (defined $query->param($qp)) && (length($query->param($qp))) ) {
    my $msg = $query->param($qp);
    my $ccMe = (defined $query->param('cc'.$qp)) && ($query->param('cc'.$qp) eq '1') ? 1 : 0;

    my $recipient=$userID;
    if (defined($usergroupID) && (defined $query->param("ug$usergroupID")) && (length($query->param("ug$usergroupID"))) )
    {
        $recipient=$usergroupID;
    }

    my $failMessage = htmlcode('sendPrivateMessage',{
      'recipient_id'=>$recipient,
      'message'=>$msg,
      'ccself'=>$ccMe,});
    undef $failMessage unless (defined $failMessage) && (length($failMessage));

    if(defined $failMessage)
    {
      $str = '<strong>Error</strong>: unable to send message "'.$msg.'": '.$failMessage;
    } else {
      $query->param($qp,'');  #clear text field
      $str = $msg;
      $str = $APP->escapeAngleBrackets($str);
      $str = parseLinks($str,0,1) unless $$VARS{showRawPrivateMsg};
      $str = '<small>You said "</small>'.$str.'<small>" to '.linkNode($recipient).'.</small>';
    }
    $str .= "<br />\n";
  }

  $messageID = "" if not defined($messageID);

  $str = "<div class='messageBox' id='replyto$messageID'><span id='sent$messageID'></span>" . $str . htmlcode('openform');
  if ($showCC)
  {
    $str .= $query->checkbox('cc'.$qp,'','1','CC ');
  }

  $str .= $query->hidden( 'showwidget' , $messageID);
  $str .= $query->hidden( 'ajaxTrigger', 1);

  my $sendName='Send'; # Unless it's a usergroup message...
  if ($usergroupID)
  {
    $sendName='Send to user';
  }

  $usergroupID = "" if not defined($usergroupID);

  $str .= $query->textfield(-name=>$qp, class=>"expandable ajax replyto$messageID:messageBox:$userID,$showCC,$messageID,$usergroupID", size=>20, maxlength=>1234 );
  $str .= ' ' .$query->submit('message send', $sendName);
  if ($usergroupID)
  {
    $str.=$query->button(-name=>'send_to_all',-value=>'Send to group', -onClick=>'$'."('#replyto$messageID > form > textarea').after('".$query->hidden("ug$usergroupID",1)."'); ".'$'."('#replyto$messageID > form').submit();");
  }

  $str .= $query->end_form() . '</div>';
  return $str;

}

sub socialBookmark
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($nodeID, $includeTitles, $asList, $myTitle, $sbURL, $sbTitle, $imgTitle)=@_;

  my $myurl="http://everything2.com/node/".$nodeID;
  my $str = undef;
  $str.="<li>" if $asList;
  $str.=" <a href=\"http://furl.net/storeIt.jsp?u=".$myurl."&t=".$myTitle."\" target=\"_new\" onClick=\"window.location='".urlGen({'node_id'=>$$NODE{node_id}, 'op'=>'socialBookmark','bookmark_site'=>'$sbTitle'},1)."'\"> $sbTitle</a>" if ($includeTitles);
  $str.="</li>" if $asList;

  return $str;
}

sub showNewGP
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($shownumbers, $isxml, $newwuonly) = @_;
  return if $APP->isGuest($USER);

  #send TRUE if you want people to see how much GP they gained/lost
  unless($$VARS{oldGP})
  {
    $$VARS{oldGP} = $$USER{GP};
  }

  return if ($$VARS{oldGP} == $$USER{GP} and not $newwuonly);
  my $VSETTINGS = getVars(getNode('vote settings', 'setting'));

  my $str = undef;
  my $header = $$VSETTINGS{showExpHeader};
  my $footer = $$VSETTINGS{showExpFooter};
  my $newGP = $$USER{GP} - $$VARS{oldGP};

  ($header, $footer) = ('', '');

  my $xmlstr = undef;
  $xmlstr = '<gpinfo>' if $isxml;
  $xmlstr .= "<gpchange value=\"$newGP\">$$USER{GP}</gpchange>" if $isxml;

  $str.=$header;
  unless($newwuonly)
  {
    my $gpNotify = $newGP;

    if($newGP > 0)
    {
      $str.='Yay! You gained ';
    } else {
      $$VARS{oldGP} = $$USER{GP};
      return;
      # $str.='Ack! You lost ';
      # $newGP= -$newGP; # Positize for display only
    }

    #htmlcode('achievementsByType','egperience');

    my $notification = getNode('GP','notification')->{node_id};
    if ($$VARS{settings})
    {
      my $all_notifications = from_json($$VARS{settings})->{notifications};
      if ($all_notifications->{$notification})
      {
        my $argSet = { amount => $gpNotify };
        my $argStr = to_json($argSet);
        my $addNotifier = htmlcode('addNotification', $notification,$$USER{user_id},$argStr);
      }
    }

    if ($shownumbers)
    {
      if ($newGP > 1)
      {
        $str.='<strong>'.$newGP.'</strong> GP!';
      } else {
        $str.='<strong>1</strong> GP.';
      }
    } else {
      $str.='GP!';
    }

  } # (end) unless($newwuonly)

  $$VARS{oldGP} = $$USER{GP};
  #reset the new GP flag

  my $lvl = $APP->getLevel($USER)+1;


  $xmlstr.='</gpinfo>' if $isxml;

  return $xmlstr if $isxml;
  return $str.$footer;
}

sub uploadAudio
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($field) =@_;
  return if $APP->isSuspended($NODE,"audio");

  my $str ='';
  my $name = $field.'_file';
  my $tmpfile = '/tmp/everythingaudio' . int(rand(10000)); 
  my $imagedir = '/usr/local/everything/www/audio';

  my $imageurl = 'audio/';
  my $sizelimit = 8000000;
  $sizelimit = 16000000 if isGod($USER);

  my $fname = $query->upload($name);
  if($fname)
  {
    my $imgname = $$NODE{title};
    $imgname =~ s/\W/_/gs;
  
    UNIVERSAL::isa($query->uploadInfo($fname),"HASH") or return "File upload failed. If this persists, contact an administrator.";
    my $content = $query->uploadInfo($fname)->{'Content-Type'};
    unless ($content =~ /(mp3|mpg3|ogg|audio\/mpeg)$/)
    {
      return "this doesn't look like an mp3 (or an Ogg Vorbis) - it seems to be a $content!" 
    }
    $imgname .= '.'.$1;

    my $size = undef;
    $str.= "Got: ".(ref $fname)."<br>$content<br>";
  
    {
      # local $/ = undef;
      my $buf = join ('', <$fname>);
      $size = length($buf);
      if($size > $sizelimit)
      {
        return "your image is too big.  Our current limit is $sizelimit bytes";
      }

      my $outfile;
      open $outfile, ">","$tmpfile";
      print $outfile $buf;
      close $outfile;
    }
	
    system "/bin/mv $tmpfile $imagedir/$imgname";
    $$NODE{$field} = $imageurl.$imgname;
    $DB->updateNode ($NODE, $USER); #this is probably unnecesssary
  
    $DB->getDatabaseHandle()->do('replace newuserimage set newuserimage_id='.getId($NODE)); # Not sure what this bit does

    $str.="$size bytes received!  " . $tmpfile;
  } else {
    $str.="Please only upload mp3s of 8MB or less, and only recordings of content you <em>explicitly have permission to record</em> - ".linkNodeTitle('be cool');
    $str.=$query->filefield($name);
  }

  return $str;
}

sub addnodeforward
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  return htmlcode('openform').'<fieldset><legend>Add node forward</legend>
    <input type="hidden" name="op" value="new">
    <input type="hidden" name="type" value="node_forward">
    <input type="hidden" name="node" id="new_node_title" value="'.$$NODE{title}.'">
    <label>Forward node to:
    <input type="text" name="forward_to_node"></label>
    <input type="submit" value="Add forward">
    </fieldset>
    </form>';
}

# TODO: Recheck all of these after e2nodes are in templates

sub page_actions
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $disabled = shift;

  my $c = undef;
  my @actions = () ;
  push @actions , $c if $APP->can_edcool($NODE) and $c = htmlcode('coolit','') ;

  if ($$NODE{type}{title} eq 'user')
  {
    my $minLevel = 11;
    my $Sanctificity = 10;
    push @actions , linkNode($NODE, 'sanctify', {op=>'sanctify', -title => "Give 'em 10GP!",
      -id => 'sanctify', -class => 'ajax (sanctify):ajaxEcho:Sanctified!'})
      if !$$VARS{GPoptout} && $$USER{title} ne $$NODE{title} &&
      $APP->getLevel($USER) >= $minLevel && $$USER{GP} >= $Sanctificity;
    my $favorite_noder = htmlcode('favorite_noder');
    push @actions , $favorite_noder if($favorite_noder);
  }

  my $bookmark_add = ""; $bookmark_add = htmlcode('bookmarkit' , $NODE , 'Add to bookmarks' ) if $APP->can_bookmark($NODE);
  my $categoryform = ""; $categoryform = htmlcode( 'categoryform' ) if $APP->can_category_add($NODE) ;
  my $w = ""; $w = htmlcode( 'weblogform' ) if($$NODE{type}{sqltablelist} =~ /document/ and $$VARS{can_weblog} and $APP->can_weblog($NODE));

  my $title = 'Add this '.( $$NODE{ type }{ title } eq 'e2node' ? 'entire page' : $$NODE{ type }{ title } ).' to a ' ;

  unless ( $query -> param( 'addto' ) )
  {
    push @actions , $bookmark_add if $bookmark_add ;
    push @actions , htmlcode( 'widget' , $categoryform , 'form' , 'Add to category&hellip;' ,
      { showwidget => 'category' , -title => $title.'category' } ) if $categoryform ;
    push @actions , htmlcode( 'widget' , $w , 'form' , 'Add to page&hellip;' ,
      { showwidget => 'weblog' , -title => $title.' usergroup page' } ) if  $w ;
  } else {
    push @actions , htmlcode( 'widget' ,
      $query -> hidden( 'addto' )."<small>$bookmark_add</small><hr>\n$categoryform\n$w" , 'form' , 'Add to&hellip;' ,
      { showwidget => 'addto'.$$NODE{ node_id } , -title => $title.'category or usergroup page' } ) ;
  }

  return '<ul class="topic actions"><li>' . join( "</li>\n<li>" , @actions ) . "</li>\n</ul>\n" if @actions ;
  return '' ;
}

sub writeupmessage
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($queryid, $N) = @_ ;
  getRef $N ;
  $N ||= $NODE ;

  my $msg = $query->param($queryid) ;
  my $wutitle = $$N{ title } ;
  $wutitle =~ s/ \(\w+\)$// ;

  my $msgreport = htmlcode('sendPrivateMessage', {
    'recipient_id'=>$$N{ author_user },
    'message'=>$msg,
    'ccself'=>( $query->param('cc'.$queryid) ? 1 : 0 ) ,
    'renode'=>$wutitle });

  if( $msgreport )
  {
    $msgreport = ' <strong>Error</strong>: unable to send writeup message "'.$msg.'": '.$msgreport ;
  } else {
    $query -> Delete($queryid);
    $msgreport = $msg;
    $msgreport =~ s/\</&lt;/g;
    $msgreport =~ s/\>/&gt;/g;
    htmlcode('addNodenote', $query -> param("nn$queryid"), qq'messaged: "$msgreport"', $USER) if $query -> param("nn$queryid");
    $msgreport = '<strong>Sent writeup message: </strong>'.parseLinks( $msgreport , $$N{parent} ) ;
  }

  return qq'<p id="sent$queryid" class="sentmessage">$msgreport</p>'

}

sub canseewriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N) = @_ ;
  $N ||= $NODE ;

  my $isTarget = undef; $isTarget = delete $PAGELOAD->{notshown}->{targetauthor} if defined($PAGELOAD->{notshown}) and defined($PAGELOAD->{notshown}->{targetauthor}) and $PAGELOAD->{notshown}->{targetauthor} == $$N{author_user};

  if ($$N{author_user} == $$USER{user_id}){
    $PAGELOAD->{my_writeup} ||= $N if $$NODE{type}{title} eq 'e2node'; # used by [addwriteup]
    return 1;
  }

  my $param = $query ? $query->param( 'showhidden' ) : "";
  $param ||= "";
  my @checks = ('unfavorite', 'lowrep');

  if ($$N{type}{title} eq 'draft'){
    return 0 if($APP->isGuest($USER) or not $APP->canSeeDraft($USER, $N, 'find'));
    unshift @checks, 'unpublished';
  }

  return 1 if $$NODE{node_id} == $$N{node_id} or $isTarget or $param eq $$N{node_id} or $param eq 'all';

  my %tests = (
    unpublished => sub{
      getNodeById($$N{publication_status}) -> {title} eq 'review' && $APP->isEditor($USER);
      },

    unfavorite => sub{ # disliked authors
      !$$VARS{ unfavoriteusers } ||
      $$VARS{ unfavoriteusers } !~ /\b$$N{author_user}\b/ ;
      },

    lowrep => sub{ # reputation threshold
      my $threshold = $Everything::CONF->writeuplowrepthreshold || 'none' ;
      $threshold = $$VARS{ repThreshold } || '0' if exists $$VARS{ repThreshold } ; # ecore stores 0 as ''
      $threshold eq 'none' or $$N{reputation} > $threshold;
      }
  );

  foreach ( @checks )
  {
    # not keys because priority order is important
    unless ( &{ $tests{$_} } )
    {
      return 1 if $param eq $_ ; # this is the reason it was hidden; we want it shown
      push @{ $PAGELOAD->{notshown}->{$_} }, $N if defined $PAGELOAD->{notshown} and defined $PAGELOAD->{notshown}->{$_} ;
      return 0 ;
    }
  }

  return 1 ;
}

sub checkInfected
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # infection arises if user has an old login cookie belonging to a locked account

  return 1 if $$VARS{infected};

  # if logged on, no old cookie
  return 0 unless $APP -> isGuest($USER) && $query;

  my $loginCookie = $query->cookie($Everything::CONF->cookiepass);

  return 0 unless $loginCookie;

  my ($user_name) = split(/\|/, $loginCookie);
  my $check_user = getNode($user_name, 'user');

  return 1 if $check_user && $$check_user{acctlock};

  return 0;

}

sub confirmop
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $N = $query -> param('like_id') || $query -> param( 'cool_id' ) || $query -> param( 'ins_id' ) || $query -> param('cure_user_id');
  my $node = undef; $node = getNodeById( $N ) if $N;
  my $author = ''; $author = getNode( $$node{ author_user } ) if $node ;
  $author = $$author{ title } if $author ;

  my $polehash_seed = $query -> param('polehash_seed');
  my $author_to_remove = $query->param('author');
  $author_to_remove = $APP->encodeHTML($author_to_remove);

  my $confirmop = $query->param('confirmop');

  my %opcodes = (
    cool => "cool $author"."'s writeup" ,
    uncoolme => 'uncool this node',
    insure => "remove the insurance on $author"."'s writeup",
    ilikeit => "send $author a message saying you like their work",
    cure_infection => "remove ${author}'s infection",
    nuke => "delete this $$NODE{type}{title}",
    nukedraft => "delete this draft",
    remove => !$polehash_seed ? "return this/these writeups to draft status"
	: "smite $author_to_remove for a vile spammer"
    , leavegroup => 'leave this usergroup'
    , usernames => 'detonate ' . $query->escapeHTML($confirmop)
  );

  my $str = '<fieldset><legend>Confirm</legend>
    <p>Do you really want to '.(
    $opcodes{ $query -> param( 'confirmop' ) } ||
    $opcodes{ $query -> param( 'notanop' ) } ||
    'do this'
    ).'?</p>' ;

  my $paramname = $query -> param( 'notanop' ) || 'op' ;
  my $paramvalue = $query -> param( 'confirmop' ) ;
  $query -> delete( 'confirmop' , 'op' , 'notanop' ) ;
  $str .= qq'<button name="$paramname" value="$paramvalue" type="submit">OK</button>' ;
  foreach ( $query -> param )
  {
    $str .= $query -> hidden( $_ ) if $query -> param( $_ ) ;
  }
  $str .= '</fieldset>' ;

  return htmlcode( 'widget' , $str , 'form' , '' , { showwidget => '' } ) ;
}

sub repair_e2node
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "" unless $APP->isEditor($USER);
  my ($syncnode, $no_order) = @_;
  $APP->repairE2Node($syncnode,$no_order);

  
  return "repaired and reordered" unless $no_order;
  return "repaired";

}

sub movenodelet
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # moves a nodelet to a position (top=0)
  # position=x removes nodelet (unless it's Master Control and the user is Godlike)
  # position=after<nodelet number> puts it after nodelet, if nodelet present
  # position=before<nodelet number>n puts it before nodelet, ditto
  # no position/invalid position: put it at the bottom

  my ($nodelet, $position) = @_;
  $nodelet = getNode($nodelet, 'nodelet')->{node_id} if $nodelet =~ /\D/;

  return unless($nodelet and (getNodeById($nodelet)->{type}->{title} eq 'nodelet') and not $APP->isGuest($USER) and ($USER->{title} ne 'everyone'));

  return if($position eq 'x' and ( $APP->isEditor($USER) ) and $nodelet == getNode('Master Control', 'nodelet')->{node_id});

  $$VARS{nodelets} =~ s/(?:(^|,),+)|(?:\b$nodelet\b,*)|(?:,*$)/$1/g ;
  return if $position eq 'x' ;

  if ( $position =~ /^(before|after)(\d*)$/ )
  {
    my $find = $2 ;
    my $replace = ( $1 eq 'before' ? "$nodelet,$find" : "$find,$nodelet" ) ;
    $$VARS{nodelets} =~ s/\b$find\b/$replace/ ;
  } elsif ( int $position ) {
    $$VARS{nodelets} =~ s/^((?:(?:^|,)\d+\b){$position})/$1,$nodelet/ ;
  } elsif ( $position eq '0' ){
    $$VARS{nodelets} = "$nodelet,$$VARS{nodelets}" ;
  }

  $$VARS{nodelets} = "$$VARS{nodelets},$nodelet" unless $$VARS{nodelets} =~ /\b$nodelet\b/ ;
  return $VARS->{nodelets};
}

sub isInfected
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
 
  my ($patient) = @_;
  getRef $patient;
  my $patientVars = getVars($patient);
  return (defined($$patientVars{infected}) and $$patientVars{infected} == 1);

}

sub editwriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N, $message) = @_;

  $message = "" unless(defined($message));
  $N ||= {};
  my $type = $$N{type}{title} || 'draft';
  my $new = !$$N{node_id};

  my $str = '<fieldset><legend>';

  if ($new){
    $str .= 'New draft';
    $str .= '/writeup' if $type eq 'writeup';
  }else{
    $str .= 'Edit '.($$N{author_user} == $$USER{node_id} ? 'your ' : 'this ').$type;
  }

  $str .= '</legend>';

  if ($type eq 'draft' and $$NODE{type}{title} ne 'e2node')
  {
    $str .= '<label>Title:'.$query -> textfield(
      -name => 'draft_title',
      class => 'draft_title',
      value => $$N{title},
      -force => 1,
      size => 80).'</label><br>';
    $str .= '<small>You already have a draft or writeup called '
      .linkNode((getNodeWhere({title => $query -> param('draft_title'),
        author_user => $$N{author_user}}, 'draft'))[0] ||
      getNode($query -> param('draft_title'), 'e2node')).'.</small>'
	if(scalar($query->param('draft_title')) && $APP->cleanNodeName(scalar $query->param('draft_title')) ne $$N{title});
  }

  $str .= qq'<textarea name="${type}_doctext" id="writeup_doctext" '.htmlcode('customtextarea', '1').' class="formattable">'.$APP->encodeHTML($$N{doctext}).'</textarea>'.$message;

  my $setType = ""; $setType = "\n<p>".htmlcode('setwriteuptype', $$N{wrtype_writeuptype})."</p>" if $type eq 'writeup' && !$APP->isMaintenanceNode($N);

  unless ($new)
  {
    $str .= $setType.$query -> submit('sexisgood', "Update $type");
  }else{
    $str .= '<input type="hidden" name="op" value="new"><p>';

    if ($type eq 'draft')
    {
      $str .= $query -> submit('sexisgood', 'Create draft')
        .'<input type="hidden" name="type" value="draft"></p>';
    }else{
      $str .= $query ->submit('sexisgood', 'submit')
        .' '.($APP->isMaintenanceNode($N)? '(post immediately as maintenance writeup)'.$query -> hidden('type', 'writeup').$query -> hidden('writeup_notnew', '1')
        : $query -> radio_group(
          -name => 'type',
          values => ['draft', 'writeup'],
          labels => {draft => 'post as draft', writeup => 'publish immediately'},
          default => $$VARS{defaultpostwriteup} ? 'writeup' : 'draft',
          force => 1
        )).'</p>'.$setType;
    }
  }

  return "$str<p class='edithelp'><strong>Some Helpful Links:</strong>".parseLinks('[E2 HTML Tags] &middot;[HTML Symbol Reference] &middot;
    [Using Unicode on E2] &middot;[Reference Desk]</p></fieldset>');

}

sub listnodecategories
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($originalN, $isIncludedParent) = @_;
  my $N = $originalN || $NODE;
  getRef $N;
  my $nodeid = $$N{node_id};

  my $category_nodeid = getType('category')->{node_id};
  my $catlinktype = getNode('category', 'linktype')->{node_id};

  my $dbh = $DB->getDatabaseHandle();
  return 'No database handle!' unless $dbh;
  my $sql = "SELECT node.node_id, node.author_user
    FROM node, links
    WHERE node.node_id = links.from_node
    AND links.to_node = $nodeid
    AND node.type_nodetype = $category_nodeid
    AND links.linktype = $catlinktype";

  my $ds = $dbh->prepare($sql);
  $ds->execute() or return $ds->errstr;

  my @items = ();
  while(my $row = $ds->fetchrow_hashref)
  {
    $sql = "SELECT node.node_id
      FROM node, links
      WHERE node.node_id = links.to_node
      AND links.from_node = $$row{node_id}
      AND links.linktype = $catlinktype
      ORDER BY links.food, node.title, node.type_nodetype";
    my $ids = $dbh->prepare($sql);
    $ids->execute() or return $ids->errstr;
    my $prev = -2;
    my $next = -2;
    while (my $irow = $ids->fetchrow_hashref)
    {
      if ($$irow{node_id} == $nodeid)
      {
        $next = -1;
      } elsif ($next == -1) { 
        $next = $$irow{node_id};
      } elsif ($next == -2) { 
        $prev = $$irow{node_id};
      } else { 
        last 
      };
    }

    my $authorCat = undef; $authorCat = {-class => ' authors'} if $$N{type}{title} eq 'writeup' && $$row{author_user} == $$N{author_user};
    if ($prev < 0)
    {
      $prev = ' ';
    } else { 
      $prev = linkNode($prev, '&#xab;', { -title => 'Previous: '.getNodeById($prev)->{title}, -class => 'previous' });
    }
    if ($next < 0)
    {
      $next = ' ';
    } else { 
      $next = linkNode($next, '&#xbb;', { -title => 'Next: '.getNodeById($next)->{title}, -class => 'next' });
    }

    my $s = "$prev&nbsp;&nbsp;" . linkNode($$row{node_id}, '', $authorCat) . "&nbsp;&nbsp;$next";
    $s =~ s/^\s+//;
    $s =~ s/\s+$//;
    unless ($authorCat)
    {
      push @items, $s;
    }else{
      unshift @items, $s;
    }
  }


  # show parent e2node categories along with writeup categories
  my $parentNodeId = $$N{parent_e2node};

  # prevent recursion from missing or self-referencing parent e2node
  if ($parentNodeId && $parentNodeId != $originalN && $$N{type}{title} eq 'writeup' && !exists $PAGELOAD->{e2nodeCategories})
  {
    $PAGELOAD->{e2nodeCategories} = htmlcode('listnodecategories', $parentNodeId, 'is parent');
  }

  if (@items || $PAGELOAD->{e2nodeCategories})
  {
    my $ies = (@items != 1 ? 'ies' : 'y');
    my ($c, $addId) = !$isIncludedParent ? ('C', qq' id="categories$nodeid"') : ('Page c', '');
    my $moggies = ""; $moggies = qq'<h4>${c}ategor$ies:</h4> <ul><li>'.(join '</li><li>', @items).'</li></ul>' if @items;
    return qq'<div class="categories"$addId">$moggies\n'.($$PAGELOAD{e2nodeCategories}||"").qq'\n</div>';
  }

  #id so content can be ajaxed in, but no class so no styling that makes it take up space:
  return qq'<div id="categories$nodeid"></div>' unless $isIncludedParent;
  return '';
}

# Not actually a 'test'. In production
#
sub testshowmessages
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($maxmsgs,$showOpts) = @_;
  $showOpts = "" unless(defined($showOpts));
  $maxmsgs = "" unless(defined($maxmsgs));

  my $json = {};
  my $jsoncount = undef; $jsoncount = 1 if $showOpts =~ /j/;

  # display options
  $showOpts ||= '';
  my $noreplylink = {getId(getNode("klaproth","user")) => 1};

  my $showD = $$VARS{pmsgDate} || (index($showOpts,'d')!=-1); #show date
  my $showT = $$VARS{pmsgTime} || (index($showOpts,'t')!=-1); #show time
  my $showDT = $showD || $showT;
  my $showArc = index($showOpts,'a')!=-1;      #show archived messages (usually don't)
  my $showNotArc = index($showOpts,'A')==-1;   #show non-archive messages (usually do)
  return unless $showArc || $showNotArc;
  my $showGroup = index($showOpts,'g')==-1;    #show group messages (usually do)
  my $showNotGroup = index($showOpts,'G')==-1; #show group messages (usually do)
  my $canSeeHidden = $APP->isEditor($USER);
  return unless $showGroup || $showNotGroup;

  return if $APP->isGuest($USER);

  my $showLastOnes = ! ($$VARS{chatterbox_msgs_ascend} || 0); 

  if($maxmsgs =~ /^(.)(\d+)$/)
  {
    # force oldest/newest first
    $maxmsgs=$2;
    if($1 eq '-')
    {
      $showLastOnes=1;
    } elsif($1 eq '+') {
      $showLastOnes=0;
    }
  }

  $maxmsgs ||= 10;
  $maxmsgs = 100 if ($maxmsgs > 100);

  my $order = $showLastOnes ? 'DESC' : 'ASC';
  my $limits = 'for_user='.getId($USER);
  my $totalMsg = $DB->sqlSelect('COUNT(*)','message',$limits); #total messages for user, archived and not, group and not, from all users
  my $filterUser = $query->param('fromuser');
  if($filterUser)
  {
    $filterUser = getNode($filterUser, 'user');
    $filterUser = $filterUser ? $$filterUser{node_id} : 0;
  }

  $limits .= ' AND author_user='.$filterUser if $filterUser;

  my $filterMinor = ''; #things to only filter for display, and not for the "X more in inbox" message
  unless($showGroup && $showNotGroup)
  {
    $filterMinor .= ' AND for_usergroup=0' unless $showGroup;
    $filterMinor .= ' AND for_usergroup!=0' unless $showNotGroup;
  }

  unless($showArc && $showNotArc)
  {
    $filterMinor .= ' AND archive=0' unless $showArc;
    $filterMinor .= ' AND archive!=0' unless $showNotArc;
  }

  my $csr = $DB->sqlSelectMany('*', 'message', $limits . $filterMinor, "ORDER BY  message_id $order LIMIT $maxmsgs");
  my $UID = getId($USER) || 0;
  my $isEDev = $APP->isDeveloper($USER, "nogods");

  my $aid = undef;  #message's author's ID
  my $message_author = undef; #message's author; have to do this in case sender has been deleted (!)
  my $ugID = undef;
  my $UG = undef;
  my $flags = undef;
  my $userLink = undef;

  # UIDs for Virgil, CME, Klaproth, and root.
  my @botlist = qw(1080927 839239 952215 113);
  my %bots = map{$_ => 1} @botlist;

  my $string = '';
  my @msgs = @{ $csr->fetchall_arrayref( {} ) };
  @msgs = reverse @msgs if $showLastOnes;
  foreach my $MSG (@msgs)
  {
    my $text = $$MSG{msgtext};

    # Bots, don't escape HTML for them.
    unless( exists $bots{$$MSG{author_user}} )
    {
      $text = $APP->escapeAngleBrackets($text);
    }

    $text =~ s/\[([^\]]*?)$/&#91;$1/; #unclosed [ fixer
    my $timestamp = $$MSG{tstamp};
    $timestamp =~ s/\D//g;
    my $str = qq'<div class="privmsg timestamp_$timestamp" id="message_$$MSG{message_id}">';

    $aid = $$MSG{author_user} || 0;
    if($aid)
    {
      $message_author = getNodeById($aid) || 0;
    } else { 
      undef $message_author;
    }
    my $authorVars = undef; $authorVars = getVars $a if $a;
    my $name = $message_author ? $$message_author{title} : '?';
    $name =~ tr/ /_/;
    $name = $APP->encodeHTML($name);

    if($$VARS{showmessages_replylink} and not $$noreplylink{$$MSG{author_user}})
    {
      $str.='<div class="repliable"></div>'
    }

    $ugID = $$MSG{for_usergroup};
    $UG = $ugID ? getNodeById($ugID) : undef;

    if($$VARS{showmessages_replylink} and defined($UG) and not $$noreplylink{$$MSG{author_user}})
    {
      my $grptitle = $$UG{node_id}==$UID ? '' : $$UG{title};
      # Grmph. -- wharf
      $grptitle =~ s/ /_/g;
      $grptitle =~ s/"/&quot;/g;
      $grptitle =~ s/'/\\'/g;
      # Test for ONO. This is moderately cheesy because the message text
      # could start with "ONO: ", but that's rare in practice. The table
      # doesn't track ONOness, so the text is all we've got.
      my $ono = undef; $ono = '?' if $text =~ /^O[nN]O: /;
    }

    if($showDT)
    {
      my $tsflags = 128; # compact timestamp
      $str .= '<small style="font-family: sans-serif;">';
      $tsflags |= 1 if !$showT; # hide time 
      $tsflags |= 2 if !$showD; # hide date
      $str .= htmlcode('parsetimestamp', "$$MSG{tstamp},$tsflags");
      $str .= '</small> ';
    }

    $str .= '(' . linkNode($UG,0,{lastnode_id=>0}) . ') ' if $ugID;

    # N-Wing probably doing too much work...
    # changes literal '\n' into HTML breaks (slash, then n; not a newline)
    $text =~ s/\s+\\n\s+/<br>/g;

    if ($$VARS{chatterbox_authorsince} && $message_author && $authorVars)
    {
      $str .= '<small>('. htmlcode('timesince', $message_author->{lasttime}, 1). ')</small> ' if (!$$authorVars{hidelastseen} || $canSeeHidden);
    }

    if($$VARS{powersMsg})
    {
      # Separating mere coders from the gods...
      my $isCommitter = $APP->inUsergroup($aid,'%%','nogods');
      my $isChanop = $APP->isChanop($aid,"nogods");

      $flags = '';
      if($APP->isAdmin($aid) && !$APP->getParameter($aid,"hide_chatterbox_staff_symbol"))
      {
        $flags .= '@';
      } elsif($APP->isEditor($aid,"nogods") && !$APP->isAdmin($aid) && !$APP->getParameter($aid,"hide_chatterbox_staff_symbol")) {
        $flags .= '$';
      }

      $flags .= '*' if $isCommitter;

      $flags .= '+' if $isChanop;

      $flags .= '%' if $isEDev && $APP->isDeveloper($aid, "nogods");
      if(length($flags))
      {
        $flags = '<small>'.$flags.'</small> ';
        $str .= $flags;
      }
    }

    $userLink = $message_author ? linkNode($message_author, 0) : '?';

    $str .= '<cite>'.$userLink.' says</cite> ' . parseLinks($text,0,1);
    my $mbid = $$MSG{message_id};
    my $noReplyWhy = undef;
    my $replyBox = htmlcode('messageBox', $aid, 0, $mbid, $ugID, \$noReplyWhy);
    my $replyWidgetOptions = {
      showwidget => $mbid
      , '-title' => "Reply to $name"
      , '-closetitle' => 'hide reply box' };
    my $removeBox = htmlcode('confirmDeleteMessage', $mbid);
    my $removeWidgetOptions = {
      showwidget => "deletemsg_$mbid"
      , '-title' => "Delete the above message"
      , '-closetitle' => 'hide delete box'
      , '-id' => "remove$mbid" };
    $str .= "<div class='actions'>";
    if ($replyBox)
    {
      $str .=  ""
      . "<div class='reply'>"
      . htmlcode('widget', $replyBox, 'div', "Reply", $replyWidgetOptions)
      . "</div>";
    } else {
      $str .=  ""
      . "<div class='reply'>"
      . "<a title='" . $APP->encodeHTML($noReplyWhy) . "'>"
      . "Can't reply"
      . "</a>"
      . "</div>";
    }
  
    $str.= ""
      . '<div class="delete">'
      . htmlcode('widget', $removeBox, 'div', "Remove", $removeWidgetOptions)
      . '</div>';
    $str .= "</div>"; # </div actions>
    $str .= "</div>"; # </div privmsg>

    unless ($jsoncount)
    {
      $string.="$str\n";
    } else {
      $$json{$jsoncount} = {
        value => $str,
        id => $$MSG{message_id},
        timestamp => $timestamp
      };
      $jsoncount++;
    }
  }

  if($totalMsg)
  {
    my $MI_node = getNode("Message Inbox", "superdoc");
    my $str = qq'<p id="message_total$totalMsg" class="timestamp_920101106172500">(you have '.linkNode($MI_node,"$totalMsg private messages").')</p>';

    unless ($jsoncount)
    {
      $string.="$str\n";
    } else {
      $$json{$jsoncount} = {
        value => $str,
        id => "total$totalMsg", # will be replaced if number changes
        timestamp => '920101106172500' # keep at bottom. 90,000 years should be enough
      };
    }
  }

  return $string unless $jsoncount;
  return $json;
}

sub confirmDeleteMessage
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($messageID,$actioned) = @_;

  if ($actioned and $actioned eq "deleted")
  {
    return "Message deleted";
  }
  if ($actioned and $actioned eq "archived")
  {
    return "Message archived";
  }

  my $archiveWhat="archive_$messageID";

  my $str = linkNode( $NODE , 'Archive message' , { op => 'message', $archiveWhat => 'yup', lastnode_id => 0 , -title => "archive the above message" , -class => "action ajax message_$messageID:confirmDeleteMessage:$messageID,archived" }).' or ';

  my $deleteWhat="deletemsg_$messageID";

  $str.=linkNode( $NODE , 'delete for good' , { op => 'message', $deleteWhat => 'yup', lastnode_id => 0 , -title => "delete the above message" , -class => "action ajax message_$messageID:confirmDeleteMessage:$messageID,deleted" });

  return $str;
}

sub notificationsJSON
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $limit = 10;
  my $wrap = shift;

  my $str = undef;

  my $safe_JSON_decode = sub {
    my $args = { };
    my $argJSON = shift;
    # Suppress failed conversion -- return empty hash instead
    local $SIG{__DIE__} = sub { };
    $args = JSON::from_json($argJSON);
    return $args;
  };

  # hide node notes from non-editors
  my $isEditor = $APP->isEditor($USER);

  my $otherNotifications = "0";

  if ($$VARS{settings})
  {
    my $notificationList = from_json($$VARS{settings})->{notifications};
    my @notify = ( );

    for (keys %{$notificationList})
    {
      next if !htmlcode('canseeNotification', $_);
      push @notify, $_;
    }

    $otherNotifications = join(",",@notify) if scalar @notify;
  }

  my $currentTime = time;
  my $sqlString = qq|
    SELECT notified.notification_id, notified.args, notified.notified_id
    , UNIX_TIMESTAMP(notified.notified_time) 'notified_time'
    , (hourLimit * 3600 - $currentTime + UNIX_TIMESTAMP(notified.notified_time)) AS timeLimit
    FROM notified
    INNER JOIN notification
    ON notification.notification_id = notified.notification_id
    LEFT OUTER JOIN notified AS reference
    ON reference.user_id = $$USER{user_id} 
    AND reference.reference_notified_id = notified.notified_id
    AND reference.is_seen = 1
    WHERE
    (
      notified.user_id = $$USER{user_id}
      AND notified.is_seen = 0
    ) OR (
      notified.user_id IN ($otherNotifications)
      AND reference.is_seen IS NULL
    )
    HAVING (timeLimit > 0)
    ORDER BY notified_id DESC
    LIMIT $limit|;

  my $dbh = $DB->getDatabaseHandle();
  my $db_notifieds = $dbh->selectall_arrayref($sqlString, {Slice => {}} );
  my $notification_list = { };
  my $notify_count = 1;

  foreach my $notify (@$db_notifieds)
  {
    my $notification = getNodeById($$notify{notification_id});
    my $displayCode = $notification->{code};
    my $invalidCheckCode = $notification->{invalid_check};
    my $argJSON = $$notify{args};
    $argJSON =~ s/'/\'/g;
    my $args = &$safe_JSON_decode($argJSON);
    my $evalNotify = sub {
      my $notifyCode = shift;
      my $wrappedNotifyCode = "sub { my \$args = shift; 0; $notifyCode };";
      my $wrappedSub = evalCode($wrappedNotifyCode);
      return &$wrappedSub($args);
      };

    # Don't return an invalid notification and remove it from the notified table
    if ($invalidCheckCode ne '' && &$evalNotify($invalidCheckCode))
    {
      $DB->sqlDelete('notified', 'notified_id = ' . int($$notify{notified_id}));
      next;
    }

    my ($pre, $post) = (undef, undef);
    if ($wrap)
    {
      my $liId = "notified_$$notify{notified_id}";
      $pre = qq'<li class="timestamp_$$notify{notified_time}" id="$liId">';
      $pre .= qq'<a class="dismiss $liId" title="dismiss notification" href="javascript:;">&#91;x]</a> ';
      $post = "</li>\n";
    }

    $$notification_list{$notify_count} = {
      id => $$notify{notified_id},
      value => $pre.parseLinks(&$evalNotify($displayCode)).$post,
      timestamp => $$notify{notified_time}};
    $notify_count++;
  }

  return $notification_list;

}

sub ip_lookup_tools
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  # $APP->encodeHTML should be a no-op here, but just in case...
  my $ip = $APP->encodeHTML(shift);

  return 
    "<a href='http://whois.domaintools.com/$ip' target=\"_blank\">whois</a>"
    . " - <a href='https://www.dan.me.uk/torcheck?ip=$ip' target=\"_blank\">Tor</a>"
    . " - <a href='http://www.google.com/search?hl=en&q=%22$ip%22&btnG=Google+Search' target=\"_blank\">Google</a>"
    . " - <a href='http://www.projecthoneypot.org/ip_$ip' target=\"_blank\">PH</a>"
    . " - <a href='http://www.stopforumspam.com/ipcheck/$ip' target=\"_blank\">SFS</a>"
    . " - <a href='http://www.botscout.com/ipcheck.htm?ip=$ip' target=\"_blank\">BS</a>";
}

sub make_node_sane
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # Expects single parameter, node_id or node ref
  # returns undef if unable to make node sane
  # returns node if successful
  my ($crazy_node) = @_;
  getRef($crazy_node);
  return unless $crazy_node;

  # In case this is a 'light' copy of the node, we get a complete copy
  #  so we don't try to create unnecessary rows
  my $crazy_node_id = $$crazy_node{node_id};
  my $crazy_node_copy = getNodeById($crazy_node_id);
  return unless $crazy_node_copy;

  # Code borrowed from insertNode() in NodeBase.pm
  my $tableArray = $$crazy_node_copy{type}{tableArray};

  # Check for document_id, writeup_id, etc. and insert row
  #  into relevant table if the table id is missing.
  foreach my $table (@$tableArray)
  {
    my $table_id = $table . "_id";
    $DB->sqlInsert($table, { $table_id => $crazy_node_id }) unless $$crazy_node_copy{$table_id};
  }

  # Now that node is sane, get one last fresh copy
  my $sane_node = getNodeById($crazy_node_id, 'force');
  return $sane_node;
}

sub blacklistIP
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

#	purpose
#		add an IP address to the blacklist table or update an existing
#		entry for the address
#
#	parameters
#		IP to block, reason to block it
#
#	returns
#		error report or report on action done
#
	my ($ipToAdd, $blockReason) = @_;

	return 'No IP given to blacklist' unless $ipToAdd;
	# still waiting for IPv6...
	return "'".$APP->encodeHTML($ipToAdd)."' is not a valid IP address" unless $ipToAdd =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
	my $result = '';

	my $data = {ipblacklist_user => $$USER{user_id}
		, ipblacklist_ipaddress => $ipToAdd
	};

	my $update = 0;

	my $listRef = $DB -> sqlSelect('ipblacklistref_id'
		, 'ipblacklist'
		, "ipblacklist_ipaddress = '$ipToAdd'"
	);

	if ($listRef){
		$$data{ipblacklistref_id} = $listRef;
		$update = {%$data
			, -ipblacklist_comment => 'CONCAT('.$DB->quote("$blockReason <br>&#91;").
				", ipblacklist_timestamp, ']: ', ipblacklist_comment)"
		};
		$result = "updated IP blacklist entry for $ipToAdd";
	}else{
		$DB -> sqlInsert('ipblacklistref', {});
		$$data{-ipblacklistref_id} = 'LAST_INSERT_ID()';
		$$data{ipblacklist_comment} = $blockReason;
		$result = "added $ipToAdd to IP blacklist";
	}

	return "Error adding $ipToAdd to blacklist" unless
		$DB -> sqlInsert('ipblacklist', $data, $update);

	$APP->securityLog(getNode('IP Blacklist', 'restricted_superdoc'), $USER, "$$USER{title} $result: \"$blockReason.\"");
	$result =~ s/^(\w)/\u$1/;
	return $result;
}

sub check_blacklist
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my @addrs = @_;

  return 0 unless scalar @addrs;

  my $ip_list = '('
    . ( join ',', map { $DB->quote($_) } @addrs )
    . ')';

  my $ban_query = qq|
    SELECT ipblacklist_id
    FROM ipblacklist
    WHERE ipblacklist_ipaddress
    IN $ip_list|;

  return 1 if ($DB->getDatabaseHandle()->selectrow_array($ban_query));

  my $intFromAddr = sub {
    my $addr = shift;
    return unless $addr =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    return ( (int $1) * 256*256*256 + (int $2) * 256 * 256 + (int $3) * 256 + (int $4));
  };

  my @addrsNum = map { &$intFromAddr($_) } @addrs;

  my $ip_between_list = ''. ( join "\n    OR ", map { '' . (int $_) . ' BETWEEN min_ip AND max_ip' } @addrsNum );

  my $range_ban_query = qq|
    SELECT ipblacklistrange_id
    FROM ipblacklistrange
    WHERE $ip_between_list|;

  return 1 if ($DB->getDatabaseHandle()->selectrow_array($range_ban_query));

  return 0;
}

sub canseeNotification
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $notification = shift;
  getRef $notification;

  my $uid = $$USER{node_id};
  my $isCE = $APP->isEditor($USER);
  my $isCoder = $APP->inUsergroup($uid,"edev","nogods") || $APP->inUsergroup($uid, 'e2coders', "nogods");
  my $isChanop = $APP->isChanop($uid, "nogods");

  return 0 if ( !$isCE && ($$notification{description} =~ /node note/) );
  return 0 if ( !$isCE && ($$notification{description} =~ /new user/) );
  return 0 if ( !$isCE && ($$notification{description} =~ /(?:blanks|removes) a writeup/) );
  return 0 if ( !$isCE && ($$notification{description} =~ /review of a draft/) );
  return 0 if ( !$isChanop && ($$notification{description} =~ /chanop/) );

  return 1;
}

sub lock_user_account
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($uid) = @_;
  getRef $uid;
  return unless $uid;
  return unless($$uid{type_nodetype} == getId(getType('user')));
  $$uid{acctlock} = $$USER{user_id};

  $APP->securityLog(getNode("lockaccount","opcode"), $USER, "$$uid{title}'s account was locked by $$USER{title}");

  # Delete all public messages from locked user
  $DB->sqlDelete('message', "for_user = 0 AND author_user = $$uid{user_id}");

  # revert all review drafts to 'findable' status
  # (they won't actually be findable unless/until the account is unlocked)
  $DB -> sqlUpdate('draft JOIN node ON draft_id=node_id', {publication_status => getId(getNode('findable', 'publication_status'))}, "node.author_user = $$uid{node_id} AND
    draft.publication_status = " . getId(getNode('review', 'publication_status')));

  return updateNode($uid, -1);
}

sub show_writeups
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  local $$VARS{wufoot} = "l:kill,$$VARS{wufoot}"
    unless !$$VARS{wufoot} or $$VARS{wufoot} =~ /\bkill\b/ or $$VARS{wuhead} =~ /\bkill\b/;

  my $oldinfo = sub { htmlcode("displayWriteupInfo", @_); }; 
  my $categories = sub { htmlcode("listnodecategories", @_); };
  my $canseewriteup = sub { htmlcode("canseewriteup", @_); };

  my $draftitem = sub{
    return 'draftitem' if $_[0]->{type}{title} eq 'draft';
    '';
  };

  return htmlcode( 'show content' , shift || $$NODE{group} || $NODE
    , '<div class="&draftitem"> oldinfo, content, categories, oldinfo'
    , cansee => $canseewriteup
    , draftitem => $draftitem
    , categories => $categories
    , oldinfo => $oldinfo);
}

sub homenodeinfectedinfo
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "" unless $APP->isEditor($USER);

  my $infectedHTML = "";

  if (htmlcode('isInfected', $NODE))
  {
    my $infectionLink = "infected";
    my $infectionExplanation = getNode('Infected Users', 'oppressor_superdoc');
    $infectionLink = linkNode($infectionExplanation, $infectionLink);
    $infectedHTML .= qq|;
      <div>
      <img src="https://s3.amazonaws.com/static.everything2.com/biohazard.png" alt="Biohazard Sign" title="User is infected">
      <p>
      This user is $infectionLink.
      </p>
     </div>|;

    if ( $APP->isAdmin($USER) )
    {
      my $cureHTML = "
        <div>\n"
        . htmlcode('openform', 'cure_infection_form')
        . htmlcode('verifyRequestForm', 'cure_infection')
        . $query->hidden("confirmop", 'cure_infection')
        . $query->hidden("cure_user_id", $$NODE{node_id})
        . '<button class="ajax homenode_infection:homenodeinfectedinfo?op=cure_infection&cure_user_id=/&cure_infection_seed=/&cure_infection_nonce=/&confirmmsg=/#Are+you+sure+you+wish+to+cure+this+user&apos;s+infection">
          <img src="https://s3.amazonaws.com/static.everything2.com/physician.png" alt="Physician Sign">
           <p>Cure User</p> </button>'
        . '</form>'
        . "</div>\n";

      $infectedHTML .= $cureHTML;
    }
  } elsif ($query->param("op") ne "cure_infection") {
    return "";
  } else {
    $infectedHTML .= qq|;
     <img src="http://static.everything2.com/physician.png" alt="Physician Sign">
     <p>Infection cured.</p>|;
  }

  return '<div id="homenode_infection" class="warning">' . $infectedHTML . '</div>';
}

sub showUserCategories
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # pass a user object (or nothing to default to the current node, or current user if the current node is not a user), and the categories maintained by the user will be returned

  my $U = $_[0];
  if($U)
  {
    $U = getId($U);
  } else {
    if($$NODE{type_nodetype} == getId(getNode('user', 'nodetype')))
    {
      $U = getId($NODE);
    } else {
      $U = getId($USER);
    }
  }

  return if(!$U);

  my $dbquery = $DB->sqlSelectMany("node_id", "node", "author_user=" . $U . " and type_nodetype=" . getId(getType("category")));

  my $row = undef;
  my @categories = ();
  push @categories, linkNode($$row{node_id}) while ($row = $dbquery->fetchrow_hashref());

  return if !scalar(@categories);
  return join(', ', @categories);
}

sub googleads 
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $node_id = $$NODE{node_id};

  foreach my $nid (@{$Everything::CONF->google_ads_badnodes})
  {
    return "<!-- noad:badnode -->" if ($node_id == $nid or ($$NODE{type}{title} eq 'writeup' and $$NODE{parent_e2node} == $nid));
    if(exists($$NODE{linklist}))
    {
      foreach my $l (@{ $$NODE{linklist} })
      {
        return "<!-- noad:badnodelink -->" if $l->{to_node} == $nid;
      }
    }
  }

  foreach my $word (@{$Everything::CONF->google_ads_badwords})
  {
    return "<!-- noad:badword -->" if $$NODE{title} =~ /\b$word/i or $$NODE{title} =~ /$word\b/i;
    if (exists $$NODE{linklist})
    {
      foreach my $l (@{ $$NODE{linklist} })
      {
        my $title = getNode($l->{to_node})->{title};
        return "<!-- noad:$title/$word -->" if $title =~ /\b$word/i or $title =~ /$word\b/i;
      }
    }
  }

  return "<!-- noad:nothingfound -->" if $node_id == getNode('Nothing Found', 'superdoc')->{node_id};
  return "<!-- noad:findings -->" if $node_id == getNode('Findings:', 'superdoc')->{node_id};
  return "<!-- noad:badnodeid -->" unless ($node_id =~ /^\d+$/);

  return '<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-0613380022572506"
     crossorigin="anonymous"></script>';
}

sub decode_short_string
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($shortString) = @_;

  my @encodeChars = qw/
   a   c d e f   h     k   m n o     r s t u   w x   z
   A B C D E F G H   J K L M N   P Q R   T U V W X Y Z
     2 3 4     7 8 9 /;

  # Exclude because of similarity: I l 1
  # Exclude because of similarity: O 0
  # Exclude because of similarity: i j
  # Exclude because of similarity: v y
  # Exclude because of similarity: g p q
  # Exclude because of similarity: b 6
  # Exclude because of similarity: S 5

  my %decodeChars = ();

  for (my $charValue = 0; $charValue < $#encodeChars; $charValue++)
  {
    $decodeChars{$encodeChars[$charValue]} = $charValue;
  }

  my $decodeInt = sub {
    my $decodeMe = shift;
    my $encodeResult = 0;

    for my $nextChar (split //, $decodeMe)
    {
      $encodeResult *= $#encodeChars;
      my $nextCharValue = $decodeChars{$nextChar};
      return (0, "Invalid char: $nextChar") if !defined $nextCharValue;
      $encodeResult += $nextCharValue;
    }

    return ($encodeResult, undef);
  };


  my ($decodeResult, $error) = &$decodeInt($shortString);
  $error = "$shortString = $decodeResult";
  my $decodeNode = getNodeById($decodeResult);
  return $decodeNode;

}

sub create_short_url
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($urlNode) = @_;
  my $targetId = getId $urlNode;

  my @encodeChars = qw/
    a   c d e f   h     k   m n o     r s t u   w x   z
    A B C D E F G H   J K L M N   P Q R   T U V W X Y Z
      2 3 4     7 8 9 
    /;

  # Exclude because of similarity: I l 1
  # Exclude because of similarity: O 0
  # Exclude because of similarity: i j
  # Exclude because of similarity: v y
  # Exclude because of similarity: g p q
  # Exclude because of similarity: b 6
  # Exclude because of similarity: S 5

  my $encodeInt = sub {
    my $encodeMe = shift;
    my $encodeResult = '';

    while ($encodeMe != 0)
    {
      my $nextCharValue = $encodeMe % $#encodeChars;
      my $nextChar = $encodeChars[$nextCharValue];
      $encodeResult = $nextChar . $encodeResult;
      $encodeMe /= $#encodeChars;
      $encodeMe = floor($encodeMe);
    }
    $encodeResult = '0' if $encodeResult eq '';
    return $encodeResult;
  };

  my $shortString = &$encodeInt($targetId);
  my $shortLink =
    'http://'
    . $Everything::CONF->canonical_web_server
    . '/s/'
    . $shortString;

  return $shortLink;

}

sub urlToNode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $targetNode = shift;
  getRef $targetNode;

  my $bNoQuoteUrl = 1;
  my $urlParams = { };
  my $redirectPath = urlGen($urlParams, $bNoQuoteUrl, $targetNode);
  return 'http://' . $ENV{HTTP_HOST} . $redirectPath;
}

sub weblogform
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ( $N , $inwriteupform ) = @_ ;
  getRef $N ;
  $N ||= $NODE ;


  $inwriteupform ||= 0;
  my $options = '' ;
  my $notification = "";

  unless ( $PAGELOAD->{ cachedweblogoptions } )
  {
    my $wls = getVars( getNode( 'webloggables' , 'setting' ) ) ;
    foreach( split ',' , $$VARS{ can_weblog } )
    {
      next if $$VARS{ 'hide_weblog_'.$_ };
      my $groupTitle = "" ;
      if ( $$VARS{ nameifyweblogs } )
      {
        $groupTitle = $$wls{ $_ } ;
      } else {
        my $wl = getNodeById($_,"light") || {title => ''};
	next unless $wl and exists($wl->{title});
        $groupTitle = $wl->{title};
      }
      $options.="\n\t\t\t<option value=\"$_\">$groupTitle</option>" if $groupTitle;
    }
    $PAGELOAD->{ cachedweblogoptions } = $options if $$NODE{type}{title} eq 'e2node' && scalar @{ $$NODE{ group } } > 1 ;
  } else {
    $options = $PAGELOAD->{ cachedweblogoptions } ;
    delete $PAGELOAD->{ cachedweblogoptions } if $$N{ node_id } == ${ $$NODE{ group } }[-1] ;
  }

  my $sourceid = undef;
  if ( $query -> param( 'op' ) eq 'weblog' and $query -> param( 'target' ) == $$N{ node_id } )
  {
    $sourceid = $query -> param( 'source' ) ;
    if ( $sourceid )
    {
      $options =~ s/$sourceid/$sourceid" selected="selected/ ;
      my $success = $DB->sqlSelect( "weblog_id" , "weblog" ,"weblog_id=$sourceid and to_node=$$N{ node_id } and linkedby_user=$$USER{ user_id }" ) ;
      $notification = ( $success ? 'Added ' : 'Failed to add ' ) .
        "$$N{ title } to ".linkNode( $sourceid ) .
	( $success ? ' (' .linkNode( $NODE , 'undo' , { op => 'removeweblog' ,
        source => $sourceid , to_node => $$N{ node_id } ,
        -class=>"ajax weblogform$$N{node_id}:weblogform:$$N{node_id},$inwriteupform" } ) . ')' : '' ) ;
    } else {
      $notification = 'No page chosen: nothing added to anything.' ;
    }
  }
  $notification = "<p><small>$notification</small></p>" if $notification ;

  return linkNodeTitle( 'Edit weblog menu[superdoc]|Edit weblog menu&hellip;' ).$notification if $$VARS{ can_weblog } and not $options ;

  $options = "\n\t\t\t<option value=\"\" selected=\"selected\">Choose&hellip;</option>$options" unless $sourceid ;

  my ( $class , $addnid ) = ("",""); ($class, $addnid) = ( "wuformaction " , $$N{ node_id } ) if $inwriteupform ;
  $class .= "ajax weblogform$$N{node_id}:weblogform?op=weblog&target=/target$addnid&source=/source$addnid:$$N{node_id},$inwriteupform" ;

  return qq'<fieldset id="weblogform$$N{node_id}"><legend>Add this '	.
    ( $$N{type}{title} eq 'e2node' ? 'entire page ' : $$N{type}{title} ) .
    qq' to a usergroup page:</legend>
    <input type="hidden" name="target$addnid" value="$$N{ node_id }">
    <select name="source$addnid">
    $options
    </select>
    <button value="weblog" name="'.( $inwriteupform ? qq'wl$addnid" type="button"' : 'op" type="submit"' ) .
    qq'class="$class">Add</button><br><small>'.linkNodeTitle( 'Edit weblog menu[superdoc]|Edit this menu&hellip;' ) .
    "</small>$notification</fieldset>" ;
}

sub categoryform
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if $APP->getLevel( $USER ) <= 1 && !$APP->isEditor($USER);

  my ( $N , $inwriteupform ) = @_ ;
  getRef $N ;
  $N ||= $NODE ;

  $inwriteupform = "" unless(defined($inwriteupform));

  my ($categoryid, $options, $choose, $createcategory, $notification) = (undef,undef,"","","");

  unless ( $PAGELOAD->{ cachedcategoryoptions } )
  {
    # get user, guest user, and user's usergroups. No huge list for admins and CEs
    my $dbh = $DB->getDatabaseHandle();
    my $inClause = join( ',' , $$USER{ user_id } , $Everything::CONF->guest_user , @{
      $dbh -> selectcol_arrayref( "SELECT DISTINCT ug.node_id
      FROM node ug,nodegroup ng WHERE ng.nodegroup_id=ug.node_id AND ng.node_id=$$USER{ user_id }" ) } );
	
    # get all the categories the user can edit
    my $nodetype = getNode( 'category' , 'nodetype' ) -> { node_id } ;
    my $csr = $DB -> sqlSelectMany(
      'n.node_id, n.title,
      (select title from node where node_id=n.author_user) as authorname' ,
      'node n' , "author_user IN ($inClause) AND type_nodetype=$nodetype
      AND node_id NOT IN (SELECT to_node AS node_id FROM links WHERE from_node=n.node_id)" ,
      'ORDER BY n.title' ) ;

    while( my $c = $csr -> fetchrow_hashref )
    {
      $options .= '<option value="'.$$c{ node_id }.'">'.$$c{ title }." ($$c{ authorname })</option>\n" ;
    }

    $PAGELOAD->{ cachedcategoryoptions } = $options if $$NODE{type}{title} eq 'e2node' ;
  } else {
    $options = $PAGELOAD->{ cachedcategoryoptions } ;
    delete $PAGELOAD->{ cachedcategoryoptions } if $$N{ node_id } eq $$NODE{ node_id } ; # last call is for page header
  }

  $categoryid = $query -> param( 'cid' );
  $choose = qq'<option value="" selected="selected">Choose&hellip;</option>' if $options && !$categoryid;
  $options .= qq'<option value="new">New category&hellip;</option>';
  $options =~ s/$categoryid/$categoryid" selected="selected/ if $categoryid;

  if ( ($query->param( 'op' ) || "" ) eq 'category' and ( $query->param('nid') and $query->param( 'nid' ) == $$N{ node_id } ) )
  {
    # report on attempt to add to category or provide opportunity to name a new category

    if ($categoryid eq 'new')
    {
      $createcategory = $query -> label('<br><small>New category name:</small><br>'.$query -> textfield(-name => 'categorytitle', size => 50));
      my $newname = $query -> param('categorytitle');
      if ($newname)
      {
        $newname = $APP->cleanNodeName($newname);
        $notification = ' (A category with this name already exists.)' if getNode($newname, 'category');
        $newname = $query -> escapeHTML($newname);
        $notification = "Failed to create new category '$newname'.$notification";
      }
    } elsif($categoryid) {
      my $success = $DB -> sqlSelect( "from_node" , "links" ,
        "from_node=$categoryid and to_node=$$N{node_id} and linktype="
        .getNode('category', 'linktype')->{node_id});

      $notification = ($success? qq'<span class="instant ajax categories$$N{node_id}:listnodecategories?a=1:$$N{node_id}:">Added</span> '
        : 'Failed to add ')."$$N{ title } to ".linkNode($categoryid);
    } else {
      $notification = 'No category chosen: nothing added to anything.' ;
    }
  }

  $notification = "<p><small>$notification</small></p>" if $notification ;

  my ( $class , $addnid ) = ("",""); ( $class , $addnid ) = ( "wuformaction " , $$N{ node_id } ) if $inwriteupform ;

  $class .= "ajax categoryform$$N{node_id}:categoryform?op=category&nid=/nid$addnid&cid=/cid$addnid"
    .($createcategory ? '&categorytitle=/' : '')
    .":$$N{node_id},$inwriteupform";

  return qq'<fieldset id="categoryform$$N{node_id}"><legend>Add this '	.
    ( $$N{type}{title} eq 'e2node' ? 'entire page ' : $$N{type}{title} ) .
    qq' to a category:</legend><input type="hidden" name="nid$addnid" value="$$N{ node_id }">
    <select name="cid$addnid">$choose $options</select>
    $createcategory
    <button value="category" name="'.( $inwriteupform ? qq'cat$addnid" type="button"' : 'op" type="submit"' )
    .qq' class="$class">Add</button> $notification</fieldset>';
}

sub widget
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # first two arguments for the widget, second two for the opener link
  # if no $linktext is provided, there will be no opener link
  # $parameters contains parameters for the link, including
  # showwidget => <parameter to make widget open on pageload>
  # (will be removed as appropriate), plus optionally:
  # -closetitle => <title attribute for close X in widget> (default: 'hide')
  # node => <node to link to for noscript fallback> ( default: $$NODE)

  my ( $content , $tagname , $linktext , $parameters ) = @_ ;
  my $N = $$parameters{ node } || $NODE ;
  delete $$parameters{ node } ;

  my $showparameter = $$parameters{ showwidget } ;
  $$parameters{ -class } = 'action showwidget' ;
  my $style = 'visibility:' ;

  if ($query->param('showwidget') and $query->param('showwidget') eq $showparameter )
  {
    $style .= 'visible' ;
    $$parameters{ -class } .= ' open' ;
    delete $$parameters{ showwidget } ;
  } else {
    $style .= 'hidden' ;
  }

  my $str = "";
  unless ( $tagname =~ '^form' )
  {
    $str = qq'<$tagname class="widget" style="$style">\n' ;
  } else {
    $str = htmlcode( 'openform' , -class=>"widget" , -style=> $style ).
    $query -> hidden( -name => 'showwidget' , -value => $showparameter , -force => 1 ) ;
  }

  $tagname =~ s/\W.*// ; # may have had extra attributes in it
  $str .= "\n".$content.linkNode( $NODE , 'X' ,
    { -class => 'action showwidget hidewidget' , -title => ( $$parameters{ -closetitle }||'hide' ) } ) .
    "\n</$tagname>\n" ;
  return $str unless $linktext ;

  delete $$parameters{ -closetitle } ;
  $$parameters{ displaytype } = $query -> param( 'displaytype' ) if $query -> param( 'displaytype' ) ;
  return $str.linkNode( $N , $linktext , $parameters ) ;
}

sub Notelet_nodelet_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return 'You can edit your <strong>Notelet Nodelet</strong> at the '.linkNodeTitle('Notelet editor[superdoc]');
}

sub Personal_Links_nodelet_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $inwidget = shift;
  my $name = 'set_personalnode';
  my $delname = 'del_personalnode';
  my $i =0;
  my $limit = 50;
  $limit=100 if isGod($USER);

  my @newnodes = ();
  my $updateflag=0;
  my $n = undef;
  while(defined $query->param($name.$i))
  {
    $n=$APP->htmlScreen(scalar($query->param($name.$i)));
    $n =~ s/\[/\&\#91;/g;
    $n =~ s/\]/\&\#93;/g;
    push(@newnodes, $n) unless $query->param($delname.$i) || $n =~ /^\s*$/;
    $i++;
    last if $i >= $limit;
    $updateflag=1;
  }

  if($updateflag)
  {
    $$VARS{personal_nodelet} = join('<br>',@newnodes);
  }

  my $tempstr = $$VARS{personal_nodelet};

  $tempstr=~ s/^\s*<br>//g;
  $tempstr=~ s/<br>\s*<br>/<br>/g;

  my @nodes = split '<br>', $tempstr;
  $i=0;
  my $str = undef;
  foreach(@nodes)
  {
    $str .= '<tr><td>'.
      $query->checkbox(-name=>$delname.$i, value=>1,checked=>0,force=>1,label=>' ').
      '</td><td>'.
      $query->textfield(-name=>$name.$i, value=>$_, force=>1).
      ($inwidget ? '' :'</td><td><small>'.linkNodeTitle($_).'</small>')."</td></tr>\n";
    $i++;
  }
  $str .= '<tr><td>&nbsp;</td><td>' . $query->textfield(-name=>$name.$i, value=>'', force=>1) .
    '</td>'.($inwidget ? '' : '<td><small>(new link)</small></td>')."</tr>\n" unless $i >= $limit;

  return 'Add/remove links:<table border="0"><tr><th><strong>x</strong></th><th>edit</th>'.($inwidget ? '' : '<th>link</th>').'</tr>'.$str.'
    </table>';
}

sub nodeletsettingswidget
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # provide a settings link/widget for the nodelet named by the first argument
  # second argument is link/opener text

  my ($name, $text, $id, $safename) = @_;
  return unless defined($name);

  $id = $safename = $name;
  my $safetext= $text;
  $safename =~ s/ /\+/g;
  $safetext =~ s/ /\+/g;
  $id =~ s/\W//g ;
  $id =lc($id);
  return linkNode(getNode('Nodelet Settings', 'superdoc'), $text,
    {'#'=>$id.'nodeletsettings', -id=>$id."settingswidget",
    -class=>"ajax $id"."settingswidget:nodeletsettingswidget?showwidget=$id"."settings:$safename,$safetext"
    }) unless(($query -> param('showwidget')||"") eq "$id"."settings");

  my $content = parseLinks(htmlcode($name.' nodelet settings', 'inwidget'))||"(no settings for $name)";
  return qq'<div id="$id'.qq'settingswidget">'.
    # wrap in div because the script function activation stuff works on one element
    # and to provide an offset parent to put the widget in the right place
    htmlcode('widget', "<fieldset><legend>$text</legend>\n$content<br>\n".
    $query -> hidden('sexisgood','1').
    # include ajax trigger because the first time it's not inserted together with the nodelet
    $query -> hidden(-name => 'ajaxTrigger', value=>1, class=>"ajax $id:updateNodelet:$safename").
    $query -> submit("submit$id",'Save')."\n</fieldset>\n",'form', $text , {showwidget=>"$id"."settings"}).'</div>';
}

sub ajaxMarkNotificationSeen
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $notified_id = shift;
  return 'invalid argument' unless $notified_id =~ /^\d+$/;

  my $for_user = $DB->sqlSelect("user_id", "notified", "notified_id = $notified_id");
  my $isPersonalNotification = ($for_user == $$USER{user_id});

  if ($isPersonalNotification)
  {
    $DB->sqlUpdate("notified",{is_seen => 1}, "notified_id = $notified_id");
  } else {
    $DB->sqlInsert("notified",
      {
        is_seen => 1
        , -user_id => $$USER{user_id}
        , -reference_notified_id => $notified_id
        , -notified_time => 'now()'
      });
  }

  return;
}

sub coolsJSON
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $csr = $DB->sqlSelectMany("
    (select title from node where node_id=cooledby_user limit 1) as cooluser, coolwriteups_id,
    (select title from node where node_id=(select author_user from node where node_id=coolwriteups_id limit 1) limit 1) as wu_author,
    (select parent_e2node from writeup where writeup_id=coolwriteups_id limit 1) as parentNode,
    (select title from node where node_id=parentNode limit 1) as parentTitle",
    "coolwriteups",
    "",
    "order by tstamp desc limit 100");

  my $count = 15;
  my $cool_count = 1;
  my %used = ();

  my $coollist = {};

  while (my $CW = $csr->fetchrow_hashref())
  {
    next if exists $used{$$CW{coolwriteups_id}};
    $used{$$CW{coolwriteups_id}} = 1;
    $$coollist{$cool_count} = {id => $$CW{coolwriteups_id}, value => linkNode($$CW{coolwriteups_id}, $$CW{parentTitle}, {lastnode_id => 0})};
    $$coollist{$$CW{coolwriteups_id}} = 1;
    $cool_count++;
    last unless (--$count);
  }

  return $coollist;
}

sub Other_Users_nodelet_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return htmlcode('varcheckbox','showuseractions','Spy on Other Users (just for fun)');
}

sub ajaxEcho
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # provide simple user feedback for AJAX opcode call (e.g., sanctify in [page actions])
  return shift;
}

sub display_draft
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $displaytype = shift;
  $displaytype ||= $query -> param('displaytype') || 'display';

  my $displaylike = undef;

  my $tinopener = ($APP->isAdmin($USER) and $query -> param('tinopener') and not $APP->canSeeDraft($USER, $NODE, 'find'));
  local ($$NODE{doctext}, $$NODE{collaborators})
    = ("<p><b>&#91;DOCTEXT REDACTED&#93;</b></p><p>You do not have permission to see this draft.</p>" , $$USER{title}) if $tinopener;

  if ($$NODE{author_user} == $$USER{node_id} || $APP->canSeeDraft($USER, $NODE ,"find") || $$NODE{type}{title} eq 'writeup')
  {
    $displaylike = getType(
      getNodeWhere({pagetype_nodetype => 117, displaytype => $displaytype}, 'htmlpage') ?'writeup' : 'document');
  } else {
    $NODE = $Everything::HTML::GNODE = getNodeById($Everything::CONF->search_results);
    $displaylike = getType($$NODE{type_nodetype});
  }

  my $PAGE = getPageForType($displaylike, $displaytype);
  my $title = lc($PAGE->{title});
  $title =~ s/ /_/g;

  if(my $delegation = Everything::Delegation::htmlpage->can($title))
  {
    return $delegation->($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
  }else{
   return parseCode($PAGE -> {page}, $NODE);
  }
}

sub nopublishreason
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # find any reasons for a user not being able to post a writeup (to an e2node)
  # second argument is optional.
  # returns text of reason, existing writeup, or ''

  my ($user, $E2N) = @_;
  $user ||= $USER;
  getRef $user;
  getRef $E2N if $E2N;

  if( $APP->isGuest($USER) )
  {
    return parseLinks('[login[superdoc]|Log in] or [Sign Up[superdoc]|register] to write something here or to contact authors.');
  }

  # unverified email address:

  return parseLinks('You need to [verify your email account[superdoc]] before you can publish writeups.') if $APP->isSuspended($user, 'email');

  # already has a writeup here:

  my @group = (); @group = @{ $$E2N{group} } if $E2N and $$E2N{group};
  foreach (@group)
  {
    getRef($_);
    return $_ if $$_{author_user} == $$user{node_id};
  }

  # no more checks if author has an editor-approved a draft for this node:
  my $linktype = getId(getNode 'parent_node', 'linktype');
  return '' if $E2N && $DB -> sqlSelect(
    'food' # 'food' is the editor
    , 'links JOIN node ON from_node=node_id'
    , "to_node=$$E2N{node_id} AND linktype=$linktype AND node.author_user=$$user{node_id}");

  my $notMe = ($$user{node_id} ne $$USER{node_id});

  # user on forbiddance:

  my $userlock = $DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$$user{user_id}");
  $userlock = {} if !$userlock && $APP->isSuspended($user, 'writeup');

  return ($notMe ? 'User is' : 'You are')
    .' currently not allowed to publish writeups. '
    .parseLinks($$userlock{nodelock_reason}) if $userlock;

  # node is locked:

  my $nodelock = undef; $nodelock = $DB->sqlSelectHashref('*', 'nodelock', "nodelock_node=$$E2N{node_id}") if $E2N;
  return '' unless $nodelock;

  return 'This node is locked. '
    .parseLinks($$nodelock{nodelock_reason}
    .($notMe ? '' : '<p>If you feel you have something to add to this node, attach your
    [Drafts[superdoc]|draft] to it and set its status to "review" to 
    request review and release for publication here by an [Content Editors[usergroup]|editor].</p>'));
}

sub e2nodetools
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  if ( $APP->isEditor($USER) )
  {
    my $str ="<div id='admintools'><h3>Admin Tools</h3>";
    $str .= htmlcode("addfirmlink");
    unless ($$NODE{group} && @{ $$NODE{group} })
    {
      $str .= htmlcode("addnodeforward")
        .htmlcode('openform')
        .'<fieldset><legend>Delete nodeshell</legend>Usually you should only delete a nodeshell if it is egregiously offensive
	or was created by mistake. If there is anything else wrong with it, you should just correct the spelling.<br>'
        .$query -> submit('sumbit', 'Delete')
        .$query -> checkbox(
          -name => 'op'
	  , value => 'nuke'
          , label => 'I really mean this')
        .'</fieldset></form>';
    } else {
      $str .= htmlcode("ordernode");
    }

    $str .= htmlcode('openform').'<fieldset><legend>Change title</legend>';		
    my $newTitle = $query->param('e2node_title') || "";
    if ($newTitle and $newTitle ne $query->param('oldTitle'))
    {
      # repair node if title has changed
      if ($$NODE{title} eq $newTitle)
      {
        htmlcode('repair e2node', $NODE, 'no-reorder');
        $str .= "Repaired node to rename all contained writeups.";
      } else {
        # failed rename
        my $reason = getNode($newTitle, 'e2node');
        $str .= $reason ? linkNode($reason).' already exists. '
          .linkNode(getNode('Magical Writeup Reparenter', 'superdoc')
          , 'Move all writeups &hellip;'
          , {old_e2node_id => $$NODE{node_id}
          , new_e2node_id => $$reason{node_id}
          , reparent_all => 1 }): 'Ack! Rename failed.';
      }

      $str .= '<br>';
    }

    $str .= htmlcode('textfield', 'title').$query -> hidden(
      -name => 'oldTitle'
      , value => $$NODE{title}
      , force => 1)
      .$query -> submit('rename', "Rename").'</fieldset></form>';

    $str .= htmlcode("softlock");
	
    return "$str\n</div>";
  }
}

sub showcurrentpoll
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $inNodelet = shift;

  my @POLL = getNodeWhere({poll_status => 'current'}, 'e2poll');
  return 'No current poll.' unless @POLL;

  my $str = htmlcode('showpoll', $POLL[0]);

  $str .= $inNodelet ? '<div class="nodeletfoot">': '<p align="right" class="morelink">';

  $str .= parseLinks('[Everything Poll Archive[superdoc]|Past polls]
    | [Everything Poll Directory[superdoc]|Future polls]
    | [Everything Poll Creator[superdoc]|New poll]
    <br> [Polls[by Virgil]|About polls]');

  $str .= $inNodelet? '</div>': '</p>';

  return $str;
}

sub showpoll
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($POLL, $showStatus) = @_;
  getRef $POLL;
  $POLL ||= $NODE;

  return "Ack! Can't find poll!" unless $POLL && $$POLL{type}{title} eq 'e2poll';

  my $vote = ($DB->sqlSelect(
    'choice'
    , 'pollvote'
    , "voter_user=$$USER{node_id} AND pollvote_id=$$POLL{node_id}"))[0];

  $vote = -1 unless defined $vote;

  $showStatus = " ($$POLL{poll_status})" if $showStatus;

  $showStatus ||= "";
  my $str = undef;
  $str = '<h2>'.linkNode($POLL)."$showStatus</h2>" unless $$POLL{node_id} == $$NODE{node_id};

  $str .= '<p><cite>by '.linkNode($$POLL{poll_author}, '', {-class => 'author'}).'</cite>';

  $str .= $query -> small(' ('.linkNode($POLL, 'edit', {displaytype => 'edit'}).')')
    if $$POLL{poll_status} eq 'new' && $query -> param('displaytype') ne 'edit' && canUpdateNode($USER, $POLL);

  $str .= '</p><h3>'
    .parseLinks($query -> escapeHTML($$POLL{question})) # question is unsanitised user input...
    .'</h3>';

  my @options = split /\s*\n\s*/s, parseLinks($$POLL{doctext});

  unless ($vote > -1 or $$POLL{poll_status} eq 'closed')
  {
    my @values = ();
    @options = map {(($values[scalar @values] = scalar @values) => $_)} @options;
    $query->autoEscape(undef);
    my $buttons = $query->radio_group(
      -name => 'vote',
      -values => \@values,
      -linebreak=>"true",
      -labels => {@options});
    $query->autoEscape(1);
    unless ($$POLL{poll_status} eq 'new')
    {
      $str .= htmlcode('openform', -class => 'e2poll')
        .qq'<input type="hidden" name="op" value="pollvote"><input type="hidden" name="poll_id" value="$$POLL{node_id}">'
        .$buttons
        .htmlcode('closeform', 'vote');
    } else {
      # new poll is inactive
      $str .= '<form class="e2poll">'.$buttons.'</form>'
    }
  } else {
    my @results = split ',', $$POLL{e2poll_results};
    my $votedivider = $$POLL{totalvotes}||1;
    $str .= '<table class="e2poll">';
    my $i = 0;
    while($options[$i])
    {
      $str.='<tr><td>'.($i == $vote ? '<b>' : '').$options[$i].($i ==$vote ? '</b>' : '').'</td>
        <td align="right">&nbsp;'.$results[$i].'&nbsp;</td>
        <td align="right">'.sprintf("%2.2f",($results[$i]/$votedivider)*100).'%</td></tr>';
      $str.="<tr><td colspan='3'><img class='oddrow' src='https://s3.amazonaws.com/static.everything2.com/dot.gif' height='8' width='"
        .sprintf("%2.0f",($results[$i]/$votedivider)*180)."' /></td></tr>";
      $i++;
    }
    $str.='<tr><td><b>Total</b></td>
      <td align="right">&nbsp;'.$$POLL{totalvotes}.'&nbsp;</td>
      <td align="right">'.sprintf("%2.2f",100).'%</td>
      </tr>';
    $str.='</table>';
  }

  return $str;
}

sub canpublishas
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # if an argument: return 1 if current user can publish under this name
  # if no argument: return a form control with names of accounts from which user can choose

  my $anonymousPublishLevel = 1; # users at or above this level can publish as 'everyone'
  my $target = shift;

  return '' unless($USER and not $APP->isGuest($USER) and $APP->getLevel($USER) >= $anonymousPublishLevel);

  my %accounts = (everyone => 1, Virgil => 'e2docs');

  @accounts{('Webster 1913', 'EDB', 'Klaproth', 'Cool Man Eddie')} = (1,1,1,1) if $APP->isEditor($USER);

  if ($target)
  {
    return '' unless $target;
    return 1 if $accounts{$target} == 1 or $DB->isApproved($USER, getNode($accounts{$target}, 'usergroup'));
    return '';
  }

  my @names = ();
  foreach (keys %accounts)
  {
    push @names, $_ if $accounts{$_} == 1 or $DB->isApproved($USER, getNode($accounts{$_}, 'usergroup'));
  }

  my $blah = '<br><small>N.B. By publishing to a different account you cede your copyright and lose all control over your writeup</small>';

  if (scalar @names == 1)
  {
    return $query -> checkbox(
      -name => 'publishas'
      , value => 'everyone'
      , label => "publish anonymously (as 'everyone')"
      ).$blah;

  } elsif(@names) {
    @names = sort {$a eq 'everyone' ? -1 : $b eq 'everyone' ? 1 : lc($a) cmp lc($b)} @names;
    return $query -> label(
      'publish as:'
      .$query -> popup_menu(
        -name => 'publishas'
        , -values => ['', @names]
        , default => ''
      )
    ).$blah;
  }

  return '';

}

sub Notifications_nodelet_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = '<p>We will notify you when...</p>';

  my $settingsHash = undef; $settingsHash = from_json($$VARS{settings}) if $$VARS{settings};

  if ($query->param('sexisgood'))
  {
    $settingsHash = {};
    my $notifierCount = 0;
    foreach ($query->param)
    {
      next unless /notification_(\d+)/;
      $$settingsHash{notifications}->{$1} = 1;
      $notifierCount++;
    }
    delete $$VARS{settings};
    $$VARS{settings} = to_json($settingsHash) if $notifierCount;
  }

  my @notifications = getNodeWhere('1 =1', "notification");
  my @notificationlist = ();
  foreach (@notifications)
  {
    next unless $$_{hourLimit} and htmlcode('canseeNotification', $_);
    push @notificationlist, [$query->checkbox('notification_'.$$_{node_id},
    $$settingsHash{notifications}->{$$_{node_id}},1,""),"$$_{description}<br>\n"];
  }

  @notificationlist = sort {my (@a,@b); @$a[1] cmp @$b[1];} @notificationlist;

  foreach my $thing (@notificationlist)
  {
    $str .= @$thing[0].@$thing[1];
  }

  $str .= '<br>'.linkNode($NODE, 'Remove Notifications nodelet', {
    op => 'movenodelet',
    position => 'x',
    nodelet => 'notifications',
    -id => 'notificationsremovallink',
    -class => 'ajax (notificationsremovallink):ajaxEcho:'
      .q!Remove+Notifications+nodelet!
      .q!&lt;script+type='text/javascript'&gt;!
      .q!e2.vanish($('#notifications'));&lt/script&gt;!
  }) unless $$VARS{settings};

  return $str;

}

sub Chatterbox_nodelet_settings
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '<h4>Chat</h4>'.

  parseCode(qq|
    [{varcheckbox:hideTopic,Hide the chatterbox topic}]<br>
    [{varcheckbox:powersChatter,Show user powers in chatterbox}]<br>
    <h4>Private messages</h4>
    [{varcheckbox:pmsgDate,Show date messages were sent}]<br>
    [{varcheckbox:pmsgTime,Show time messages were sent}]<br>
    [{varcheckbox:chatterbox_authorsince,Show when message sender was last seen}]<br>
    [{varcheckbox:chatterbox_msgs_ascend,Show oldest messages instead of newest}]<br>
    <br>
    [{varcheckboxinverse:showmessages_replylink,Hide reply-to link}]<br>
    [{varcheckbox:powersMsg,Show user powers in private messages}]<br>
    <br>
    [{varcheckbox:showRawPrivateMsg,Show sent message as you typed it (not with links)}]<br>
    [{varcheckbox:hideprivmessages,Don't show private messages in the chatterbox}]<br>
  |);
}

sub setdraftstatus
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # set publication_status and collaborators
  # show parent node, option to change it, and option to publish

  my $N = shift || $NODE;
  getRef $N;
  return '<div class="error">Not a draft.</div>' unless $$N{type}{title} eq 'draft';

  return htmlcode('parentdraft', $N) if $query -> param('parentdraft');

  my $ajax = "";
  $ajax = " instant ajax adminheader$$N{node_id}:voteit:$$N{node_id},5" if $query -> param('ajaxTrigger');

  my %stash = (
    public => 'visible to any logged-in user',
    findable => 'as "public," and may be shown in search findings',
    private => 'visible only to you and any users and groups you choose below',
    shared => 'your chosen collaborators can also edit',
    review => 'as "findable," and the site\'s editors are told you want feedback',
    removed => 'you published this and an editor removed it: as "private" but visible to editors',
    nuked => 'you published this and it was deleted before Jun 10, 2011: same as "private"'
  );

  my @status = $DB -> getNodeWhere({}, 'publication_status');
  my %labels = ();
  foreach (@status)
  {
    next unless $stash{$$_{title}};
    $labels{$_->{node_id}} = "$$_{title} <small>($stash{$$_{title}})</small>";
    $stash{$$_{title}} = $$_{node_id};

  }

  my @values = (map {$stash{$_} } qw(private shared public findable review)); #sorted!
  push @values, $$N{publication_status} if $stash{removed} == $$N{publication_status} || $stash{nuked} == $$N{publication_status};

  $query -> autoEscape(0);

  my $str = htmlcode('openform').qq'<fieldset class="draftstatus$ajax"><legend>Status and Sharing</legend>
    <p>Draft status:</p><p>'
    .$query -> radio_group(
      -name => 'draft_publication_status',
      values => \@values,
      labels => \%labels,
      default => $$N{publication_status},
      -force => 1,
      linebreak => 1
    ) # note current status to avoid repeat notifications:
    .$query -> hidden(
      -name => 'old_publication_status',
      value => $$N{publication_status},
      -force => 1
    ).'</p><p><label>Share with:<br>'
    .htmlcode('textfield', 'collaborators', 80, 'expandable')
    .'</label><br><small>';

  $query -> autoEscape(1);

  $str .= 'These users and groups can '
    .($labels{$$N{publication_status}} =~ /^private/
      ? 'see this draft but not edit it. '
      : 'edit this draft unless you set its status to "private." ') if $$N{collaborators};

  $str .= '(Put commas between names.)</small></p></p>';

  $str .= $query -> submit(
    -name => 'sexisgood',
    value => 'Update status/sharing')
    .$query -> hidden(
      -name => 'ajaxTrigger',
      value => 1,
      class => "ajax draftstatus$$N{node_id}:setdraftstatus:$$N{node_id}")
    .'</fieldset></form>';

  my $linktype = getId(getNode 'parent_node', 'linktype');

  if (my $newparent = $query -> param('writeup_parent_e2node'))
  {
    # remove old attachment
    $DB->sqlDelete('links', "from_node=$$N{node_id} AND linktype=$linktype");

    if ($newparent eq 'new')
    {
      my $title = $APP->cleanNodeName($query->param('title'));
      # insertNode checks user can do this and returns false if not or fails
      $newparent = $DB -> insertNode($title, 'e2node', $USER) if $title;
    }

    $DB -> sqlInsert('links', {
      from_node => $$N{node_id},
      to_node => $newparent,
      linktype => $linktype
      }) if $newparent && $newparent !~ /\D/;
  }

  my ($parent, $editor, $changeParent, $detach) = $DB -> sqlSelect(
    'to_node, food' # 'food' is the approving editor, if any
    , 'links'
    , "from_node=$$N{node_id} AND linktype=$linktype");

  if ($parent)
  {
    $parent = 'This draft is attached to: '
      .linkNode($parent, , 0, {-class => 'title'});
    $parent .= '<br>Approved for publication by '.linkNode($editor) if $editor;
    $changeParent = 'Change';
    $detach = $query -> submit(
      -name => 'writeup_parent_e2node',
      value => 'Detach',
      class => "ajax draftstatus$$N{node_id}:setdraftstatus?writeup_parent_e2node=/:$$N{node_id}"
      ).' &nbsp; ';
  } else {
    $parent = 'This draft is not attached to any page';
    $changeParent = 'Attach to page...';
    $detach = '';
  }

  my ($publishas, $advanced) = (undef,undef);
  if ($query->param('advanced'))
  {
    $publishas = htmlcode('canpublishas');

    $publishas = $query->p($publishas) if $publishas;

    $advanced = '<button type="submit" name="confirmop" value="publishdrafttodocument"
      title="publish this draft as a document">Publish as document</button>' if $APP->isEditor($USER);
 } else {
    $advanced = $query -> submit(
      -name => 'advanced'
      , value => 'Advanced option(s)...'
      , class => "ajax draftstatus$$N{node_id}:setdraftstatus?advanced=1:$$N{node_id}"
      ) if $APP->getLevel($USER);
  }

  $advanced = $query->p($advanced) if $advanced;

  $publishas = "" if not defined($publishas);
  $advanced = "" if not defined($advanced);
  $detach = "" if not defined($detach);

  unless ($stash{removed} == $$N{publication_status})
  {
    $str .= htmlcode('openform')
      ."<fieldset class=\"parentdraft\"><legend>Attachment and Publishing</legend>
      <p>$parent</p>
      $publishas
      $detach"
      .$query -> submit(
        -name => 'parentdraft',
        value => $changeParent,
        class => "ajax draftstatus$$N{node_id}:parentdraft?parentdraft=attach:$$N{node_id}"
        )
      .' &nbsp; '
      .$query -> submit(
        -name => 'parentdraft',
        value => 'Publish',
        class => "earlybeforeunload ajax draftstatus$$N{node_id}:parentdraft?parentdraft=Publish&publishas=/:$$N{node_id}"
        )
      ."<p><small>Attached drafts are shown on the page they are attached to:
        you always see your own draft, while other users with permission to see it
        can click on a link to show it.</small>
        </p>
        </fieldset>
        $advanced
        </form>";
  }

 return $query -> div({id => "draftstatus$$N{node_id}", class => 'parentdraft'}, $str);

}

sub ordernode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isEditor($USER);

  my $str = htmlcode('openform', 'adminordernode')
    .'<fieldset><legend>Writeups, order and repair</legend><p>'
    .$query -> hidden('repair_id', $$NODE{node_id})
    .$query -> hidden('showhidden', 'all');

  my $lockButt = 'Lock writeup order';
  if ($$NODE{orderlock_user})
  {
    $lockButt = 'Unlock';
    $str.= '<input type="hidden" name="unlock" value="1">';
  }

  $lockButt = qq' <button name="op" value="orderlock" type="submit"
    class="ajax adminordernode:ordernode?op=orderlock&unlock=/">$lockButt</button></p><p>';

  if($NODE->{orderlock_user})
  {
    $str .= 'Writeup ordering locked by '
      .linkNode($$NODE{orderlock_user})
      ."$lockButt";
  }else{
    $str .= htmlcode("windowview", "editor,Edit writeup order&hellip;").$lockButt;
    $str .= '<button name="op" value="repair_e2node" type="submit">Repair and reorder node</button> ';
  }

  $str .= '<button name="op" value="repair_e2node_noreorder" type="submit">Repair without reordering</button></p>'
    .linkNode(getNode('Magical Writeup Reparenter', 'superdoc')
      , 'Reparent writeups&hellip;'
      , {old_e2node_id => $$NODE{node_id}});

  return "$str</fieldset></form>";
}

sub addNodenote
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($notefor, $notetext, $user) = @_;

  getRef $user;
  $notefor = getId $notefor;

  if($user)
  {
    $notetext="[$$user{title}\[user]]: $notetext";
    $user = $$user{user_id};
  }
  $user ||= 0;

  $DB->sqlInsert("nodenote", {
    nodenote_nodeid => $notefor
    , noter_user => $user
    , notetext => $notetext});

  my $nodenote_id = $DB->{dbh}->last_insert_id(undef, undef, qw(nodenote nodenote_id)) || 0;

  htmlcode('addNotification', 'nodenote', 0, {
    node_noter => $user
    , node_id => $notefor
    , nodenote_id => $nodenote_id}) if $user;

  return $nodenote_id;
}

sub unpublishwriteup
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($wu, $reason) = @_;

  getRef $wu;
  return unless $wu and $$wu{type}{title} eq 'writeup';

  return unless $$USER{node_id} == $$wu{author_user} or $APP->isEditor($USER);

  my $id = $$wu{node_id};
  my ($title, $noexp) = ($$wu{title}, 0);

  my $E2NODE = getNodeById($$wu{parent_e2node});

  if ($E2NODE)
  {
    $noexp = $APP->isMaintenanceNode($E2NODE);
    $title = $E2NODE -> {title};
  }elsif ($title =~ / \((\w+)\)$/ and getNode($1, 'writeuptype')){
    $title =~ s/ \((\w+)\)$//;
  }

  my $draftType = getType('draft');
  return 0 unless $DB -> sqlUpdate('node, draft', {
    type_nodetype => $draftType -> {node_id},
    title => $title,
    publication_status => getId(getNode('removed', 'publication_status'))},"node_id=$id AND draft_id=$id"
  );

  $$wu{title} = $title; # save possible fiddling elsewhere (e.g. in [remove])
  $$wu{type} = $draftType;
  $$wu{type_nodetype} = $draftType -> {node_id};
  delete $$wu{wrtype_writeuptype};

  $DB->sqlDelete('writeup', "writeup_id=$id");
  $DB->removeFromNodegroup($E2NODE, $wu, -1) if $E2NODE;

  $DB->{cache}->incrementGlobalVersion($wu); # tell other processes this has changed...
  $DB->{cache}->removeNode($wu); # and it's in the wrong typecache, so remove it

  $DB->sqlDelete('newwriteup', "node_id=$id");
  $APP->updateNewWriteups();

  $DB->sqlDelete('publish', "publish_id=$id");
  $DB->sqlDelete('links',
    "to_node=$id OR from_node=$id AND linktype=".getId(getNode('category', 'linktype')));

  my ($remover, $notification) = (undef,undef); my %editor = ();

  if ($$USER{node_id} == $$wu{author_user})
  {
    $remover = $notification = 'author';
  }else{
    $remover = "[$$USER{title}\[user]]";
    $notification = 'editor';
    %editor = (editor_id => $$USER{user_id});
  }

  htmlcode('addNotification', "$notification removed writeup", 0, {
    writeup_id => $$wu{node_id}
    , title => $$wu{title}
    , author_id => $$wu{author_user}
    , reason => $reason
    , %editor});

  $reason = ": $reason" if $reason;
  htmlcode('addNodenote', $wu, "Removed by $remover$reason");

  my $author = getNodeById($$wu{author_user});
  my $mass = getNode('massacre', 'opcode');

  $APP->securityLog(getNode('massacre', 'opcode'), $USER, "[$title] by [$$author{title}] was removed$reason");

  unless($noexp)
  {
    $APP->adjustExp($$wu{author_user}, -5);

    my $vars = getVars $author;
    $$vars{numwriteups}--;
    $$author{numwriteups} = $$vars{numwriteups};

    setVars($author, $vars);
    updateNode($author, -1);
  }

  return 1;
}

sub ajax_publishhere
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $did = shift;

  my $nope = htmlcode('nopublishreason', $USER, $query -> param('writeup_parent_e2node'));
  return '<div>'
    .(ref $nope? 'You already have a writeup here.': $nope)
    .'</div>' if $nope;

  return $query -> hidden('writeup_parent_e2node')
    .$query -> hidden('draft_id', $did)
    .htmlcode('setwriteuptype', {node_id => $did})
    # class makes name get changed to 'op' and form get submitted on click:
    .'<br>
    <button type="button" name="publishbutton" value="publishdraft" class="wuformaction">Publish</button>';
}

sub show_paged_content
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($select, $from, $where, $orderby, $instructions, %functions) = @_;
  my %parameters = $query->Vars();

  $orderby =~ s/\s*\bLIMIT\s+(\d+)\s*$//si;

  $parameters{perpage} ||= $1 || 50;
  $parameters{perpage} = int $parameters{perpage}; #SQueaL safely
  my $page = 1; # default
  $page = int(abs(delete $parameters{page})) if(defined($parameters{page}));

  my ($offset, $crs, $rowCount, $pageCount) = (undef,undef,undef,undef);

  do{
    $offset = ($page - 1) * $parameters{perpage};
    $crs = $DB -> sqlSelectMany(
      "SQL_CALC_FOUND_ROWS $select"
      , $from
      , $where
      , "$orderby LIMIT $offset, $parameters{perpage}");
	
    $rowCount = $DB -> sqlSelect('FOUND_ROWS()');
    $pageCount = int(($rowCount - 1)/$parameters{perpage}) + 1;

  } while $page > $pageCount && ($page = $pageCount);

  my $content = $instructions ? htmlcode('show content', $crs, $instructions, %functions)
    : $crs; # no instructions: caller wants to handle it

  my $navigation = '';

  if ($pageCount > 1)
  {
    # 3 possible parameters from url, 1 an ecore mistake, 1 from submit button
    delete @parameters{qw(node node_id type op sexisgood)};
    my $link = sub{
      my ($p, $text) = @_;
      my %class = (); %class = (-class => $1.'link') if $text && $text =~ /(?:^|;)(\w+)/;
      $text ||= $p;

      '&nbsp;'.linkNode($NODE, $text, {
        %parameters
        , page => $p
        , -title => "go to page $p"
        , %class
      }).' ';
    };

    my @navigation = ();
    $navigation[$page] = qq'<b class="thispage">&nbsp;$page </b>';

    # show five page numbers including this one, plus first and last,
    # plus second/second-last if we also have 3rd/3rd last. Dots in gaps.
    # max 9 links/dotties, so show all if count <= 9
    # 'go to' box if missing links
    my ($n, $z) = $pageCount > 9
      ? (5, $pageCount - $page < 2 ? $pageCount - 5 : $page - 3)
      : ($pageCount, 0);
    my $i = $page;

    until($navigation[((--$i > $z) and $i) or ($i = $i + $n)])
    {
      $navigation[$i] = &$link($i);
    }

    if ($pageCount > 9)
    {
      $navigation[1] ||= &$link(1);
      $navigation[2] ||= $navigation[3] ? &$link(2) : '&nbsp;&hellip; ';
      $navigation[$pageCount] ||= &$link($pageCount);
      $navigation[-2] ||= $navigation[-3] ? &$link($pageCount - 1) : '&nbsp;&hellip; ';

      $navigation = '<p><label>Go to page:<input type="text" name="page" size="2"></label>'
        .$query -> submit('submit', 'Go');

      unless($functions{noform})
      {
        $navigation = htmlcode('openform', -class => 'pagination', -method => 'get')
          .join ("\n",
            map {$query -> hidden($_, $parameters{$_})} keys %parameters)
          .$navigation
          .'</form>';
      }else{
        $navigation = $query -> div({class=>'pagination'}, $navigation);
      }
    }

    $navigation[0] = &$link(1, '&#xAB;&#xAB;first') if $page > 2;
    $navigation[0] .= &$link($page - 1, '&#xAB;prev') if $page > 1;
    $navigation[$pageCount] .= &$link($page + 1, 'next&#xBB;')
    unless $page == $pageCount;
    $navigation[$pageCount] .= &$link($pageCount, 'last&#xBB;&#xBB;')
    unless $page > $pageCount - 2;

    @navigation = map {defined($_)?($_):('')} @navigation;
    $navigation ='<p class="pagination">Pages: '
      .join('', @navigation)
      ."</p>$navigation";
  }

  my $last = $offset + $parameters{perpage};
  $last = $rowCount if $last > $rowCount;

  return ($content, $navigation, $rowCount, $offset + 1, $last) if wantarray;
  return qq'$content $navigation';
}

sub drafttools
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my ($N, $open) = @_;
  getRef $N;

  return htmlcode('writeuptools', @_) if $$N{type}{title} eq 'writeup';

  my $isEditor = $APP->isEditor($USER);

  my $isMine = ($$N{author_user} == $$USER{node_id});

  my @tools = ();
  my ($text , $linktitle, $attachment, $notes) = (undef,undef,undef,undef);
  my $n = $$N{node_id};
  my $id = 'adminheader'.$n ;

  my $author = getNodeById( $$N{author_user} );
  $author = $query -> escapeHTML($$author{title}) if $author;

  my $status = undef; $status = getNodeById($$N{publication_status}) if $$N{publication_status};
  $status = $$status{title} if $status;

  $text = $status || 'private';
  $text = "$text/tin-opened" if $query -> param('tinopener')
    and $$N{collaborators} ne $$N{_ORIGINAL_VALUES}{collaborators};

  $linktitle = {
    private => $isMine ? 'only visible to you and your collaborators' :
      "$author has given you permission to see this draft",
    shared =>  $isMine ? 'visible to you and your collaborators (who can also edit it)' :
      "$author has given you permission to see and edit this draft",
    public => 'visible to all logged-in users',
    findable => 'visible to all logged-in users, and may be shown in search findings',
    review => 'comments/suggestions invited',
    removed => 'removed by an editor',
    nuked => 'posted and deleted before June 10, 2011'} -> {$text} || $text;

  $text =~ s/^(\w)/\u$1/;
  $text .= '<sup>*</sup>' if $text eq 'private' && !$isMine;
  $text = "<b>$text draft</b>";

  if ($isMine and $$NODE{node_id} != $n)
  {
    push @tools, linkNode($N, 'Set draft status...', { # can't put the forms here: we're already in a form
      '#' => "draftstatus$n"
      , -class => "ajax draftstatus$n:setdraftstatus?node_id=$n:$n"
      , -onclick => "parent.location='#draftstatus$n'" # inline JS. Whatever next? 
      });
	
    $attachment = linkNode($N, 'Publish here', {
      '#' => "draftstatus$n"
      , parentdraft => 'publish'
      , writeup_parent_e2node => $$NODE{node_id}
      , -id => "publishhere$n"
      , -class => "ajax publishhere$n:ajax+publishhere:$n"
      });
  }

  if ($isEditor)
  {
    my $linktype = getId(getNode 'parent_node', 'linktype');
    my ($parent, $approver) = $DB -> sqlSelect( # editor approval is flagged by feeding the link
      'to_node, food', 'links', "from_node=$$N{node_id} AND linktype=$linktype");

    unless ($status eq 'private' || $status eq 'removed' || $isMine)
    {
      my %options = (private => 'Made Private', public => 'Removed from review');
      my $change = $query -> param('smiteStatus');

      if ($change && $options{$change})
      {
        $$N{publication_status} = getId(getNode($change, 'publication_status'));
        updateNode($N, -1);
        $text = $status = $linktitle = $options{$change};
        $DB->sqlUpdate('links', {food => ($approver = 0)},
          "from_node=$$N{node_id} AND linktype=$linktype") if $approver;
      }else{
        push @tools, linkNode($N, 'Remove from review', {
          smiteStatus => 'public'
          , -class => "action ajax $id:drafttools:$n,1"
          }) if $status eq 'review';
        push @tools, linkNode($N, 'Make private', {
          smiteStatus => 'private'
          , -class => "action ajax $id:drafttools:$n,1"});
      }

    }elsif($status eq 'removed'){
      $attachment = linkNode($N, 'Unremove', {
        parentdraft => 'publish'
        , -class => "ajax republish:parentdraft"
        , -title => 'republish this because someone goofed'});
    }

    if (($parent and $approver) or ($status eq 'review'))
    {
      $attachment ||= 'Attached to '
        .$query -> b(linkNode($parent, $$NODE{node_id} == $parent ? 'this node' :''));

      my $approve = '';
      if ($approver)
      {
         $attachment .= '<br><br>Approved for publication by '.linkNode($approver);
         $linktitle .= '. Approved';
         $approve = 'Revoke approval';
      }else{
         my $block = htmlcode('nopublishreason', $$N{author_user}, $parent);
         if ($block && !ref($block) && $block !~ /email/)
         {
           $attachment .= "<br><br>Requires approval before publication because:<br>
             <small style='white-space:normal'>$block</small>";
           $linktitle .= '. Needs approval';
           $approve = 'Approve';
         }
      }

      $attachment .= '<br><br>'.linkNode($N, "<b>$approve</b>", {
        op => 'approve_draft'
        , revoke => $approver
        , draft => $$N{node_id}
        , e2node => $parent
        , -class => "action ajax $id:drafttools:$n,1" }) if $approve;

    }

    $notes = htmlcode('nodenote', $N) if $status eq 'review';
  }

  push @tools, $attachment if $attachment;
  push @tools, $notes if $notes;

  if (@tools)
  {
    $query -> param('showwidget' , 'admin') if $open;
    $text = htmlcode('widget'
      , join('<hr>', @tools)
      , 'span'
      , $text
      , {showwidget => 'admin', -title => "$linktitle. Click here to show/hide admin options."}
    );
    $linktitle = '';
  }

  return $query -> span({class => 'admin', id => $id, title => $linktitle}, $text);
 
}

sub blacklistedIPs
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = undef;
  my $offset = int($query->param('offset')) || 0;
  my $pageSize = 200;
  my ($firstItem, $lastItem) = ($offset + 1, $offset + $pageSize);
  my $records = $pageSize * 2;
  my $displayCount = $pageSize;

  ###################################################
  # addrFromInt
  ###################################################
  # Takes an integer representing an IPv4 address
  #  as an argument
  #
  # Returns a string with dotted IP notation
  ###################################################
  my $addrFromInt = sub {
    my $intAddr = shift;
    my ($oc1, $oc2, $oc3, $oc4) =
      ($intAddr & 255
      , ($intAddr >> 8) & 255
      , ($intAddr >> 16) & 255
      , ($intAddr >> 24) & 255);
    return "$oc4.$oc3.$oc2.$oc1";
  };

  ###################################################
  # rangeBitsFromInts
  ###################################################
  # Takes two integers representing ends of an IP
  #  address range.
  #
  # Returns the number of bits it spans if they
  #  represent a CIDR range.
  # Returns undef otherwise.
  ###################################################
  my $rangeBitsFromInts = sub {
    my ($minAddr, $maxAddr) = @_;
    my $diff = abs($maxAddr - $minAddr) + 1;
    my $log2diff = log($diff)/log(2);
    my $epsilon = 1e-11; 
    return if (($log2diff - int($log2diff)) > $epsilon);
    return (32 - $log2diff);
    };

  ###################################################
  # populateAddressForRange
  ###################################################
  # Takes a hashref containing either data about IP
  #  blacklist entry or an IP blacklist range entry
  # If it contains a range entry, Modifies the row
  #  so ipblacklist_address contains a string
  #  representation
  #
  # Returns nothing
  ###################################################
  my $populateAddressForRange = sub {
    my $row = shift;

    if (defined $$row{min_ip})
    {
      my ($minAddrInt, $maxAddrInt) = ($$row{min_ip}, $$row{max_ip});
      my ($minAddr, $maxAddr) = (&$addrFromInt($minAddrInt), &$addrFromInt($maxAddrInt));
      my $bits = &$rangeBitsFromInts($minAddrInt, $maxAddrInt);
      if (defined $bits)
      {
        $$row{ipblacklist_ipaddress} = "$minAddr/$bits";
      } else {
        $$row{ipblacklist_ipaddress} = "$minAddr - $maxAddr";
      }
    }
  };

  ###################################################
  # removeButton
  ###################################################
  # Takes a hashref containing either data about IP
  #  blacklist entry or an IP blacklist range entry
  #
  # Returns a string containing a submit button to
  #  remove the given entry
  ###################################################
  my $removeButton = sub {
    my ($row) = @_;
    my $hiddenHash = { };
    $$hiddenHash{-name}  = 'remove_ip_block_ref';
    $$hiddenHash{-value} = $$row{ipblacklistref_id};
    my $result =  $query->hidden($hiddenHash) . ''. $query->submit({ -name => 'Remove' });

    return $result;
  };

  ###################################################
  ###################################################
  # End Functions
  ###################################################

  my $getBlacklistSQL = qq|
  SELECT ipblacklistref.ipblacklistref_id
    , IFNULL(ipblacklist.ipblacklist_user, ipblacklistrange.banner_user_id)
    'ipblacklist_user'
    , ipblacklist_timestamp
    , ipblacklist.ipblacklist_ipaddress
    , IFNULL(ipblacklist.ipblacklist_comment, ipblacklistrange.comment)
    'ipblacklist_comment'
    , ipblacklistrange.min_ip
    , ipblacklistrange.max_ip
    FROM ipblacklistref
    LEFT JOIN ipblacklistrange ON ipblacklistrange.ipblacklistref_id = ipblacklistref.ipblacklistref_id
    LEFT JOIN ipblacklist ON ipblacklist.ipblacklistref_id = ipblacklistref.ipblacklistref_id
    WHERE (ipblacklist_id IS NOT NULL OR ipblacklistrange_id IS NOT NULL)
    ORDER BY ipblacklist_timestamp DESC
    LIMIT $offset,$records|;

  my $cursor = undef;
  my $saveRaise = $DB->{dbh}->{RaiseError};
  $DB->{dbh}->{RaiseError} = 1;
  ## no critic (RequireCheckingReturnValueOfEval)
  eval { 
    $cursor = $DB->{dbh}->prepare($getBlacklistSQL);
    $cursor->execute();
  };
  ## use critic (RequireCheckingReturnValueOfEval)

  $DB->{dbh}->{RaiseError} = $saveRaise;

  if ($@)
  {
    $str .= "<h3>Unable to load IP blacklist</h3>";
    return $str;
  }

  my $fetchResults = $cursor->fetchall_arrayref({});
  my $resultCount = scalar @$fetchResults;
  # Shorten fetchResults to just the items we will display
  $fetchResults = [ @$fetchResults[0..($displayCount - 1)] ];

  my ($prevLink, $nextLink) = ('', '');

  if ($offset > 0)
  {
    my $prevOffset = $offset - $pageSize;
    my $offsetHash = { };
	
    $$offsetHash{showquery} = $query->param('showquery') if $query->param('showquery');

    if ($prevOffset <= 0)
    {
      $prevOffset = 0;
    } else {
      $$offsetHash{offset} = $prevOffset;
    }

    $prevLink = linkNode(
      $NODE
      , "Previous (" . ($prevOffset + 1) . " - " . ($prevOffset + $pageSize) . ")"
      , $offsetHash);

  }

  if ($resultCount > $pageSize)
  {
    my $maxRecord = $offset + $resultCount;
    my $offsetHash = { 'offset' => $offset + $pageSize };
	
    $$offsetHash{showquery} = $query->param('showquery') if $query->param('showquery');

    $nextLink = linkNode(
      $NODE
      , "Next (" . ($pageSize + $offset + 1) . " - " . $maxRecord . ")"
      , $offsetHash
      );
  } else {
    $lastItem = $offset + $resultCount;
    $displayCount = $resultCount;
  }

  my $header = qq|
    <h3>Currently blacklisted IPs (#$firstItem - $lastItem)</h3>
    <p>
    $prevLink
    $nextLink
    </p>
    <table border="1" cellspacing="2" cellpadding="3">
      <tr>
        <th>IP Address</th>
        <th>Blocked<br>by user</th>
        <th>Blocked on/at</th>
        <th>Reason</th>
        <th>Remove?</th>
      </tr>|;

  $str .= $header;

  $str .= "<pre>$getBlacklistSQL</pre>" if $query->param('showquery');

  # Don't retain the value if we just deleted a block
  $query->delete('remove_ip_block_ref');

  for my $row (@$fetchResults)
  {
    &$populateAddressForRange($row);
    $str .= "<tr>"
      ."<td>$$row{ipblacklist_ipaddress}</td>"
      ."<td>".linkNode($$row{ipblacklist_user})."</td>"
      ."<td>$$row{ipblacklist_timestamp}</td>"
      ."<td>$$row{ipblacklist_comment}</td>"
      ."<td>"
      . htmlcode('openform', 'removebanform')
      . &$removeButton($row)
      . $query->end_form()
      ."</td>"
      ."</tr>"
  }

  $str .= "</table>";

  return $str;

}

sub resurrectNode
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  
  my ($node_id) = @_;

  my $N = $DB->sqlSelectHashref("*", 'tomb', "node_id=".$DB->{dbh}->quote("$node_id"));
  return unless $N;

  my $NODEDATA = eval($$N{data});

  @$N{keys %$NODEDATA} = values %$NODEDATA;

  delete $$N{data};
  delete $$N{killa_user};
  delete $$N{node_id};

  return $N;
}

sub reinsertCorpse
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
  
  my ($N) = @_;
  my @kids = ();
  if ($$N{group})
  {
    foreach (@{ $$N{group} })
    {
      my $KID = htmlcode("resurrectNode",$_);
      push @kids, htmlcode("reinsertCorpse", $KID);
    }
  }

  my $author = $$N{author_user};
  delete $$N{author_user};
  my $title = $$N{title};
  delete $$N{title};
  my $type = $$N{type_nodetype};
  delete $$N{type_nodetype};
  delete $$N{group} if exists $$N{group};

  my $A = getNodeById($author);
  $A = getNode('root','user') unless $A;
  my $id = insertNode($title, $type, $A, $N);
  insertIntoNodegroup($id, $author, \@kids) if @kids;
  return $id;
}

sub frontpage_creamofthecool
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $length = 512;
  my $str = htmlcode( 'show content' , $DB->stashData("creamofthecool"), 'parenttitle, type, byline,'.$length ) ;

  # stop PRE breaking layout: replace PRE with TT; fix spaces and newlines to still work
  while ( $str =~ /<pre>(.*?)<\/pre>/si )
  {
    my $temp = $1;
    $temp =~ s/\n/<br>/g;
    $str =~ s/<pre>(.*?)<\/pre>/<tt>$temp<\/tt>/si;
    $str =~ s/  / &nbsp;/g; # replace two spaces with space and nbsp
  }

  $str =~ s!<hr.+>!<hr>!ig ; # no width on hr to avoid stretch

  # For the transition period, pretend this is a nodelet
  return qq|<div id="cotc">$str</div>|;
}

sub frontpage_cooluserpicks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  my $cache = $DB->stashData("coolnodes");

  my $count = 15;
  my %used = ();

  $str.="\n\t<ul class=\"linklist\">";

  foreach my $CW (@$cache) {
    next if exists $used{$$CW{coolwriteups_id}};
    $used{$$CW{coolwriteups_id}} = 1;
    $str.="\n\t\t<li>".linkNode($$CW{coolwriteups_id}, $$CW{parentTitle}, {lastnode_id => 0}) ."</li>";
    last unless (--$count);
  }

  $str.= parseLinks("</ul><div class='nodeletfoot morelink'>([Cool Archive|more])</div>" );
  return $str;
}

sub frontpage_staffpicks
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<ul class="linklist">|;

  foreach my $N(@{$DB->stashData("staffpicks")})
  {
    $str .= qq|<li>|.linkNode(getNodeById($N), '', {lastnode_id => 0}).qq|</li>|;
  }

  $str .= qq|</ul><div class="nodeletfoot morelink">(|.linkNodeTitle("Page of Cool|more").qq|)</div>|;

  return $str;

}

sub frontpage_news
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<div class="weblog">|;
  
  my $fpnews = $DB->stashData("frontpagenews");

  my $newsnodes = [];
  foreach my $N(@$fpnews)
  {
    push @$newsnodes, $DB->getNodeById($N->{to_node});
  }

  my %weblogspecials = ();

  # Lifted largely from [weblog]

  $weblogspecials{ getloggeditem } = sub {
    my ( $L ) = @_ ;
    my $N = getNodeById( $L->{ to_node } ) ;
    # removed nodes/de-published drafts:
    return "Can't get node id ".$L->{ to_node } unless $N and $$N{type}{title} ne 'draft';
    $_[0] = { %$N , %$L } ; # $_[0] is a hashref from a DB query: no nodes harmed
    return '' ;
  } ;

  $str.= htmlcode("show content", $newsnodes, "getloggeditem, title, byline, date, linkedby, content");

  $str .= qq|</div>|;
  return $str;
}

sub frontpage_altcontent
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<div class="cotc">|;
  my $fpcontent = $DB->stashData("altfrontpagecontent") || [];
  my $content = [];
  foreach my $N(@$fpcontent)
  {
    push @$content, $DB->getNodeById($N);
  }

  $str .= htmlcode("show content", $content, 'parenttitle, type, byline,1024-512');

  $str .= qq|</div>|;
  return $str;

}

sub giftshop_star
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if ($$VARS{GPoptout});

  my $str = "";
  my $minLevel = 1;
  my $userLev = $APP->getLevel($USER);
  my $userGP = $$USER{GP};
  my $StarMax = 75;
  my $StarMin = 25;
  my $StarCost = $StarMax - (($userLev - 1) * 5);

  if ($StarCost < $StarMin) {$StarCost = 25};

  $str.= "<p><hr width='300' /></p><p><b>The Gift of Star</b></p>";

  if ($userLev < $minLevel)
  {
    $str.="<p>Sorry, you must be at least [Level $minLevel] to purchase a Star. Please come back when you have reached Level $minLevel.</p>";

    return $str;
  }

  $str.= "<p>Because you are Level $minLevel or higher, you have the power to purchase a Star to reward other users. For Level $userLev users, Stars currently cost <b>$StarCost GP</b>.";
  if ($StarCost > $StarMin)
  {
    $str.=" Gain another level to reduce the Star cost by 5 GP.</p>";
  } else {
    $str.="</p>";
  }

  $str.="<p>Giving a user a Star sends them a private message telling them that you have given them a Star and informing them of the reason why they earned it.</p>";

  if ($userGP < $StarCost)
  {
    $str.="<p>Sorry you do not have enough GP to buy a Star right now. Please come back when you have <b>$StarCost GP</b>.</p>";
    return $str;
  } else {
    $str.="<p>You have <b>$userGP GP</b>.</p>";
  }

  if ($query->param('give_star'))
  {
    my $recipient = $query->param('givee');
    my $reason = $query->param('starReason');
    my $Color = $query->param('starColor');
    my $U = getNode($recipient, 'user');
    my $article = "b";
    return "<p><hr width='300' /></p><p><b>The Gift of Star</b></p><p>That user doesn't exist! Please [E2 Gift Shop|try again].</p>" unless $U;
    return "<p><hr width='300' /></p><p><b>The Gift of Star</b></p><p>Sorry, you cannot give a star to yourself! Please [E2 Gift Shop|try again].</p>" if ($$U{user_id} == $$USER{user_id});
    return "<p><hr width='300' /></p><p><b>The Gift of Star</b></p><p>You must enter a reason. Please [E2 Gift Shop|try again].</p>" unless $reason;
    if ( $Color =~ /^\s*[aeiou]/i )
    {
      $article = "an"; 
    } else {
      $article = "a";
    } 

    $$U{stars} += 1;
    updateNode($U,-1);
    $APP->adjustGP($USER, -$StarCost);
    $APP->securityLog(getNode('The Gift of Star', 'node_forward'), $USER, "[$$USER{title}] gave $article $Color Star to [$$U{title}] at the [E2 Gift Shop].");

    my $from = $$USER{title};
    htmlcode('sendPrivateMessage',{
      'author_id' => getId(getNode('Cool Man Eddie', 'user')),
      'recipient_id' => $$U{user_id},
      'message' => "Sweet! [$from] just awarded you $article [Star|$Color Star], because <i>$reason</i>"});
    $str = "<p><hr width='300' /></p><p><b>The Gift of Star</b></p><p>Okay, $article $Color Star has been awarded to [" . $$U{title} ."]. ";

    if ($$USER{GP} >= $StarCost)
    {
      return $str . "You have <b>" . $$USER{GP} . "</b> GP left. Would you like to [E2 Gift Shop|give another Star]?</p>";
    }

    return $str . "You now have <b>" . $$USER{GP} . "</b> GP left.</p>";

  }

  $str.=$query->start_form();
  $str.=$query->hidden('node_id', $$NODE{node_id});
  $str.="<p>Yes! Please give a " . $query->textfield('starColor', 'Gold', 10) . " Star to noder " . $query->textfield('givee');
  $str.=" because " . $query->textfield('starReason', '', 40) . "</p>";
  $str.=$query->submit('give_star','Star Them!');
  $str.=$query->end_form();

  return $str;
}

sub giftshop_sanctify
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return if ($$VARS{GPoptout});

  my $minLevel = 11;
  my $Sanctificity = 10;

  return unless $APP->getLevel($USER)>= $minLevel or $APP->isEditor($USER);

  my $str = "<p><hr width='300' /></p><p><b>The Gift of Sanctity</b></p><p>You are at least [The Everything2 Voting/Experience System|Level $minLevel], so you have the power to [Sanctify user|Sanctify] other users with GP. Would you like to [Sanctify user|sanctify someone]?</p><p>You may also sanctify other users by clicking on the link on their homenode, or by using the \/sanctify command in the [Chatterbox].";

  return $str;

}

sub giftshop_buyvotes
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $voteCost = 1;

  my $minlevel = 2;
  my $lvl = $APP->getLevel($USER);
  my $CurGP = $$USER{GP};

  my $str = "<p><hr width='300' /></p><p><b>The Gift of Votes</b></p>";

  return $str if ($$VARS{GPoptout});

  if (($lvl >= $minlevel) && ($CurGP >= $voteCost))
  {
    $str.="<p>Because you are at least [The Everything2 Voting/Experience System|Level $minlevel] you can also buy additional votes, if you want. Each additional vote costs <b>$voteCost GP</b>. You currently have <b>$CurGP GP</b>.</p><p>Please note that these votes will expire and reset at the end of the day, just like normal votes.</p>";

    my $voteIncrease = $query->param("numVotes");

    if ($query->param('buyVotes'))
    {

      if ($voteIncrease < 1)
      {
        $str.="<p>You must enter a positive number.</p>";
      } elsif ($voteIncrease <= $$USER{GP}) {

        $$USER{votesleft} += $voteIncrease;
        $$USER{GP} -= ($voteIncrease*$voteCost);
        $APP->securityLog(getNode('Buy Votes', 'node_forward'), $USER, "$$USER{title} purchased $voteIncrease votes at the [E2 Gift Shop].");
        updateNode($USER, -1);

        $str= "<p><hr width='300' /></p><p><b>The Gift of Votes</b></p><p>You now have <b>$$USER{votesleft}</b> total votes. Happy voting!</p>"; 
      } else {
        $str.="<p>You do not have enough GP!</p>";
      }
    }

    $str.=htmlcode('openform');
    $str.="</p><p>How many votes would you like to buy? " . $query->textfield('numVotes')."<br /><br />";
    $str.=$query->submit("buyVotes","Buy Votes");
    $str.=$query->end_form;

  } elsif ($lvl >= $minlevel) {

    return "<p><hr width='300' /></p><p><b>The Gift of Votes</b></p><p>You do not have enough GP to buy votes at this time. Please come back when you have more GP!</p>";

  } else {

    return "<p><hr width='300' /></p><p><b>The Gift of Votes</b></p><p>You are not a high enough level to buy votes yet. Please come back when you reach [The Everything2 Voting/Experience System|Level $minlevel]!</p>";

  }

  return $str;
}

sub giftshop_votes
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $minLev = 9;
  my $votesLev = 1;
  my $lvl = $APP->getLevel($USER);
  my $vts = $$USER{votesleft};

  return if (($lvl < $votesLev) || ($lvl < $minLev));

  my $str = "<p>Give the gift of votes! If you happen to have votes to spare, you can give up to 25 of them at a time to another user as a gift. Please use this to encourage newbies.</p>";

  return $str."<p>Sorry, but it looks like you don't have any votes to give away now. Please come back when you have some votes.</p>" if $vts < 1;

  $str.="<p>You currently have <b>$vts</b> votes.</p>";

  if ($query->param('give_votes'))
  {
    my $recipient = $query->param('give_to');
    my $amt = $query->param('votesGiven');
    my $U = getNode($recipient, 'user');
    return "<p>That user doesn't exist! Please [E2 Gift Shop|try again].</p>" unless $U;
    return "<p>You do not have that many votes! Please [E2 Gift Shop|try again].</p>" unless $amt <= $vts;
    return "<p>You must enter a number less than 26 and greater than zero. Please [E2 Gift Shop|try again].</p>" if ($amt < 1 || $amt > 25);
    $$U{votesleft}+=$amt;
    $$U{sanctity} += 1;
    updateNode($U,-1);
    $$USER{votesleft}-=$amt;
    updateNode($USER, -1);
        
    $APP->securityLog(getNode('The Gift of Votes', 'node_forward'), $USER, "$$USER{title} gave $amt of their votes to $$U{title} at the [E2 Gift Shop].");

    my $from =  ($query->param('anon') eq 'sssh') ? "someone mysterious" : ('[' . $$USER{title} . ']');
    htmlcode('sendPrivateMessage',{
      'author_id' => getId(getNode('Cool Man Eddie', 'user')),
      'recipient_id' => $$U{user_id},
      'message' => "Whoa! $from just [E2 Gift Shop|gave you] ".($amt||"0")." vote".($amt == 1 ? "" :"s")." to spend. You'd better use 'em by midnight, baby!" });
    $str = "<p>Okay, ".($amt||"0")." vote".($amt == 1 ? " is" :"s are")." waiting for [" . $$U{title} ."]. ";
    if ($$USER{votesleft} != 0)
    {
      return $str . "You have <b>" . $$USER{votesleft} . "</b> votes left. Would you like to [E2 Gift Shop|give some more]?</p>";
    }

    return $str . "Those were your last votes for today!</p>";
  }

  $str.=$query->start_form();
  $str.=$query->hidden('node_id', $$NODE{node_id});

  $str.="<p>Who's the lucky noder? " . $query->textfield('give_to');
  $str.=" And how many votes are you giving them? " . $query->textfield('votesGiven');
  $str.=$query->checkbox(-name=>'anon',
    -value=>'sssh',
    -label=>'Give anonymously') . '</p>';

  $str.=$query->submit('give_votes','Give Votes!');
  $str.=$query->end_form();

  return $str;
}

sub giftshop_ching
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $ChingLev = 4;
  my $lvl = $APP->getLevel($USER);

  my $str = "<p><hr width='300' /></p><p><b>The Gift of Ching</b></p>";

  $str.="<p>Give the gift of ching! If you happen to have a C! to spare, why not spread the love and give it to a fellow noder?</p>" if ($lvl >= $ChingLev);

  return "<p>Sorry, you must be [The Everything2 Voting/Experience System|Level $ChingLev] to give away C!s</p>" unless ($lvl >= $ChingLev);

  return "<p>Sorry, but you don't have a C! to give away. Please come back when you have a C!.</p>" unless $$VARS{cools} && $$VARS{cools} > 0;

  if ($query->param('give_cool'))
  {
    my $recipient = $query->param('give_to');

    my $user = getNode($recipient, 'user');

    return "<p>Sorry, users must be Level 1 or higher to receive a C!.</p>" unless $lvl > 0;

    return "<p>The user '$recipient' doesn't exist! Please [E2 Gift Shop|try again].</p>" unless $user;
    my $v = getVars($user);

    $$v{cools}++;
    setVars($user, $v);
    $$user{sanctity} += 1;
    updateNode($user,-1);
    $$VARS{cools}--;
    $APP->securityLog( getNode('The Gift of Ching', 'node_forward'), $USER, "$$USER{title} gave a C! to $$user{title} at the [E2 Gift Shop].");

    my $from =  ($query->param('anon') eq 'sssh') ? "someone mysterious" : ('[' . $$USER{title} . ']');
    htmlcode('sendPrivateMessage',{
      'author_id' => getId(getNode('Cool Man Eddie', 'user')),
      'recipient_id' => $$user{user_id},
      'message' => "Hey, $from just [E2 Gift Shop|gave you] a C! to spend. Use it to rock someone's world!"
    });

    $str = "<p>A neatly-wrapped C! is waiting for [" . $$user{title} ."]. ";
    if ($$VARS{cools} != 0)
    {
      return $str . "You have <b>" . $$VARS{cools} . "</b> C!s left. Would you like to [E2 Gift Shop|give another]?</p>";
    }
    
    return $str . "That was your last C! for today.</p>";

  }

  $str.=$query->start_form();
  $str.=$query->hidden('node_id', $$NODE{node_id});
  $str.= "</p><p>Who's the lucky noder? " . $query->textfield('give_to');


  $str.= $query->checkbox(-name=>'anon',
    -value=>'sssh',
    -label=>'Give anonymously') . '</p>';

  $str.=$query->submit('give_cool','Give C!');
  $str.=$query->end_form();

  return $str;

}

sub giftshop_buyching
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $minLevel = 12;
  my $gpCost = 100;
  my $ChingLevel = 4;
  my $lvl = $APP->getLevel($USER);

  return if ($$VARS{GPoptout});

  my $msg = "<p>If you'd like another ching to use or give away, you might be able to buy one for the bargain price of <strong>$gpCost GP</strong>. You must be at least [The Everything2 Voting/Experience System|Level $minLevel], and you can only buy one C! every 24 hours.</p>";

  return $msg."<p>Sorry, you must be [The Everything2 Voting/Experience System|Level $minLevel] in order to buy chings.</p>" unless $lvl>= $minLevel;

  return "<p>Sorry, you must have at least $gpCost GP in order to buy a ching.</p>" unless $$USER{GP} >= $gpCost;

  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time-86400);
  my $hours24 = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
  $year+1900,$mon+1,$mday,$hour,$min,$sec;

  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
  my $curTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d",
  $year+1900,$mon+1,$mday,$hour,$min,$sec;

  if ($$VARS{chingbought} gt $hours24)
  {
    my ($d, $t) = split(' ',$$VARS{chingbought});
    my ($chinghour, $chingmin, $chingsec) = split(':',$t);
    my ($chingyear, $chingmonth, $chingday) = split('-',$d);
    my $ching_time = timelocal($chingsec, $chingmin, $chinghour, $chingday, $chingmonth-1, $chingyear);

    ($d, $t) = split(' ',$hours24);
    ($chinghour, $chingmin, $chingsec) = split(':',$t);
    ($chingyear, $chingmonth, $chingday) = split('-',$d);
    my $hour_time = timelocal($chingsec, $chingmin, $chinghour, $chingday, $chingmonth-1, $chingyear);

    my $timeDiff = $ching_time-$hour_time;
    my $hourDiff = floor($timeDiff / 3600);
    my $minDiff = floor(($timeDiff - $hourDiff * 3600) / 60);

    return "<p>You bought your last ching at <b>".$$VARS{chingbought}."</b>.<br /> You may buy another ching in $hourDiff hours, $minDiff minutes.</p>";
  }


  if ($query->param('buy_ching'))
  {

    $$VARS{cools} ||= 0;
    $$VARS{cools}++;
    $$VARS{chingbought} = $curTime;
    setVars($USER, $VARS);
    $APP->securityLog(getNode('Buy Chings', 'node_forward'), $USER, "$$USER{title} purchased a C! at the [E2 Gift Shop] for $gpCost GP.");

    $$USER{GP} += (-1*$gpCost);
    return "<p>Transaction complete. You have $$VARS{cools} cools now.  Thank you, come again!</p>";
  }


  my $str = "";
  $str.="<p>You currently have <b>".$$USER{GP}." GP</b>.</p>";
  $str.=$query->start_form();
  $str.="<input type='hidden' name='node_id' value='$$NODE{node_id}' />";
  $str.=$query->submit('buy_ching','Buy Ching!');
  $str.=$query->end_form();

  return $msg.$str;

}

sub giftshop_topic
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p><hr width='300' /></p><p><b>The Gift of Topic</b></p>|;

  my $minlevel = 6;

  my $lvl = $APP->getLevel($USER);

  my $tokenCost = 25;
  my $canBuy = (($$USER{GP} >= $tokenCost) && ($lvl >= $minlevel));

  my $resultStr = "";

  $$VARS{tokens} = 0 unless exists($$VARS{tokens});
  $$VARS{tokens} = 0 if($$VARS{tokens} eq "");

  if ($query->param("buyToken") && $$USER{GP} >= $tokenCost)
  {
    $$USER{GP} += (-1*$tokenCost);
    $$VARS{tokens}++;
    $$VARS{tokens_bought}++;
    setVars($USER, $VARS);
    $resultStr = "Sweet, now you have <b>".$$VARS{tokens}."</b> token".($$VARS{tokens} == 1 ? "" :"s");
  }

  if (int($$VARS{tokens}) <= 0)
  {
    $str .= "<p>You don't have any tokens right now.</p>";

    if ($canBuy)
    {
      $str.="Wanna buy one? Only $tokenCost GP ...</p>";
      $str.=htmlcode('openform');
      $str.=$query->submit("buyToken","Buy Token");
      $str.=$query->end_form;
    } else {
      $str.="<p>You can't buy one right now. You need to be";
      $str.=" at least [Voting/Experience System|Level $minlevel] and have at least <b>$tokenCost GP</b>.</p>";
    }

    return $str;
  }

  if ($query->param("setTopic"))
  {
    $$VARS{tokens}--;

    #possibly limit topic changes to one every 30 minutes?

    my $room = 0;

    my $settingsnode = getNode('Room topics', 'setting');
    my $topics = getVars($settingsnode);
    my $oldtopic = $$topics{$room};
    my $utf8topic = $query->param("newtopic");
    $utf8topic = $APP->htmlScreen($utf8topic); #Admins and chanops can still put HTML in topic, though.
    $$topics{$room} = $utf8topic;
    $$topics{$room} = $oldtopic if $utf8topic eq '' || $utf8topic =~ /^No information/i;
    setVars($settingsnode, $topics);
    $APP->securityLog($NODE, $USER, "$$USER{title} changed room topic to '".$utf8topic."'");
    return "The topic has been updated. Go now and enjoy the fruits of your labor.";
  }

  $str.="<p>You currently have <b>".$$VARS{tokens}."</b> token".($$VARS{tokens} == 1 ? "" :"s")."</p>";


  if ($APP->isSuspended($USER,"topic"))
  {
    return $str."<p>Your topic privileges have been suspended. Ask nicely and maybe they will be restored.</p>";
  }

  my ($lastChange, $lastTime) = $DB->sqlSelect(
    "seclog_details, seclog_time"
    , "seclog"
    , "seclog_node = $$NODE{node_id}"
    , "ORDER BY seclog_id DESC LIMIT 1" );

  # Escape brackets for easier copy & paste action
  $lastChange =~ s/\[/&#91;/g;
  $lastChange =~ s/]/&#93;/g;
  my $lastTopic = "At $lastTime, $lastChange";

  $str.="<p>You can update the outside room topic for the low cost of <b>1</b> token. To do so, just fill in the box below. The only rules are no insults or harassment of noders, no utter nonsense, and no links to NSFW material. Violators will lose their topic-setting privileges.";

  $str .= htmlcode('openform')
    . "<dl><dt>Last topic change</dt><dd>$lastTopic</dd></dl>"
    . $query->textfield("newtopic", "New Topic", 100)
    . "<br />"
    . $query->submit("setTopic","Set The Topic")
    . $query->end_form;

  return $str.$resultStr if ($$VARS{GPoptout});

  if ($lvl >= $minlevel)
  {
    $str.="<p>Because you are at least [The Everything2 Voting/Experience System|Level $minlevel]";
    if ($$USER{GP} >= $tokenCost)
    {
      $str.= ", you can also buy more tokens, if you want. One token costs <b>$tokenCost GP</b>.</p>";
      $str.=htmlcode('openform');
      $str.=$query->submit("buyToken","Buy Token");
      $str.=$query->end_form;

    } else {
      $str.= ", you are allowed to buy additional tokens. But one token costs <b>$tokenCost GP</b>, so you do not have enough GP right now. Please come back when you have more GP.</p>";
    }
  }

  return $str.$resultStr;

}

sub giftshop_buyeggs
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $minlevel = 7;

  my $lvl = $APP->getLevel($USER);

  my $eggCost = 25;
  my $canBuy = (($$USER{GP} >= $eggCost) && ($lvl >= $minlevel));
  my $canBuyFive = ($canBuy && ($$USER{GP} >= $eggCost * 5));

  my $str = "";
  my $resultStr = "";

  $str .= "<p><hr width='300' /></p><p><b>The Gift of Eggs</b></p>";

  $$VARS{easter_eggs} = 0 unless exists($$VARS{easter_eggs});
  $$VARS{easter_eggs} = 0 if($$VARS{easter_eggs} eq "");

  return $str if ($$VARS{GPoptout});

  my $boughtEggs = 0;
  if ($query->param("buyEgg"))
  {
    $$USER{GP} += (-1*$eggCost);
    $$VARS{easter_eggs}++;
    $$VARS{easter_eggs_bought}++;
    $boughtEggs = 1;
  } elsif ($query->param("buyFiveEggs")) {
    $$USER{GP} += (-5*$eggCost);
    $$VARS{easter_eggs} += 5;
    $$VARS{easter_eggs_bought} += 5;
    $boughtEggs = 1;
  }

  if ($boughtEggs)
  {
    setVars($USER, $VARS);
    $resultStr = "Sweet, now you have ".$$VARS{easter_eggs}." easter egg".($$VARS{easter_eggs} == 1 ? "" :"s");
  }

  if ($canBuy)
  {
    $str.="<p>You also can buy Easter Eggs if you want. Only <b>$eggCost GP</b> per egg!</p>";

    if ($resultStr eq '')
    {
      $str.="<p>You currently have <b>".($$VARS{easter_eggs} ? $$VARS{easter_eggs} :"no")."</b> Easter Egg".($$VARS{easter_eggs} == 1 ? "" :"s")."</p>";
    }

    $str.=htmlcode('openform');
    $str.=$query->submit("buyEgg","Buy Easter Egg");
    if ($canBuyFive)
    {
      $str.=$query->submit("buyFiveEggs","Buy Five (5) Easter Eggs");
    }
    
    $str.=$query->end_form;

  } elsif ($lvl >= $minlevel) {

    $str.="<p>You do not have enough GP to buy an easter egg right now. Please come back when you have at least $eggCost GP.<br /><br /></p>";

  } else {
    $str.="<p>You are not a high enough level to buy easter eggs yet. Please come back when you reach [The Everything2 Voting/Experience System|Level $minlevel].<br /><br /></p>";

  }

  return $str.$resultStr;

}

sub giftshop_eggs
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $buyEggsLev = 7;
  my $lvl = $APP->getLevel($USER);
  my $eggs = $$VARS{easter_eggs};

  return if ($lvl < $buyEggsLev);

  my $str = "<p>Give the gift of eggs! If you happen to have some easter eggs to spare, you can give one to another user as a gift. Please use this to encourage newbies.</p>";

  return $str."<p>Sorry, but it looks like you don't have any eggs to give away now. Please come back when you have an egg.</p>" if $eggs < 1;

  if ($query->param('give_egg'))
  {
    my $recipient = $query->param('give_to');
    my $U = getNode($recipient, 'user');
    return "<p>That user doesn't exist! Please [E2 Gift Shop|try again].</p>" unless $U;
    my $v = getVars($U);
    $$v{easter_eggs}++;
    setVars($U, $v);
    $$VARS{easter_eggs}--;

    $APP->securityLog(getNode('The Gift of Eggs', 'node_forward'), $USER, "$$USER{title} gave an easter egg to $$U{title} at the [E2 Gift Shop].");

    my $from =  ($query->param('anon') eq 'sssh') ? "someone mysterious" : ('[' . $$USER{title} . ']');
    htmlcode('sendPrivateMessage',
    {
      'author_id' => getId(getNode('Cool Man Eddie', 'user')),
      'recipient_id' => $$U{user_id},
      'message' => "Hey, $from just gave you an [easter egg]! That means you are tastier than an omelette!"
    });

    $str = "<p>Okay, the Easter Bunny just paid a visit to [" . $$U{title} ."]. ";
    if ($$USER{votesleft} != 0)
    {
      return $str . "You have <b>".($$VARS{easter_eggs}||"0")."</b> easter egg".($$VARS{easter_eggs} == 1 ? "" :"s")." left. Would you like to [E2 Gift Shop|give another]?</p>";
    }

    return $str . "You just gave away your last easter egg!</p>";
  }

  $str.=$query->start_form();
  $str.=$query->hidden('node_id', $$NODE{node_id});

  $str.="<p>Who's the lucky noder? " . $query->textfield('give_to');
  $str.=$query->checkbox(-name=>'anon',
    -value=>'sssh',
    -label=>'Give anonymously') . '</p>';

  $str.=$query->submit('give_egg','Egg them!');
  $str.=$query->end_form();

  return $str;
}

1;
