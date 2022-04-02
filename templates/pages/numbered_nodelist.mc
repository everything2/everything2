<%class>
  has 'nodelist' => (required => 1);
</%class>
<& 'ennchoice', node => $.node &>
<br>(see also <& 'linknodetitle', node => 'Writeups by Type', type => 'superdoc' &>)<br><br>
<& 'nodelist', node => $.node, nodelist => $.nodelist &>
