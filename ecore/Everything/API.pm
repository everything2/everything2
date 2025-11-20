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

  my @compiled_routes;

  foreach my $route(keys %{$routes})
  {
    my $routetarget = $routes->{$route};
    my $original_route = $route;
    $route =~ s/^\///g;

    my $routesections = [split("/",$route)];
    $routesections ||= [];

    my $variables = [];
    my $re_parts = [];

    foreach my $section (@$routesections)
    {
      if(my ($variable) = $section =~ /^:([^:]+)/)
      {
        push @$variables, $variable;

        if($variable eq "id")
        {
          # id is a numeric hint
          push @$re_parts,'(\d+)';
        }else{
          push @$re_parts,'([^\/]+)';
        }
      }else{
        push @$re_parts, quotemeta($section);
      }
    }

    my $pattern = '^' . join('\/',@$re_parts) . '$';
    my $regex = qr/$pattern/;

    my ($method, $arguments) = $routetarget =~ /^([^\(]+)\(?([^\)]*)\)?/;
    $arguments ||= "";

    # Parse argument list into array of variable names
    my @arg_names = split(/[\s,]+/, $arguments);
    @arg_names = grep { $_ } map { (my $name = $_) =~ s/^://; $name } @arg_names;

    push @compiled_routes, {
      regex => $regex,
      variables => $variables,
      method => $method,
      arguments => \@arg_names,
    };
  }

  # Return a closure that does the routing at runtime
  my $subroutineref = sub {
    my $REQUEST = shift;
    my $path = shift;

    foreach my $route (@compiled_routes)
    {
      if(my @captures = $path =~ $route->{regex})
      {
        # Build argument list for method call
        my @method_args = ($REQUEST);

        # Add captured path variables
        foreach my $capture (@captures)
        {
          push @method_args, $capture;
        }

        # Add additional arguments (like constants from route definition)
        foreach my $arg_name (@{$route->{arguments}})
        {
          # If argument starts with $ it's a captured variable reference
          # For now just pass argument names - may need enhancement
          push @method_args, $arg_name if $arg_name;
        }

        my $method = $route->{method};
        return $self->$method(@method_args);
      }
    }

    return [$self->HTTP_UNIMPLEMENTED];
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
