<%class>
  has 'NODE' => (isa => 'HashRef', required => 1); #TODO: Do we need this?
  has 'USER' => (isa => 'HashRef', required => 1); #TODO: Do we need this?

  has 'nodeletclass' => (isa => 'Str', required => 1);
  has 'nodelettitle' => (isa => 'Str', required => 1);  
</%class>
<%augment wrap>
<div class='nodelet' id='<% $.nodeletclass %>'>
<h2 class="nodelet_title"><% $.nodelettitle %></h2>
<div class='nodelet_content'>
<% inner() %>
</div>
</div>
</%augment>
