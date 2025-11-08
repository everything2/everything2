package Everything::Delegation::htmlpage;

use strict;
use warnings;

# Used by writeup_xml_page, e2node_xml_page
use Everything::XML;

# Used by room_display_page
use POSIX qw(ceil floor);

# Used by collaboration_display_page, collaboration_useredit_page
use POSIX qw(strftime);

# Used by choosetheme_view_page
use Everything::Delegation::container;

# Used by superdoc delegation
use Everything::Delegation::document;

# Used by ajax_update_page
use JSON;

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
  *canUpdateNode = *Everything::HTML::canUpdateNode;
  *evalCode = *Everything::HTML::evalCode;
}

sub container_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = '';
  $str .= q|parent container: |;

  if($NODE->{parent_container})
  {
    $str .= linkNode($NODE->{parent_container}) if $NODE->{parent_container};
  }else{
    $str .= q|<i>none</i>|;
  }

  $str .= htmlcode('listcode','content');

  return $str;
}

sub container_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;
 
  my $str = "";
  $str .= qq|title:|.htmlcode("textfield","title");
  $str .= qq|maintained by:|.htmlcode("node_menu","author_user,user,usergroup").qq|<br>|;
  $str .= qq|Parent container:|.htmlcode("node_menu","parent_container").qq|<br>|;
  $str .= qq|container html:<br>|.htmlcode("textarea","context");

  return $str; 
}

sub nodelet_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '' if $APP->isGuest($USER);
  $PAGELOAD->{ pagenodelets } = $$VARS{ nodelets } ;
  $PAGELOAD->{ pagenodelets } =~ s/\b$$NODE{node_id}\b,?//;
  delete $PAGELOAD->{pagenodelets} if $PAGELOAD->{pagenodelets} eq $$VARS{nodelets};

  return Everything::HTML::insertNodelet($NODE);
}

sub document_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p align="right">|;
  $str .= linkNode($NODE, 'edit', {displaytype=>"edit"}) if $APP->isEditor($USER);
  $str .= qq|</p>|;
  $str .= qq|<div class="content">|;
  $str .= htmlcode("parselinks","doctext");
  $str .= qq|</div>|;

  return $str;
}

sub document_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = q|<h4>title:</h4>|.htmlcode('textfield','title');
  $str .= qq|<h4>owner:</h4>|.htmlcode("node_menu","author_user,user,usergroup");
  $str .= qq|<p><small><strong>Edit the document text:</strong></small><br />|;
  $str .= htmlcode("textarea","doctext,30,60");

  return $str;
}

sub htmlcode_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return htmlcode('listcode','code');
}

sub htmlcode_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|title:|.htmlcode("textfield","title").qq|maintained by:|.htmlcode("node_menu","author_user,user,usergroup").qq|<br />|;
  
  $str .= htmlcode("listcode","code"). qq|<p><small><strong>Edit the code:</strong></small><br />|;
  $str .= htmlcode("textarea","code,30,80");

  return $str;
}

sub htmlpage_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<b>pagetype</b>:|; 

  my $N = $DB->getNodeById($$NODE{pagetype_nodetype}, 'light');
  $str .= linkNode($N);
  $str .= qq|<br><b>parent container</b>:|;
  if($NODE->{parent_container})
  {
    $str .= linkNode ($$NODE{parent_container});
  }else{
    $str .= "<i>none</i>";
  }

  $str .= qq|<br><b>displaytype</b>:$$NODE{displaytype}<br><b>MIMEtype</b>: $$NODE{mimetype}<p>|;
  $str .= htmlcode("listcode","page");

  return $str;
}

sub htmlpage_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|title:|.htmlcode("textfield","title").qq|<br>|;
  $str .= qq|maintained by:|.htmlcode("node_menu","author_user,user,usergroup").qq|<br>|;
  $str .= qq|pagetype: |.htmlcode("node_menu","pagetype_nodetype").qq|<br>|;
  $str .= qq|displaytype: |.htmlcode("textfield","displaytype").qq|<br>|;
  $str .= qq|parent container: |.htmlcode("node_menu","parent_container").qq|<br>|;
  $str .= qq|MIME type:|.htmlcode("textfield","mimetype").qq|<br>|;
  $str .= qq|<table width="100%"><tr><td width="90%"><p><font size=2><b>Edit the page:</b></font><br>|;
  $str .= htmlcode("textarea","page").qq|</td><td width=10%><font size=2>|;

  my $N = getType($$NODE{pagetype_nodetype});
  $str .= "<li>";
  $str .= join "\n<li>", $DB->getFields;

  my @tables = @{ $DB->getNodetypeTables($N) };
  foreach (@tables) {
    $str .="\n<li>";
    $str .= join "\n<li>", $DB->getFields($_);
  }
  $str .= qq|</font></td></tr></table>|;
  return $str;
}

sub node_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return htmlcode("displayNODE");
}

sub nodegroup_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  unless ($NODE->{group})
  {
    $str .= "<i>This nodegroup is empty</i>";
  } else {
    my @list = map {$query -> li(linkNode($_))} @{$$NODE{group}};
    $str .= $query -> ul( {id => 'pagecontent'}, join("\n", @list) );
  }

  $str .= qq|<div id="pagefooter">|.htmlcode("windowview","editor,launch editor").qq|</div>|;
  return $str;
}

sub nodegroup_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return htmlcode("groupeditor");
}

sub nodegroup_editor_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p align="right">|;

  if ($query->param('op') eq 'close')
  {
    $$VARS{group} = "";
    $str .= "<SCRIPT language=\"javascript\">parent.close()</SCRIPT>";		
  }else{ 
    $$VARS{group}||= getId ($NODE);
    $str .=linkNode($NODE, "close", {displaytype=> $query->param('displaytype'), op => 'close'});
  }

  $str .= htmlcode("groupeditor").qq|</FORM>|;

  return $str;
}

sub nodelet_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|title:|.htmlcode("textfield","title");
  $str .= qq|maintained by:|.htmlcode("node_menu","author_user","user","usergroup").qq|<br />|;
  $str .= qq|parent container:|.htmlcode("node_menu","parent_container").qq|<br />|;
  $str .= qq|update_interval:|.htmlcode("textfield","updateinterval").qq|(in seconds)<br />|;
  $str .= qq|nodelet code:<br />|;
  $str .= htmlcode("textarea","nlcode",30,80,"off");

  return $str;
}

sub nodetype_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p><a href=|.urlGen({
    'node'=>'List Nodes of Type',
    'type'=>'superdoc',
    'setvars_ListNodesOfType_Type'=>$$NODE{node_id}
    }).qq|>List Nodes of Type</a></p>|;

  $str .= qq|<p><strong>Authorized Readers</strong>:|.htmlcode("listgroup","readers_user").
    htmlcode("displayInherited","readers_user");
  $str .= qq|<p><strong>Authorized Creators</strong>:|.htmlcode("listgroup","writers_user").
    htmlcode("displayInherited","writers_user");
  $str .= qq|<p><strong>Authorized Deleters</strong>:|.htmlcode("listgroup","deleters_user").
    htmlcode("displayInherited","deleters_user");

  $str .= qq|<p><strong>Restrict Duplicates</strong> (identical titles):|;

  if($$NODE{restrictdupes} == -1)
  {
    $str.='parent';
  } else {
    $str.=($$NODE{restrictdupes} ? 'Yes':'No');
  }

  $str .= htmlcode("displayInherited","restrictdups");
  $str .= qq|<p><strong>Verify edits to maintain security</strong>:|;
  $str .= ($$NODE{verify_edits} ? 'Yes':'No');

  my $plural = '';
  my $tablestr = '';
  if (exists $$NODE{sqltable})
  {
    my $tableList = $$NODE{sqltable};
    my @tables = split /,/, $tableList;
    $plural = 's' if scalar @tables > 1;
    $tablestr .= join ', ', map { linkNode(getNode($_, 'dbtable')); } @tables;
  } else {
    $tablestr .=  '<i>none</i>';
  }

  $str .=  "<p><strong>Sql Table$plural</strong>: $tablestr";

  $str .= htmlcode("displayInherited","sqltable");
  $str .= qq|<p><strong>Extends Nodetype:</strong> |;

  $str .= linkNode ($$NODE{extends_nodetype}) if ($$NODE{extends_nodetype});

  $str .= qq|<p><strong>Relevant pages:</strong><br />|;

  $str .= '<ul>';
  my @pages = ();
  push @pages, Everything::HTML::getPages($NODE);

  foreach (@pages)
  {
    $str .= '<li>' .linkNode($_) . '</li>';
  }
  $str .= qq|</ul>|;
  $str .= qq|<p><strong>Active Maintenances:</strong><br />|;

  $str .= qq|<ul>|;

  my (@maints) = getNodeWhere ({maintain_nodetype=>getId($NODE)}, getType('maintenance'));

  unless(@maints)
  {
    $str .= '<em>no maintenance functions</em>';
  } else {
    foreach (@maints)
    {
      $str .= '<li>'.linkNode($_).'</li>';
    }
  }
  $str .= '</ul>' ;

  return $str;
}

sub nodetype_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>readers: |.htmlcode("node_menu","readers_user,user,usergroup,-parent_-1").
    htmlcode("displayInherited","readers_user");
  $str .= qq|<p>creators: |.htmlcode("node_menu","writers_user,user,usergroup,-parent_-1").
    htmlcode("displayInherited","writers_user");
  $str .= qq|<p>deleters: |.htmlcode("node_menu","deleters_user,user,usergroup,-parent_-1").
    htmlcode("displayInherited","deleters_user");
  $str .= qq|<p>sqltable : |.htmlcode("textfield","sqltable").
    htmlcode("displayInherited","sqltable");
  $str .= qq|<p>grouptable: |.htmlcode("textfield","grouptable").
    htmlcode("displayInherited","grouptable");
  $str .= qq|<p>extends: |.htmlcode("node_menu","extends_nodetype");
  $str .= qq|<p>restrict nodetype(groups):|.htmlcode("node_menu","restrict_nodetype,nodetype,nodetypegroup").
    htmlcode("displayInherited","restrict_nodetype");
  $str .= qq|<p>restrict duplicate titles: |.htmlcode("node_menu","restrictdupes,-yes_1,-no_0,-parent_-1").
    htmlcode("displayInherited","restrictdupes");
  $str .= qq|<p>verify edits to maintain security: |.htmlcode("node_menu","verify_edits, -no_0, -yes_1").qq|</p>|;

  return $str;
}

sub dbtable_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>Database table $$NODE{title}|;

  if(isGod($USER))
  {

    my $tableName = $$NODE{title};
    my $strRowCount = "<small>(";
    my $sthTableStats = undef;

    my $qh = $DB->{dbh}->prepare("SHOW TABLE STATUS LIKE '$tableName'");
    $qh->execute();
    $sthTableStats = $qh->fetchrow_hashref();
    $qh->finish();

    my $engine = $sthTableStats->{'Engine'};
    my $rowCount = $sthTableStats->{'Rows'};

    $strRowCount .= "Engine: $engine";

    if ($engine eq 'MyISAM')
    {
      $strRowCount .= ", $rowCount actual record";
      $strRowCount .= "s" if ($rowCount != 1);
      $strRowCount .= ".)</small></p>";

    } else {

      $strRowCount .= ", approx. $rowCount record";
      $strRowCount .= "s" if ($rowCount != 1);

      if ($query->param('showRowCount') && htmlcode('verifyRequest', 'showRowCount'))
      {

        $rowCount = -1;
        $qh = $DB->{dbh}->prepare('SELECT COUNT(*) FROM ' . $$NODE{title});

        if($qh)
        {
          $qh->execute();
          ($rowCount) = $qh->fetchrow();
          $qh->finish();
          $strRowCount .= ", $rowCount actual record";
          $strRowCount .= "s" if ($rowCount != 1);
          $strRowCount .= ".";

        } else {

          $strRowCount .= "; Failed to find row count!";

        }

        $strRowCount .= ")</small></p>";

      } else {

        $strRowCount .= ''. ")</small></p>"
         . htmlcode('openform', 'showcountform')
         . htmlcode('verifyRequestForm', 'showRowCount')
         . $query->submit(
            -name => 'showRowCount'
            , -value => 1
            , -label => "Show row count.  (DB intensive.)"
         )
         . '</form>';

      }

    }
    $str .= $strRowCount;
  } else {
    $str .= qq|</p>|
  }

  $str .= qq|<p align="right">|.linkNode($NODE, "indexes", {displaytype => "index"}).qq|</p>|.
    htmlcode("displaytable",$$NODE{title});

  return $str;
}

sub dbtable_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return htmlcode("updatetable",$NODE->{title}).htmlcode("displaytable",$NODE->{title});
}

# Pushed to templates
sub maintenance_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|Maintains:|; 

  my $N = $DB->getNodeById($$NODE{maintain_nodetype}, 'light');
  $str .= linkNode($N);

  $str .= qq|<br><p>Maintenance operation:|;
  $str .= qq|$$NODE{maintaintype}|;
  $str .= qq|<p>|.htmlcode("listcode","code");

  return $str;
}

sub maintenance_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $str = qq|title:|.htmlcode("textfield","title").qq| maintained by:|.
    htmlcode("node_menu","author_user,user,usergroup").qq|<br>|;
  $str .= qq|Maintains: |.htmlcode("node_menu","maintain_nodetype").qq|<br>|;
  $str .= qq|maintaintype: |.htmlcode("textfield","maintaintype").qq|(create, update, or delete)<br>|;

  $str .= qq|<table width=100%><tr><td width=90%><p><FONT SIZE=2><b>Edit the code:</b></FONT><br>|;
  $str .= htmlcode("textarea","code").qq|</td><td width=10%><font size=2>|;

  my $N = $DB->getNodeById($$NODE{maintain_nodetype});
  $str .= "<li>";
  $str .= join "\n<li>", $DB->getFields;

  my @tables = @{ $DB->getNodetypeTables($$NODE{maintain_nodetype}) };
  foreach (@tables)
  {
    $str .="\n<li>";
    $str .= join "\n<li>", $DB->getFields($_);
  }

  $str .= qq|</font></td></tr></table>|;
 
  return $str;
}

sub node_edit_page
{
  return "This is a temporary edit page for the basic node.  If we want to edit raw nodes, we will need to implement this.";
}

sub setting_display_page
{
  return htmlcode("displayvars");
}

sub setting_edit_page
{
  return htmlcode("editvars");
}

sub mail_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<TABLE width=100% cellpadding=0 cellspacing=1 border=0>|;
  $str .= qq|<TR bgcolor="#CCCCCC"><TH>To:</TH><TD width=100%>|;
  $str .= linkNode($$NODE{author_user}).qq|<TD></TR><TR bgcolor="#CCCCCC"><TH>From:</TH></TH><TD width=100%>|;

  if(not $$NODE{from_address})
  {
    $str .= "<i>nobody</i>";
  } else {
    $str .= $$NODE{from_address};
  }

  $str .= qq|</TD></TR></TABLE>|;
  $str .= $APP->parseLinks($APP->encodeHTML($NODE->{doctext}));

  return $str;
}

sub writeup_xml_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return node2xml($NODE, ['reputation'])."" unless canUpdateNode($USER, $NODE);
  return node2xml($NODE, [])."";
}

sub e2node_edit_page
{
  return htmlcode("e2nodetools");
}

sub writeup_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return 'If you need a writeup removed, revert it to draft' unless ( $APP->isEditor($USER) ); 

  my $str = "";
  my $pname = $query->param('parentnodename');
  if($pname)
  {
    my $E2N = getNode($pname, 'e2node');
    if($E2N)
    {
      my $nid = getId($NODE);
      $$NODE{parent_e2node} = getId($E2N);
      updateNode($NODE, $USER);

      my $alreadyIn = 0;
      foreach(@{$$E2N{group}})
      {
        if($_==$nid)
        {
          $alreadyIn = 1;
          last;
        }
      }

      if($alreadyIn)
      {
        $str .= 'Writeup is already in ';
      } else {
        insertIntoNodegroup($E2N, -1, $NODE);
        $str.= 'Writeup has been reparented with ';
      }
        $str .= linkNode($E2N) . '.';
      } else {
        $str.="No e2node named $pname exists!";
      }
  }

  $str.='<p>parent e2node:';
  my $E2NODE = getNodeById($$NODE{parent_e2node});
  $str.=$query->textfield('parentnodename', $$E2NODE{title});

  $str .= qq|<p>Writeuptype: |.htmlcode("node_menu","wrtype_writeuptype");
  $str .= qq|<p>|.htmlcode("textarea","doctext");
  
  return $str;
}

