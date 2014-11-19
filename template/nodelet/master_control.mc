<%flags>
  extends => '/nodelet.mc';
</%flags>
<%class>
  has "admin_searchform" => (isa => "Maybe[Str]");
  has "admin_toolset" => (isa => "Maybe[Str]");
  has "nodenote" => (isa => "Maybe[Str]");
  has "episectionadmin" => (isa => "Maybe[Str]");
  has "episectionces" => (isa => "Maybe[Str]");
</%class>
<% $.admin_searchform %>
<% $.admin_toolset %>
<% $.nodenote %>
<% $.episectionadmin %>
<% $.episectionces %>
