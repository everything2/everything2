package Everything::Delegation::htmlpage;

use strict;
use warnings;

# Used by room_display_page
use POSIX qw(ceil floor);

# Used by collaboration_display_page, collaboration_useredit_page
use POSIX qw(strftime);

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
  *parseLinks = *Everything::HTML::parseLinks;
  *isNodetype = *Everything::HTML::isNodetype;
  *isGod = *Everything::HTML::isGod;
  *getRef = *Everything::HTML::getRef;
  *getType = *Everything::HTML::getType;
  *updateNode = *Everything::HTML::updateNode;
  *setVars = *Everything::HTML::setVars;
  *getNodeWhere = *Everything::HTML::getNodeWhere;
  *insertIntoNodegroup = *Everything::HTML::insertIntoNodegroup;
  *linkNodeTitle = *Everything::HTML::linkNodeTitle;
  *canUpdateNode = *Everything::HTML::canUpdateNode;
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

sub node_edit_page
{
  return "This is a temporary edit page for the basic node.  If we want to edit raw nodes, we will need to implement this.";
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

  # Copy the array to avoid mutating the cached TYPE object
  my $tables = [@{$DB->getNodetypeTables($$NODE{type_nodetype})}];
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

  # Sort fields alphabetically for deterministic display (improves E2E testability)
  foreach my $field (sort keys %titletype)
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

sub fullpage_display_page
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
    $doctitle = "fullpage_$doctitle";
  }

  $APP->devLog("Proposed fullpage delegation for '$NODE->{title}': '$doctitle'");
  if(my $delegation = Everything::Delegation::document->can("$doctitle"))
  {
    $APP->devLog("Using fullpage delegation for $NODE->{title} as '$doctitle'");
    my $output = $delegation->($DB, $query, $NODE, $USER, $VARS, $PAGELOAD, $APP);
    return $PAGELOAD->{noparsecodelinks} ? $output : parseLinks($output);
  }

  return "Error: Fullpage delegation not implemented for '$NODE->{title}' (expected: $doctitle)";
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

  my $node = $APP->node_by_id($NODE->{node_id});
  my $xml = $node->to_xml();
  return qq|<?xml version="1.0" standalone="yes"?>\n$xml|;
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

# podcast_display_page REMOVED - migrated to Everything::Controller::podcast::display with React Podcast.js component. Jan 2026.

# collaboration_display_page REMOVED - migrated to Everything::Controller::collaboration with React Collaboration.js component. Jan 2026.
# collaboration_useredit_page REMOVED - migrated to Everything::Controller::collaboration with React CollaborationEdit.js component. Jan 2026.

# e2client_display_page REMOVED - migrated to Everything::Controller::e2client with React E2client.js component. Jan 2026.
# e2client_edit_page REMOVED - migrated to Everything::Controller::e2client with React E2clientEdit.js component. Jan 2026.

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
    # ilikeit - REMOVED: React ILikeItButton + /api/ilikeit handles this
    weblogform => 		[ $node_id , $anything ], #writeup_id, flag for in writeup
    categoryform => 	[ $node_id , $anything ], #writeup_id, flag for in writeup
    listnodecategories 		=>[ $node_id ],
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

1;
