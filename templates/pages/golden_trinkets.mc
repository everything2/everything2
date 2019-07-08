<%class>
  has 'other_user' => (isa => 'Maybe[Everything::Node::user]');
  has 'error';
</%class>
<br><br><br><p align="center">
<font size="4">
% if ($REQUEST->user->karma == 0) {
<em>You are not feeling very special.</em>
% } elsif ($REQUEST->user->karma < 0) {
<strong>You feel a burning sensation...</strong>
% } else {
You feel blessed -- every day, the gods see you and are glad -- you have collected <% $REQUEST->user->karma %> of their <& '/helpers/linknodetitle.mi', "node" => "bless", title => "Golden Trinkets" &>
% }
</font>
<br><br><br>
</p>

% if($REQUEST->user->is_admin) {
<& '/helpers/openform.mi', node => $.node &>other user: <input type="text" name="gtuser" /><input type="submit" name="SubMitt" /></form><br>
%  if(defined $.other_user) {
%   $.Capture(\my $content) {{
     <& '/helpers/linknode.mi', node => $.other_user &>
%   }}
<% $content | Trim %>'s karma: <% $.other_user->karma %>
%  }
% }
