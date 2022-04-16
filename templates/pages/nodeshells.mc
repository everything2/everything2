<%class>
  has 'nodeshells' => (isa => 'ArrayRef[Everything::Node]', required => 1);
  has 'needs_link_parse' => (default => 1); 
</%class>

<h3>New Titles in Search of Content</h3>
<ol>
% foreach my $node (@{$.nodeshells})
% {
<li><& 'linknode', node => $node &></li>
% }
</ol>
<p><small>These are [nodeshell|empty headings] created between half an hour and one month ago. They exist to be filled with writing. If you feel like writing, but you don't know what,
you might also like to visit [Everything's Most Wanted]. See also [Random Nodeshells].
% unless($REQUEST->user->is_guest)
% {
 And [Your Nodeshells], and [Your Filled Nodeshells].
% }
</small></p>
