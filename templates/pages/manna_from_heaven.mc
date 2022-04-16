<%class>
  has 'writeups' => (isa => 'ArrayRef[HashRef]', required => 1);
  has 'numdays' => (isa => 'Int', required => 1);

  has 'totalwriteups' => (lazy => 1, builder => '_buildtotalwriteups');

  sub _buildtotalwriteups
  {
    my ($self) = @_;

    my $total = 0;
    foreach my $line (@{$self->writeups})
    {
      $total += $line->{count};
    }

    return $total;
  }
</%class>

<& 'openform' , node => $.node &>
<input type='text' value='<% $.numdays %>' name='days' /><input type='submit' name='sexisgood' value='Change Days' /></form>
<table width='25%'><tr><th width='80%' >User</th><th width='20%'>Writeups</th></tr>
% foreach my $line (@{$.writeups})
% {
<tr><td><b><& 'linknode', node => $line->{user} &></b></td><td><& 'linknodetitle', node => 'Everything User Search', params => {usersearch => $line->{user}->title, orderby => 'createtime DESC'}, title => $line->{count} &></td></tr>
% }
</table>
