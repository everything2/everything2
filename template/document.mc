<%flags>
  extends => 'zen.mc'
</%flags>
<%class>
  has 'document_edit_link' => (isa => "Maybe[Str]");
</%class>
% if(defined $.document_edit_link) {
<p align="right"><% $.document_edit_link %></p>
% }
<div class="content">
<% $.parselinks($.NODE->{doctext}) %>
</div>