sub classic_user_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  $PAGELOAD->{pageheader} = '<!-- put at end -->'.htmlcode('settingsDocs');
  my $str = htmlcode('openform').htmlcode('verifyRequestForm', 'edit_user');

  $str .= qq|<p align="right">|.linkNode($NODE, 'display', {displaytype=>'display', lastnode_id => undef});

  if(Everything::isApproved($NODE, getNode('users with image', 'nodegroup')) or $APP->getLevel($NODE) >= 1)
  {
    my $isMe = getId($NODE)==getId($USER);
    $str .=  '<p>Your coveted user image<br />';

    $str .= htmlcode('uploaduserimage', 'imgsrc') . '<br />';

    my $k = 'remove_user_imgsrc';
    if( (defined $query->param('sexisgood')) && (defined $query->param($k)) && ($query->param($k) eq '1') )
    {
      $str .= 'image <a href="/'.$$NODE{imgsrc}.'">'.$$NODE{imgsrc}.'</a> will no longer be displayed on '.($isMe?'your':$$NODE{title}.'\'s').' homenode';
      my $olduserimage= "/var/everything/www/".$$NODE{imgsrc};
      # Strip fake timestamp/cache-fixing directory from filepath
      $olduserimage =~ s"/[^/]+?(/[^/]+)$"$1";
      unlink($olduserimage);
      $$NODE{imgsrc} = '';
      updateNode $NODE, $USER;
      $query->param($k,'');
    }

    my $showuserimage = htmlcode('showuserimage','1');
    $str .= $showuserimage if defined($showuserimage);
    $str .= '<br />' . $query->checkbox($k, '', '1', 'remove image') if (exists $$NODE{imgsrc}) && length($$NODE{imgsrc});
  }

  $str .= qq|<p><b>Real Name</b>:|; 

  my $realname = $$NODE{realname};
  $realname =~ s/\</\&lt\;/g;
  $realname =~ s/\>/\&gt\;/g;
  $str .= $realname;

  $str .= qq|<br />|.htmlcode("textfield","realname").qq|</p>|;
  $str .= qq|<p>Change password:<br />|.htmlcode("password_field","passwd").qq|</p>|;

  $str .= qq|<p><b>Email Address</b>:|; 
 
  my $email = $$NODE{email};
  $email =~ s/\</\&lt\;/g;
  $email =~ s/\>/\&gt\;/g;
  $str .= $email;

  $str .= qq|<br>|.htmlcode("textfield","email,40").qq|</p>|;
  $str .= qq|<p><b>User's Bio</b>:</p>|;
  $str .= qq|<p><textarea id='user_doctext' name='user_doctext' |;
  $str .= htmlcode('customtextarea','1');
  $str .= qq| class='formattable' >|;
  $str .= $APP->encodeHTML($NODE->{doctext});
  $str .= qq|</textarea></p>|;


  $str .= qq|<p>|.htmlcode("editSingleVar","mission,mission drive within everything").qq|</p>|;
  $str .= qq|<p>|.htmlcode("editSingleVar","specialties").qq|</p>|;
  $str .= qq|<p>|.htmlcode("editSingleVar","employment","school/company").qq|</p>|;
  $str .= qq|<p>|.htmlcode("editSingleVar","motto").qq|</p>|;
  $str .= qq|<p>You can remove your bookmarks:</p>|;
  
  $str .= qq|<input type="button" value="Check All" id="checkall" style="display:none">|;
  $str .= htmlcode("showbookmarks","edit");

  $str .= htmlcode("closeform");

  $str .= qq|<p align="center">Your current homenode bio is shown below:</p>|;
  $str .= qq|<hr class="clear"><table width="100%" id='homenodetext'><tr><td><div class='content'>|;
  $str .= htmlcode("displayUserText");

  $str .= qq|</div></td></tr></table>|;

  return $str;
}

sub superdoc_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $doctitle = $NODE->{title};
  $doctitle =~ s/[\s-]/_/g;
  $doctitle =~ s/[^A-Za-z0-9]/_/g;
  $doctitle = lc($doctitle);

  if($doctitle =~ /^\d+$/)
  {
    $doctitle = "document_$doctitle";
  }

  $APP->devLog("Proposed delegation for '$NODE->{title}': '$doctitle'");
  if(my $delegation = Everything::Delegation::document->can("$doctitle"))
  {
    $APP->devLog("Using document delegation for $NODE->{title} as '$doctitle'");
    return parseLinks($delegation->($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP));
  }else{
    return htmlcode('parsecode','doctext');
  }
}

sub node_basicedit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "" unless ( isGod( $USER ) );

  my $str = "";

  my $type = $$NODE{type}{title};
  if (!htmlcode('verifyRequest', "basicedit_$type"))
  {
    $query->delete_all() if (grep {/^update_/} $query->Vars);
  }else{

    # This code does the update, if we have one.
    my @params = $query->param;

    foreach my $param (@params)
    {
      if ($param =~ /^update_(\w*)$/)
      {
        $$NODE{$1} = $query->param($param);
      }
    }

    updateNode($NODE, $USER);
  }

  $str .= htmlcode('openform');

  # This code generates the form fields and the stuff that
  # the user sees.

  my $tables = $DB->getNodetypeTables($$NODE{type_nodetype});
  my @fields = ();
  my %titletype = ();

  $str .= htmlcode('verifyRequestForm', "basicedit_$type");

  push @$tables, 'node';
  foreach my $table (@$tables)
  {
    @fields = $DB->getFieldsHash($table);

    foreach my $field (@fields)
    {
      $titletype{$$field{Field}} = $$field{Type};
    }
  }

  pop @$tables;

  foreach my $field (keys %titletype)
  {
    $str .= "$field ($titletype{$field}): ";

    if($titletype{$field} =~ /int/)
    {
      $str .= $query->textfield( -name => "update_$field", -default => $$NODE{$field}, -size => 15,
        -maxlength => 15) . "<br>\n";
    }elsif($titletype{$field} =~ /char\((.*)\)/)
    {
      my $size = 80;

      $size = $1 if($size > $1);
      $str .= $query->textfield( -name => "update_$field",
        -default => $$NODE{$field}, -size => $size,
        -maxlength => $1 ) . "<br>\n";
    }elsif($titletype{$field} =~ /text/)
    {
      $str .= $query->textarea( "update_$field",
        $$NODE{$field}, 20, 80) . "<br>\n";
    }elsif($titletype{$field} =~ /datetime/)
    {
      $str .= $query->textfield( -name => "update_$field",
        -default => $$NODE{$field}, -size => 19,
        -maxlength => 19 ) . "<br>\n";
    }else
    {
      # This is for the unknown field types.
      $str .= $query->textfield( -name => "update_$field",
        -default => $$NODE{$field}, -size => 80,
        -maxlength => 256) . "<br>\n";
    }
  }

  $str .= htmlcode( 'closeform' );

  return $str;
}

sub superdoc_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  $str .= qq|<h4>title</h4> |.htmlcode("textfield","title");
  $str .= qq|<h4>maintainer:</h4> |.htmlcode("node_menu","author_user,user,usergroup");
  $str .= qq|<p><small><strong>Edit the document text:</strong></small></p>|;
  $str .= qq|<p align="center" style="border: solid black 2px; background: #ffa; color: black; spacing: 2px; padding: 5px;"><big><strong>This is a live edit. Be careful.</strong></big></p>|;

  $str .= htmlcode("textarea","doctext,30,80");
  $str .= qq|<br />|;

  return $str;
}

sub fullpage_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $noparse = 0;
  $noparse = 1 if lc($NODE->{title}) =~ /chatterlight/;
  my $out = htmlcode("parsecode","doctext", $noparse);
  $out =~ s/^\s+//g;
  return $out;
}

sub room_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  $str .= qq|Title: |.htmlcode("textfield","title").qq| maintained by: |.
    htmlcode("node_menu","author_user,user,usergroup").qq|<br>|;
  $str .= qq|Other Users Abrev: |.htmlcode("textfield","abbreviation").qq|<br>|;
  $str .= qq|<b>Criteria</b> (evaled perl)<br>|;
  $str .= htmlcode("textarea","criteria");
  $str .= qq|<p><b>description</b><br>|;
  $str .= htmlcode("textarea","doctext");

  return $str;
}

sub room_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  if($APP->isAdmin($USER))
  {
    my $open = "1\;";
    my $locked = "0\;";

    my $otherone = "";
    my $title = "";
    if ($$NODE{criteria} eq $open)
    {
      $title = "lock";
      $otherone = $locked;
    } elsif ($$NODE{criteria} eq $locked) {
      $title = "unlock";
      $otherone = $open;
    } 

    $str .= "<font size=1><i>".linkNode($NODE, $title, {room_criteria=>$otherone})."</i></font>";
  }
  
  $str .= qq|<p>|;

  ## no critic (ProhibitStringyEval)
  # TODO: Part of database code removal modernization - criteria should be a proper method
  if((eval $$NODE{criteria}) and not $APP->isGuest($USER))
  {
    $APP->changeRoom($USER, $NODE);
    # For room usage counting:
    my (undef, undef, undef, $day, $mon, $year) = localtime();
    $NODE->{lastused_date} = join "-", ($year+1900,++$mon,$day);
    updateNode($NODE, -1);

    $str .= "You walk into $$NODE{title}";
  }else{
    $str .= "You cannot go into $$NODE{title}, I'm sorry.";
  }

  $str .= qq|<p>|.htmlcode("parselinks","doctext");
  $str .= "<br><p align=\"right\">(".linkNode(getNode("go outside", "superdocnolinks")).")</p>";

  return $str;
}

sub e2node_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = htmlcode("votehead");

  # do admin stuff now so the node has been repaired if necessary before being displayed
  $PAGELOAD->{admintools} = htmlcode('e2nodetools') if $APP->isEditor($USER);

  my $stuff = $$NODE{group} || [];

  unless ( $APP->isGuest($USER) )
  {
    # find attached drafts:
    my $linktype = getId(getNode 'parent_node', 'linktype');
    my $drafts = $DB->{dbh}->selectcol_arrayref("
      SELECT from_node
      FROM links
      WHERE
      to_node = $$NODE{node_id}
      AND linktype = $linktype");
    $stuff = [@$stuff, @$drafts] if @$drafts;

    # [show writeups] passes [canseewriteup] to [show content] to decide what to show
    # canseewriteup stores hidden writeups/drafts in $PAGELOAD->{notshown} if the appropriate key exists
    # and removes targetauthor if it processes a writeup or draft by that author:

    $PAGELOAD->{notshown} = {"lowrep" => [], "unfavorite" => [],  "unpublished" => []};
    $PAGELOAD->{notshown}->{targetauthor} = $query->param('author_id');
  }

  $str .= $stuff -> [0] ? htmlcode('show writeups', $stuff) : '';
  unless($PAGELOAD->{notshown})
  {
    # add missing matching draft if requested
    if ($PAGELOAD->{notshown} -> {targetauthor})
    {
      my @dropin = getNodeWhere({
        author_user => $PAGELOAD->{notshown} -> {targetauthor},
        title => $$NODE{title}
	}, 'draft');

      my $addition = htmlcode('show writeups', \@dropin);
      $addition =~ s!(</div>\s*<div class="content")!
        <div><em>Title/author match: not normally visible on this page.</em></div>$1!;
      $str .= $addition;
    }

    # indicate existence of hidden stuff:
    my $hidden = undef;
    my $reasoncount = 0 ;

    # Preserve showhidden value if it's passed in
    if ($query -> param('showhidden'))
    {
      $str .= $query -> hidden('showhidden');
      $reasoncount = 1;
    }

    $query -> param('showhidden', 'all') ;

    my $reveal = sub {
	my $N = shift;
	'&nbsp;[ '
	.linkNode($NODE, 'show', {
		-class=> 'action',
		showhidden => $$N{node_id},
		'#' => ($$N{author} ? $$N{author} : getNodeById($$N{author_user})) -> {title}
	})
	.' ]';
    };

    if ( my $count = scalar @{ $PAGELOAD->{notshown}->{lowrep} || [] } )
    {
      $reasoncount++;
      $hidden .= '<h3>Low reputation writeup'.($count == 1 ? '' : 's')
        .qq'</h3>\n<ul class="infolist">\n'.
        htmlcode('show content', $PAGELOAD->{notshown}{lowrep},
        '<li> type, byline, reputation, reveal',
        reveal => $reveal,
        reputation => sub {
          return unless $APP->isEditor($USER);
          qq'<span class="reputation">(reputation: $_[0]{ reputation })</span>' ;
          }
	)."\n</ul>\n";
      $hidden .= '<p>'.linkNode($NODE, 'Show all low-reputation writeups',
        {-class=>'action', showhidden=>'lowrep'})."</p>\n" if $count > 1 ;
    }

    if (my $count = scalar @{ $PAGELOAD->{notshown}->{unpublished} || []})
    {
      $reasoncount++;
      $hidden .= qq'<h3>Drafts</h3>\n<ul class="infolist">\n'
        .htmlcode('show content', $PAGELOAD->{notshown}{unpublished},
          '<li>type,byline,date,reveal',
          reveal => $reveal
        )."\n</ul>\n";
      $hidden .= '<p>'.linkNode($NODE, 'Show all drafts',
        {-class=>'action', showhidden=>'unpublished'})."</p>\n" if $count > 1 ;
    }

    if ( my $count = scalar @{ $PAGELOAD->{notshown}->{unfavorite} || [] } )
    {
      $reasoncount++;
      $hidden.=qq'<h3>Unfavorites</h3>\n<ul class="infolist">
        <li>There is something here by at least one of your '
        .linkNodeTitle('Pit of Abomination[superdoc]|unfavorite authors')
        .'. [ '.linkNode($NODE, 'show', {-class=>'action', showhidden=>'unfavorite'})." ]</li></ul>\n" ;
    }

    delete $PAGELOAD->{ notshown } ;
    $query -> delete('showhidden') ;

    $hidden .= "\n<p><strong>["
      .linkNode($NODE, ' Show all writeups ',
        {-class=> 'action' , showhidden => 'all'})
        ."]</strong></p>\n" if $reasoncount > 1;

    $str .= "<div class=\"alsoonthispage\">\n<h2>Also on this page:</h2>\n$hidden\n</div>" if $hidden;
  }

  $str .= qq|<div id='displaytypelinks'>|;
  unless($APP->isGuest($USER))
  {
    $str .= qq|<p>|;
    $str .= linkNode($NODE, 'chaos', { displaytype => 'chaos' , lastnode_id => '0', -rel => 'nofollow' } );
    $str .= qq|</p>|;
  }

  $str .= qq|</div>|;

  $str .= htmlcode("votefoot");

  $str .= qq|<div id='softlinks'>|;
  $str .= htmlcode("softlink");
  $str .= qq|</div>|;

  $str .= $PAGELOAD->{admintools} || "";

  $str .= htmlcode("addwriteup");

  return $str;
}

sub writeup_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  $str .= htmlcode("votehead") || "";
  $str .= htmlcode("show writeups") || "";

  $str .= qq|<div id='displaytypelinks'>|;
  
  unless($APP->isGuest($USER))
  {
    $str .= qq|<p>|.linkNode($NODE, 'link view', { displaytype => 'linkview' } ).qq|</p>|;
  }

  $str .= qq|</div>|;

  $str .= htmlcode("votefoot") || "";

  $str .= htmlcode("writeuphints") || "";

  if($NODE->{parent_e2node})
  {
    $str .= qq|<div id="softlinks">|.htmlcode('softlink').qq|</div>|;
  }


  if((($$NODE{type}{title} ne 'draft' and canUpdateNode($USER, $NODE)) or
	($$NODE{type}{title} eq 'draft' and $APP->canSeeDraft($USER, $NODE, 'edit'))))
  {

    $str .= htmlcode('openform', -class=>'writeup_add')
      .htmlcode('editwriteup', $NODE)
      .qq|</form>|;
  }
  
  return $str;
}

sub edevdoc_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  $str .= qq|<p align=right>|;
  $str .= linkNode($NODE,'display', {displaytype=>'display'});
  $str .= qq|<p><h2>title:</h2>|;
  $str .= htmlcode("textfield","title");

  $str .= qq|<p><h2>Edit the document text:</h2>|;
  $str .= htmlcode("textarea","doctext");

  return $str;
}

sub nodelet_viewcode_page
{
  return htmlcode("listcode","nlcode");
}

sub superdoc_viewcode_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isDeveloper($USER);

  return htmlcode('listcode','doctext');
}

