package Everything::Router;

use diagnostics;
use Moose;
use namespace::autoclean;
use JSON;
use Everything;
use Everything::Request;

with 'Everything::Globals';
with 'Everything::HTTP';

has 'CONTROLLER_TABLE' => (isa => "HashRef", is => "ro", builder => "_build_controller_table", lazy => 1);
has 'CONTROLLER_TYPE' => (is => 'ro', isa => 'Str', default => 'Controller');

sub _build_controller_table
{
  my ($self, $plugin_type) = @_;
  my $routes = {};
  $plugin_type ||= $self->CONTROLLER_TYPE;

  foreach my $plugin (@{$self->FACTORY->{lc($plugin_type)}->all})
  {
    $routes->{$plugin} = $self->FACTORY->{lc($plugin_type)}->available($plugin)->new();
  }
  return $routes;
}

sub dispatcher
{
  my ($self) = @_;
  my $REQUEST = Everything::Request->new; 
  return $self->output($REQUEST, [$self->HTTP_UNIMPLEMENTED]);
}

sub output
{
  my ($self, $REQUEST, $output) = @_;

  my $response_code = $output->[0];
  my $data = $output->[1];
  my $headers = $output->[2];

  $headers->{status} ||= $response_code;
  $headers->{charset} ||= "utf-8";
  $headers->{type} ||= "text/html";
  
  if($self->CONF->{environment} eq "development")
  {
    $headers->{'-Access-Control-Allow-Origin'} = '*';
  }

  print $REQUEST->header($headers);
  if($data)
  {
    if($headers->{type} eq "application/json")
    {
      print $self->JSON->encode($data); 
    }else{
      print $data;
    }
  }

  return;
}

__PACKAGE__->meta->make_immutable;
1;
