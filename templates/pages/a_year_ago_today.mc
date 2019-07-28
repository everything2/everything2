<%class>
  has 'nodes' => (isa => 'ArrayRef');
  has 'current_year' => (isa => 'Int');
  has 'count' => (isa => 'Int');
  has 'yearsago' => (isa => 'Int');
  has 'startat' => (isa => 'Int');
</%class>
<p align="center">Turn the clock back!</p><br><br>
<ul>
% foreach my $node (@{$.nodes}) {
%   $.Capture(\my $content) {{
<& '/helpers/linknode.mi', node => $node->parent, title => "full" &>
%   }}
<li>(<% $content | Trim %>) - <& '/helpers/linknode.mi', node => $node, title => $node->parent->title &> by <& '/helpers/linknode.mi', node => $node->author &> <small>entered on <% ($node->createtime) | PrettyDate %></small></li>
% }
</ul>
<p><% $.count %> writeups submitted <% (($.yearsago == 1)?("a year"):($.yearsago." years")) %> ago today</p>
<p align="center"><table width="70%">
<tr>
<td width="50%" align="center">
% if ($.startat - 50 >= 0) {
<& '/helpers/linknode.mi', node => $.node, params => {"startat" => $.startat, "yearsago" => $.yearsago} &>
% } else {
<%  $.startat %>-50
% }
</td>
<td width="50%" align="center">
% my $secondstr = ($.startat+50)."-".(($.startat + 100 < $.count)?($.startat+100):($.count));

% if(($.startat+50) <= ($.count)){
<& '/helper/linknode.mi', node => $.node, title => $secondstr, params => {"startat" => ($.startat+50), "yearsago" => $.yearsago } &>
% }else{
(end of list)
% }
</td>
</tr></table></p>
<p align="center"><hr width="200"></p>
<p align="center">
%  my @years = ();
%  for my $year (1999..($.current_year-1))
%  {
%  $.Capture(\my $yearlink) {{
%    if($.yearsago == ($.current_year - $year)) {
<% $year %>
%    } else {
<& '/helpers/linknode.mi', node => $.node, title => $year, params => {"yearsago" => ($.current_year - $year)} &>
%    }
%  }}
%    push @years,$yearlink;
%  }
<%  join " | ", reverse(@years) %>
</p>