sub usergroup_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>|.htmlcode("windowview","editor,launch editor");

  if(isGod($USER))
  {
    $str .= '| '.htmlcode('usergroupmultipleadd');

    my $wSet = getVars(getNode('webloggables','setting'))->{$$NODE{node_id}};

    if ($wSet)
    {
      $str .= "<br>Already has ify - <b>$wSet</b>";
    } else {

      $str .=htmlcode('openform');
      $str.="Value to Display (e.g. <b>Edevify</b>): ";
      $str.=$query->textfield('ify_display','')." ";
      $str.="<input type='hidden' name='op' value='weblogify' />";
      $str.=$query->submit('sexisgood','add ify!');
      $str.=$query->end_form;
    }

  }

  $str .= qq|</p>|;

  if($APP->isEditor($USER))
  {
    my $cOwner = $APP->getParameter($NODE, 'usergroup_owner');
    $str.= htmlcode('openform');
    $str.= 'Owner is <b>'.linkNode($cOwner).'</b><br>' if $cOwner;
    $str.="New Owner: ";
    # 'leader' is correct: leadusergroup does in fact set owner
    $str.=$query->textfield('new_leader','')." ";
    $str.="<input type='hidden' name='op' value='leadusergroup'>";
    $str.=$query->submit('sexisgood','make owner');
    $str.="<br>Note that the user must be a member of the group <em>before</em> they can be set as the owner.";
    $str.=$query->end_form;
  }

  if($APP->inUsergroup($USER, $NODE))
  {
    #TODO: Undo node_id hardcoding
    $str .= '<p align="right">'.linkNode(1977025,"Discussions for $$NODE{title}.",{show_ug => $$NODE{node_id}}).'</p>';
  }

  $str .= qq|<table border=0> <!-- enclose writeups in table to prevent overflow -->|;
  $str .= qq|<tr><td>|;
  $str .= htmlcode("parselinks","doctext");
  $str .= qq|</td></tr>|;
  $str .= qq|</table> <!-- end overflow-blocking table -->|;
  $str .= qq|<p><h2>Venerable members of this group:</h2><p>|;

  my $UID = getId($USER);
  my $isRoot = $APP->isAdmin($USER);
  my $isGuest = $APP->isGuest($USER);
  my $isInGroup=0;
  my @users = ();
  my @memberIDs=();
  my $flags = undef;
  my $curID = undef;
  my $ugOwnerIndex = undef;

  #don't show standard groups when actually viewing that page
  #FIXME? is there a better way to tell if on that group page?
  my $showMemberAdmin = ($$NODE{title} ne 'gods');
  my $showMemberCE = ($$NODE{title} ne 'Content Editors');

  #get usergroup "owner"
  my $ugOwner = $APP->getParameter($NODE, 'usergroup_owner') || 0;

  if($$NODE{group})
  {
    my $leavingnote = '';
    $leavingnote = '</p><strong>You have left this usergroup</strong></p>' if $query -> param('leavegroup')
      && htmlcode('verifyRequest', 'leavegroup')
      && $DB->removeFromNodegroup($NODE, $USER, -1);

    my $GROUP = $$NODE{group};
    @memberIDs = @$GROUP;

    $isInGroup = $APP->inUsergroup($UID, $NODE);

    my $s;
    my $i=0;
    foreach(@memberIDs)
    {
      $s = linkNode($_);

      if($_==$ugOwner)
      {
        $ugOwnerIndex = $i;
        $s = '<em>'.$s.'</em>';
      }

      if($_==$UID)
      {
        $s = '<strong>'.$s.'</strong>';
      }

      my $isChanop = $APP->isChanop($_, "nogods");

      #show normal groups user is in
      $flags = '';
      $flags .= '@' if $showMemberAdmin and $APP->isAdmin($_) and not $APP->getParameter($_,"hide_chatterbox_staff_symbol");

      $flags .= '$' if $showMemberCE and $APP->isEditor($_, "nogods") and not $APP->isAdmin($_) and not $APP->getParameter($_,"hide_chatterbox_staff_symbol");
      $flags .= '+' if $showMemberAdmin && $isChanop;

      if(length($flags))
      {
        $s .= '<small><small>'.$flags.'</small></small>';
      }

      push(@users, $s);
      ++$i;
    }
    $str .= join(', ', @users);

    $str.="<br>This group of $i member"
      .($i==1?'':'s')
      ." is led by  $users[0]$leavingnote";
  } else {
    $str = '<em>This usergroup is lonely.</em>';
  }
  $str .= '</p>';

  if(!$isGuest)
  {

    if ($isInGroup)
    {
      $str .= htmlcode('openform')
        .htmlcode('verifyRequestForm', 'leavegroup')
        .$query -> hidden('notanop', 'leavegroup')
        .$query -> submit(
          -name => 'confirmop'
          , value => 'Leave group'
          , title => 'leave this usergroup')
        .'</form>';
    }

    #determine ways user may talk walk usergroup, owner, and/or leader
    $str .= '<p style="border: solid black 1px; padding:2px;">' . htmlcode('openform');


    if(scalar(@memberIDs > 0))
    {
      $curID = $memberIDs[0];	#first user in group

      #send message to group "owner"
      # $ugOwner
      if($ugOwner && defined $ugOwnerIndex)
      {
        $str .= '/msg the group "owner", '
          .$users[$ugOwnerIndex]
          .($isInGroup ? '' : ' (they can add you to the group)')
          .htmlcode('msgField', 'msggrpowner' . $ugOwner . ',,' . $$NODE{node_id} . ',' . $ugOwner) . "<br>\n";
      }

      #send message to group leader (first person)
      if($curID and (getNodeById($curID,'light')->{type_nodetype}) == (getNode('user','nodetype','light')->{node_id}) )
      {
        #only /msg group leader if they are a user
        $str .= '/msg the group leader, '.$users[0].': '.htmlcode('msgField', 'msggrpleader'.$curID . ',,' . $$NODE{node_id} . ',' . $curID) . "<br />\n";
      }

    }


    #send message to group, show number of messages from group
    if($isInGroup || $isRoot)
    {
      $str .= '(You aren\'t in this group, but may talk to it anyway, since you\'re an administrator. If you want a copy of your /msg, check the "CC" box.)<br />' if !$isInGroup;
      $curID = $$NODE{node_id};
      $str .= '/msg the usergroup';
      #TODO ' (messages archived at [usergroup message archive] group = thisone)'
      $str .= ': '.htmlcode('msgField', 'ug'.$curID.',,'.',,'.$curID)."<br />\n";

      if(!$$VARS{hidemsgyou})
      {
        my $nummsgs = $DB->sqlSelect('count(*)', 'message', "for_user=$$USER{node_id} and for_usergroup=$$NODE{node_id}");
        $str .= '<p>'.linkNode(getNode('message inbox', 'superdoc'), "you have $nummsgs message".($nummsgs==1?'':'s').' from this usergroup', { fromgroup => $$NODE{title} }).'</p>' if $nummsgs;
      }
    }

    my $andTheRest = htmlcode('msgField','0');
    $str .= 'other /msgs: '.$andTheRest.'<br />' if length($andTheRest);
    $str .= htmlcode('closeform').'</p>';

  }
  $str .= htmlcode("weblog");

  return $str;
}

sub usergroup_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>|.htmlcode("usergroupmultipleadd").qq|</p>|;
  $str .= qq|<p><b>Title</b></p>|;
  $str .= htmlcode("textfield","title");
  $str .= qq|<p><b>Moderator Type</b></p>|;

  my %valueList = ('0' => 'Single Moderator', '1' => 'Multiple Moderator');
  my @list =  keys(%valueList);

  $str .= $query->popup_menu('usergroup_modtype', \@list, $$NODE{modtype}, \%valueList);

  $str .= qq|<p><b>Join Type</b></p>|;

  %valueList = ('0' => 'Open to All', '1' => 'User Request', '2' => 'Moderator Only');
  @list =  keys(%valueList);

  $str .= $query->popup_menu('usergroup_jointype', \@list, $$NODE{jointype}, \%valueList);

  $str .= qq|<p>|.$query->checkbox('usergroup_messageArchive',$$NODE{messageArchive},1,'Archive messages?').qq|</p>|;

  $str .= qq|<p><b>Recommendation Link</b> (aka Weblog Link)</p>|.htmlcode("textfield","recommendationLink");

  $str .= qq|<p><b>Usergroup Lineup Info (255 char. max)</b></p>|;
  $str .= htmlcode("textarea","shortdesc,4,40");

  $str .= qq|<p><b>Usergroup Doctext</b></p>|;
  $str .= htmlcode("textarea","doctext");

  return $str; 
}

sub node_xml_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return qq|<?xml version="1.0" standalone="yes"?><error><message>You can only use the XML displaytype on your own writeups.</message></error>|;

}

sub mail_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  $str .= qq|<H4>title:</H4>|.htmlcode("textfield","title");
  $str .= qq|<h4>owner:</h4>|.htmlcode("node_menu","author_user,user,usergroup");
  $str .= qq|<h4>from address:</h4>|.htmlcode("textfield","from_address");
  $str .= qq|<p><small><strong>Mail body:</strong></small><br>|;
  $str .= htmlcode("textarea","doctext,30,60");

  return $str;
}

sub superdocnolinks_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $doctitle = $NODE->{title};
  $doctitle =~ s/[\s-]/_/g;
  $doctitle =~ s/[^A-Za-z0-9]/_/g;
  $doctitle = lc($doctitle);

  if($doctitle =~ /^\d+$/)
  {
    $doctitle = "document_$doctitle";
  }

  $APP->devLog("Proposed delegation for '$NODE->{title}': '$doctitle'");
  if(my $delegation = Everything::Delegation::document->can("$doctitle"))
  {
    $APP->devLog("Using document delegation for $NODE->{title} as '$doctitle'");
    return $delegation->($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
  }else{
    return htmlcode('parsecode','doctext');
  }
}

sub e2node_xml_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  use Everything::XML;
  my $except = ['reputation'];

  my $str = "";
  foreach (@{ $$NODE{group}})
  {
    $str.= node2xml($_, $except)."\n";
  }

  return $str;
}

sub node_forward_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $origTitle = $query->param("originalTitle");
  $origTitle = "" if not defined($origTitle);
  my $circularLink = ($origTitle eq $$NODE{title});

  my $targetNodeId = $$NODE{doctext};
  my $targetNode = undef;
  if ($targetNodeId ne '') {
    $targetNode = getNodeById($targetNodeId, 'light');
  }

  my $badLink = ($circularLink || !$targetNode);
  $origTitle ||= $$NODE{title};

  my $urlParams = { };

  unless ($APP->isAdmin($USER) && $badLink)
  {
    if (!$badLink)
    {
      # For good links, forward all users
      $urlParams = { 'originalTitle' => $origTitle };

    } else {

      # For circular or non-functional links, send non-gods to the search page
      $urlParams = {
         'node' => $$NODE{title}
         , 'match_all' => 1
      };

    }

    $$urlParams{'lastnode_id'} = $query->param('lastnode_id')
      if defined $query->param('lastnode_id');

  } else {
    # For circular or non-functional links, send gods directly to the edit page
    $targetNode = $NODE;
    $urlParams = {
      'displaytype' => 'edit'
      , 'circularLink' => $circularLink
    };
  }

  my $redirect_url = urlGen($urlParams, 'no escape', $targetNode);

  # TODO: Replace with Request goodness
  $Everything::HTML::HEADER_PARAMS{-status} = 303;
  $Everything::HTML::HEADER_PARAMS{-location} =
    (($Everything::CONF->environment eq "development")?('http://'):('https://')) . $ENV{HTTP_HOST} . $redirect_url;

  my $str = qq|<html>
    <head>
    <title>$$NODE{title}\@everything2.com</title>
    <script language="JavaScript">
    <!--
      location.href = "$redirect_url";
    -->
    </script>
    <noscript>
    <meta http-equiv="refresh" content="0; URL='$redirect_url'">
    </noscript>
    </head>
    <body>|;

  # The following is a simple informative display for gods only.
  # It shoudl never appear unless someone has disabled HTTP,
  #  META, *and* javascript redirects.

  return $str.qq|</body></html>| unless $APP->isAdmin($USER);

  $str .=
    '<p>'
    .  linkNode(
       $$NODE{ 'node_id' }
       , "edit <b>$$NODE{ 'title' }</b>"
       , { 'displaytype' => 'edit' }
     )
  . '</p>';

  if ($$NODE{doctext} ne '') {
    $str .= '<p><strong>forward-to:</strong> '
      . linkNode( $$NODE{ 'doctext' } )
      . '</p>'
  }

  if ($circularLink)
  {
    $str .= '<p><strong>This is a circular link!</srong></p>';

  }

  $str.=qq|</body></html>|;

  return $str;

}

sub node_forward_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;


  my $str = qq|<p><strong>|.(linkNode( getType('node_forward') )).qq|</strong></p>|;
  $str .= qq|<table><tr><th align="right"><strong>title:</strong></th>|;
  $str .= qq|<td>|.htmlcode("textfield","title").qq|</td></tr><tr><th align="right"><strong>owner:</strong></th>|;
  $str .= qq|<td>|.htmlcode("node_menu","author_user,user,usergroup").qq|</td></tr>|;
  $str .= qq|<tr><th align="right"><strong>forward-to node ID/title:</strong></th>|;
  $str .= qq|<td>|.htmlcode("textfield","doctext").qq|</td>|;
  $str .= qq|</tr></table>|;

  if ($query->param('circularLink')) {
     $str .= "<p><strong>This is a circular link!</strong></p>";
  } 

  my $targetNodeId = $$NODE{doctext};
  my $targetNode = undef;

  $str .= "<p>";

  if ($targetNodeId ne '')
  {
    $targetNode = getNodeById($targetNodeId, 'light');
    if ($targetNode)
    {
      $str .= "Forwards to: " . linkNode($targetNode);
    } else {
      $str .= "The current forward node ID doesn't lead to a valid node.";
    }

  } else {
    $str .= "This forward is presently blank.";
  }

  $str .= "</p>";

  return $str;
}

sub document_viewcode_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return unless $APP->isDeveloper($USER);
  return htmlcode('listcode','doctext');
}

sub debatecomment_display_page
{
  return htmlcode("showdebate",1);
}

sub ticker_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return parseCode($$NODE{doctext});
}

sub plaindoc_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return $NODE->{doctext};
}

sub debatecomment_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  my $restrict = undef;
  if ( $query->param( 'sexisgood' ) )
  {
    $restrict = $query->param( 'debatecomment_restricted' );
    $$NODE{ 'restricted' } = $restrict;
  }

  $restrict = getNodeById($$NODE{ 'root_debatecomment' }) -> {'restricted'};
  my $title = $$NODE { 'title' };
  $title =~ s/\</\&lt\;/g;
  $title =~ s/\>/\&gt\;/g;

  my $ug_name = getNodeById($restrict) -> {'title'};

  $title =~ /^\s*([\w\s]+):/;
  my $prefix = $1;

  $title = "$ug_name: ".$title unless lc($prefix) eq lc($ug_name);

  $$NODE { 'title' } = $title;
  updateNode( $NODE, $USER );

  $str .= htmlcode("showdebate",0);

  my $rootnode = getNodeById( $$NODE{ 'root_debatecomment' } );
  $restrict = $$NODE{restricted};

  # If the user's not in the usergroup, deny access
  if ( $APP->inUsergroup($USER, getNodeById($$rootnode{ restricted })) || Everything::isApproved($USER,$rootnode) )
  {

    $str .= qq|<input type="hidden" name="debatecomment_author_user" value="$$USER{node_id}"></input>|;
    $str .= qq|<input type="hidden" name="sexisgood"><input type="hidden" name="debatecomment_restricted" value="$restrict">|;
    $str .= qq|<h2>Edit your comment</h2><p><label>Comment title:|;
  
    my $ug_id = $restrict;
    my $ug = getNodeById($ug_id);
    $ug_name = $$ug{'title'};
    my $cleantitle = $$NODE{ 'title' };
    $cleantitle =~ s/^$ug_name\: //;

    $cleantitle =~ s/\&lt\;/\</g;
    $cleantitle =~ s/\&gt\;/\>/g;

    my $fieldname = $$NODE{type}{title}."_title";

    $str .= $query -> textfield($fieldname,$cleantitle, 20).'</label></p>';
    $str .= '<p><strong>Comment:</strong><br>';
    $str .= htmlcode("textarea","doctext,20,60,virtual").qq|</p>|;

  }
  return $str;
}

sub debatecomment_replyto_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<form method="post" id="pagebody">|;
  
  $str .= htmlcode("showdebate",0);
  my $rootnode = getNodeById( $$NODE{ 'root_debatecomment' } );

  #new way - includes hack to cover old way
  my $restrict = $$rootnode{restricted}||0;
  if($restrict==0) {
    $restrict=getNode("Content Editors","usergroup")->{node_id};
  } elsif($restrict==1) {
    $restrict=getNode("gods","usergroup")->{node_id};
  }

  my $restrictNode = getNodeById($restrict);
  unless($restrictNode)
  {
    #ack! no group permission somehow!
    return 'Ack! Parent has no group!';
  }

  unless( $APP->inUsergroup($USER,$restrictNode) || Everything::isApproved($USER,$restrictNode) )
  {
    $str.= 'You are not allowed to add a comment to this debate.';
  }else{

    my $newtitle = $$NODE{ 'title' };
    my $ug_name = $restrictNode->{'title'};

    $newtitle =~ s/^$ug_name: //;
    $newtitle = 're: ' . $newtitle unless ( $newtitle =~ /^re: / );
    $newtitle =~ s/"/&quot;/g;

    $str .= qq|<input type="hidden" name="op" value="new">|;
    $str .= qq|<input type="hidden" name="type" value="debatecomment">|;
    $str .= qq|<input type="hidden" name="displaytype" value="edit">|;
    $str .= qq|<input type="hidden" name="debatecomment_restricted" value=".$restrict.">|;
    $str .= qq|<input type="hidden" name="debatecomment_parent_debatecomment" value="$$NODE{node_id}">|;
    $str .= qq|<input type="hidden" name="debatecomment_root_debatecomment" value="$$NODE{root_debatecomment}">|;
    $str .= qq|<h2>Enter your reply</h2>|;
    $str .= qq|<label>Comment title:<input type="text" size="60" maxlength="64" name="node" value="$newtitle"></label><br>|;
    $str .= qq|<p><strong>Comment:</strong><br>|;
    $str .= qq|<textarea name="debatecomment_doctext" cols="60" rows="20" wrap="virtual"></textarea></p>|;
    $str .= qq|<input type="submit" name="sexisgood" value="sumbit">|;
  }

  $str .= qq|</form>|;

  return $str;
}

