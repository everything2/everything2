package Everything::Delegation::htmlcode;

# We have to assume that this module is subservient to Everything::HTML
#  and that the symbols are always available

BEGIN {
  *getNode = *Everything::HTML::getNode;
  *getNodeById = *Everything::HTML::getNodeById;
  *getId = *Everything::HTML::getId;
  *urlGen = *Everything::HTML::urlGen;
  *linkNode = *Everything::HTML::linkNode;
  *htmlcode = *Everything::HTML::htmlcode;
} 

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

1;
