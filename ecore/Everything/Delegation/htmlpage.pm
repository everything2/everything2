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

sub debatecomment_display_page
{
  return htmlcode("showdebate",1);
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

  if($restrict = getNodeById($$NODE{ 'root_debatecomment' }))
  {
    $restrict = $restrict->{restricted};
  }else{
    $restrict = undef;
  }
  my $title = $$NODE { 'title' };
  $title =~ s/\</\&lt\;/g;
  $title =~ s/\>/\&gt\;/g;

  my $ug_name = "";
  $ug_name = getNodeById($restrict)->{'title'}.": " if(defined($restrict) and $restrict);

  $title =~ /^\s*([\w\s]+):/;
  my $prefix = $1;

  $title = $ug_name.$title unless lc($prefix) eq lc($ug_name);

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

# podcast_display_page REMOVED - migrated to Everything::Controller::podcast::display with React Podcast.js component. Jan 2026.

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
