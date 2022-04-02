<%class>

has 'nodes' => (isa => 'ArrayRef[Everything::Node::writeup]', default => sub { [] });

sub wit
{
  my @wit = (
    "The most neglected writeups on Everything:",
    "Adopt a writeup today:",
    "Won't you help a vote deprived writeup?",
    "Straight from no-man's land:");

  return $wit[int(rand(@wit))];
}

</%class>
<% $.wit %>
<br><ol>

% if(int @{$.nodes} == 0) {
<em>No nodes!</em>
% } else {
%   foreach my $n (@{$.nodes}) {
<li><& '/helpers/linknode.mi', node => $n &></li>
%   }
% }
</ol>
