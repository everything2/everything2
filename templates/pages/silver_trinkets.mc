<%class>
  has 'error' => (isa => 'Maybe[Str]');
  has 'for_user' => (isa => 'Maybe[Everything::Node::user]');
</%class>

<br><br><br><p align=center><font size=4>
% if ($REQUEST->user->sanctity <= 0){
<em>You are not feeling very special right now.</em>
% } else {
You feel validated -- every day, your fellow users look upon you and approve -- you have collected <% $REQUEST->user->sanctity %> of their <& '/helpers/linknodetitle.mi', "node" => "sanctify", "title" => "Silver Trinkets" &>
% }
</font><br><br><br></p>

% if($REQUEST->user->is_admin) {
<& '/helpers/openform.mi', node => $.node &><input type="text" name="gtuser"><input type="submit" value="SubMitt"></form><br />
%   if(defined $.error) {
<em><% $.error %></em>
%   }
%   if(defined($.for_user)) {
<& '/helpers/linknode.mi', node => $.for_user &>'s sanctity: <% $.for_user->sanctity %>
%   }
% }
