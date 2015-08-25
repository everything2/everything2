package Everything::APIRouter;

use diagnostics;
use Moose;
use namespace::autoclean;
use JSON;
use Everything;
use Everything::Request;

use Everything::API::v1::messages;
use Everything::API::v1::login;
use Everything::API;

has 'ROUTE_TABLE' => (isa => "HashRef", is => "ro", builder => "build_route_table");
has 'HTTP_METHOD_NOT_ALLOWED' => (isa => "Int", is => "ro", default => "405");

sub build_route_table
{
#  foreach my $path (@INC)
#  {
#    if(-d "$path/Everything/API/")
#    {
#
#    }
#  }
   my $args = {"DB" => $Everything::DB, "APP" => $Everything::APP, "CONF" => $Everything::CONF};

   return { 
    "messages" => { "1" => Everything::API::v1::messages->new($args) }, 
    "login" => { "1" => Everything::API::v1::login->new($args) },
    "catchall" => Everything::API->new($args)
  }; 
}

sub route
{
  my ($self) = @_;
  my $REQUEST = Everything::Request->new("DB" => $Everything::DB, "APP" => $Everything::APP, "CONF" => $Everything::CONF);
  my $urlform = $REQUEST->url(-absolute=>1);
  my $method = lc($REQUEST->request_method());
  if(!grep($method,"get","put","post","delete","patch"))
  {
    return $self->output($REQUEST, [$self->HTTP_METHOD_NOT_ALLOWED]); 
  }

  my ($version, $endpoint);
  if(($version,$endpoint) = $urlform =~ /^\/api\/v(\d+)\/([^\/]+)/)
  {
    if(exists $self->ROUTE_TABLE->{$endpoint} and exists $self->ROUTE_TABLE->{$endpoint}->{$version})
    {
      $self->output($REQUEST, $self->ROUTE_TABLE->{$endpoint}->{$version}->$method($REQUEST));
    }else{
      $self->output($REQUEST, $self->ROUTE_TABLE->{catchall}->$method($REQUEST));
    }
  }else{
    $self->output($REQUEST, $self->ROUTE_TABLE->{catchall}->$method($REQUEST));
  }
}

sub output
{
  my ($self, $REQUEST, $output) = @_;

  my $response_code = $output->[0];
  my $data = $output->[1];
  my $additional_headers = $output->[2];

  print $REQUEST->header(-status => $response_code);
  if($data)
  {
    print $REQUEST->header("application/json");
    print JSON::to_json($data); 
  }
}

__PACKAGE__->meta->make_immutable;
1;
