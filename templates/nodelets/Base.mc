<%class>
  has 'title';
  has 'id';
  has 'delegated_content';
  has 'node';
  has 'react_handled' => (isa => 'Bool', default => 0);
</%class>
<%augment wrap>
<div class='nodelet' id='<% $.id %>'>
% if (!$.react_handled) {
<h2 class="nodelet_title"><% $.title %></h2><div class='nodelet_content'>
%   if ($.delegated_content) {
<% $.delegated_content %>
%   } else {
<% inner() %>
%   }
</div>
% }
</div>
</%augment>