sub debatecomment_compact_page
{
  return htmlcode("showdebate","4");
}

sub node_xmltrue_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
  $str.= htmlcode("xmlheader").htmlcode("formxml").htmlcode("xmlfooter");
  return $str;
}

sub podcast_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $TAGNODE = getNode 'approved html tags', 'setting';
  my $TAGS=getVars($TAGNODE);

  my $text = $APP->htmlScreen($$NODE{description}, $TAGS);
  $text = parseLinks($text);

  my $str = qq|<h2><a href='$$NODE{link}'>download mp3</a></h2>|;
  $str.="$text";
  $str.='<p align="right">('.linkNode($NODE, 'edit', {'displaytype'=>'edit', 'lastnode_id'=>0}).")</p>" if canUpdateNode($USER, $NODE);
 
  return $str;
}

sub collaboration_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<table cellpadding="8"><tr><td>|;
  #---------------------------------------------------------
  # wharfinger
  # 2/15/2002
  #---------------------------------------------------------

  # User node_ids are in $$NODE{ 'group' }
  # It would be nice to have read-only users, too.


  #---------------------------------------------------------
  # Is the user allowed in?
  my $GROUP   = $NODE->{group};
  my $UID     = $USER->{node_id};
  my $isRoot  = $APP->isAdmin($USER);
  my $isCE    = $APP->isEditor($USER);
  my $allowed = 0;

  my $NL = "<br />\n"; 

  $allowed = $isRoot || $isCE;
  $allowed ||= Everything::isApproved( $USER, getNode( 'crtleads', 'usergroup' ) );
  $allowed ||= Everything::isApproved( $USER, $NODE );
  if( !$allowed )
  {
    if ($$NODE{public}==1)
    {
      $str .= $NL.htmlcode('showcollabtext', 'doctext').$NL;
    }
    else
    { 
      $str .= '<p>Permission denied.</p><p>('.$$NODE{public}.')</p>';
    }
  }else{
    #---------------------------------------------------------
    # List allowed users
    if ( $GROUP )
    {
      $str .= '<p><strong>Allowed users/groups:</strong> ';
      foreach my $item ( @$GROUP )
      {
        $str .= linkNode( $item ) . ' ';
      }
      $str .= "</p>\n";
    }

    my $lockedby_user = $$NODE{ 'lockedby_user' } || 0;
    my $locktime      = $$NODE{ 'locktime' } || 0;
    my $lockendtime   = strftime( '%Y-%m-%d %H:%M:%S', localtime( time() - ( 15 * 60 ) ) );
    my $lockedbyother = $lockedby_user != 0 && $lockedby_user != $UID;
    my $canedit       = ( $isRoot || $isCE || ! $lockedbyother );

    my $unlock = $query->param( 'unlock' ) || '';

    # Use it or lose it. Locks expire after fifteen minutes 
    # without submitting anything.
    if ( ( $lockedbyother && $lockendtime ge $locktime ) || ( $canedit && $unlock eq 'true' ) )
    {
      $$NODE{ 'locktime' }      = 0;
      $$NODE{ 'lockedby_user' } = 0;

      updateNode( $NODE, -1 );

      $locktime      = 0;
      $lockedby_user = 0;
      $lockedbyother = 0;

      $str .= '<p>You just unlocked it. </p>' if ( $canedit && $unlock eq 'true' );
    }

    if ( ! $canedit )
    {
      $str .= '<p><strong>Locked by</strong> ' . linkNode( $lockedby_user ) . '</p>';
    } else {
      $str .= '<p>';

      if ( $lockedby_user == $UID )
      {
        $str .= '<strong>Locked by</strong> ' . linkNode( $UID, 'you' ) . ': ';
      } elsif ( $lockedbyother ) {
        $str .= '<strong>Locked by</strong> ' . linkNode( $lockedby_user ) . ': ';
      }

      $str .= linkNode( $$NODE{ 'node_id' }, '<strong>edit</strong>', { 'displaytype' => 'useredit' } ) . ' ';

      if ( $lockedbyother && ( $isRoot || $isCE ) )
      {
        $str .= ' (editing will <strong>lock the node</strong> and boot ' . linkNode( $lockedby_user ) . ') ';
      }

      if ( $lockedby_user != 0 && $canedit )
      {
        $str .= linkNode( $$NODE{ 'node_id' }, 'unlock', { 'unlock' => 'true' } ) . ' ';
      }

      if ( $isRoot || $isCE )
      {
        $str .= $query -> a({
          href => "/?node_id=$$NODE{node_id}&confirmop=nuke"
          , class => 'action'
          , title => 'delete this collaboration'
          }, 'delete');
      }

      $str .= "</p>\n\n";
    }


    #---------------------------------------------------------
    # Display doctext

    my $doctext = htmlcode('showcollabtext', 'doctext');
    $str .= $NL.$doctext.$NL;
  }
  
  $str .= qq|</td></tr></table>|;
  return $str;
}

sub edevdoc_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";

  if($APP->isDeveloper($USER))
  {
    $str .= qq|<p align="right">|.linkNode($NODE, 'edit', {displaytype => 'edit'}).qq|</p>|;
  }

  $str .= htmlcode("parselinks","doctext");

  return $str;
}

sub schema_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<h4>title:</h4>|.htmlcode("textfield","title");
  $str .= qq|<h4>maintainer:</h4>|.htmlcode("node_menu","author_user,user,usergroup");
  $str .= qq|<h4>schema_extends:</h4>|.htmlcode("node_menu","schema_extends,ticker,nodetype");
  $str .= qq|<p><small><strong>Edit the document text:</strong></small><br />|;
  $str .= htmlcode("textarea","doctext,30,80");

  return $str;
}

sub collaboration_useredit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<table cellpadding="8" width="100%"><tr><td>|;

  my $NL = "\n";
  
  #---------------------------------------------------------
  # Is the user allowed in?
  my $GROUP   = $$NODE{ 'group' } || [];
  my $UID     = getId( $USER );
  my $isRoot  = $APP->isAdmin($USER);
  my $isCE    = $APP->isEditor($USER);
  my $allowed = 0;

  my $AUTOLOCKEXPIRE_SEC = 15*60;
  my $lockedby_user = $$NODE{ 'lockedby_user' } || 0;
  my $locktime      = $$NODE{ 'locktime' } || 0;
  my $lockendtime   = strftime( "%Y-%m-%d %H:%M:%S", localtime( time() - $AUTOLOCKEXPIRE_SEC ) );
  my $lockedbyother = $lockedby_user != 0 && $lockedby_user != $UID;

  my $canedit = ( $isRoot || $isCE || ! $lockedbyother );
  $allowed = $isRoot || $isCE;

  $allowed ||= Everything::isApproved( $USER, getNode( 'crtleads', 'usergroup' ) );
  $allowed ||= Everything::isApproved( $USER, $NODE );

  return "<p>Permission denied.</p></td></tr></table>" unless ( $allowed );

  # Unlock if the locker has gone for a while without 
  # submitting any changes.
  if ( $lockedbyother && $lockendtime ge $locktime )
  {
    $lockedby_user = $UID;
    $lockedbyother = 0;
    $canedit       = 1;
  }

  #---------------------------------------------------------
  $str .= '<p><strong>Locked by</strong> ' . linkNode( $lockedby_user ) . '</p>' if ( $lockedbyother && ! $canedit );
  $str .= '<p>' . linkNode( $$NODE{ 'node_id' }, '<b>display</b>' ) . " ";

  if ( $canedit )
  {
    $$NODE{ 'lockedby_user' } = $$USER{ 'node_id' };
    $$NODE{ 'locktime' }      = strftime( "%Y-%m-%d %H:%M:%S", 
                                          localtime() );
    updateNode( $NODE, -1 );

    $str .= linkNode( $$NODE{ 'node_id' }, 'unlock', { 'unlock' => 'true' } ) . ' ';

    if ( $isRoot || $isCE )
    {
      $str .= $query -> a({
        href => "/?node_id=$$NODE{node_id}&confirmop=nuke"
        , class => 'action'
        , title => 'delete this collaboration'
        }, 'delete');
    }

    $str .= "</p>\n";
  } else {
    return $str . "</p></td></tr></table>";
  }

  #---------------------------------------------------------
  # List allowed users
  $str .= htmlcode( 'openform' );
  $str .= "<p><b>Allowed users/groups (one per line):</b> \n";

  if ( $isRoot || $isCE ) 
  {
    $str .= '<br />'; 
    if ( defined $query->param( 'users' ) )
    {
      my $usernames = $query->param( 'users' );
      # Remove whitespace from beginning and end of each line   
      $usernames =~ s/\s*\n\s*/\n/g;

      my @users = split( '\n', $usernames );

      foreach my $user ( @$GROUP ) {
        $DB->removeFromNodegroup( $NODE, getNodeById( $user ), -1 );
      }

      my $badusers = '';
      my $user = 0;

      foreach my $username ( @users )
      {
        $user = getNode( $username, 'user' ) || getNode( $username, 'usergroup' );

        if ( $user )
        {
          insertIntoNodegroup( $NODE, -1, $user );
	} else {
          $badusers .= '<dd>['.$username.']</dd>'.$NL;
        }
      }

      if ( $badusers )
      {
        $str .= "<dl><dt><b>These aren't real users:</b></dt>\n";
        $str .= parseLinks( $badusers );
        $str .= "</dl>\n";
      }
    }

    $str .= '<textarea cols="20" rows="6" name="users">';
    $GROUP = $$NODE{ 'group' } || [];
    if ( $GROUP )
    {
      my $user;
      foreach my $item ( @$GROUP )
      {
        $user = getNode( $item );
        $str .= $$user{ 'title' } . $NL;
      }
    }

    $str .= "</textarea>\n</p>\n";
  } else {
    if ( $GROUP )
    {
      foreach my $item ( @$GROUP )
      {
        $str .= linkNode( $item ) . ' ';
      }
    }
    $str .= "</p>\n";
  }

  if ( defined $query->param( 'doctext' ) )
  {
    $$NODE{ 'doctext' } = $query->param( 'doctext' );
    if ( $query->param( 'public' ) )
    {
      $$NODE{ 'public' } =  1;
    } else {
      $$NODE{ 'public' } =  0;
    }
    updateNode( $NODE, -1 );
  }

  #---------------------------------------------------------
  # Display doctext
  $str .= "<p><b>Content:</b><br />\n";
  # Dammit, the doctext this digs up is from before the update 
  # above. 
  $str .= htmlcode( 'showcollabtext', 'doctext' ) . $NL;

  # Edit doctext
  $str .= '<textarea name="doctext" rows="20" cols="60" wrap="virtual">';

  my $doctext = $query->param( 'doctext' ) || $$NODE{ 'doctext' };
  $doctext =~ s/\&/\&amp;/g;
  $doctext =~ s/</&lt;/g;
  $doctext =~ s/>/&gt;/g;
  $str .= $doctext;

  $str .= "</textarea>\n";
  $str .= $NL;
  $str .="<input type='checkbox' name='public' ".( ($$NODE{ 'public' }==1) ? "checked='true'" : "")." value='1' /> Public?<br />";

  $str .= htmlcode( 'closeform' );
  $str .= qq|</td></tr></table>|;
  return $str;
}

sub e2client_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";
  $str .= (($$USER{user_id} == $$NODE{author_user})?('<p align="right">'.linkNode($NODE, 'edit', {'displaytype'=>'edit'}).'</p>'):(''));
  $str .= qq|<p><table>|;

  my $usr = getNodeById($$NODE{author_user});
  my $clientstr = "<tr><td><strong>Maintainer:</strong></td><td>".linkNode($usr)."</td></tr>";
  $clientstr .= "<tr><td><strong>Homepage:</strong></td><td>[$$NODE{homeurl}]</td></tr>";
  $clientstr .= "<tr><td><strong>Download:</strong></td><td>[$$NODE{dlurl}]</td></tr>.";
  $clientstr .= "<tr><td><strong>Version:</strong></td><td>$$NODE{version}</td></tr>.";
  $clientstr .= "<tr><td><strong>Unique Client String:</strong></td><td><b>$$NODE{clientstr}</b></td></tr>";

  $str .= parseLinks($clientstr);
  $str .= qq|</table></p><br><br><hr><br>|.htmlcode("parselinks","doctext");

  return $str;
}

sub e2client_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<table><tr><td><b>Title:</b></td><td>|.htmlcode("textfield","title").qq|</td>|;
  $str .= qq|<tr><td><b>Client ID (string):</b></td><td>|.htmlcode("textfield","clientstr").qq|</td></tr>|;
  $str .= qq|<tr><td><b>Version (string):</b></td><td>|.htmlcode("textfield","version").qq|</td></tr>|;
  $str .= qq|<tr><td><b>Homepage URL:</b></td><td>|.htmlcode("textfield","homeurl").qq|</td></tr>|;
  $str .= qq|<tr><td><b>Download URL:</b></td><td>|.htmlcode("textfield","dlurl").qq|</td></tr>|;
  $str .= qq|</table><br><br><b>Description:</b><br>|;
  $str .= htmlcode("textarea","doctext,30,60");

  return $str;
}

sub node_help_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";  

  if($APP->isAdmin($USER))
  {
    my $dohelp = $query->param("dohelp");  
    my $txt = $query->param("helptext");

    if($dohelp eq "create")
    {
      $DB->sqlInsert("nodehelp", {nodehelp_id => $$NODE{node_id}, nodehelp_text => $txt});
      $str.= "Help topic created!<br><br>";
    }
  
    if($dohelp eq "update")
    {
      $DB->sqlUpdate("nodehelp", {nodehelp_text => $txt}, "nodehelp_id=$$NODE{node_id}");
      $str.= "Help topic updated!<br><br>";
    }
  }

  my $csr = $DB->sqlSelectMany("*", "nodehelp", "nodehelp_id=$$NODE{node_id}");
  $str .= "<p align=\"right\">Help for: ".linkNode($NODE)."</p><br>";
  my $nohelp = "<em><p align=\"center\">No help topic available for this item</p></em>";

  if(my $row = $csr->fetchrow_hashref())
  { 
     if(length($$row{nodehelp_text}) < 3)
     {
      $str.= $nohelp 
     }
     else
     {
      $str.= parseLinks($$row{nodehelp_text});
     }
  }
  else
  {
     $str.= $nohelp;
  }
  
  $str.= "<br><br>";
  

  if($APP->isAdmin($USER))
  {
    $csr = $DB->sqlSelectMany("*", "nodehelp", "nodehelp_id=$$NODE{node_id}");
    my $row = undef;
    my $dohelp = undef;
    if($row = $csr->fetchrow_hashref())
    {
      $dohelp = "update";
    } else{
      $dohelp = "create";
    }

    $str .= "<br><br><p align=\"center\"><hr width=\"200\"></p><br>Because you are spiffy, you can edit the help topic for ".linkNode($NODE).":<br><br>".htmlcode("openform")."<input type=\"hidden\" name=\"dohelp\" value=\"$dohelp\"><textarea name=\"helptext\" rows=\"30\" cols=\"80\">$$row{nodehelp_text}</textarea><br><input type=\"submit\" value=\"submit\"></form>";

  }

  return $str;
}

sub datastash_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $json = JSON->new;
  return qq|<pre>|.$json->pretty->encode($json->decode($NODE->{vars} || "[{}]")).qq|</pre>|;
}

sub jsonexport_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $json_struct = evalCode($NODE->{code});
  return encode_json($json_struct);
}

