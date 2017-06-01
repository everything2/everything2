package Everything::Delegation::htmlpage;

use strict;
use warnings;

# Used by writeup_xml_page, e2node_xml_page
use Everything::XML;

# Used by room_display_page
use POSIX qw(ceil floor);

# Used by collaboration_display_page, collaboration_useredit_page
use POSIX qw(strftime);

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
  *evalCode = *Everything::HTML::evalCode;
  *getPageForType = *Everything::HTML::getPageForType;
  *opLogin = *Everything::HTML::opLogin;
  *replaceNodegroup = *Everything::HTML::replaceNodegroup;
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

  my $str = "";
  $str .= qq|parent container: |;

  if($NODE->{parent_container})
  {
    $str .= linkNode ($$NODE{parent_container}) if $$NODE{parent_container};
  }else{
    $str .= "<i>none</i>"; 
  }

  $str .= htmlcode("listcode","content");

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

  my $str = qq|<H4>title:</H4>|.htmlcode("textfield","title");
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

  return htmlcode("listcode","code");
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
  
  if($APP->isAdmin($USER) and $NODE->{type}->{title} eq "patch")
  {
    if($query->param("op") eq "applypatch")
    {
      $str .= linkNode($NODE, "Apply this patch", {"op" => "applypatch", "patch_id" => "$$NODE{node_id}"})."<Br>";
    }else{
      $str .= "<font color=\"red\">The patch has been applied</font> ".linkNode($NODE, "Unapply", {"op" => "applypatch", "patch_id" => "$$NODE{node_id}"})."<br />";
    }
  }

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
  $str .= qq|<TR bgcolor="|.($$VARS{mailhead_color} or "#CCCCCC").qq|"><TH>To:</TH><TD width=100%>|;
  $str .= linkNode($$NODE{author_user}).qq|<TD></TR><TR bgcolor="|.($$VARS{mailhead_color} or "#CCCCCC");
  $str .= qq|"><TH>From:</TH></TH><TD width=100%>|;

  if(not $$NODE{from_address})
  {
    $str .= "<i>nobody</i>";
  } else {
    $str .= $$NODE{from_address};
  }

  $str .= qq|</TD></TR></TABLE>|;
  $str .= htmlcode("parseLinks","doctext");

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

    $str .= htmlcode('showuserimage','1');
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
  return htmlcode("parsecode","doctext");
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

  $str .= htmlcode("openform");
 
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
  $str .= qq|<p align="center" style="border: solid black 2px; background: #ffa; color: black; spacing: 2px; padding: 5px;"><big><strong>Danger! This is editing the code with no undo function! <em>Please use patches to edit code, it drives us nuts when you don't. Ideally, put the patches on the development server.</em></strong></big></p>|;

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

  my $out = htmlcode("parsecode","doctext");
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

  if((eval {$$NODE{criteria}}) and not $APP->isGuest($USER))
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

  $str .= $PAGELOAD->{admintools};

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
  $str .= htmlcode("votehead");
  $str .= htmlcode("show writeups");

  $str .= qq|<div id='displaytypelinks'>|;
  
  unless($APP->isGuest($USER))
  {
    $str .= qq|<p>|.linkNode($NODE, 'link view', { displaytype => 'linkview' } ).qq|</p>|;
  }

  $str .= qq|</div>|;

  $str .= htmlcode("votefoot");

  $str .= htmlcode("writeuphints");

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
  my $ugOwner = $APP -> getParameter($NODE, 'usergroup_owner');

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
  return htmlcode("parsecode","doctext",1);
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

