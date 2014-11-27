package Everything::Router;

use Moose;
use namespace::autoclean;

has "CONTROLLER_CACHE" => (isa => "HashRef", is => "rw", default => sub { {} });
has "SUBTYPE_CACHE" => (isa => "HashRef", is => "rw", default => sub { {} });
has "CONF" => (isa => "HashRef | Everything::Configuration", is => "ro", required => 1);
has "APP" => (isa => "Everything::Application", "is" => "ro", required => 1);
has "DB" => (isa => "Everything::NodeBase", "is" => "ro", required => 1);

sub can_handle
{
  my ($this, $type, $displaytype) = @_;

  $this->APP->printLog("Everything::Router::can_handle for $type,$displaytype");

  next unless defined($type);
  next unless $type ne "";

  if(exists($this->CONTROLLER_CACHE->{$type}->{$displaytype}))
  {
    return $this->CONTROLLER_CACHE->{$type}->{$displaytype};
  }

  eval("use Everything::Controller::$type");

  if($@)
  {
    $this->APP->printLog("Couldn't use 'Everything::Controller::$type': $@");
    return;
  }

  if("Everything::Controller::$type"->can($displaytype))
  {
    my $controller = "Everything::Controller::$type"->new(CONF => $this->CONF, APP => $this->APP, DB => $this->DB, ROUTER => $this);
    if($controller->displaytype_allowed($displaytype))
    {
      $this->CONTROLLER_CACHE->{$type}->{$displaytype} = $controller;
      return $controller;
    }else{
      $this->APP->printLog("Found controller 'Everything::Controller:$type', but not permitted to call '$displaytype'");
      $this->APP->printLog("Permitted from 'Everything::Controller:$type': ".join(",", @{$controller->EXTERNAL}));
    }
  }else{
    $this->APP->printLog("Controller 'Everything::Controller::$type' does not have symbol for '$displaytype'");
  }

  return;
}

sub dispatch_subtype
{
  my ($this, $request, $node) = @_;

  $this->DB->getRef($node);
  my $nodetype = $node->{type}->{title};
  my $node_class = $this->classify_node($node);
  if(not exists($this->SUBTYPE_CACHE->{$node_class}))
  {
    eval("use $node_class");
  
    if($@)
    {
      $this->APP->printLog("Couldn't use '$node_class': $@");
      return;
    }

    my $controller = "$node_class"->new(CONF => $this->CONF, APP => $this->APP, DB => $this->DB, ROUTER => $this);
    $this->SUBTYPE_CACHE->{$node_class} = $controller;
  }

  if(my $delegation = "$node_class"->can($nodetype))
  {
    return $this->SUBTYPE_CACHE->{$node_class}->$nodetype($request, $node);
  }
}

sub classify_node
{
  my ($this, $node) = @_;
  $this->DB->getRef($node);
  my $title = lc($node->{title});
  my $type = $node->{type}->{title};
  $title =~ s/[^a-z1-9_]/_/g;
  return "Everything::Controller::".$type."::".$type."_$title";
}

__PACKAGE__->meta->make_immutable;

1;