sub document_linkview_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p align="right">Return to |.linkNode($NODE).qq|</p>|;

  my @links = ();
  my @notlinks = ();

  my $regex = qr/\[(.*?)[\]\[\|]/;
  my $ntt = $NODE->{type}->{title};
  my $codeDoc = ($ntt eq 'superdoc') || ($ntt eq 'superdocnolinks') || ($ntt eq 'restricted_superdoc') || ($ntt eq 'oppressor_superdoc'); #FIXME better way of checking for code
  $regex = qr/\[([^%{].*?)[\]\[\|]/ if $codeDoc;

  my $text = $$NODE{doctext};
  my $scratchID;

  my @link_ids = ();
  while ($text =~ /$regex/g)
  {
    my $lnk = $1;
    #omit external links
    next if ($lnk =~ /^\s*https?:\/\//);


    $lnk = $APP->htmlScreen($lnk);

    if (my $node_id = $DB->sqlSelect('node_id', 'node','title='.$DB->{dbh}->quote($lnk)))
    {
      push @link_ids, [$node_id,$lnk];
    } else {
      push @notlinks, linkNodeTitle($lnk, $NODE);
    }
  }

  my %fillednode_ids = ();
  #Only make one SQL call to find the non-nodeshells.
  if (@link_ids)
  {
    my $sql = "SELECT DISTINCT nodegroup_id
      FROM nodegroup
      WHERE nodegroup_id IN ("
      .join(", ",
      (map { $_ -> [0]} @link_ids)
      ).")";

    @fillednode_ids{  @{$DB->{dbh} -> selectcol_arrayref($sql)}  } = ();
  }

  #If it's a link to anything but an e2node (type 116), it's also filled.
  if (@link_ids)
  {
    my $sql = "SELECT node_id
     FROM node
     WHERE type_nodetype != ".$DB->getType("e2node")->{node_id}." 
       AND node_id in ("
     .join(", ",
     (map {$_ -> [0]} @link_ids)
     ).")";

    @fillednode_ids{  @{$DB->{dbh} -> selectcol_arrayref($sql)}  } = ();
  }

  foreach my $linkref(@link_ids)
  {
    my $isfilled = exists $fillednode_ids{$linkref -> [0]};
    push @links, [linkNodeTitle($linkref -> [1], $NODE), $isfilled ];
  }

  my $TAGNODE = getNode 'approved html tags', 'setting';
  my $TAGS=getVars($TAGNODE);

  @notlinks = () if $codeDoc;

  $text = $APP->breakTags($text) unless $codeDoc;

  my $oddrowclr  = '#999999';

  $str .= "<table class=\"item\"><tr><td width=\"80%\" class=\"content\">$text</td><td width=\"5%\"></td><td valign=\"top\"
    bgcolor=\"".$oddrowclr."\" class=\"content\"><strong>Existing:</strong><br>";

  $str .= "<ul class=\"linklist\">\n";

  foreach my $linkref(@links)
  {
    my $link = $$linkref[0];
    my $isfilled = $$linkref[1];
    $str .= "<li ".($isfilled ? "" : "class=\"nodeshell\"" ).">";
    $str .= $link."</li>\n";
  }

  $str .= "</ul>\n";
  $str .= "<hr width=\"20\"><br><strong>Non-Existing:</strong><br>";

  $str .= "<ul class=\"linklist\">\n <li>";

  $str .=  join("</li>\n<li>", @notlinks)
    ."</li>\n</ul></td></tr></table>";

  return $str;
}

sub e2node_chaos_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";

  my @junk=(
    "Where did I put that?"
    , "I lost my mind in San Francisco"
    , "Shuffle shuffle"
    , "I smashed it into a million pieces, and cut myself on its beauty"
    , "It used to be full of stars, but now I'm full of scars.");

  $str .= qq|<small><p align="right"><strong>$junk[rand(@junk)]</strong></p></small>|;


  my $softlinkType = 0;
  my $E2NODE = $NODE;
  my $csr =
    $DB->sqlSelectMany(
    "to_node"
    , "links"
    , "from_node = $$E2NODE{node_id} AND linktype = $softlinkType"
    );

  my @LINKS = ();

  while(my $row = $csr->fetchrow_hashref)
  {
    my $N = getNodeById($$row{to_node}, 'light');
    next unless $N;
    push @LINKS, $N;
  }

  if(scalar(@LINKS) == 0)
  {
    $str .= "<p>Ain't nothin'</p>";
  }else{
    $str = qq|<p>Somewhere near |.linkNode($E2NODE).qq| I got lost in:</p>|;
    $str .= '<div id="softlinks">';

    foreach(sort {rand() <=> rand()} @LINKS)
    {
      my $fontSize = int((rand(8)**2.2+65)) . '%';
      $str .= linkNode($_, undef, {
      lastnode_id => $$E2NODE{node_id}
      , -style=> "font-size: $fontSize;"});

      $str .= "&nbsp;" x (rand(50));
    }
  $str .= '</div>';
  }

return $str;
}

sub dbtable_index_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>Indices for database table $NODE->{title}</p>|;
  my $table = $NODE->{title};
  my @cols = qw(Name Seq Column Coll Card SubPt Packed Comment );
  my %cols = ( Name=>'Key_name', Seq=>'Seq_in_index',
    Column=>'Column_name', Coll=>'Collation',
    Card=>'Cardinality', SubPt=>'Sub_part',
    Packed=>'Packed', Comment=>'Comment' );

  my @fields;
  {
    my $sth= $DB->{dbh}->prepare( "show index from $table" );
    $sth->execute();
    while(  my $rec= $sth->fetchrow_hashref()  )
    {
      push @fields, $rec;
    }
    $sth->finish();
  }

  $str .= "<table class=\"index\">\n";
  $str .= " <tr>\n";

  foreach my $fieldname (  @cols  )
  {
    $str .= qq|  <th class="indexHeader">$fieldname</th>|;
  }
  $str .= " </tr>\n";

  foreach my $field (  @fields  )
  {
    $str .= " <tr>\n";
    foreach my $value (  @{$field}{@cols{@cols}}  )
    {
      $value = "&nbsp;"   if  $value eq "";
      $str .= "  <td class=\"indexValue\">$value</td>\n";
    }

    $str .= " </tr>\n";
  }

  $str .= "</table>\n";

  return $str;
}

sub user_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = htmlcode("setupuservars") || "";
  $str .= qq|<div id='homenodeheader'>|;
  $str .= htmlcode("homenodeinfectedinfo") || "";
  $str .= qq|<div id='homenodepicbox'>|;
  $str .= htmlcode("showuserimage") || "";

  if(getId($USER) == getId($NODE) and not $APP->isGuest($USER))
  {
    $str.= '<p>' . linkNode($NODE, '(edit user information)', {displaytype=>'edit', "-id" => "usereditlink"}) . '</p>';
  }

  $str .= qq|</div>|;
  $str .= htmlcode("zenDisplayUserInfo");

  $str .= qq|</div>|;
  $str .= qq|<hr class='clear'>|;
  $str .= qq|<table width="100%" id='homenodetext'><tr><td>|;

  my $isignored = $DB->sqlSelect("ignore_node","messageignore","messageignore_id=$$NODE{node_id} and ignore_node=$$USER{node_id}");
  if(not $isignored and not $APP->isGuest($USER))
  {

    my $csr = $DB->sqlSelectMany('*','registration',
      'from_user='.$$NODE{user_id}.' && in_user_profile=1');

    if($csr)
    {
      my $labels = ['Registry','Data','Comments'];
      my $rows = undef;

      while(my $ref = $csr->fetchrow_hashref())
      {
        push @$rows,{
          'Registry'=>linkNode($$ref{for_registry}),
          'Data'=>$APP->breakTags(parseLinks($APP->htmlScreen($$ref{data}))),
          'Comments'=>$APP->breakTags(parseLinks($APP->htmlScreen($$ref{comments}))),
        };
      }
      $str .= $APP->buildTable($labels,$rows,'class="registries",nolabels') if($rows);
    }else{
      $str .= "SQL problem, tell a [coder]";
    }
  }

  $str .= qq|<div class='content'>|;
  $str .= htmlcode("displayUserText");
  $str .= qq|</div></td></tr></table>|;

  $str .= htmlcode("showbookmarks");

  return $str;
}

sub e2node_softlinks_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n";
  $str.= htmlcode("xmlheader")."<softlinks>\n".htmlcode("softlink", "xml")."</softlinks>\n".htmlcode("xmlfooter");
  return $str;
}

sub datastash_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<h4>title:</h4>|.htmlcode("textfield","title");
  $str .= qq|<p><small><strong>Edit the data:</strong></small><br />|;
  $str .= htmlcode("textarea","vars,30,60");

  return $str;
}

sub e2poll_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = htmlcode("openform");
  $str .= qq|<fieldset><legend>Edit poll</legend>|;
 
  if($NODE->{poll_status} ne "new")
  {
    $str.= qq|<p><strong>This poll has already been posted for voting. Editing it now is probably a stupid idea.</strong></p>|;
  }

  $str .= qq|<label>Question:|.htmlcode("textfield","question,72").qq|</label>|;
  $str .= qq|<p><b>Answers</b> are separated by one or more line-breaks:</p>|;
  $str .= qq|<textarea name="e2poll_doctext" |.htmlcode("customtextarea","1").qq|>|;

  $str .= $query -> escapeHTML($$NODE{doctext});
  $str .= qq|</textarea></fieldset>|;
  $str .= htmlcode("closeform");

  $str .= qq|<h2>$$NODE{title}</h2>|;

  $str .= htmlcode("showpoll");
  return $str;
}

sub category_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $page = int($query->param('p') || 0);
  my $count = 50;
  my $isCategoryEditor = 0;
  my $maintainer = getNodeById($$NODE{author_user});
  my $guestuserId = getId(getNode('guest user', 'user'));
  if ($$maintainer{type_nodetype} == getId(getType('user')))
  {
    if($$maintainer{node_id} == $$USER{user_id} && !$APP->isGuest($USER) )
    {
      $isCategoryEditor = 1;
    }
  }elsif($$maintainer{type_nodetype} == getId(getType('usergroup'))) {
    if ($APP->inUsergroup($USER, getNodeById($$maintainer{node_id})))
    {
      $isCategoryEditor = 1;
    }
  }

  if (!$isCategoryEditor)
  {
    if ($APP->isEditor($USER))
    {
      $isCategoryEditor = 1;
    }
  }

  my $str = "";
  if ($isCategoryEditor == 1)
  {
    $str .= '<p style="text-align:right">'.linkNode($NODE, 'edit', {displaytype => 'edit'}).'</p>';
  } elsif(!$APP->isGuest($$NODE{author_user})) {
    $str .= '<p>If you find any nodes you think should be in this category, message the maintainer (or an editor) with your suggestion.</p>';
  }

  if ($APP->isGuest($$maintainer{node_id}) )
  {
    $str .= '<p><b>Maintained By:</b> Everyone</p>';
  } else {
    $str .= '<p><b>Maintained By:</b> '.linkNode($maintainer).'</p>';
  }

  my $descr = $NODE->{doctext};
  my $TAGNODE = getNode('approved html tags', 'setting');
  my $TAGS = getVars($TAGNODE);
  $descr = $APP->htmlScreen($descr, $TAGS);
  $descr = $APP->screenTable($descr);
  $descr = parseLinks($descr, undef);
  $descr = $APP->breakTags($descr);

  if ($descr ne "")
  {
    $str .= qq|<div class="content">$descr</div>|;
  }

  my $catlinktype = getNode('category', 'linktype')->{node_id};

  my $sql = "SELECT node.node_id,node.title,node.type_nodetype,node.author_user
           FROM node,links
           WHERE node.node_id=links.to_node
            AND links.from_node=$$NODE{node_id}
            AND links.linktype = $catlinktype
           ORDER BY links.food, node.title, node.type_nodetype
           LIMIT ".($page*$count).",$count";
  my $ds = $DB->{dbh}->prepare($sql);
  $ds->execute() or return $ds->errstr;

  my $ctr = 0;
  my $num = $page*$count;
  my $nodetype;
  my $table;
  while(my $row = $ds->fetchrow_hashref)
  {
    $ctr++;
    $num++;
    $nodetype = getNode($$row{type_nodetype});
    if ($ctr % 2 == 0)
    {
      $table .= '<tr>';
    }else {
      $table .= '<tr class="oddrow">';
    }

    $table .= '<td style="text-align:center">'.$num.'</td>
           <td>'.linkNode($$row{node_id}, $$row{title}, {lastnode_id=>0}).'</td>
           <td>'.($$nodetype{title} eq 'writeup' ? 
				linkNode($$row{author_user},'', {lastnode_id=>0}):'&nbsp;').'</td>
           <td style="text-align:center">'.$$nodetype{title}.'</td>
           </tr>';
  }

  unless ($num)
  {
    $str .= '<p><strong>This category is empty.</strong></p>';
  }else{
    $str .= qq|<table align="center" cellpadding="3"><tr><th>&nbsp</th><th>Title</th>|;
    $str .= qq|<th>by</th><th>Type</th></tr>$table\n</table>\n|;
  }

  if ($page || $ctr == $count)
  {
    $str .= '<p style="text-align:center">';
    $str .= '<a href="/index.pl?node_id='.$$NODE{node_id}.'&p='.($page-1).'">&lt;&lt;Prev</a>' if $page;
    $str .= ' | <b>Page '.($page+1).'</b> | ';
    $str .= '<a href="/index.pl?node_id='.$$NODE{node_id}.'&p='.($page+1).'">Next&gt;&gt;</a>' if $ctr == $count;
    $str .= '</p>'
  }

  return $str;
}

sub category_editor_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p align=right>|;

  if ($query->param('op') eq 'close')
  {
    $$VARS{group} = "";
    $str .= "<SCRIPT language=\"javascript\">parent.close()</SCRIPT>";		
  }else{
    $$VARS{group}||= getId ($NODE);
    $str .= linkNode($NODE, "close", {displaytype=> $query->param('displaytype'),op => 'close'});
  }
  $str .= htmlcode("groupeditor");
  $str .= qq|</FORM>|;

  return $str;
}