sub patch_display_page
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $str = qq|<p>Back to |.linkNodeTitle("patch manager").qq|</p>|;
  $str .= qq|<p align="right">|;

  my $status = getNodeById($NODE->{cur_status});

  my $caneditpatch = ($APP->isAdmin($USER) || $$NODE{author_user} == $$USER{user_id});

  if($APP->isAdmin($USER))
  {
    if($status->{applied})
    {
      $str.= "<font color=\"red\">The patch has been applied</font>".
        linkNode($NODE, "Unapply", 
               {"op" => "applypatch", 
                "patch_id" => "$$NODE{node_id}",
                "displaytype" => "edit"})."<br>";
    }else{
      $str .= linkNode($NODE, "Apply this patch", 
                    {"op" => "applypatch",
                     "patch_id" => "$$NODE{node_id}"})
                     ."<br>" unless $status -> {applied};
    }
  }

  if($caneditpatch and not $status->{applied})
  {
    $str .= linkNode($NODE, 'edit',
                {'displaytype'=>'edit',
                 'lastnode_id'=>0});
  }

  $str .= qq|</p>|;

  if($caneditpatch)
  {
    $str.= htmlcode('openform').qq|<br>|;
  }

  $str .= qq|<p>|.linkNode($$NODE{author_user},0,{lastnode_id=>0}).qq|submitted a patch for|; 

  my $patchee = getNodeById($$NODE{for_node});
  my $patchee_text = '';
  if($patchee)
  {
    $patchee_text = linkNode($$NODE{for_node},0,{lastnode_id=>0});
  } else {
    $patchee_text = "missing node $$NODE{for_node}";
  }

  $str .= $patchee_text.qq|'s "<code>["$$NODE{field}"]</code>" field on |.htmlcode('parsetime','createtime');
  $str .= qq|<br>patch's purpose: |;
  if($caneditpatch)
  {
    $str .= htmlcode( 'textfield' , 'purpose', 80, 'expandable' );
  }else{
    $str .= ( $$NODE{purpose} ? $APP->htmlScreen($$NODE{purpose},0) : '<em>unknown</em>' );
  }

  $str .= qq|<br><strong>Additional instructions</strong> for bringing it live: |;
  
  if($caneditpatch)
  {
    $str .= htmlcode( 'textfield' , 'instructions', 80, 'expandable' );
  }else{
    $str .= ( $$NODE{instructions} ? $APP->htmlScreen($$NODE{instructions},0) : '<em>none</em>' );
  }

  $str .= qq|<br>status:|;

  htmlcode('settype', ',status,cur_status,node_id,' . ($APP->isAdmin($USER)?1:0) );

  $str .= qq|<br>assigned to: |;

  my $assignedstr = " ".htmlcode('assign_patch',$NODE->{node_id});
  $assignedstr=($$NODE{assigned_to} ? linkNode($$NODE{assigned_to}) : '<em>nobody</em>') . $assignedstr;

  $assignedstr.= '<p><a href="https://everything2.com/node/superdoc/Patch+importer?patch_action=review&patch_id='.$$NODE{node_id}.'">Review and import patch</a></p>' if $status -> {title}eq"production-ready";   

  $str .= $assignedstr;

  $str .= qq|</p>|;

  if($caneditpatch)
  {

    if($query->param('sexisgood'))
    {

      if ( $APP->isAdmin($USER) )
      {
	  #Changing the status of a patch assigns it to the person who changes
	  #it, except for "assigned" status.
	  my $newstat = $query -> param("setfield_cur_status_$$NODE{node_id}");
	  my $curstat = $$NODE{cur_status};
	  my $assigned_stat = getNode("assigned","status") -> {node_id};
	
	  if($newstat != $curstat && $newstat != $assigned_stat){
	    $$NODE{assigned_to} = $$USER{user_id};
	  }
	
	  #If not assigned to anyone, it defaults to the person choosing the
	  #assigned status.
	  my $assigned_to = $query -> param("setfield_assigned_to_$$NODE{node_id}");
	  if($newstat == $assigned_stat && !$assigned_to){
	    $$NODE{assigned_to} = $$USER{user_id};
	  }
      }
      $$NODE{ purpose } = $query -> param( 'patch_purpose' ) || $$NODE{ purpose } ;
      $$NODE{ instructions } = $query -> param( 'patch_instructions' ) || $$NODE{ instructions } ;
      updateNode($NODE,-1);
    }
    $str .= htmlcode('closeform','');
  }

  $str .= qq|<p style="border:solid black 1px; padding:5px;">Talk to people related to this patch:|;

  $str .= htmlcode("openform");

  my %whoRelated = (
    'author' => $$NODE{author_user},
    'assigned' => $$NODE{assigned_to},
  );

  my $w = undef;
  
  foreach(sort(keys(%whoRelated)))
  {
    next unless (exists $whoRelated{$_}) && (defined $whoRelated{$_}) && length($w=$whoRelated{$_}) && $w;
    $str .=  htmlcode('msgField', 'patch' . $$NODE{node_id} . '_' . $_ . '_' . $w . ',,' . $$NODE{node_id} . ',' . $w) . ' ' . $_ . ', ' . linkNode($w,0,{lastnode_id=>0}) . "<br />\n";
  }

  $str .= htmlcode("msgField").qq|<br />|;
  $str .= htmlcode("closeform");

  $str .= qq|</p>|;

  my $patchedNode = $$NODE{for_node};
  my $patchCreateTime = $$NODE{createtime};
  # When there's a more recent patch to the current node, it's more helpful
  #  to diff against that, so we see just what this individual patch was
  #  intended to do.
  my $patchSearch = "
    SELECT patch.patch_id
    FROM patch
    JOIN node
      ON patch_id = node.node_id
    JOIN status
      ON patch.cur_status = status.status_id
    WHERE patch.for_node = ?
      AND node.createtime > ?
      AND status.applied = 1
    ORDER BY node.createtime ASC
    LIMIT 1";

  my $nextPatch = $DB->getDatabaseHandle()->selectrow_array(
    $patchSearch
    , {}
    , ( $patchedNode, $patchCreateTime ));

  my $diffNode = undef;
  my $codeOrig = undef;

  if ($nextPatch)
  {
    $diffNode = getNodeById($nextPatch);
    $codeOrig = $$diffNode{code};
  } else {
    $diffNode = getNodeById($$NODE{for_node});
    $codeOrig = $$diffNode{$$NODE{field}};
  }

  my $codeNew = $NODE->{code};

  #Don't show applied/production-ready patches as reversed
  if($status -> {applied})
  {
    ($codeNew,$codeOrig) = ($codeOrig,$codeNew);
  }

  my $compareLink = linkNode($diffNode);
  my $shortDiff   = $APP->showPartialDiff($codeOrig,  $codeNew);
  my $longDiff    = $APP->showCompleteDiff($codeOrig, $codeNew);

  $str .= qq|<p>Diffing against $compareLink</p><hr><p>Just the changes: <br><br></p>|;
  $str .= qq|<pre>$shortDiff</pre><p>The complete diff:<br><br></p><pre>$longDiff</pre>|;

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

  my $str = "";
  $str.= qq|<object type="application/x-shockwave-flash" data="http://static.everything2.com/player_mp3_maxi.swf" width="300" height="20"><param name="movie" value="http://static.everything2.com/player_mp3_maxi.swf" /><param name="bgcolor" value="#ffffff" /><param name="FlashVars" value="mp3=$$NODE{link}&amp;width=300&amp;autoload=0&amp;volume=50&amp;showstop=1&amp;showinfo=1&amp;showvolume=1" /></object><h2><a href='$$NODE{link}'>download mp3</a></h2>|;
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

1;
