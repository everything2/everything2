package Everything::APIRouter;

use diagnostics;
use Moose;
use namespace::autoclean;
use JSON;
use Everything;
use Everything::Request;
use Data::Dumper;
use Everything::API;

with 'Everything::Globals';
with 'Everything::HTTP';

has 'MODULE_TABLE' => (isa => "HashRef", is => "ro", builder => "build_module_table", lazy => 1);

sub build_module_table
{
  my ($self) = @_;
  my $routes;

  foreach my $plugin (@{$self->FACTORY->{api}->all})
  {
    $routes->{$plugin} = $self->FACTORY->{api}->available($plugin)->new();
  }

  $routes->{catchall} = Everything::API->new;
  return $routes;
}


sub dispatcher
{
  my ($self) = @_;
  my $REQUEST = Everything::Request->new;
  my $urlform = $REQUEST->url(-absolute=>1);
  my $method = lc($REQUEST->request_method());

  if(!grep($method,"get","put","post","delete","patch"))
  {
    return $self->output($REQUEST, [$self->HTTP_METHOD_NOT_ALLOWED]); 
  }

  # While in beta, API access is restricted
  unless($REQUEST->isGuest || $REQUEST->isEditor || $REQUEST->isDeveloper || $REQUEST->isClientDeveloper || $Everything::CONF->environment eq "development")
  {
    $self->output($REQUEST, [$self->HTTP_FORBIDDEN]);
    return;
  }

  $self->devLog("Received API request: $urlform");

  if(my ($endpoint, $extra) = $urlform =~ m|^/api/([^/]+)/?(.*)|)
  {
    if(exists $self->MODULE_TABLE->{$endpoint})
    {
      $self->output($REQUEST, $self->MODULE_TABLE->{$endpoint}->route($REQUEST, $extra));
    }else{
      $self->devLog("Request fell through to catchall after MODULE_TABLE check");
      $self->output($REQUEST, $self->MODULE_TABLE->{catchall}->$method($REQUEST));
    }
  }else{
    $self->devLog("Request fell through to catchall after form check: $method for $urlform");
    $self->output($REQUEST, $self->MODULE_TABLE->{catchall}->$method($REQUEST));
  }
}

sub output
{
  my ($self, $REQUEST, $output) = @_;

  my $response_code = $output->[0];
  my $data = $output->[1];
  my $headers = $output->[2];

  $headers->{status} = $response_code;
  $headers->{charset} = "utf-8";
  $headers->{type} = "application/json";

  print $REQUEST->header($headers);
  if($data)
  {
    print JSON::to_json($data); 
  }
}

__PACKAGE__->meta->make_immutable;
1;
