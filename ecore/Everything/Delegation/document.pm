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
  *evalCode = *Everything::HTML::evalCode;
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

1;