sub category_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p align="right">|.linkNode($NODE, 'display', {displaytype => 'display'}).qq|</p>|;

  return $str.'You cannot edit this category.' unless(not $APP->isGuest($USER) and canUpdateNode($USER, $NODE));

  if ($query -> param('op') eq 'nuke' && $query->param('node_id') == $$NODE{node_id} && htmlcode('verifyRequest', 'nukecat'))
  {
    $DB->nukeNode($NODE, -1);
    return $query->b('Category deleted');
  }


  my $isCE = $APP->isEditor($USER);

  my $mydbh = $DB->getDatabaseHandle();
  return 'No database handle!' unless $mydbh;
  my $sql;

  # delete a link
  my $deleteId = int($query->param('del'));
  if ($deleteId > 0)
  {
    my $linktypeId = getId(getNode('category', 'linktype'));
    $DB->sqlDelete("links", "from_node=$$NODE{node_id} AND to_node=$deleteId AND linktype=$linktypeId");
  }

  my $addstr = '';
  if ($isCE)
  {
    $str .= htmlcode('openform', 'titleForm').'<fieldset><legend>Fix title</legend><p></p>'
      .$query -> label(
        'Please only change the title on request from the maintainer or if it really obviously needs fixing:<br>'
        .$query -> textfield('category_title', $$NODE{title}, 25)
      ).$query -> submit('Fix')
      .'</fieldset>'
      .$query->end_form;

    my $maintainer = getNodeById($$NODE{author_user});

    # change the maintainer
    my $setMaintainer = $query->param('setMaintainer');
    if ($setMaintainer && htmlcode('verifyRequest', 'setMaintainerForm'))
    {
      my $newMaintainer = getNode($setMaintainer, 'user');
      if (!$newMaintainer)
      {
        $newMaintainer = getNode($setMaintainer, 'usergroup');
      }

      if ($newMaintainer)
      {
        $$NODE{author_user} = $$newMaintainer{node_id};
        updateNode($NODE, -1);
        $maintainer = $newMaintainer;
      } else { $str .= "<b>Unable to find user or usergroup: $setMaintainer </b><br>"; }
    }
	
    $str .= htmlcode('openform', 'setMaintainerForm')
      .'<fieldset><legend>Maintainer</legend><p>Since you\'re an editor, you can change the maintainer of this category.</p>
      Enter the name of a user or usergroup, or "Guest User" to allow anyone who can create categories to contribute:<br>'
      . $query->textfield('setMaintainer', $$maintainer{title}, 25)
      . $query->submit("changeit", "Change")
      . '<br> Current maintainer: ' . linkNode($maintainer)
      . '</fieldset>'
      . htmlcode('verifyRequestForm', 'setMaintainerForm')
      . $query->end_form;
  } else {
    $str .= '<p>To change the title or maintainer of this category, please contact an editor.</p>';
  }

  my $catlinktype = getNode('category', 'linktype')->{node_id};

  # add a node if the user submitted the addnode form
  if ($query->param('addnode') && htmlcode('verifyRequest', 'addCatNode'))
  {
    my $addnodename = $query->param('addnodename');
    my $byuser;
    my $authornotfound = 0;
	
    if ($addnodename =~ /(.*)\[by (.*)\]$/)
    {
      $addnodename = $1;
      $byuser = getId(getNode($2, 'user'));
      if (!$byuser) { $authornotfound = 1; }
    }
	
    my $addnodeid;
    if (!$authornotfound)
    {
      $addnodeid = getId(getNode($addnodename, 'e2node'));
    }
	
    if ($addnodeid && $byuser)
    {
      my $cursor = $DB->sqlSelectMany('writeup_id','writeup', "parent_e2node = $addnodeid");		
      my $wid;
      $addnodeid = 0;
      while (($wid) = $cursor->fetchrow())
      {
        if (getNode($wid)->{author_user} == $byuser)
        {
          $addnodeid = $wid;
	  last;
        }
      }
    }
	
    if ($addnodeid)
    {
      $DB->sqlInsert("links", {
        from_node => $$NODE{node_id},
        to_node => $addnodeid,
        linktype => $catlinktype,
      });

      $addstr .= "Added " . linkNode($addnodeid);
    } else {
      $addstr .= "Node not found: " . parseLinks("[$addnodename]");
      if ($byuser)
      { 
        $addstr .= " by " . linkNode($byuser);
      }elsif ($authornotfound){ 
        $addstr .= " (unknown author given)";
      }
    }
  }


  # reorder the nodes if the user submitted a reordering form
  if ($query->param('orderthem') && htmlcode('verifyRequest', 'reorderCatNodes'))
  {
    for my $param ($query->param)
    {
      next unless $param =~ /^catfood_(\d+)$/;
      my $nid = $1;
      my $nf = $query->param($param);
      $query->delete($param);
      if ($nf eq '' || $nf =~ /\D/)
      {
        $nf = 0;
      }
		
      $sql = "UPDATE links
        SET food = $nf
        WHERE links.to_node = $nid
        AND links.from_node = $$NODE{node_id}
        AND links.linktype = $catlinktype";
      my $ds = $mydbh->prepare($sql);
      $ds->execute() or return $ds->errstr;
    }
  }


  # "add a node" box---mostly so that editors can add nodes to categories

  $str .= htmlcode('openform', 'addCatNode')
    . '<fieldset><legend>Add by name</legend>'
    . '<p>Add a whole node ("node title") or a single writeup ("node title[by someone]"):</p>'
    . htmlcode('verifyRequestForm', 'addCatNode');

  if ($addstr ne '')
  {
    $str .= "<p>$addstr</p>";
  }

  $str .= ''.$query->textfield("addnodename", '', 25)
   . $query->submit("addnode", "Add")
   . '</fieldset>' . $query->end_form;


  $str .= htmlcode('openform', 'updateDescrForm').'<fieldset><legend>Category Description</legend>'
    .'<textarea name="category_doctext" id="category_doctext" '
    . htmlcode('customtextarea', '1')
    . ' class="formattable">'
    . $APP->encodeHTML($$NODE{doctext})
    . '</textarea>'
    . $query->submit("update", "Update Description")
    . '</fieldset>' . $query->end_form;


  # list nodes in the category, with "delete" links

  $sql = "SELECT node.node_id,node.title,node.type_nodetype,node.author_user
    FROM node,links
    WHERE node.node_id=links.to_node
    AND links.from_node=$$NODE{node_id}
    AND links.linktype = $catlinktype
    ORDER BY links.food, node.title, node.type_nodetype";

  my $ds = $mydbh->prepare($sql);
  $ds->execute() or return $ds->errstr;

  my $ctr = 0;
  my $table = '';
  my $nodetype;
  while(my $row = $ds->fetchrow_hashref)
  {
    $ctr++;
    $nodetype = getNode($$row{type_nodetype});
    if ($ctr % 2 == 0)
    {
      $table .= '<tr>';
    }else{
      $table .= '<tr class="oddrow">';
    }

    $table .= '<td>'.linkNode($$row{node_id}, $$row{title}, {lastnode_id=>0}).'</td><td>'.
      ($$nodetype{title} eq 'writeup' ? linkNode($$row{author_user},'', {lastnode_id=>0}):'&nbsp;').
      '</td><td style="text-align:center">'.$$nodetype{title}.
      '</td><td style="text-align:center"><a href="/index.pl?node_id='.$$NODE{node_id}.
      '&displaytype=edit&del='.$$row{node_id}.'">delete</a></td><td>'.
      $query->textfield("catfood_$$row{node_id}", 10*$ctr, 10) . '</td></tr>';
  }

  unless ($ctr)
  {
    $str .= '<p><strong>This category is empty.</strong></p>';
  }else{
    $str .= htmlcode('openform', 'reorderCatNodes')
    . '<fieldset><legend>Reorder</legend>'
    . htmlcode('verifyRequestForm', 'reorderCatNodes')
    . qq'<table><tr>
      <th>Title</th>
      <th>by</th>
      <th>Type</th>
      <th>Delete</th>
      <th>Order</th>
      </tr>$table<tr><td colspan="4">&nbsp;</td><td>'
	. $query->submit("orderthem", "Reorder")
	. '</td></tr></table>'
	. '</fieldset>'
	. $query->end_form;
  }

  $str .= htmlcode('openform')
    .htmlcode('verifyRequestForm', 'nukecat')
    .'<br><button type="submit" name="confirmop" value="nuke" title="delete this category">Delete Category</button> </form>'
    if $$NODE{author_user} == $$USER{node_id} || $isCE;

  return $str;

}

sub stylesheet_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = '<p><cite>by&nbsp;' . linkNode ($$NODE{author_user}) . '</cite></p>';
  $str .= '<p><a href="https://github.com/everything2/everything2/blob/master/www/css/'.$NODE->{node_id}.'.css">View this stylesheet on GitHub</a></p>';

  if(not $APP->isGuest($USER))
  {
    if ($query->param('userstyle'))
    {
      $$VARS{userstyle} = $$NODE{node_id};
    }

    if ($$USER{user_id} == $$NODE{author_user} or $APP->isAdmin($USER) )
    {
      my $usercnt = $DB->sqlSelect("count(*)","setting","vars like '%userstyle=$$NODE{node_id}%'");

      if ($$USER{user_id} == $$NODE{author_user})
      {
        $str .="<p>Talk to your users ($usercnt):</p>";
      } else {
        $str .="<p>Talk to the stylesheet's users ($usercnt):</p>";
      }

      $str .= '<input type="text" name="style_msg" size="50" value="">';
      $str .= "<br>";

      my $msg = $query -> param('style_msg');

      #Trim whitespace so that we don't send blank /msgs.
      $msg =~ s/^\s*//;
      $msg =~ s/\s*$//;

      # Send /msg to users if there is a /msg to send --[Swap]
      if ($msg)
      {
        my $csr = $DB->sqlSelectMany('setting_id','setting',"vars like '%userstyle=$$NODE{node_id}%'");
        my $numusers = $csr -> rows;
        my $maxusers = 500;

        if ($numusers > $maxusers)
        {
          # Kernel blue has about 15,000 users at the time of this coding
          # (April 2009). Somehow, I don't think that /msging 15,000
          # people at once is a good idea. --[Swap]
          $str .= "<p><small>Sorry, you have too many users! Talk to [e2 staff|an admin or editor] to make a general announcement on the front page instead if you really need to.</small></p>";
        } else {
          my @stylesheet_users;
          while (my $row = $csr -> fetchrow_hashref)
          {
            my $uid = $$row{'setting_id'};
            my $user = getNodeById($uid) -> {'title'};
            push @stylesheet_users,$user;
          }

          htmlcode('sendPrivateMessage',{'recipient' => \@stylesheet_users,'message' => $msg,});

          #No XSS!
          $msg =~ s/\</\&lt\;/g;
          $msg =~ s/\>/\&gt\;/g;

          $str .= "<p><small>You said, <i>\"$msg\"</i> (sent to ".@stylesheet_users." users)</small></p>\n";
        }
      }
    }

    $str .= '<p>'.linkNode( $NODE , 'Try this stylesheet out' , {displaytype => 'choosetheme', theme => $$NODE{ node_id }, noscript => 1, -id => 'testdrive'}).'</p>' ;

    $str .= "<p><input type='checkbox' ".
      ( $$VARS{userstyle} == $$NODE{node_id} ?"checked='checked''" :"").
      " name='userstyle' value='".$$NODE{node_id}."'> Use this stylesheet</p>";

    $str .= '<input type="button" value="Preview this style" id="previewstyle">';
  }

  return $str;

}

sub stylesheet_view_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  if ($query->param('version'))
  {
    # Set a far-future expiry time if a specific version is requested.
    $Everything::HTML::HEADER_PARAMS{'-expires'} = '+10y';
  }

  return $$NODE{doctext};
}

sub debatecomment_atom_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $N = getNodeById($$NODE{ 'root_debatecomment' });

  my $UID = getId($USER);
  unless( $APP->isAdmin($USER) )
  {
    my $gID_CE = $DB->getNode("Content Editors","usergroup")->{node_id};
    my $restrictGroup = $$N{restricted} || $gID_CE;	#old way of indicating CEs only was 0
    return if $restrictGroup==114;	#quick check for admins (they were already checked for, so don't bother checking again)
    return if ($restrictGroup==$gID_CE) && !$APP->isEditor($USER);	#quick check for editors
    return if ($restrictGroup==838015) && !$APP->isDeveloper($USER);	#quick check for edev

    $restrictGroup = getNodeById($restrictGroup);
    return unless $restrictGroup;
    return unless Everything::isApproved($USER, $restrictGroup);
  }

  my $GROUP = $$N{ 'group' };


  my @com = $APP->getCommentChildren(@$GROUP);
  my @sorted = sort {$b cmp $a} @com;
  my $str;
  foreach (@sorted) {
    my $comment = $_;
    $str .= htmlcode('atomiseNode', $comment);
  }

  $str .=  htmlcode('atomiseNode', $$N{'node_id'});

  return $str;
}

sub achievement_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p><strong>Displaying:</strong>$$NODE{display}</p>|;
  $str .= qq|<p><strong>Type:</strong>$$NODE{achievement_type}</p>|;
  $str .= qq|<p><strong>Subtype:</strong>$$NODE{subtype}</p>|;
  $str .= qq|<p><strong>Still available:</strong>|.($$NODE{achievement_still_available} ? 'yes' : 'no').qq|</p>|;
  $str .= htmlcode("listcode","code");
  return $str;
}

sub achievement_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>title:|.htmlcode("textfield","title").qq| maintained by:|.htmlcode("node_menu","author_user,user,usergroup").qq|<br>|;
  $str .= qq|display:|.htmlcode("textfield","display,100").qq|<br>|;
  $str .= qq|type:|.htmlcode("textfield","achievement_type").qq|<br>|;
  $str .= qq|subtype:|.htmlcode("textfield","subtype").qq|<br>|;
  $str .= qq|<small>When checking <a href="/node/htmlcode/achievementsByType">achievements by type</a>, achievements of the same subtype are checked in title order only up to the first unachieved one.</small>|;

  $str .= qq|</p>|.htmlcode("listcode","code");
  $str .= qq|<p><small><strong>Edit the code:</strong></small><br>|;
  $str .= htmlcode("textarea","code,30,80");
 
  return $str;
}

sub notification_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<dl><dt>|.parseLinks(qq!Description (used in [Notifications nodelet settings[htmlcode]]).  Changing this may have [canseeNotification[htmlcode]|security implications].!).qq|</dt>|;
  $str .= qq|<dd>$NODE->{description}</dd>|;
  $str .= qq|<dt>Maximum hours this notification is good for (0 will cause it to never display)</dt>|;
  $str .= qq|<dd>$NODE->{hourLimit}</dd>|;
  $str .= qq|<dt>Code to display notification</dt>|;
  $str .= qq|<dd>|.htmlcode("listcode","code").qq|</dd>|;
  $str .= qq|<dt>Code to check for invalid notification</dt>|;
  $str .= qq|<dd>|.htmlcode("listcode","invalid_check").qq|</dd></dl>|;

  return $str;
}

sub notification_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = htmlcode("listcode","code");
  $str .= qq|<p><small><strong>description:</strong></small>|.htmlcode("textfield","description,80").qq|</p>|;
  $str .= qq|<p><small><strong>Time Limit (in Hours):</strong></small> |.htmlcode("textfield","hourLimit").qq|</p>|;
  $str .= qq|<p><small><strong>Edit the code:</strong></small><br />|;
  $str .= htmlcode("textarea","code,30,80");
  $str .= qq|<p><small><strong>Edit the invalidation check:</strong></small><br />|;
  $str .= htmlcode("textarea","invalid_check,30,80");
  $str .= qq|</p>|;
 
  return $str;
}

sub podcast_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str='<p align="right">('.linkNode($NODE, 'display', {'displaytype'=>'display', 'lastnode_id'=>0}).")</p>";

  # This code does the update, if we have one.
  my @params = $query->param;

  foreach my $param (@params)
  {
    if ($param =~ /^update_(\w*)$/)
    {
      $$NODE{$1} = $query->param($param);
    }
  }

  updateNode($NODE, $USER);

  $str.=htmlcode( 'openform' );

  my $field;
  my %titletype;
  my $size = 80;

  $field="title";
  $str .= "$field: ";
  $str .= $query->textfield( -name => "update_$field",
    -default => $$NODE{$field}, -size => $size,
    -maxlength => $1 ) . "<br>\n";

  $field="link";
  $str .= "$field: ";
  $str .= $query->textfield( -name => "update_$field",
    -default => $$NODE{$field}, -size => $size,
    -maxlength => $1 ) . "<br>\n";

  $field="description";
  $str .= "$field: ";
  $str .= $query->textarea( -name => "update_$field",
    -default => $$NODE{$field}, -rows => 20, -columns => $size,
    -maxlength => $1 ) . "<br>\n";

  $field="pubdate";
  $str .= "$field: ";
  $str .= $query->textarea( -name => "update_$field",
    -default => $$NODE{$field}, -rows => 20, -columns => $size,
    -maxlength => $1 ) . "<br>\n";


  $str .= htmlcode( 'closeform' );

  $str .= '
    <hr />
    <b>Add a new recording:</b><br />
    <form method="post">
    <input type="hidden" name="op" value="new">
    <input type="hidden" name="type" value="recording">
    <input type="hidden" name="recording_appears_in" value="'.$$NODE{node_id}.'">
    <input type="hidden" name="displaytype" value="edit">
    <input type="text" size="50" maxlength="64" name="node" value="">
    <input type="submit" value="create">
    </form>
  ';
  return $str;

}

sub recording_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return "You're in the wrong place" unless(canUpdateNode($USER, $NODE));

  my $str='<p align="right">('.linkNode($NODE, 'display', {'displaytype'=>'display', 'lastnode_id'=>0}).")</p>";
  $str.=htmlcode( 'openform' );
  $str.=htmlcode("uploadAudio", "link");

  # This code does the update, if we have one.
  my @params = $query->param;
  my $author_id;
  my $wu_author;
  my $wu_title;

  foreach my $param (@params)
  {
    if ($param =~ /^update_(\w*)$/)
    {
      $$NODE{$1} = $query->param($param);
    }elsif ($param eq 'wu_author'){
      $wu_author=$query->param($param);    
      $author_id=getNode($wu_author, "user")->{node_id};
    }elsif ($param eq 'wu_title'){
      $wu_title=$query->param($param);    
    }elsif ($param eq "read_by"){
      my $reader=getNode($query->param($param), "user")->{node_id};
      if ($reader) {
        $$NODE{read_by}=$reader;
      }else {
        $str.="<p>Reader not found</p>";
      }
    }
  }

  if ($wu_title)
  {
    my $parentNodeId=getNode($wu_title, "e2node")->{node_id};

    $$NODE{recording_of}=$DB->sqlSelect("node_id","node LEFT JOIN writeup ON node.node_id = writeup.writeup_id", "writeup.parent_e2node=$parentNodeId AND node.author_user = $author_id");
  }

  updateNode($NODE, $USER);

  my $field;
  my %titletype;
  my $size = 80;
  my $wu;
  $wu = getNodeById($$NODE{'recording_of'});

  my ($writername, $readername);

  if ($wu) { $writername = getNodeById($$wu{'author_user'}) -> {'title'}; }
  if ($$NODE{'read_by'}) { $readername = getNodeById($$NODE{'read_by'}) -> {'title'};  }

  $str .="<table>";

  $field="title";
  $str .= "<tr><td>$field: </td><td>";
  $str .= $query->textfield( -name => "update_$field",
    -default => $$NODE{$field}, -size => $size,
    -maxlength => $1 ) . "</td></tr>\n";

  $field="link";
  $str .= "<tr><td>$field: </td><td>";
  $str .= $query->textfield( -name => "update_$field",
    -default => $$NODE{$field}, -size => $size,
    -maxlength => $1 ) . "</td></tr>\n";

  $str .= "<tr><td>recording of: </td><td>";
  my $nodeTitle={getNodeById($$wu{parent_e2node}) || {}}->{title};
  $str .= $query->textfield( -name => "wu_title",
    -default => $nodeTitle, -size => $size,
    -maxlength => $1 )."</td></tr>\n";

  $str .= "<tr><td>written by: </td><td>";
  $str .= $query->textfield( -name => "wu_author",
    -default => $writername, -size => $size, 
    -maxlength => $1);
  $str .= "</td></tr>\n";

  $field="read_by";
  $str .= "<tr><td>read by:</td><td>";
  $str .= $query->textfield( -name => "read_by",
    -default => $readername, -size => $size,
    -maxlength => $1 ) . "</td></tr>\n";

  $field="description";
  $str .= "<tr><td>$field: </td><td>";
  $str .= $query->textarea( -name => "update_$field",
    -default => $$NODE{$field}, -rows => 20, -columns => $size,
    -maxlength => $1 ) . "</td></tr>\n";

  $str .= "</table>\n";

  $str .= htmlcode( 'closeform' );

  return $str;

}

