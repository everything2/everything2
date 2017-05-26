package Everything::Delegation::htmlpage;

use strict;
use warnings;

# Used by writeup_xml_page
use Everything::XML;

# Used by room display page
use POSIX qw(ceil floor);

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
        my $qh = $DB->{dbh}->prepare('SELECT COUNT(*) FROM ' . $$NODE{title});

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
    $query->delete_all() if (grep(/^update_/, $query->Vars));
  }else{

    # This code does the update, if we have one.
    my $param = undef;
    my @params = $query->param;

    foreach $param (@params)
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
  my $table = undef;
  my $field = undef;
  my %titletype = ();

  $str .= htmlcode('verifyRequestForm', "basicedit_$type");

  push @$tables, 'node';
  foreach $table (@$tables)
  {
    @fields = $DB->getFieldsHash($table);

    foreach $field (@fields)
    {
      $titletype{$$field{Field}} = $$field{Type};
    }
  }

  pop @$tables;

  foreach $field (keys %titletype)
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

  if(eval($$NODE{criteria}) and !$APP->isGuest($USER))
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

    if ( my $count = scalar @{ $PAGELOAD->{notshown}->{lowrep} } )
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

    if (my $count = scalar @{ $PAGELOAD->{notshown}->{unpublished} })
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

    if ( my $count = scalar @{ $PAGELOAD->{notshown}->{unfavorite} } )
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
    $str .= linkNode($NODE, 'printable version', { displaytype => 'printable' , lastnode_id => '0', -rel => 'nofollow' } );
    $str .= qq|</p>|;

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

1;
