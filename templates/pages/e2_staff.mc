
<%class>
  has 'editors' => (isa => 'ArrayRef[Everything::Node::user]', required => 1);
  has 'gods' => (isa => 'ArrayRef[Everything::Node::user]', required => 1);
  has 'inactive' => (isa => 'ArrayRef[Everything::Node::user]', required => 1);
  has 'sigtitle' => (isa => 'ArrayRef[Everything::Node::user]', required => 1);
  has 'chanops' => (isa => 'ArrayRef[Everything::Node::user]', required => 1);

  has 'needs_link_parse' => (default => 1);
</%class>
<p>This document will explain the powers and functions of editors and "[gods]." If you have any questions about E2 and you've read [Everything2 Help] and looked through the links in your [nodelet|nodelets] please [Chatterbox|/msg] one of these volunteers and they will gladly help you out.</p>
<ul><li>The <big><strong>$</strong></big> symbol indicates the user is a [content editors|Content Editor]. These users are charged with helping users on the site with any and all issues related to writeup creation, submission, and maintenance.</li>
<li>The <big><strong>@</strong></big> symbol indicates the user is a "[e2gods|god]." These users are administrators who are charged keeping various aspects of the site running smoothly. Be warned: these users are not actual "gods" in the tradition of [Odin], [Osiris] and [Shiva] ... they are merely the 'gods' of E2. It's an antiquated nomenclature from the days when the only 'god' was [nate] so please forgive the blasphemy.</li>
<li>Some members of the gods group concern themselves strictly with the site's code and do not bear any symbol in the Other Users list. These people do not perform administrative or editorial duties unless they also have the @ or $ symbol.</li>
<li>The <big><strong>+</strong></big> symbol indicates that its bearer is a member of the [chanops] group, which manages the [chatterbox].</li></ul>
<hr width="250" /><p>If you're interested in being an Everything2 editor please sit tight and wait for a call. We're trying to keep the number of staff at 30 or less by rotating new blood in now and then based on activity, merit, <i>writing</i> skill, and ability to function in whichever role is needed at a given time. Also, I'll probably tap you on the shoulder quicker if you <i>don't</i> msg me about it. The [gods] group is always watching and suggestions for new editorial staff are passed around based on their observations.
<hr width="250" />
<h3>The [content editors|Content Editor] Usergroup:</h3>
<p>Membership in the content editor usergroup gives the user the following abilities:</p>
<ul><li>The power to "[cool]" a node. "[page of cool|Cooling]" a node simply places that node onto the [Page of Cool].  It <i><b>does not</b></i> award any particular user with [xp] or change the reputation of <i>any</i> of the writeups within the node. The nodes featured on [Page of Cool] are meant to stand as examples of [node for the ages|superior nodes]; nodes with writeups that are informative, humorous or just plain outstanding.  [Page of Cool] is checked by hundreds of users daily and the resulting attention usually means many + votes--which an editor believed the writeups deserved. <b>Note:</b> A "[page of cool|Cool]" is <i><b>not</b></i> the same as a [C!]. </li>
<li>The power to remove things from New Writeups.  When a writeup is deleted the author will lose the 5XP gained upon creation of said [writeup] but can rewrite and republish later.  See [Writeup Deletion] for details.</li>
<li>Content editors can actually edit the text of any writeup.  They are assigned to go forth and fix spelling/punctuation errors or broken links in writeups.  They are the editorial staff of E2 and help the [gods] group by handling [e2 nuke request|deletion requests] and error spotting/correcting.</li>
<li>Content editors can place a "[firm link]" from one node to another node. The aim is to display a better suggestion for where a writeup should go (or where more information on a topic is most likely to be found). Think of it as a nudge in the right direction.</li>
<li>Editors can [soft lock] a node - preventing further writeups from being added.  This is always done with the understanding that if a user has a better writeup they should [Drafts|create a draft] and have an editor take a look.  The node can be unlocked and the new writeup added if it's worthy.</li>
<li>When doing a [everything user search|user search] on another user editors can see the reputation of that user's writeups, whether they've voted on them or not.</ul>
<p>The mission of these editors is three-fold:</p>
<ul>
<li>Provide users, new and old, with examples of the best and brightest nodes.</li>
<li>Weed out writeups, new and old, that just <i>don't make the grade</i>.  It's semantically impossible to draw a line in the sand that everyone is going to understand and, inevitably, a user will be upset that they've lost a writeup. If they want to know why, advice is located at [Writeup Deletion].
<p>If this has happened to you, take some time to peruse the nodes on [Page of Cool] and just observe E2 by clicking around for a few days before beginning to add your own content.</li>
<li>Editors are constantly [msg]ing new users to help them with their writing and noding skills. They also provide advice on how to integrate your writing into the site. Editors are always happy to answer a serious question  and a quick [Chatterbox|private msg] to them can often save a lot of frustration and time. <i>Let them help you.</i></li></ul>
<p><b>The Content Editor group is currently:</b></p>
<ol>
% foreach my $u(@{$.editors}) {
<li><& '/helpers/linknode.mi', node => $u &></li>
% }
</ol>

