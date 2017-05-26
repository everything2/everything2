package Everything::Delegation::htmlpage;

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
    #'chosen_type'=>$$NODE{title},
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

1;
