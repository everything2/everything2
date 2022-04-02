<%class>
  has 'for_user' => (isa => 'Maybe[Everything::Node::user]');
  has 'error';
</%class>
<br><br><br><p align="center">
<font size="4">
% if ($REQUEST->user->karma == 0) {
<em>You are not feeling very special.</em>
% } elsif ($REQUEST->user->karma < 0) {
<strong>You feel a burning sensation...</strong>
% } else {
You feel blessed -- every day, the gods see you and are glad -- you have collected <% $REQUEST->user->karma %> of their <& 'linknodetitle', "node" => "bless", title => "Golden Trinkets" &>
% }
</font>
<br><br><br>
</p>

% if($REQUEST->user->is_admin) {
<& 'username_selector', node => $.node &><br />
%   if(defined $.error) {
<em><% $.error %></em>
%   }
%   if(defined($.for_user)) {
<& 'linknode', node => $.for_user &>'s karma: <% $.for_user->karma %>
%   }
% }
