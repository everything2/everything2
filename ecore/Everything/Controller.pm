package Everything::Controller;

use Moose;
use Everything::Delegation::htmlcode;

# Export no external methods by default
has 'EXTERNAL' => (lazy => 1, is => "ro", isa => 'ArrayRef', default => sub { [] });
has 'CONF' => (is => "ro", isa => 'HashRef', required => 1);
has 'APP' => (is => "ro", isa => 'Everything::Application', required => 1);
has 'DB' => (is => "ro", isa => 'Everything::NodeBase', required => 1, handles => [qw(getNodeById getNode)]);
has 'ROUTER' => (is => "ro", isa => 'Everything::Router', required => 1, handles => [qw(dispatch_subtype)]);

sub display
{
  my ($this, $request) = @_;

  my $user_stylesheet = $this->getNodeById($request->VARS->{userstyle}) || $this->getNode($this->CONF->{default_style},"stylesheet");

  my $stylesheets = [
    {"id" => "basesheet", "href" => $this->APP->stylesheetCDNLink($this->getNode("basesheet","stylesheet")), "media" => "all"},
    {"id" => "zensheet", "href" => $this->APP->stylesheetCDNLink($user_stylesheet), "media" => "screen,tv,projection"},
    {"id" => "printsheet", "href" => $this->APP->stylesheetCDNLink($this->getNode("print","stylesheet")), "media" => "print"},
  ];

  $request->response->PAGEDATA->{stylesheets} = $stylesheets;

  #TODO: Make pagetitle a property of individual nodetypes
  $request->response->PAGEDATA->{pagetitle} = $this->APP->pagetitle($request->NODE);
  if(defined $request->VARS->{customstyle})
  {
    $request->response->PAGEDATA->{customstyle} = $this->APP->cleanupHTML($request->VARS->{customstyle});
  }

  $request->response->PAGEDATA->{bodyclass} .= " ".$request->NODE->{type}->{title};

  $request->response->PAGEDATA->{isguest} = $this->APP->isGuest($request->USER);

  $request->response->PAGEDATA->{basehref} = $this->APP->basehref();

  # This is a temporary measure until all of the nodelets are ported
  $request->response->PAGEDATA->{nodelets} = $this->dispatch_subtype($request, $this->getNode("Master Control", "nodelet"));

  # This is a temporary measure until individual pages can set noindex:
  if(($request->NODE->{type_nodetype}==116 && int($request->NODE->{group}) == 0) ||$request->NODE->{node_id}==1140332||$request->NODE->{node_id}==668164)
  {
    $request->response->PAGEDATA->{noindex} = 1;
  }

  # This is a temporary measure until individual pages can set atomlink/atomtitle
  if($request->NODE->{title} eq "Cool Archive")
  {
    $request->response->PAGEDATA->{atomtitle} = "Everything2 Cool Archive";
    $request->response->PAGEDATA->{atomlink} = "/node/ticker/Cool+Archive+Atom+Feed";
  }

  if($request->NODE->{type}->{title} eq "user")
  {
    # TODO: Check URL encoding here
    $request->response->PAGEDATA->{atomlink} = "/node/ticker/New+Writeups+Atom+Feed?foruser=".$request->NODE->{title};
  }

  foreach my $legacy_item (qw/zenadheader static_javascript zensearchform/)
  {
    $request->response->PAGEDATA->{$legacy_item} = $this->emulate_htmlcode($legacy_item,$request);
  }

  my $epicenter = $this->DB->getNode("Epicenter", "nodelet")->{node_id};
  if($request->VARS->{nodelets} and $request->VARS->{nodelets} !~ /$epicenter/)
  {
    $request->response->PAGEDATA->{alternate_epicenter} = $this->emulate_htmlcode("epicenterZen", $request);
  }

  #TODO: Website microdata

  return $request->response->render();
}

sub displaytype_allowed
{
  my ($this, $displaytype) = @_;
  $this->APP->printLog("Checking displaytype for $displaytype in: '".ref($this)."'");
  return grep($displaytype, @{$this->EXTERNAL});
}

sub emulate_htmlcode
{
  my ($this, $htmlcode, $request, @htmlcode_args) = @_;

  if(my $delegation = "Everything::Delegation::htmlcode"->can($htmlcode))
  {
    return $delegation->($request->DB,$request->cgi,$request->NODE,$request->USER,$request->VARS,$request->PAGELOAD,$request->APP, @htmlcode_args);
  }else{
    $this->APP->printLog("Could not use legacy htmlcode delegation: '$htmlcode'");
  }
}

1;
