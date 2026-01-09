package Everything::APIRouter;

use diagnostics;
use Moose;
extends 'Everything::Router';

has 'CONTROLLER_TYPE' => (is => 'ro', isa => 'Str', default => 'API');

sub dispatcher
{
  my ($self) = @_;
  my $REQUEST = Everything::Request->new;
  my $urlform = $REQUEST->url(-absolute=>1);
  my $method = lc($REQUEST->request_method());

  if(not grep {$method} ("get","put","post","delete","patch"))
  {
    return $self->output($REQUEST, [$self->HTTP_METHOD_NOT_ALLOWED]);
  }

  if($self->CONF->maintenance_message)
  {
    return $self->output($REQUEST, $self->CONTROLLER_TABLE->{catchall}->$method($REQUEST));
  }

  if(my ($endpoint, $extra) = $urlform =~ m|^/api/([^/]+)/?(.*)|)
  {
    if(exists $self->CONTROLLER_TABLE->{$endpoint})
    {
      return $self->output($REQUEST, $self->CONTROLLER_TABLE->{$endpoint}->route($REQUEST, $extra));
    }else{
      # Request fell through to catchall after CONTROLLER_TABLE check
      return $self->output($REQUEST, $self->CONTROLLER_TABLE->{catchall}->$method($REQUEST));
    }
  }else{
    # Request fell through to catchall after form check
    return $self->output($REQUEST, $self->CONTROLLER_TABLE->{catchall}->$method($REQUEST));
  }
}

around 'output' => sub {
  my ($orig, $self, $REQUEST, $output)  = @_;
  $output->[2]->{charset} = "utf-8";
  $output->[2]->{type} = "application/json";
  return $self->$orig($REQUEST, $output);
};

__PACKAGE__->meta->make_immutable;
1;
