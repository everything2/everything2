package Everything::API;
use Moose;
use JSON;
use namespace::autoclean;

has 'CONF' => (isa => "Everything::Configuration", is => "ro", required => 1);
has 'DB' => (isa => "Everything::NodeBase", is => "ro", required => 1);
has 'APP' => (isa => "Everything::Application", is => "ro", required => 1);

has 'HTTP_OK' => (is => "ro", isa => "Int", default => 200);

has 'HTTP_BAD_REQUEST' => (is => "ro", isa => "Int", default => 400);
has 'HTTP_FORBIDDEN' => (is => "ro", isa => "Int", default => 403);
has 'HTTP_UNIMPLEMENTED' => (is => "ro", isa => "Int", default => 405);

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
  $self->APP->printLog("parse_postdata: ".$REQUEST->POSTDATA);
  if(!$REQUEST->POSTDATA)
  {
    return {};
  }
  return JSON::from_json($REQUEST->POSTDATA);  
}

__PACKAGE__->meta->make_immutable;
1;
