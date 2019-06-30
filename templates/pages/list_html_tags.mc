<%flags>
    extends => '/zen.mc'
</%flags>
<%class>
  has 'approved_tags' => (isa => 'HashRef', required => 1);
</%class>
<p>This is the list of HTML tags that have been approved for use in writeups. Allowed attributes for the tags are listed below the tag name.</p>
<dl>
% foreach my $key (sort {$a cmp $b} keys %{$.approved_tags}) {
<dt><% $key %></dt>
%   unless($.approved_tags->{$key} eq "1") {
<dd><% $.approved_tags->{$key} %></dd>
%   }
% }
</dl>
