<%class>
  has 'nodelist' => (required => 1);
</%class>
<& '/helpers/ennchoice.mi', node => $.node &>
% $.Capture(\my $link) {{
<& '/helpers/linknodetitle.mi', node => 'Writeups by Type', type => 'superdoc' &>
% }}
<br>(see also <% $link | Trim %>)<br><br>
<& '/helpers/nodelist.mi', node => $.node, nodelist => $.nodelist &>