<br /><br /><hr width=250/><br /><br />
<h3>The [e2gods|gods] usergroup:</h3>

<p>Okay, now these users have got some [action].  The group has the following abilities:</p>

<ul>
<li>Gods have all the powers of the [Content Editor] group.</li>
<li>Gods have the power to bless a user. A '[bless]' grants the user 10 [GP]. Blessings are given for a multitude of reasons, often if a user offers helpful advice in the [chatterbox]. See [Golden Trinkets] for <i>your</i> blessings.</li>
<li>Gods can 'bestow 25 votes' unto <i>any</i> user. This means that that user will have 25 more votes to spend as they please that day. They can also bestow a C! Of course, most users of a certain level can do the same thing through the [E2 Gift Shop|Gift Shop].</li>
<li>Gods can delete an entire node or any writeups within a node. Gods handle [Edit these E2 titles|title edit requests] and help content editors handle the [Broken Nodes] by fixing spelling and misplaced links.  A god will not alter any meaningful text without a msg to the author. A god may leave an <b>Editor's Note:</b> within a given writeup to add a comment or clear up a misapprehension.</li>

<li>Gods can move a writeup from one node to another. This is done on a case by case basis, to choose where the writeup should go best. This is usually done in the case of duplicate content, or where many different writeups should be all put together in the most easy to find place. You want writeups to be in the right place for all time, but if that changes, the gods can shuffle them around a bit. A user will receive a msg if a writeup is moved.</li></ul>

<p>To clear up a few common myths: members of the gods group <em>cannot</em></p>

<ul>
<li>Vote on any given writeup more than once.</li>
<li>Vote on their own writeups.</li>
<li>Have any effect on the reputation of a writeup other than casting their single vote.</li>
<li>See the reputation of a writeup before casting their vote (except as described above, via [Everything User Search|the user search]).</li>
<li>Gods do not, contrary to popular belief, have infinite [C!|chings]. Both editors and gods <i>used</i> to have this power.</li>
</ul>

<p>The following is a list of users in the [gods] usergroup:</p>

<strong>Active:</strong>
<ol>
% foreach my $u(@{$.gods}) {
<li><& '/helpers/linknode.mi', node => $u &></li>
% }
</ol>

<strong>Inactive:</strong>
<ol>
% foreach my $u(@{$.inactive}) {
<li><& '/helpers/linknode.mi', node => $u &></li>
% }

</ol>

<hr width=250/>
<h2>Who does what?</h2>

<p>These people are in charge of things:</p>
<ul>
<li>[jaybonci]: Site owner</li>
<li>[Tem42]: Site management</li>
<li>[mauler]: Director of User Relations</li>
</ul>

<p>These administrators and editors have special assignments:</p>
<ul><li>[mauler]: [Everything User Poll|E2 Polls]</li></ul>

<p>The following staff members work with [jaybonci] to maintain and grow the site's code:</p>
<ul>
<li>[DonJaime]</li>
<li>[Oolong]</li>
<li>[in10se]</li>
<li>[ascorbic]</li>
<li>[call[user]]</li>
<li>[mauler]</li>
<li>[avalyn]</li>
<li>[Two Sheds]</li>
</ul>

<p>Copyright compliance:</p>
<ul>
<li>[avalyn]</li>
</ul>

<p>Documentation, FAQs, staff docs, [superdocs|sekrits]</p>
<ul><li>Position currently open</li></ul>

<hr width="250" />

<p>[SIGTITLE] user group: [Edit These E2 Titles|Node Titles]</p>
<ul>
% foreach my $u(@{$.sigtitle}) {
<li><& '/helpers/linknode.mi', node => $u &></li>
% }
</ul>

<br />
<hr width="250" />
<h2>Chanops</h2>
<p>People in this group are responsible for maintaining good order in the [Chatterbox]. Think of them as the moderators.</p>
<ul>
% foreach my $u(@{$.chanops}) {
<li><& '/helpers/linknode.mi', node => $u &></li>
% }
</ul>

<hr width="250" />
<p><b>That's it.</b> If you've any questions about this or anything else (regarding E2) please [message] [jaybonci] or [Tem42].</p>