sub recording_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $TAGNODE = getNode('approved html tags', 'setting');
  my $TAGS=getVars($TAGNODE);

  my $text = $APP->htmlScreen($$NODE{description}, $TAGS);
  $text = parseLinks($text);

  my $str = "";
  $str.="<h2><a href='$$NODE{link}'>audio file</a></h2>";
  if ($$NODE{recording_of}!=0)
  {
    $str.="<h3>A recording of ".linkNode($$NODE{recording_of})."</h3>";
    $str.="<h4>Written by ".linkNode(getNode($$NODE{recording_of})->{author_user})."</h4>";
  }

  $str.="<h4>Read by ".linkNode($$NODE{read_by})."</h4>";
  $str.="$text";
  $str.='<p align="right">('.linkNode($NODE, 'edit', {'displaytype'=>'edit', 'lastnode_id'=>0}).")</p>" if canUpdateNode($USER, $NODE);
 
  return $str;
}

sub e2poll_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = htmlcode("showpoll");
  $str .= qq|<p align="right" class="morelink">|;
  $str .= parseLinks('[Everything Poll Archive[superdoc]|Past polls]
	| [Everything Poll Directory[superdoc]|Future polls]
	| [Everything Poll Creator[superdoc]|New poll]
	<br> [Polls[by Virgil]|About polls]'); 
  $str .= qq|</p>|;
  return $str;
}

sub choose_theme_view_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # get default stylesheet, user's stylesheet, and the one to test
  my $defaultStyle = getNode($Everything::CONF->default_style,'stylesheet')->{node_id};
  my $currentStyle = $$VARS{userstyle} || $defaultStyle;

  my $theme = $query->param('theme');

  if($theme =~ /^\d+$/)
  {
    my $themenode = getNodeById($theme);
    $theme = "" if($theme and (!$themenode || $themenode->{ type }{ title } ne 'stylesheet'));
  }else{
    $theme = undef;
  }

  $theme ||= getNodeById($currentStyle);

  if ($query->param( 'usetheme' ) and not $APP->isGuest($USER) )
  {
    $$VARS{ userstyle } = $theme  ;
    return "OK" if $query -> param('usetheme') eq 'ajax' ;
  }

  # testdisplay parameter enables testing other displaytypes than display
  my $testdisplay = undef;
  $testdisplay = $query->param( 'testdisplay' ) unless($query->param('testdisplay') and $query->param('testdisplay') eq 'choosetheme');
  $query->delete('displaytype');
  $query->param('displaytype', $testdisplay) if $testdisplay;

  # generate page output with user's current stylesheet
  my $PAGE = Everything::HTML::getPage( $NODE , $testdisplay ) ;
  my $str = parseCode( $$PAGE{ page } , $NODE ) ; #currently, ecore ignores the 2nd argument
  if ( $$PAGE{ parent_container } )
  {
    if(my $container_node = $DB->getNodeById($$PAGE{parent_container}))
    {
      my $delegation = Everything::Delegation::container->can($container_node->{title});
      $str = $delegation->($DB, $query, $Everything::HTML::GNODE, $USER, $VARS, $PAGELOAD, $APP, $str);
    }
  }

  return $str if $query->param('usetheme') or $query->param('cancel');

  # replace current theme with theme to test
  my $themeLink = htmlcode('linkStylesheet', $theme, 'serve');
  $str =~ s!(<link rel="s.*?zensheet.*href=")[^"]*("[^>]*?>)!$1$themeLink$2! if
    $theme ne $currentStyle or $query -> param('autofix');

  # Get list of stylesheets sorted by popularity
  # ============ nearly same code as Theme Nirvana =============
  # only show themes for "active" users (in this case lastseen within 6 months

  my ($sec,$min,$hour,$mday,$mon,$year) = gmtime(time - 15778800); # 365.25*24*3600/2
  my $cutoffDate = ($year+1900).'-'.($mon+1)."-$mday";

  my $rows = $DB->sqlSelectMany( 'setting.setting_id,setting.vars' ,
	'setting,user' ,
	"setting.setting_id=user.user_id 
		AND user.lasttime>='$cutoffDate' 
		AND setting.vars LIKE '%userstyle=%'
		AND setting.vars NOT LIKE '%userstyle=$defaultStyle%'" ) ;

  my $dbrow = undef;
  my %styles = ();

  while($dbrow = $rows->fetchrow_arrayref)
  {
    $$dbrow[1] =~ m/userstyle=([0-9]+)/;
    if (exists($styles{$1}))
    {
      $styles{$1} = $styles{$1}+1;
    }else{
      $styles{$1} = 1;
   }
  }

  my @keys = sort {$styles{$b} <=> $styles{$a}} (keys(%styles)) ;
  unshift( @keys , $defaultStyle ) ;
  # ======== end nearly same code ========

 # add theme to test to menu if it's not already in it
  unshift( @keys , $theme ) unless $styles{ $theme } or $theme eq $defaultStyle ;

  my $widget = '' ;
  if(not $APP->isGuest($USER) )
  {
    foreach ( @keys )
    {
      my $n = getNodeById( $_ );
      next unless $n ;
      $widget .= "<option value=\"$_\"" ;
      $widget .= ' selected="selected"' if $_ eq $theme ;
      $widget .= '>'.$$n{ title } ;
      $widget .= '*' if $_ eq $$VARS{ userstyle } ;
      $widget .= '</option>' ;
    }

    $theme = getNodeById($theme);
    my $banner = "Test a theme:";
    if(defined($theme) and $theme->{type}->{title} eq "stylesheet")
    {
      $banner = "Test theme: <em>$theme->{title}</em>";
    }
    $widget = htmlcode( 'openform' , 'widget' ).
      '<h3 id="widgetheading">'.$banner.'</h3><div>
	<label>Choose a theme:<select name="theme">'.$widget.'</select></label>
	<input type="submit" name="usetheme" value="Use this theme">
	<input type="submit" name="cancel" value="Cancel">
	<br>
	<small>Click on links to test this theme on other pages.
	Bugs to <a href="/user/DonJaime">DonJaime</a>.</small>
	</div>
	</form>' ;
  }

  my $widgetstyle = '
    <style type="text/css">
      html body form#widget {
	position: absolute ;
	position: fixed ;
	top: 5em ; left:5em ;
	z-index: 1000000 ;
	font: 16px sans-serif normal ;
	background: #ffd ;
	color:black;
	border: 1px solid black ;
	padding: 0.25em ;
      }

      html body form#widget > * {
	font: inherit ;
	color: inherit ;
	background: inherit ;
      }

      html body form#widget h3 {
	font-weight: bold ;
	margin: 0 0 0.5em ;
	padding: 0.125em 0.25em ;
	color: #ffd ;
	background: black ;
      }

      html body form#widget small {
	border-top: 1px solid black ;
	display: block ;
	margin-top: 0.5em ;
	font-size: 75% ;
      }
      '. # old IE hack:
      '* html #widget { position: absolute ; }
      </style>' ;

  $str =~ s!(<body.*?>)!$1$widget! ;
  $str =~ s!</head>!$widgetstyle</head>! ;

  my $querystring = '';
  my $currentLink = htmlcode('linkStylesheet', $currentStyle, 'serve').$querystring;

  my $script = qq'<script type="text/javascript">
    var zenSheet = jQuery( "#zensheet" ) ;
    var titletext = jQuery( "#widgetheading em" )[0] ;
    var widget = jQuery("#widget")[0];
    var theme = "$theme->{node_id}" ;
    var currentLink = "$currentLink";

    jQuery( widget.theme ).bind("change", function() {
      theme = this.value ;
      zenSheet.attr( "href" , "/index.pl?node_id=" + theme + "&displaytype=serve$querystring" ) ;
      titletext.nodeValue = this[ this.selectedIndex ].firstChild.nodeValue ;
    });

    widget.usetheme.onclick = function() {
      jQuery.ajax( {url:this.form.action, data: { displaytype: "choosetheme" , usetheme: "ajax" , theme: theme } ,success: cleanup } ) ;
      return false ;
    }

    widget.cancel.onclick = function(){
      zenSheet.attr("href" , currentLink) ;
      cleanup() ;
      return false ;
    }

    function cleanup() {
      document.body.removeChild( widget ) ;
      jQuery("a").unbind(".themetest");
    }

    function changehref(){
 	// leave already changed and external/js links alone
	if (this.savehref || this.getAttribute( "href" ).match( /^\\w+:/ )) return;

	this.savehref = this.href ;

	// rename any displaytype parameter:
	this.href = this.href.replace( /(\\?|&)displaytype=/ , "\$1testdisplay=" ) ;
	// add parameters to existing queries:
	this.href = this.href.replace( /\\?(.*)/ ,
		"?displaytype=choosetheme$querystring&theme=" + theme + "&\$1" ) ;
	// add query if was none
	if ( this.href.match( /\\?/ ) ) return ;
	this.href = this.href.replace( /\$|(#.*)/ , "?displaytype=choosetheme$querystring&theme=" + theme + "\$1" ) ;
    }

    function unchangehref(){
      this.href = this.savehref ;
      delete this.savehref;
    }

    zenSheet.attr( "href" , "/index.pl?node_id=" + theme + "&displaytype=serve$querystring" ) ;
    jQuery("a").bind("focus.themetest click.themetest", changehref).bind("blur.themetest", unchangehref) ;
    jQuery(widget).draggable().css("cursor","move");
    </script>' ;
  $str =~ s!</body>!$script</body>! ;
  return $str;

}

sub registry_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This code does the update, if we have one.
  my @params = $query->param;

  foreach my $param (@params)
  {
    if ($param =~ /^update_(\w*)$/)
    {
      $$NODE{$1} = $query->param($param);
    }
  }

  updateNode($NODE, $USER);

  my $str='<p align="right">('.linkNode($NODE, 'display', {'displaytype'=>'display', 'lastnode_id'=>0}).")</p>";

  $str.= htmlcode("openform");
  $str.= $APP->buildTable(['key','value'],[
    {'key'=>'Title','value'=>
    $query->textfield( -name => "update_title", -default => $$NODE{title}, -size => 40, -maxlength => 255 )},
    {'key'=>'Introduction','value'=>
    $query->textarea( -name => "update_doctext", -default => $$NODE{doctext}, -rows => 7, -columns => 50 )},

    ],'nolabels','center');

  $str.=htmlcode("closeform");

  return $str;
}

sub registry_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = "";

  if($APP->isGuest($USER))
  {
    $str .= '<div style="margin:20px;text-align:center;font-weight:bold;">( back to '.linkNodeTitle('Registry Information').' )</div>';
    $str .= "Registries are only available to logged in users at this time."
  }else{

    $str.= htmlcode('openform')
           .'<div style="margin:20px;text-align:center;">'
           .' (this registry created by '.linkNode($$NODE{author_user}).')'
           .'<div style="margin:20px">'.$APP->breakTags(parseLinks($APP->htmlScreen($$NODE{doctext}))).'</div>'
           .'</div>';
    my $entry = $DB->sqlSelectHashref('data,comments,in_user_profile',
      'registration','from_user='.$$USER{user_id}.' && for_registry='.$$NODE{node_id});

    my $blurb = '';

    my $userdata = $query->param('userdata');
    my $usercomments = $query->param('usercomments');
    my $userprofile = $query->param('userprofile')||'0';
    my $userdelete = $query->param('userdelete');
  
    # they want to DELETE their entry
    if($userdelete)
    {    
      if($DB->sqlDelete('registration', "from_user=$$USER{user_id} && for_registry=$$NODE{node_id}"))
      {
        $blurb.='<br />Your record was removed successfully'
      }else{
        $blurb.='<br />There was a problem removing your record. Please notify a [coder]';
      }
    }else{
      if ($$NODE{input_style} eq 'date' && $userdata)
      {
        my $years=$query->param('years');
        my $months=$query->param('months');
        $months='0'.$months if ($months<10);
        my $days=$query->param('days');
        $days='0'.$days if ($days<10);

        if ($years eq 'secret')
        {
          $userdata="$months-$days";
        } else { 
          $userdata="$years-$months-$days";
        }
      }
      
      # they want to UPDATE their entry
      if($entry && $userdata)
      {
        if($DB->sqlUpdate('registration',{'data'=>$userdata,'comments'=>$usercomments,'in_user_profile'=>$userprofile},
          "from_user=$$USER{user_id} && for_registry=$$NODE{node_id}"))
        {
          $blurb.='<br />Your record was updated successfully';
        }else{
          $blurb.='<br />There was a problem updating your record. Please notify a [coder]';
        }
      }elsif(!$entry && $userdata){   
        # they want to INSERT their entry
        if($DB->sqlInsert('registration',{'data'=>$userdata,
          'comments'=>$usercomments,'from_user'=>$$USER{user_id},
          'for_registry'=>$$NODE{node_id},'in_user_profile'=>$userprofile}))
        {
          $blurb.='<br />Your record was added successfully!';
        }else{
          $blurb.='<br />There was a problem adding your record. Please notify a [coder]';
        }
      }
    }

    ## fetch data again to display and calculate which options user has.
    $entry = $DB->sqlSelectHashref('data,comments,in_user_profile',
      'registration',"from_user=$$USER{user_id} && for_registry=$$NODE{node_id}");
 
    my $input = undef;
    if ($$NODE{input_style} eq 'date')
    {
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
      my @years=('secret');
      for (my $yearCounter=0; $yearCounter<=$year; $yearCounter++)
      {
        push(@years,$yearCounter+1900);
      }
      $input.=$query->popup_menu(-name=>'years',-values => \@years);

      my @months = ();
      for (my $monthCounter=1; $monthCounter<=12; $monthCounter++)
      {
        push(@months,$monthCounter);
      }
      $input.=$query->popup_menu(-name=>'months',-values => \@months);
      # Handy list of month names follows, in case we decide we're keen to implement them
      # my @monthNames=qw(nomonth January February March April May June July August September October November December);
    
      my @days = ();
      for (my $dayCounter=1; $dayCounter<=31; $dayCounter++)
      {
        push (@days, $dayCounter);
      }
    
      $input.=$query->hidden(-name=>'userdata', -value=>'date');
      $input.=$query->popup_menu(-name=>'days',-values => \@days);
    } elsif ($$NODE{input_style}eq'yes/no'){
      $input.=$query->popup_menu(-name=>'userdata',-values => ['Yes', 'No']);
    } else {
      $input=$query->textfield(-name=>'userdata',-default=>$$entry{data}, -size => 40,-maxlength => 255);
    }
  
    $str.= htmlcode('openform').$APP->buildTable(['key','value'],[
     {'key'=>'Your Data','value'=> $input},
     {'key'=>'Comments?<br>(optional)','value'=>
       $query->textarea(-name=>'usercomments',-default=>$$entry{comments},
      	class => 'expandable', onfocus => 'this.maxlength=512;',
	  	-onKeyPress=>"document.getElementById('lengthCounter').innerHTML=this.maxlength-this.value.length+' chars left';",
      -rows => 2,-cols => 40)."<div id='lengthCounter'>512 chars allowed</div>"},
     {'key'=>'Show in your profile?','value'=>
      $query->checkbox('userprofile',$$entry{in_user_profile},1,'yes please!')},
     {'key'=>'&nbsp;','value'=>$query->submit("sexisgood", "submit").
      ((($$entry{data}||$userdata)&&!$userdelete)?
        $query->submit("userdelete", "remove my entry"):'')}],"nolabels")."$blurb</form>";
  
    my $csr = $DB->sqlSelectMany('*','registration',
       "for_registry=$$NODE{node_id}",'ORDER BY tstamp DESC');
     $str.= 'SQL Error (prepare).  Please notify a [coder]' if(not $csr);

    my $labels = ['User','Data','As of','Comments','Profile?'];
    my $rows = [];
    while(my $ref = $csr->fetchrow_hashref())
    {
      my $username=getNode($$ref{from_user})->{title};
      push @$rows,{
        'User'=>linkNode($$ref{from_user})."<a name=\"$username\"></a>",
        'Data'=>$APP->parseAsPlainText($$ref{data}),
        'Comments'=>$APP->parseAsPlainText($$ref{comments}),
        'Profile?'=>['No','Yes']->[$$ref{in_user_profile}],
        'As of'=>$$ref{tstamp}#parseSQLTstamp($$ref{tstamp})
      };
    }
  
    if(scalar(@$rows))
    {
      $str.=$APP->buildTable($labels,$rows,"class='registries'");
    }else{
      $str.= '<div style="text-align:center;font-weight:bold;margin:20px;">
        No users have submitted information to this registry yet.</div>'
    }
  
    $str .= qq|<div style="margin:20px;text-align:center;font-weight:bold;">|;
    $str .= '( '.linkNodeTitle('Recent Registry Entries|What are other people saying?').' )';
    $str .= qq|</div>|;
  }

  return $str;
}

