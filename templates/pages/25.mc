<%flags>
    extends => '/zen.mc'
</%flags>
<%class>
  has 'nodelist' => (required => 1);
</%class>
<& '/helpers/ennchoice.mi', node => $.node &>
