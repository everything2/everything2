import React from 'react'
import LinkNode from '../LinkNode'

/**
 * Online Only Messages - Documentation for /msg? command
 *
 * Explains how to send messages only to online members of a usergroup
 */
const OnlineOnlyMsg = ({ user }) => {
  const hasOfflineMsgs = user?.vars?.getofflinemsgs === '1'

  return (
    <div className="document">
      <p>
        <big><strong>Summary</strong></big><br />
        Typing<br />
        <code>/msg?</code> <var>group</var> <var>message</var><br />
        will only send to online members of that group, unless they have that long-winded-option picked, then they'll get it anyway.
      </p>

      <p>
        <big><strong>Detail</strong></big><br />
        Since some groups' messages seem to be only relevant for a short period of time, you can now send a /msg to only people that are currently online. This is done by simply appending a question mark, <big><big>?</big></big>, to the <code>/msg</code> command. For example, if I want to send a message to only the content editors that are active, I could do:
        <blockquote><code>
          /msg? content_editors Only those of you on right now will get this message!
        </code></blockquote>
        Note the <code>?</code> after the <code>/msg</code>. This could be useful for questions only useful for a short while, such as "Does anybody besides me think {user?.node_id && <LinkNode nodeId={user.node_id} title="SomeDumbTroll" />} is just a troll, and not just a misguided newbie?".<br />
        But what if you're one of those paranoid people who likes a full Message Inbox? Then you can simply visit <LinkNode title="user settings" /> and make sure the option with the verbose description that reads something like "get online-only messages while offline" is checked. You currently have this option {hasOfflineMsgs ? 'enabled, so you\'ll get messages marked for online-only, even when you aren\'t on E2' : 'disabled, so you will only get online-only messages while you are on E2'}.
      </p>

      <p><big><strong>Random Notes</strong></big></p>
      <ul>
        <li>normal /msgs (without the ? symbols) will act the same old way - they'll send to everybody in the group, offline and online</li>
        <li>if you send an online-only message after not loading a page recently, you may not be considered to be online, so it is possible you won't get the /msg</li>
        <li>a /msg sent this way will have the text "<code>OnO: </code>" in the front - this stands for <strong>on</strong>line <strong>o</strong>nly, which means it was sent using online-only mode; if somebody sends a group message that way, you probably should respond likewise (with <code>/msg?</code> instead of a plain <code>/msg</code></li>
      </ul>

      <p><big><strong>Q</strong></big> <small>(not FAQs, since there is only one question that has been only asked once)</small></p>
      <dl>
        <dt>Does online-only /msgs ignore cloaked users?</dt>
        <dd>No, online-only sends to everybody online, regardless of their cloaked status. (Essentially, being cloaked only changes other users' displays, nothing else.)</dd>
      </dl>
    </div>
  )
}

export default OnlineOnlyMsg