sub ajax_update_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  # This is implemented as an htmlpage/display type so as to go
  # through the usual security checks to access the $NODE
  # htmlcodes called have to be listed here with a definition of
  # valid arguments unless their name begins with ajax or ends with JSON,
  # in which case they are presumed to be written safely

  if ($query -> param('originaldisplaytype'))
  {
    $query->param('displaytype', $query -> param('originaldisplaytype'));
  }else{
    $query->delete('displaytype');
  }

  my $title = '\\w[^\'"<>]*' ;
  my $node_id = '\\d*' ;
  my $anything = '.*' ;
  my $something = '.+' ;

  my %valid = (
    updateNodelet => 	[ $title ], #nodelet name
    nodeletsection =>	[ $title, $title, $title, "($title)?", '\\w*', '\\w*' ], # ($nlAbbrev, $nlSection, $altTitle, $linkTo, $styleTitle, $styleContent)
    ilikeit =>			[ $node_id ],
    coolit => 			[],
    ordernode => 		[],
    favorite_noder =>	[],
    'admin toolset' =>	[],
    nodenote =>			[ $anything ],
    bookmarkit =>		[ $node_id , $title , $title ], #node_id, link text, link title
    weblogform => 		[ $node_id , $anything ], #writeup_id, flag for in writeup
    categoryform => 	[ $node_id , $anything ], #writeup_id, flag for in writeup
    voteit => 			[ $node_id , '\\d\\d?' ], #writeup_id, flag for editor stuff/vote/both
    writeuptools =>		[ $node_id , $anything ], #writeup_id, flag for open widget
    drafttools => 		[ $node_id , $anything ], #writeup_id, flag for open widget
    writeupmessage => 	[ $anything , $node_id ], #parameter name for message, writeup_id
    writeupcools => 	[ $node_id ], #writeup_id
    changeroom => 		[ $title ], #nodelet name
    showmessages =>		[ $node_id , '\\w*' ], #max message number, show options
    testshowmessages =>		[ $node_id , '\\w*' ], #max message number, show options
    showchatter =>		[ $anything ], # flag to send JSON
    displaynltext2 => 	[ $title ], #nodelet name
    movenodelet => 		[ "($node_id|$title)" , $anything ], # bad position is harmless
    setdraftstatus => 	[ $node_id ],
    parentdraft => 		[ $node_id ],
    listnodecategories 		=>[ $node_id ],
    zenDisplayUserInfo		=>[],
    messageBox				=>[ $node_id, $anything, $title, $node_id ],
    confirmDeleteMessage	=>[ $node_id, $title ],
    nodeletsettingswidget	=>[ $title, $title ], #nodelet name, link text
    homenodeinfectedinfo	=> [],
    "user searcher"		=> [ $something ],
  );

  my @args = ();
  my $str = "";
  my $flagComplete = undef;
  @args = split ',', $query->param('args');
  $flagComplete = '<!-- AJAX OK -->'; # let client distinguish empty/partial/failure

  my $htmlcode = $query->param('htmlcode') ;
  return unless $htmlcode ;
  my $test = $valid{$htmlcode};

  unless ($test)
  {
    $str = 'unauthorised htmlcode' unless $htmlcode =~ /^ajax|JSON$/; # these carry out their own checks if needed
  } else {
    my $i = 0 ;
    my @test = @$test ;
    foreach (@args)
    {
      $str .= "argument $i invalid<br>" unless $_ =~ /^$test[$i]$/s ;
      $i++ ;
    }
  }

  unless ( $str )
  {
    $str = htmlcode($htmlcode, @args) ;
  } else {
    if ( Everything::isApproved( $USER , getNode('edev', 'usergroup') ) )
    {
      $str = $APP->parseLinks("[ajax update page[htmlpage]]: error running htmlcode [${htmlcode}[htmlcode]]<br>$str");
    } elsif ( $APP->isEditor($USER) ) {
      $str = 'ajax htmlcode/argument error' ;
    } else {
      $str = 'code error' ;
    }
  
    $str = qq'<span class="error">$str</span>'; # needs to be wrapped in case it replaces something
  }

  return $str.$flagComplete unless $query->http('accept') =~ /\bjson\b/i;
  $str = [ $str ] if ref $str eq "";
  return to_json($str);

}

sub mysqlproc_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<br /><b>CREATE PROCEDURE $NODE->{title}($NODE->{parameters} )</b><br /><b>BEGIN</b><br />|;
  $str .= qq|<pre>$NODE->{doctext}</pre><b>END</b><br />|;

  return $str;
}

sub node_editvars_page
{
  return htmlcode("editvars");
}

sub node_listnodelets_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '' if $APP->isGuest($USER);

  my $str = qq|<table><tr><td>|;
  $str .= htmlcode("zensearchform");
  $str .= qq|</td></tr></table><div class="nodelet"><div class="nodelet_title">Nodelets</div>|;

  # Duplicated wholesale from [nodelet meta-container]. This should be refactored,
  # probably much the way it is in pre-1.0
  #

  unless ( $$VARS{nodelets} ) {
    #push default nodelets on
    $VARS->{nodelets} = join(',',@{$Everything::CONF->default_nodelets});
  }

  my $required = getNode('Master Control', 'nodelet') -> { node_id } ;
  if( $APP->isEditor($USER) )
  {
    # If Master Control is not in the list of nodelets, add it right at the beginning. 
    $$VARS{ nodelets } = "$required,".$$VARS{ nodelets } unless $$VARS{ nodelets } =~ /\b$required\b/ ;
  }else{
    # Otherwise, if it is there, remove it, keeping a comma as required
    $$VARS{nodelets} =~ s/(,?)$required(,?)/$1 && $2 ? ",":""/ge;
  }

  my $nodelets = $PAGELOAD->{pagenodelets} || $$VARS{nodelets} ;
  my @nodelets = ();
  @nodelets = split(',',$nodelets) if $nodelets ;

  my $n = 1;
  $str .= qq|<table width="100%">|; 

  $str .= ( join '', map {
    my $current_nodelet = getNode($_);
    $n = 1 - $n;
    my $row = undef;
    if ($n) {
      $row = '<tr class="oddrow"><td>';
    } else {
      $row = '<tr class="evenrow"><td>';
    }
    $row .= linkNode($NODE, $current_nodelet->{title},
                   { displaytype => 'shownodelet',
                     nodelet_id => $_}).'</t></tr>';
    } @nodelets); 
  $str .= '</table></div>';

  return $str;
}

sub node_shownodelet_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return '' if $APP->isGuest($USER);

  my $nodelet_id = $query->param('nodelet_id');
  my $current_nodelet = getNode($nodelet_id);
  if (!$current_nodelet) {
    return 'no nodelet to show';
  }

  my $nl = insertNodelet($current_nodelet);

  # Nasty hack: if a nodelet links back to the same node preserving
  # the displaytype, the 'shownodelet' display type will be
  # meaningless without the nodelet_id to show. So reinsert it
  # anywhere within a tag.
  $nl =~ s/(<[^>]*\bdisplaytype=shownodelet\b)/$1&nodelet_id=$nodelet_id/g;
  # Also insert a hidden 'nodelet_id' next to any input that sets a displaytype of 'shownodelet'.
  $nl =~ s{
    (<input\b[^>]*\bname=(|'|")displaytype(|'|")[^>]*value=(|'|")shownodelet(|'|")
    | <input\b[^>]*\bvalue=(|'|")shownodelet(|'|")[^>]*\bname=(|'|")displaytype(|'|"))
  }{<INPUT TYPE="hidden" NAME="nodelet_id" VALUE="$nodelet_id" />$1}gxi;

  return $nl;
}

sub stylesheet_serve_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  if ($query->param('version'))
  {
    # Set a far-future expiry time if a specific version is requested.
    $Everything::HTML::HEADER_PARAMS{'-expires'} = '+10y';
  }

  my $out = $$NODE{doctext};
  $out =~ s/^\s+//mg;
  $out .= "/* SOFTLINK COLORS */\n";

  my $styleRule = '\\b\\s*(?:,[^{]*)?{[^}]*background[^;}]*#(?:(\\w\\w)(\\w\\w)(\\w\\w)|(\\w)(\\w)(\\w))';
  my @max = ( 255, 255, 255 ) ;
  my @min = ( 170, 170, 170 ) ;
  @max = (hex($1||$4.$4),hex($2||$5.$5),hex($3||$6.$6)) if $out =~ /#sl1$styleRule/ || $out =~ /#mainbody$styleRule/ || $out =~ /\bbody$styleRule/ ;
  @min = (hex($1||$4.$4),hex($2||$5.$5),hex($3||$6.$6)) if $out =~ /#sl64$styleRule/ || $out =~ /\.slend$styleRule/ || $out =~ /\.oddrow$styleRule/ ;

  for (my $i=64; $i; $i--)
  {
    $out .= "td#sl$i\{background:#".( join '' , ( map {sprintf( '%02x', int($max[$_]-($i-1)*($max[$_]-$min[$_])/63) )} (0..2) ) ).';}';
    $out .= "\n" if $i % 4 == 1 ;
  }

  return $out;
}

sub draft_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  return htmlcode("display draft","display");
}

sub draft_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  if(!$APP->canSeeDraft($USER, $NODE))
  {
    return;
  }

  my $str = undef;
  my $nukedraft = $query->param('nukedraft');
  $nukedraft = "" if not defined($nukedraft);

  if ($nukedraft eq 'Delete draft' && htmlcode('verifyRequest', 'nukedraft'))
  {
    my @fields = $DB -> getFieldsHash('draft', 0);
    my $linktype = getId(getNode 'parent_node', 'linktype');
    my $parent = $DB -> sqlSelect(
      'to_node', 'links', "from_node=$$NODE{node_id} AND linktype=$linktype");
    
    $str = '<p><strong>Draft permanently deleted</strong></p>'.htmlcode('openform')
      .'<input type="hidden" name="op" value="new">'
      .$query -> hidden('type', 'draft')
      .$query -> hidden('node', $$NODE{title})
      .$query -> hidden('draft_doctext', $$NODE{doctext})
      .$query -> hidden('writeup_parent_e2node', $parent)
      .join ("\n", map {$_ ne 'draft_id' && $query -> hidden("draft_$_", $$NODE{$_})} @fields)
      .htmlcode('closeform', 'Undo')
      .$query -> small('(create a new draft with the same content and status as the one you just deleted, using information stored in this page on your browser.)')
      .$query -> hr()
      .$query -> h2('What next?')

      .$query -> h3('Write:')
      .$query -> ul($query -> li(linkNodeTitle('Drafts[superdoc]|Your other drafts'))
      .$query -> li($query -> h4('Pages thirsting for content')
      .$query -> ul($query -> li(linkNodeTitle('Your nodeshells[superdoc]|Created by you'))
      .$query -> li(linkNodeTitle('Random nodeshells[superdoc]|Created by anyone')))))
      .$query -> h3('Read:')
      .$query -> ul($query -> li($query -> h4('Cool inspiration').htmlcode('frontpage_cooluserpicks'))
      .$query -> li($query -> h4('What Inspired the Editors').htmlcode('frontpage_staffpicks')));

      $DB->nukeNode($NODE, -1, 1); # no user check, gone forever

      return $str;
  }

  if (($$NODE{author_user} != $$USER{node_id}) and ($query->param('draft_title') or $query -> param('draft_doctext')) and
    $APP->canSeeDraft($USER, $NODE, 'edit'))
  {
    my ($tt, $tx) = (undef, undef);
    $$NODE{title} = $tt if $tt = $query -> param('draft_title');
    $$NODE{doctext} = $tx if $tx = $query -> param('draft_doctext');	
    updateNode($NODE, -1);
  }

  $str = htmlcode('display draft');

  if ($$USER{node_id} == $$NODE{author_user})
  {
    $str .= htmlcode('setdraftstatus', $NODE).htmlcode('openform')
      .htmlcode('verifyRequestForm', 'nukedraft')
      .'<br><input type="submit" name="confirmop" value="Delete draft" title="delete this draft">
        <input type="hidden" name="notanop" value="nukedraft"></form>';

  }elsif($APP->isEditor($USER)){
    my $status = getNodeById($$NODE{publication_status}) -> {title};
    if ($status eq 'review' && $APP->canSeeDraft($USER, $NODE, 'find') )
    {
      # let editors see the HTML
      $str .= '<form class="writeup_add"><fieldset><legend>HTML source (not editable)</legend>
        <textarea id="writeup_doctext" class="readonly"'.htmlcode('customtextarea', '1').'>'
        .$APP->encodeHTML($$NODE{doctext})
        .'</textarea></fieldset></form>';
    }elsif($status eq 'removed'){
      # let editors restore if removed by mistake
      if ($query -> param('parentdraft'))
      {
        $str .= htmlcode('parentdraft', $NODE);
      }else{
        $str .= $query -> div({-id => 'republish'},'');
      }
    }
  }

  return $str;
}

sub draft_linkview_page
{
  return htmlcode("display draft");
}

sub mysqlproc_edit_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<H4>title:</H4>|.htmlcode("textfield","title");
  $str .= qq|<h4>parameters:|.htmlcode("textfield","parameters,60");
  $str .= qq|<h4>owner:</h4>|.htmlcode("node_menu","author_user,user,usergroup");
  $str .= qq|<p><small><strong>Edit the mysql procedure code:</strong></small><br />|;
  $str .= qq|<br /><br /><em>|.htmlcode("mysqlproctest").qq|</em>|;
  $str .= htmlcode("textarea","doctext,30,60");

  return $str;
}

sub draft_restore_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = undef;

  if ($query -> param('nukedraft') eq 'Delete draft' && htmlcode('verifyRequest', 'nukedraft'))
  {
    my @fields = $DB -> getFieldsHash('draft', 0);
    my $linktype = getId(getNode 'parent_node', 'linktype');
    my $parent = $DB -> sqlSelect(
      'to_node', 'links', "from_node=$$NODE{node_id} AND linktype=$linktype");

    $str = '<p><strong>Draft permanently deleted</strong></p>'.htmlcode('openform')
      .'<input type="hidden" name="op" value="new">'
      .$query -> hidden('type', 'draft')
      .$query -> hidden('node', $$NODE{title})
      .$query -> hidden('draft_doctext', $$NODE{doctext})
      .$query -> hidden('writeup_parent_e2node', $parent)
      .join ("\n", map {$_ ne 'draft_id' && $query -> hidden("draft_$_", $$NODE{$_})} @fields)
      .htmlcode('closeform', 'Undo')
      .$query -> small('(create a new draft with the same content and status as the one you just deleted,
        using information stored in this page on your browser.)')
      .$query -> hr()
      .$query -> h2('What next?')
      .$query -> h3('Write:')
      .$query -> ul($query -> li(linkNodeTitle('Drafts[superdoc]|Your other drafts'))
      .$query -> li($query -> h4('Pages thirsting for content')
      .$query -> ul($query -> li(linkNodeTitle('Your nodeshells[superdoc]|Created by you'))
      .$query -> li(linkNodeTitle('Random nodeshells[superdoc]|Created by anyone')))))
      .$query -> h3('Read:')
      .$query -> ul($query -> li($query -> h4('Cool inspiration')
      .htmlcode('frontpage_cooluserpicks'))
      .$query -> li($query -> h4('What Inspired the Editors').htmlcode('frontpage_staffpicks')));
      
      $DB->nukeNode($NODE, -1, 1); # no user check, gone forever
      return $str;
  }

  if (($$NODE{author_user} != $$USER{node_id}) and
	($query -> param('draft_title') or $query -> param('draft_doctext')) and
	$APP->canSeeDraft($USER, $NODE, 'edit'))
  {
    my ($tt, $tx) = (undef, undef);
    $$NODE{title} = $tt if $tt = $query -> param('draft_title');
    $$NODE{doctext} = $tx if $tx = $query -> param('draft_doctext');
	
    updateNode($NODE, -1);
  }

  $str = htmlcode('display draft');

  if ($$USER{node_id} == $$NODE{author_user})
  {
    $str .= htmlcode('setdraftstatus', $NODE)
      .htmlcode('openform')
      .htmlcode('verifyRequestForm', 'nukedraft')
      .'<br><input type="submit" name="confirmop" value="Delete draft" title="delete this draft"><input type="hidden" name="notanop" value="nukedraft"></form>';

  }elsif($APP->isEditor($USER)){
    my $status = getNodeById($$NODE{publication_status}) -> {title};

    if ($status eq 'review' && !$APP->canSeeDraft($USER, $NODE, 'edit'))
    {
      # let editors see the HTML
      $str .= '<form class="writeup_add"><fieldset><legend>HTML source (not editable)</legend>
        <textarea id="writeup_doctext" class="readonly"'
        .htmlcode('customtextarea', '1')
        .'>'
        .$APP->encodeHTML($$NODE{doctext})
        .'</textarea></fieldset></form>';
    }elsif($status eq 'removed'){
      # let editors restore if removed by mistake
      if ($query -> param('parentdraft'))
      {
        $str .= htmlcode('parentdraft', $NODE);
      }else{
        $str .= $query -> div({-id => 'republish'},'');
      }
    }
  }

  return $str;
}

1;
