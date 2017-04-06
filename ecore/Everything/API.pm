package Everything::API;
use Moose;
use strict;
use JSON;
use namespace::autoclean;

has 'CONF' => (isa => "Everything::Configuration", is => "ro", required => 1);
has 'DB' => (isa => "Everything::NodeBase", is => "ro", required => 1);
has 'APP' => (isa => "Everything::Application", is => "ro", required => 1, handles => ["printLog"]);

with 'Everything::HTTP';

# This compiles the route template into perlcode which does the right thing.
# It supports variables as denoted by :
# We have actions verbs specified as as a token so the route chooser doesn't
# confuse things like /:id and /create
#
# TODO: There's no sanity checking that a variable conforms to anything in particular

sub _build_routechooser
{
  my ($self) = @_;

  my $routes = $self->routes;
  my $subroutineref;
  my $perlcode = 'sub { my $REQUEST=shift;my $path=shift;';

  foreach my $route(keys %{$routes})
  {
    my $routetarget = $routes->{$route}; 
    $route =~ s/^\///g;

    my $routesections = [split("/",$route)];
    $routesections ||= [];

    my $variables = [];
    my $re = [];

    foreach my $section (@$routesections)
    {
      if(my ($variable) = $section =~ /^:([^:]+)/)
      {
        push @$variables, $variable;
        push @$re,'([^\/]+)';
      }else{
        push @$re,$section;
      }
    }

    $perlcode.= 'if(';
    if(scalar(@$variables) > 0)
    {
      $perlcode.= 'my (';
      foreach my $variable (@$variables)
      {
        $perlcode .='$'.$variable.',';
      }
      $perlcode.= ')=';
    }
    my ($subref, $arguments) = $routetarget =~ /^([^\(]+)\(?([^\)]*)\)?/;

    $perlcode .= '$path =~ /^';
    $perlcode .= join('\/',@$re);
    $perlcode .= '$/){ ';
    #$perlcode .= '$self->printLog("Choosing \''.$routetarget.'\' for $path");';
    $perlcode .= 'return ';

    $perlcode .= '$self->'.$subref.'(';
    $arguments ||= "";
    $arguments =~ s/\:/\$/g;
    $perlcode .= '$REQUEST,'."$arguments)};";
 
  }
  $perlcode .= '$self->printLog("Could not choose route for $path");';
  $perlcode .= 'return [$self->HTTP_UNIMPLEMENTED];';
  $perlcode .= '}';
  
  $self->printLog("Compiled routes into code: '$perlcode'");
  eval("\$subroutineref = $perlcode");
  if($@)
  {
    # TODO: Something other than die
    die "Router compiler error! ($perlcode): $@";
  }

  return $subroutineref;
}

sub routes
{
  {"/" => "get"}
}

sub get
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_UNIMPLEMENTED];
}

sub post
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_UNIMPLEMENTED];
}

sub put
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_UNIMPLEMENTED];
}

sub patch
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_UNIMPLEMENTED];
}

sub delete
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_UNIMPLEMENTED];
}

sub parse_postdata
{
  my ($self, $REQUEST) = @_;
  $self->printLog("parse_postdata: ".$REQUEST->POSTDATA);
  if(!$REQUEST->POSTDATA)
  {
    return {};
  }
  return JSON::from_json($REQUEST->POSTDATA);  
}


sub route
{
  my ($self, $REQUEST, $path) = @_;

  #$self->printLog("Choosing route for $path in '".ref($self)."'");
  # Since Moose is giving me trouble with this, I'll let mod_perl cover me
  # TODO: The right way with Moose Meta 
  $self->{routerchooser} ||= $self->_build_routechooser;

  return $self->{routerchooser}->($REQUEST, $path);

}

__PACKAGE__->meta->make_immutable;
1;
