<%class>

  has 'onlymynotes' => (isa => 'Bool', required => 1);
  has 'hidesystemnotes' => (isa => 'Bool', required => 1);

  has 'notes' => (isa => 'ArrayRef[HashRef]');

  has 'page' => (isa => 'Int', required => 1);
  has 'total' => (isa => 'Int', required => 1);
  has 'perpage' => (isa => 'Int', required => 1);

  has 'needs_link_parse' => (default => 1); 
</%class>
<p align="center"><strong>&#91
% if($.onlymynotes)
% {
<& 'linknode', node => $.node, title => "Show everyone's notes", params => { onlymynotes => 0 } &>
% } else {
<& 'linknode', node => $.node, title => "Show only my notes", params => {onlymynotes => 1 } &> |
%   if($.hidesystemnotes)
%   {
<& 'linknode', node => $.node, title => "Show system notes", params => { onlymynotes => 0, hidesystemnotes => 0 } &>
%   } else {
<& 'linknode', node => $.node, title => "Hide system notes", params => { onlymynotes => 0, hidesystemnotes => 1 } &>
%   }
% }
&#93</strong></p>

<table width='95%'><tr><th>Node</th><th>Note</th><th>Time</th></tr>
% foreach my $note (@{$.notes})
% {
%   $note->{note} =~ s/\</&lt;/g;
<tr><td><& 'linknode', node => $note->{node} &>
%   if($note->{node}->type->title eq "writeup" or $note->{node}->type->title eq "draft")
%   {
<cite>by <& 'linknode', node => $note->{node}->author &></cite>
%   }
</td><td><% $note->{note} %></td><td nowrap><% $note->{timestamp}->compact %></td></tr>
% }
</table>
<p align="center"><& 'pagination', page => $.page, total => $.total, perpage => $.perpage, node => $.node, carryparams => ['onlymynotes','hidesystemnotes'] &></p>
