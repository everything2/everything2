package Everything::Delegation::htmlcode;

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

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
} 

# Used by showchoicefunc
use Everything::XML;

# Used by parsetime
use Time::Local;

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

  if($codenode->{delegated})
  {
    $code = "Error: could not find code in delegated htmlcode";
    my $file="/var/everything/ecore/Everything/Delegation/htmlcode.pm";

    my $filedata = undef;
    my $fileh = undef;

    open $fileh,$file;
    {
      local $/ = undef;
      $filedata = <$fileh>;
    }

    close $fileh;

    my $name="$$NODE{title}";
    $name =~ s/ /_/g;
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

1;
