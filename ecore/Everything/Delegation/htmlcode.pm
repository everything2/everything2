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
} 

# Used by showchoicefunc
use Everything::XML;


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

# This is the meat of the superdoc display code
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
  $text;
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
1;
