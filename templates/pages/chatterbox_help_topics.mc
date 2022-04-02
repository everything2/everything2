<%class>
  has 'helpuser' => (isa => 'Everything::Node::user', required => 1);
  has 'helptopics' => (isa => 'HashRef', required => 1);
</%class>
<p>The chatterbox help topics are a good way for new users to learn some of the basics of E2.  Simply type "/help TOPIC" in the chatterbox to get an automated message from <& 'linknode', node => $.helpuser &> about that topic.  Best results will be achieved by searching in lowercase and multi-word topics should use underscores rather_than_spaces.  If you notice errors, or think additional topics should be available, contact an editor.</p>

<p>Examples:
<br><tt>/help editor</tt>
<br><tt>/help wheel_of_surprise</tt></p>

<h3>Currently available help topics</h3>
<p>(not including aliases for topics listed under multiple titles)</p>

<ol>
% foreach my $key (sort keys %{$.helptopics}) {
%  unless($.helptopics->{$key} =~ qq|/help .*|) {
<li>/help <% $key %></li>
%  }
% }
</ol>

