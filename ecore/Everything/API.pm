package Everything::API;
use Moose;
use Try::Tiny;
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
# TODO: There's no sanity checking that a variable conforms to a particular pattern such as number or string in particular

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
    $perlcode .= 'return ';

    $perlcode .= '$self->'.$subref.'(';
    $arguments ||= "";
    $arguments =~ s/\:/\$/g;
    $perlcode .= '$REQUEST,'."$arguments)};";

  }
  $perlcode .= 'return [$self->HTTP_UNIMPLEMENTED];';
  $perlcode .= '}';

  try {
    ## no critic (ProhibitStringyEval)
    eval ("\$subroutineref = $perlcode") or do {
      die "Router compiler error! ($perlcode): $@";
    }
  } catch {
    die "Router compiler error (in catch)! ($perlcode): $_";
  };

  return $subroutineref;
}

sub routes
{
  return {"/" => "get"}
}

sub get
{
  my ($self, $REQUEST) = @_;
  return [$self->HTTP_UNIMPLEMENTED];
}

sub route
{
  my ($self, $REQUEST, $path) = @_;

  # Since Moose is giving me trouble with this, I'll let mod_perl cover me
  # TODO: The right way with Moose Meta 
  my $version = $REQUEST->get_api_version;
  $version = $self->CURRENT_VERSION unless(defined($version));

  if($version == 0 || $version > $self->CURRENT_VERSION)
  {
    return [$self->HTTP_BAD_REQUEST];
  }

  if($version < $self->MINIMUM_VERSION)
  {
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

  if($REQUEST->is_guest)
  {
    return [$self->HTTP_UNAUTHORIZED];
  }
  return $self->$orig($REQUEST, @_);
}

sub unauthorized_unless_type
{
  my $self = shift;
  my $orig = shift;
  my $REQUEST = shift;
  my $type = shift;

  unless($type)
  {
    return [$self->HTTP_UNAUTHORIZED];
  }

  $type = "is_$type";

  if($REQUEST->user->$type || $REQUEST->user->is_admin)
  {
    return $self->$orig($REQUEST, @_);
  }

  return [$self->HTTP_UNAUTHORIZED];
}

sub unauthorized_unless_developer
{
  my $orig = shift;
  my $self = shift;
  my $REQUEST = shift;
  return $self->unauthorized_unless_type($orig,$REQUEST,"developer", @_);
}

sub unauthorized_unless_editor
{
  my $orig = shift;
  my $self = shift;
  my $REQUEST = shift;
  return $self->unauthorized_unless_type($orig,$REQUEST,"editor", @_);
}

__PACKAGE__->meta->make_immutable;
1;
