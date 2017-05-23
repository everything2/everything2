package Everything::API;
use Moose;
use JSON;
use namespace::autoclean;

with 'Everything::Globals';
with 'Everything::HTTP';

has 'CURRENT_VERSION' => (isa => "Int", default => 1, is => "ro");
has 'MINIMUM_VERSION' => (isa => "Int", lazy => 1, builder => "_build_minimum_version", is => "ro");

# This compiles the route template into perlcode which does the right thing.
# It supports variables as denoted by :
# We have actions verbs specified as as a token so the route chooser doesn't
# confuse things like /:id and /create
#
# TODO: There's no sanity checking that a variable conforms to anything in particular

sub _build_minimum_version
{
  my ($self) = @_;
  
  # If minimum isn't set then the current version is the minimum
  return $self->CURRENT_VERSION;
}

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

        if($variable eq "id")
        {
          # id is a numeric hint
          push @$re,'(\d+)';
        }else{
          push @$re,'([^\/]+)';
        }
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
    $perlcode .= '$self->devLog("Choosing \''.$routetarget.'\' for ".(($path == "")?("/"):($path)));';
    $perlcode .= 'return ';

    $perlcode .= '$self->'.$subref.'(';
    $arguments ||= "";
    $arguments =~ s/\:/\$/g;
    $perlcode .= '$REQUEST,'."$arguments)};";
 
  }
  $perlcode .= '$self->devLog("Could not choose route for $path");';
  $perlcode .= 'return [$self->HTTP_UNIMPLEMENTED];';
  $perlcode .= '}';
  
  $self->devLog("Compiled routes into code: '$perlcode'");
  eval ("\$subroutineref = $perlcode");
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
  $self->devLog("Handling with get catchall: ".$REQUEST->url(-absolute=>1));
  return [$self->HTTP_UNIMPLEMENTED];
}

sub route
{
  my ($self, $REQUEST, $path) = @_;

  $self->devLog("Choosing route for $path in '".ref($self)."'");
  # Since Moose is giving me trouble with this, I'll let mod_perl cover me
  # TODO: The right way with Moose Meta 
  my $version = $REQUEST->get_api_version;
  $version = $self->CURRENT_VERSION unless(defined($version));

  if($version == 0 || $version > $self->CURRENT_VERSION)
  {
    $self->devLog("Sending HTTP_BAD_REQUEST due to request version being 0 or higher than CURRENT_VERSION");
    return [$self->HTTP_BAD_REQUEST];
  }

  if($version < $self->MINIMUM_VERSION)
  {
    $self->devLog("Sending HTTP_GONE due to request version being lower than minimum");
    return [$self->HTTP_GONE];
  }

  $self->{routerchooser} ||= $self->_build_routechooser;
  return $self->{routerchooser}->($REQUEST, $path);
}


sub unauthorized_if_guest
{
  my $orig = shift;
  my $self = shift;
  my $REQUEST = shift;

  if($self->APP->isGuest($REQUEST->USER))
  {
    $self->devLog("Can't access path due to being Guest");
    return [$self->HTTP_UNAUTHORIZED];
  }
  return $self->$orig($REQUEST, @_);
}

__PACKAGE__->meta->make_immutable;
1;
