package Everything::API::writeups;

use Moose;
extends 'Everything::API::nodes';

has 'CREATE_ALLOWED' => (is => 'ro', isa => 'Int', default => 1);

sub translate_create_params
{
  my ($self, $postdata) = @_;

  unless(defined($postdata->{writeuptype}) and defined($postdata->{title}) and defined($postdata->{doctext}))
  {
    # Writeup create API needs writeuptype, title, and doctext; missing at least one
    return;
  }

  my $writeuptype = $self->APP->node_by_name($postdata->{writeuptype},"writeuptype");
  if($writeuptype)
  {
    $postdata->{wrtype_writeuptype} = $writeuptype->node_id
  }else{
    $self->devLog("Invalid writeuptype '".$postdata->{writeuptype}."', returning BAD REQUEST");
    return;
  }

  my $e2node = $self->APP->node_by_name($postdata->{title},"e2node");
  if($e2node)
  {
    $postdata->{parent_e2node} = $e2node->node_id;
  }else{
    $self->devLog("Invalid parent e2node: '".$postdata->{title}."', returning BAD REQUEST");
    return;
  }

  $postdata->{title} = $postdata->{title}." (".$writeuptype->title.")";

  return $postdata;
}

__PACKAGE__->meta->make_immutable;
1;
