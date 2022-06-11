<%class>
  has 'error' => (isa => 'Maybe[Str]');
  has 'for_user' => (isa => 'Maybe[Everything::Node::user]');
  has 'nodeshells' => (isa => 'ArrayRef[Everything::Node::e2node]');

  has 'needs_link_parse' => (default => 1);
 </%class>

Look up user:<br /><& 'username_selector', node => $.node &><br />

% if(defined $.error) {
<em><% $.error %></em>
% }
<p>(Be sure to check out [your filled nodeshells], too.)</p> <p><strong><% scalar(@{$.nodeshells}) %></strong> nodeshells created by
% if(defined($.for_user) and $.for_user->node_id != $REQUEST->user->node_id)
% {
<& 'linknode', node => $.for_user &>
% } else {
you
% }
which do not contain writeups:</p>
<ul>
% foreach my $nodeshell (sort {lc($a->title) cmp lc($b->title) } @{$.nodeshells})
% {
<li><& 'linknode', node => $nodeshell &>\
%   if(scalar(@{$nodeshell->firmlinks}) > 0)
%   {
 - <b>Firm linked to:</b> <& 'linknode', node => $nodeshell->firmlinks->[0] &>\
%   }
% }
</li>
</ul>
