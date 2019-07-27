<%class>
  has 'maintainer' => (isa => 'Everything::Node::user', 'required' => 1);
</%class>

<ul><li><a href="http://twitter.com/everything2com">New Writeups Twitter Feed</a></li>
<li><a href="http://community.livejournal.com/everything2/profile">LiveJournal community</a></li>
<li><a href="http://www.last.fm/group/Everything2">Last.fm group</a></li>
<li><a href="http://www.flickr.com/groups/everything2/">Flickr group</a></li>
<li><a href="https://www.facebook.com/Everything2com/">Facebook group</a></li>
<li><a href="http://www.segnbora.com/e2web.html">Web Pages of Everythingians</a></li>
</ul>
% $.Capture(\my $content) {{
<& '/helpers/linknodetitle.mi', node => 'Community Directory', type => 'document' &>
% }}
<p>You might also like to see the <% $content | Trim %>.</p>
% unless($REQUEST->user->is_guest) {
<p>Complaints? Suggestions? Tell <& '/helpers/linknode.mi', node => $.maintainer &> about it.
<& '/helpers/messagebox.mi', to => $.maintainer, node => $.node &>
% }
