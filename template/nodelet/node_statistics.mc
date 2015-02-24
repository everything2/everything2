<%flags>
  extends => '/nodelet.mc';
</%flags>
<%class>
  has 'nodeid' => (isa => "Maybe[Int]");
  has 'createtime' => (isa => "Maybe[Str]");
  has 'hits' => (isa => "Maybe[Int]");
  has 'nodetype' => (isa => "Maybe[Int]");
</%class>
Node ID: <% $.nodeid %><br />
Created on:<br /> <% $.createtime %><br />
Hits: <% $.hits %><br />
Nodetype: <% $.linkNode($.nodetype) %><br />
