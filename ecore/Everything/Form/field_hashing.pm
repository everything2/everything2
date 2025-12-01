package Everything::Form::field_hashing;

use Moose::Role;
use Digest::SHA;

has 'formsecret' => (is => 'ro', default => '236391bd13e64d3d8a0c22d23b26827101419ed8f95f48073fe5620a8cb4491a');
has 'formlife' => (is => 'ro', default => 86400);
has 'signaturefield' => (is => 'ro', default => 'formsignature');
has 'formtimefield' => (is => 'ro', default => 'formtime');

sub hash_item {
  my $self = shift;
  my $item = shift;
  my $signaturetime = shift;

  return Digest::SHA::sha256_hex(join("|",$item,$signaturetime,$self->formsecret));
}

sub get_formtime {
  my ($self,$REQUEST) = @_;
  return $REQUEST->param($self->formtimefield);
}

sub formsignature {
  my ($self,$signaturetime) = @_;
  return $self->hash_item($self->signaturefield,$signaturetime);
}

sub formsignature_html
{
  my ($self,$signaturetime) = @_;
  return qq|<input type="hidden" name="|.$self->formtimefield.qq|" value="|.$self->formtime.qq|"><input type="hidden" name="|.$self->signaturefield.qq|" value="|.$self->formsignature($signaturetime).qq|">|;
}

sub is_form_submitted
{
  my ($self, $REQUEST) = @_;

  if(defined $REQUEST->param($self->formtimefield))
  {
    return 1;
  }
  return;
}

sub has_valid_formsignature {
  my ($self, $REQUEST) = @_;

  my $formtime = $self->get_formtime($REQUEST);
  if(defined $REQUEST->param($self->signaturefield) and defined($formtime))
  {
    if($self->formsignature($formtime) eq $REQUEST->param($self->signaturefield))
    {
      my $formage = time - $formtime;
      if($formage >= 0 and $formage < $self->formlife)
      {
        return 1;
      }
    }else{
      return 0;
    }
  }else{
    return 0;
  }
}

sub get_hashed_field {
  my ($self, $REQUEST, $fieldname) = @_;


  my $formtime = $self->get_formtime($REQUEST);
  if($formtime)
  {
    my $hashed_field = $self->hash_item($fieldname, $formtime);
    if($hashed_field)
    {
      return $REQUEST->param($hashed_field);
    }
  }

  return '';
}

1;
