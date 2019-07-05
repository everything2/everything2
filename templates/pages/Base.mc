<%flags>
    extends => '/zen.mc'
</%flags>
<%class>
  has 'needs_link_parse';
  has 'node';
</%class>
<%augment wrap>
% if ($.needs_link_parse) {
% $.Capture(\my $content) {{
<% inner() %>
% }}
<% $content | ParseLinks %>
% } else {
<% inner() %>
% }
</%augment>
