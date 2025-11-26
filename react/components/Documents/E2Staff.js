import React from 'react'
import ParseLinks from '../ParseLinks'
import LinkNode from '../LinkNode'

/**
 * E2 Staff Page - List of editors, gods, and staff with their roles
 *
 * Phase 4a migration from templates/pages/e2_staff.mc
 */
const E2Staff = ({ data }) => {
  const { editors, gods, inactive, sigtitle, chanops } = data

  return (
    <div className="e2-staff">
      <p>
        This document will explain the powers and functions of editors and <ParseLinks text="[gods]" />. If you have any questions about E2 and you've read <ParseLinks text="[Everything2 Help]" /> and looked through the links in your <ParseLinks text="[nodelet|nodelets]" /> please <ParseLinks text="[Chatterbox|/msg]" /> one of these volunteers and they will gladly help you out.
      </p>

      <ul>
        <li>
          The <big><strong>$</strong></big> symbol indicates the user is a <ParseLinks text="[content editors|Content Editor]" />. These users are charged with helping users on the site with any and all issues related to writeup creation, submission, and maintenance.
        </li>
        <li>
          The <big><strong>@</strong></big> symbol indicates the user is a <ParseLinks text="[e2gods|god]" />. These users are administrators who are charged keeping various aspects of the site running smoothly. Be warned: these users are not actual "gods" in the tradition of <ParseLinks text="[Odin]" />, <ParseLinks text="[Osiris]" /> and <ParseLinks text="[Shiva]" /> ... they are merely the 'gods' of E2. It's an antiquated nomenclature from the days when the only 'god' was <ParseLinks text="[nate]" /> so please forgive the blasphemy.
        </li>
        <li>
          Some members of the gods group concern themselves strictly with the site's code and do not bear any symbol in the Other Users list. These people do not perform administrative or editorial duties unless they also have the @ or $ symbol.
        </li>
        <li>
          The <big><strong>+</strong></big> symbol indicates that its bearer is a member of the <ParseLinks text="[chanops]" /> group, which manages the <ParseLinks text="[chatterbox]" />.
        </li>
      </ul>

      <hr width="250" />

      <p>
        If you're interested in being an Everything2 editor please sit tight and wait for a call. We're trying to keep the number of staff at 30 or less by rotating new blood in now and then based on activity, merit, <i>writing</i> skill, and ability to function in whichever role is needed at a given time. Also, I'll probably tap you on the shoulder quicker if you <i>don't</i> msg me about it. The <ParseLinks text="[gods]" /> group is always watching and suggestions for new editorial staff are passed around based on their observations.
      </p>

      <hr width="250" />

      <h3><ParseLinks text="[content editors|Content Editor]" /> Usergroup:</h3>
      <p>Membership in the content editor usergroup gives the user the following abilities:</p>
      <ul>
        <li>
          The power to <ParseLinks text="[cool]" /> a node. <ParseLinks text="[page of cool|Cooling]" /> a node simply places that node onto the <ParseLinks text="[Page of Cool]" />. It <i><b>does not</b></i> award any particular user with <ParseLinks text="[xp]" /> or change the reputation of <i>any</i> of the writeups within the node. The nodes featured on <ParseLinks text="[Page of Cool]" /> are meant to stand as examples of <ParseLinks text="[node for the ages|superior nodes]" />; nodes with writeups that are informative, humorous or just plain outstanding. <ParseLinks text="[Page of Cool]" /> is checked by hundreds of users daily and the resulting attention usually means many + votes--which an editor believed the writeups deserved. <b>Note:</b> A <ParseLinks text="[page of cool|Cool]" /> is <i><b>not</b></i> the same as a <ParseLinks text="[C!]" />.
        </li>
        <li>
          The power to remove things from New Writeups. When a writeup is deleted the author will lose the 5XP gained upon creation of said <ParseLinks text="[writeup]" /> but can rewrite and republish later. See <ParseLinks text="[Writeup Deletion]" /> for details.
        </li>
        <li>
          Content editors can actually edit the text of any writeup. They are assigned to go forth and fix spelling/punctuation errors or broken links in writeups. They are the editorial staff of E2 and help the <ParseLinks text="[gods]" /> group by handling <ParseLinks text="[e2 nuke request|deletion requests]" /> and error spotting/correcting.
        </li>
        <li>
          Content editors can place a <ParseLinks text="[firm link]" /> from one node to another node. The aim is to display a better suggestion for where a writeup should go (or where more information on a topic is most likely to be found). Think of it as a nudge in the right direction.
        </li>
        <li>
          Editors can <ParseLinks text="[soft lock]" /> a node - preventing further writeups from being added. This is always done with the understanding that if a user has a better writeup they should <ParseLinks text="[Drafts|create a draft]" /> and have an editor take a look. The node can be unlocked and the new writeup added if it's worthy.
        </li>
        <li>
          When doing a <ParseLinks text="[everything user search|user search]" /> on another user editors can see the reputation of that user's writeups, whether they've voted on them or not.
        </li>
      </ul>

      <p>The mission of these editors is three-fold:</p>
      <ul>
        <li>Provide users, new and old, with examples of the best and brightest nodes.</li>
        <li>
          Weed out writeups, new and old, that just <i>don't make the grade</i>. It's semantically impossible to draw a line in the sand that everyone is going to understand and, inevitably, a user will be upset that they've lost a writeup. If they want to know why, advice is located at <ParseLinks text="[Writeup Deletion]" />.
          <p>If this has happened to you, take some time to peruse the nodes on <ParseLinks text="[Page of Cool]" /> and just observe E2 by clicking around for a few days before beginning to add your own content.</p>
        </li>
        <li>
          Editors are constantly <ParseLinks text="[msg]" />ing new users to help them with their writing and noding skills. They also provide advice on how to integrate your writing into the site. Editors are always happy to answer a serious question and a quick <ParseLinks text="[Chatterbox|private msg]" /> to them can often save a lot of frustration and time. <i>Let them help you.</i>
        </li>
      </ul>

      <p><b>The Content Editor group is currently:</b></p>
      <ol>
        {editors.map((user, idx) => (
          <li key={user.node_id}>
            <LinkNode type="user" title={user.title} node_id={user.node_id} />
          </li>
        ))}
      </ol>

      <br /><br /><hr width="250" /><br /><br />

      <h3><ParseLinks text="[e2gods|gods]" /> usergroup:</h3>

      <p>Okay, now these users have got some <ParseLinks text="[action]" />. The group has the following abilities:</p>

      <ul>
        <li>Gods have all the powers of the <ParseLinks text="[Content Editor]" /> group.</li>
        <li>
          Gods have the power to bless a user. A <ParseLinks text="[bless]" /> grants the user 10 <ParseLinks text="[GP]" />. Blessings are given for a multitude of reasons, often if a user offers helpful advice in the <ParseLinks text="[chatterbox]" />. See <ParseLinks text="[Golden Trinkets]" /> for <i>your</i> blessings.
        </li>
        <li>
          Gods can 'bestow 25 votes' unto <i>any</i> user. This means that that user will have 25 more votes to spend as they please that day. They can also bestow a C! Of course, most users of a certain level can do the same thing through the <ParseLinks text="[E2 Gift Shop|Gift Shop]" />.
        </li>
        <li>
          Gods can delete an entire node or any writeups within a node. Gods handle <ParseLinks text="[Edit these E2 titles|title edit requests]" /> and help content editors handle the <ParseLinks text="[Broken Nodes]" /> by fixing spelling and misplaced links. A god will not alter any meaningful text without a msg to the author. A god may leave an <b>Editor's Note:</b> within a given writeup to add a comment or clear up a misapprehension.
        </li>
        <li>
          Gods can move a writeup from one node to another. This is done on a case by case basis, to choose where the writeup should go best. This is usually done in the case of duplicate content, or where many different writeups should be all put together in the most easy to find place. You want writeups to be in the right place for all time, but if that changes, the gods can shuffle them around a bit. A user will receive a msg if a writeup is moved.
        </li>
      </ul>

      <p>To clear up a few common myths: members of the gods group <em>cannot</em></p>

      <ul>
        <li>Vote on any given writeup more than once.</li>
        <li>Vote on their own writeups.</li>
        <li>Have any effect on the reputation of a writeup other than casting their single vote.</li>
        <li>See the reputation of a writeup before casting their vote (except as described above, via <ParseLinks text="[Everything User Search|the user search]" />).</li>
        <li>Gods do not, contrary to popular belief, have infinite <ParseLinks text="[C!|chings]" />. Both editors and gods <i>used</i> to have this power.</li>
      </ul>

      <p>The following is a list of users in the <ParseLinks text="[gods]" /> usergroup:</p>

      <strong>Active:</strong>
      <ol>
        {gods.map((user, idx) => (
          <li key={user.node_id}>
            <LinkNode type="user" title={user.title} node_id={user.node_id} />
          </li>
        ))}
      </ol>

      <strong>Inactive:</strong>
      <ol>
        {inactive.map((user, idx) => (
          <li key={user.node_id}>
            <LinkNode type="user" title={user.title} node_id={user.node_id} />
          </li>
        ))}
      </ol>

      <hr width="250" />
      <h2>Who does what?</h2>

      <p>These people are in charge of things:</p>
      <ul>
        <li><ParseLinks text="[jaybonci]" />: Site owner</li>
        <li><ParseLinks text="[Tem42]" />: Site management</li>
        <li><ParseLinks text="[mauler]" />: Director of User Relations</li>
      </ul>

      <p>These administrators and editors have special assignments:</p>
      <ul>
        <li><ParseLinks text="[mauler]" />: <ParseLinks text="[Everything User Poll|E2 Polls]" /></li>
      </ul>

      <p>The following staff members work with <ParseLinks text="[jaybonci]" /> to maintain and grow the site's code:</p>
      <ul>
        <li><ParseLinks text="[DonJaime]" /></li>
        <li><ParseLinks text="[Oolong]" /></li>
        <li><ParseLinks text="[in10se]" /></li>
        <li><ParseLinks text="[ascorbic]" /></li>
        <li><ParseLinks text="[call[user]]" /></li>
        <li><ParseLinks text="[mauler]" /></li>
        <li><ParseLinks text="[avalyn]" /></li>
        <li><ParseLinks text="[Two Sheds]" /></li>
      </ul>

      <p>Copyright compliance:</p>
      <ul>
        <li><ParseLinks text="[avalyn]" /></li>
      </ul>

      <p>Documentation, FAQs, staff docs, <ParseLinks text="[superdocs|sekrits]" /></p>
      <ul>
        <li>Position currently open</li>
      </ul>

      <hr width="250" />

      <p><ParseLinks text="[SIGTITLE]" /> user group: <ParseLinks text="[Edit These E2 Titles|Node Titles]" /></p>
      <ul>
        {sigtitle.map((user, idx) => (
          <li key={user.node_id}>
            <LinkNode type="user" title={user.title} node_id={user.node_id} />
          </li>
        ))}
      </ul>

      <br />
      <hr width="250" />
      <h2>Chanops</h2>
      <p>People in this group are responsible for maintaining good order in the <ParseLinks text="[Chatterbox]" />. Think of them as the moderators.</p>
      <ul>
        {chanops.map((user, idx) => (
          <li key={user.node_id}>
            <LinkNode type="user" title={user.title} node_id={user.node_id} />
          </li>
        ))}
      </ul>

      <hr width="250" />
      <p><b>That's it.</b> If you've any questions about this or anything else (regarding E2) please <ParseLinks text="[message]" /> <ParseLinks text="[jaybonci]" /> or <ParseLinks text="[Tem42]" />.</p>
    </div>
  )
}

export default E2Staff
