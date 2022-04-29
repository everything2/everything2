<%class>
  has 'writeups' => (isa => 'ArrayRef[Everything::Node]');
</%class>
You have insured the following writeups:
<p><ul>
% foreach my $writeup (@{$.writeups})
% {
<li><& 'linknode', node => $writeup &></li>
% }
</ul>
