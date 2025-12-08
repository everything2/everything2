package Everything::Delegation::container;

use strict;
use warnings;

BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getVars = *Everything::HTML::getVars;
  *getId = *Everything::HTML::getId;
  *htmlcode = *Everything::HTML::htmlcode;
}

sub zen_stdcontainer
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $contained_stuff = shift;
  $contained_stuff ||= '';

  my $str = undef;
  $str = qq|<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta http-equiv="X-UA-Compatible" content="IE=Edge" />
<title>|.$APP->pagetitle($NODE).qq| - Everything2.com</title>
<link rel="stylesheet" id="basesheet" type="text/css" href="|.htmlcode("linkStylesheet","basesheet").qq|" media="all"><link rel="stylesheet" id="zensheet" type="text/css" href="|
. htmlcode('linkStylesheet', $APP->get_user_style($USER), 'serve')
. '" media="screen,tv,projection">' ;

  if (exists(($$VARS{customstyle})) && defined(($$VARS{customstyle}))) {
	$str .= qq|<style type="text/css">|.$APP->htmlScreen($$VARS{customstyle}).'</style>';
  }

  $str .= qq|<link rel="stylesheet" id="printsheet" type="text/css" href="|.htmlcode("linkStylesheet","print").qq|" media="print">|;
  if ($ENV{HTTP_HOST} !~ /^m\.everything2/i) {
    $str .= qq|<base href="|.$APP->basehref().qq|">| if $APP->isGuest($USER);
  }

  my $canonical_web_server = $Everything::CONF->canonical_web_server;
  my $url = "";
  $url = ($APP->is_tls()?('https'):('http')).'://'.$canonical_web_server if $APP->isGuest($USER);
  $url .= $APP->urlGenNoParams( $NODE , 'noQuotes' ) unless $$NODE{ node_id } eq $Everything::CONF->default_node ;
  $url .= "http://localhost:9080" if $APP->inDevEnvironment();
  $url ||= '/' ;
  $str .= '<link rel="canonical" href="' . $url . '">' ;

  my $no='';
  if($$NODE{type}{title} eq 'e2node'
	|| ($$NODE{type}{title} eq 'superdoc'
		and ($$NODE{title} eq 'Findings:' or $$NODE{title} eq 'Nothing Found'))
	|| ($$NODE{type}{title} eq 'user'
		and $APP -> getLevel($NODE)==0 and $no='no'))
  {
    unless($$NODE{group} and int( @{ $$NODE{group} }))
    {
      $str.= qq|<meta name="robots" content="noindex, ${no}follow">|;
    }
  }

  $str .= htmlcode("metadescriptiontag");
  $str .= qq|<link rel="icon" href="|.$APP->asset_uri("static/favicon.ico").qq|" type="image/vnd.microsoft.icon">
	<!--[if lt IE 8]><link rel="shortcut icon" href="|.$APP->asset_uri("static/favicon.ico").qq|" type="image/x-icon"><![endif]-->|;

  if ($$NODE{title} eq "Cool Archive") {
    $str.= '<link rel="alternate" type="application/atom+xml" title="Everything2 Cool Archive" href="/node/ticker/Cool+Archive+Atom+Feed'
	. ( $query->param('cooluser') ? '?foruser='.$query->param('cooluser') : '' ) . '">';
  } else {
    $str.= '<link rel="alternate" type="application/atom+xml" title="Everything2 New Writeups" href="/node/ticker/New+Writeups+Atom+Feed'
	. ( $$NODE{type_nodetype}==15 ? '?foruser='.$$NODE{title} : '' ) . '">';
  }
  
  # Google Analytics 4
  $str .= qq|<script async src="https://www.googletagmanager.com/gtag/js?id=G-2GBBBF9ZDK"></script>|;

  $str .= qq|</head><body class="|;
  $str .= 'writeuppage ' if $$NODE{e2node_id} || $$NODE{writeup_id} || $$NODE{draft_id};
  $str .= $$NODE{type}{title};
  if($$NODE{type}{title} =~ /superdoc/)
  {
    #superdocs and variants further identified by title
    my $id = ( $$NODE{ node_id } != 124 ? lc( $$NODE{ 'title' } ) : 'frontpage' ) ;
    $id =~ s/\W//g ;
    $str.='" id="'.$id ;
  }
  $str .= qq|" itemscope itemtype="http://schema.org/WebPage">|;

  $str .= $contained_stuff;

  $str .= htmlcode("static javascript");
  $str .= qq|</body></html>|;
  return $str;
}

sub zen_container
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $contained_stuff = shift;
  $contained_stuff ||= "";  
  my $str = undef;
  
  $str .= htmlcode("zenadheader");
 
  $str .= qq|<div id='header'>|;

  my $epid = getNode('Epicenter','nodelet')->{node_id};
  $str .= (htmlcode('epicenterZen') || "") if $$VARS{nodelets} && $$VARS{nodelets} !~ /\b$epid\b/;
 
  $str.= qq|<div id='searchform'>|.htmlcode("zensearchform").qq|</div>|;

  $str.=qq|<div id='e2logo'><a href="/">Everything<span id="e2logo2">2</span></a></div></div>|;

  $str.=qq|<div id='wrapper'>|;

  $str.=qq|<div id='mainbody' itemprop="mainContentOfPage"><!-- google_ad_section_start -->|;
  $str.=htmlcode("page header");
  $str.=qq|$contained_stuff<!-- google_ad_section_end --></div>|;

  $str.=qq|<div id='sidebar'|;
  $str.=' class="pagenodelets"' if $PAGELOAD->{pagenodelets};
  $str.='>';

  $str.=qq|<div id='e2-react-root'></div>|;
  $str.=qq|</div><!-- end sidebar --></div><div id='footer'>|;

  $str.=htmlcode("zenFooter");
  $str.=qq|</div></div>|;

  return zen_stdcontainer($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP, $str); 
}

sub formcontainer
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $contained_stuff = shift;
  $contained_stuff ||= "";  
  
  my $str = "";
  
  $str.= $query->start_form(-method=>'POST', action=>$ENV{script_name}, name=>'pagebody', id=>'pagebody') .
    $query->hidden('displaytype') .
    $query->hidden('node_id', getId($NODE));

  if ($NODE && $$NODE{type} && $query->param('displaytype') eq 'edit') {
    my $type = $$NODE{type}{title};
    $str.=htmlcode('verifyRequestForm', "edit_$type");
  } 

  $str.=$contained_stuff;

  $str.=$query->submit('sexisgood', 'stumbit') .
    $query->end_form;

  return zen_container($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP, $str);
}

sub atom_container
{
  my $DB = shift;
  my $query = shift;
  my $NODE = shift;
  my $USER = shift;
  my $VARS = shift;
  my $PAGELOAD = shift;
  my $APP = shift;

  my $contained_stuff = shift;
  $contained_stuff ||= "";  

  my $str = qq|
<?xml version="1.0" encoding="UTF-8" ?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:base="http://everything2.com/">|;
  $str .= "<title>" . $$NODE{title} ."</title>\n";
  $str .= "    <link rel=\"alternate\" type=\"text/html\" href=\"http://everything2.com/?node=25\" />\n";
  $str .= "    <link rel=\"self\" type=\"application/atom+xml\" href=\"?node_id= " . $$NODE{node_id} . "&amp;displaytype=atom\" />\n";
  $str .= "    <id>http://everything2.com/?node_id=" . $$NODE{node_id} . "</id>\n";
  $str .= "    <updated>";
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
  $str .= sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", $year + 1900, $mon + 1, $mday, $hour, $min, $sec);
  $str .= "</updated>\n";
  $str .= $contained_stuff;
  $str .= qq|</feed>|;
 
  return $str;
}

1;
