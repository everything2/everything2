import React from 'react';

export default function EdevFAQ({ data }) {
  const { is_edev, user_title } = data;

  return (
    <div style={{ padding: '20px', fontFamily: 'Arial, sans-serif' }}>
      <p>
        Okey-dokey, here are some FAQs for those in the{' '}
        <a href="/user/edev">edev</a> usergroup.
        You, <a href={`/user/${encodeURIComponent(user_title)}?lastnode_id=`}>{user_title}</a>,{' '}
        {is_edev ? (
          <>
            <strong>are</strong> a respected <small>(haha, yeah, right!)</small>
          </>
        ) : (
          <>are <strong>not</strong> a</>
        )}{' '}
        member of the edev group here, on E2. In this FAQ, "I" is <a href="/user/N-Wing">N-Wing</a>.
      </p>

      <p>
        First: All E2 development is driven out of{' '}
        <a href="https://github.com/everything2/everything2">Github</a>. Anyone can spin up a
        development environment using Docker, see how it works, submit pull requests, or ask for
        features that they can work on. There's plenty to chip in on. Check out the{' '}
        <a href="https://github.com/everything2/everything2/issues">open issues</a> and feel free to
        start contributing.
      </p>

      <p><strong>Questions:</strong></p>
      <ol>
        <li><a href="#powers">What are some of my superpowers?</a></li>
        <li><a href="#msg">Why are random people sending me private messages that start with "EDEV:" or "ONO: EDEV:"?</a></li>
        <li><a href="#background">What is the background of edev and it's relationship to the development of the site/source?</a></li>
        <li><a href="#edevify">What is this "Edevify!" link thingy I see in my Epicenter nodelet?</a></li>
        <li><a href="#ownesite">Does everybody have their own Everything site for hacking on?</a></li>
        <li><a href="#edevite">What is an edevite?</a></li>
        <li><a href="#edevdoc">What is an Edevdoc?</a></li>
        <li><a href="#whyjoin">Why did others (or, why should I) join the edev group?</a></li>
        <li><a href="#improvements">How do we go about finding tasks here? If we have personal projects for the improvement of E2, what is the appropriate way to get started? Should I verify that what I'm thinking of is useful, or should I make it work and then submit source patches?</a></li>
      </ol>

      <hr />
      <a name="powers"><strong>Q: What are some of my superpowers?</strong></a>
      <p>A: I wouldn't say <em>superpowers</em>, just <em>powers</em>. Anyway:</p>
      <ul>
        <li>
          You're a hash! (in the <a href="/title/Other Users">Other Users</a> nodelet,{' '}
          <a href="#edevite">edevites</a> have a <code>%</code> next to their name
          (which is only viewable by fellow edevites))
        </li>
        <li>
          You can see the source code for many things here. If you visit something like a{' '}
          <a href="/title/superdoc">superdoc</a> (for example, this node), if you append{' '}
          <code>&amp;displaytype=viewcode</code> to the URL, it will show the code that generates
          that node. When you have the <a href="/title/Everything Developer">Everything Developer</a>{' '}
          nodelet turned on, you can more easily simply follow the little "viewcode" link
          (which only displays on nodes you may view the source for). For example, you can see
          this node's source by going{' '}
          <a href="?displaytype=viewcode">here</a>
        </li>
        <li>
          You can see other random things, like <a href="/title/dbtable">dbtables</a> (nodes and
          other things (like softlinks) are stored in tables in the database; viewing one shows
          the field names and storage types) and <a href="/title/theme">theme</a> (a theme contains
          information about a generic theme).
        </li>
        <li>
          You can see/use <a href="/title/List Nodes of Type">List Nodes of Type</a>, which lists
          nodes of a certain type. One example <small>(</small>ab<small>)</small>use of this is to
          get a list of rooms. <a href="/user/nate">nate</a> in{' '}
          <a href="/title/Edev First Post!">Edev First Post!</a>{' '}
          <small>(doesn't that sound like a troll title?)</small> lists some other node types you
          may be interested in. Actually, you should probably read that anyway, it has other
          starting information, too.
        </li>
        <li>
          You have your own (well, shared with editors and admins) section in{' '}
          <a href="/title/user settings 2">user settings 2</a>. (As of the time this FAQ was written,
          there is only 1 setting there, which is explained in the <a href="#msg">next question</a>.)
        </li>
        <li>
          You can <a href="/title/Edevify">Edevify</a> things. See the{' '}
          <a href="#edevify">later question</a> for more information about this.
        </li>
      </ul>

      <hr />
      <a name="msg"><strong>Q: Why/how are random people sending me private messages that have '([edev])' in front of them?</strong></a>
      <p>A (short): They aren't random people, and they aren't sending to just you.</p>
      <p>
        A (longer): When somebody is a member of a <a href="/title/usergroup">usergroup</a>, they
        can send a private message to that group, which will then be sent to everybody in that group.
        In this case, those "random people" are other people in the{' '}
        <a href="/user/edev">edev</a> usergroup, and they're typing something like this in the
        chatterbox:
      </p>
      <p>
        <code>/msg edev Hi everybody, I'm Doctor Nick! Have you seen [EDev FAQ] yet?</code>
      </p>
      <p>and (assuming the other person is you), everybody in edev would then get a message that looks something like:</p>
      <form style={{ marginBottom: '1em' }}>
        <input type="checkbox" />
        ([edev]) <i>{user_title} says</i> Hi everybody, I'm Doctor Nick! Have you seen [EDev FAQ] yet?
      </form>
      <p>
        If the <code>/msg</code> is changed to a <code>/msg?</code> instead (with the question mark),
        then that message is only sent to people that are currently online (which will make the
        message start with 'ONO: '). For the most part, there isn't much reason to send this type
        of message in the edev group. For a little more information about this feature, see{' '}
        <a href="/title/online only /msg">online only /msg</a>.
      </p>

      <hr />
      <a name="background"><strong>Q: What is the background of edev and it's relationship to the development of the site/source?</strong></a>
      <p>
        A: Edev is the coordination list for development of Everything2.com. It is used for
        discussion of new features or of modifications, or to help people debug their problems.
        Some code snippets people have written as part of edev have been incorporated into the
        E2 code here. The main way this happens is by creating Github pull requests.
      </p>

      <hr />
      <a name="edevify"><strong>Q: What is this "Edevify!" link thingy I see in my Epicenter nodelet?</strong></a>
      <p>
        A: This simply puts whatever node you're viewing on the <a href="/user/edev">edev</a>{' '}
        (usergroup) page. About the only time to use this is when you create a normal writeup
        that is relevant to edev. Note: this does not work on things like "group" nodes, which
        includes <a href="/title/e2node">e2nodes</a>; to "Edevify" your writeup, you must be
        viewing your writeup alone (the easiest way is to follow the idea/thing link when
        viewing your writeup from the e2node).
      </p>

      <hr />
      <a name="ownesite"><strong>Q: Does everybody have their own Everything site for hacking on?</strong></a>
      <p>
        A: Yes! Everything has a Docker-based development environment that makes it easy to spin
        up a local copy of the site. The repository is hosted on{' '}
        <a href="https://github.com/everything2/everything2">GitHub</a>, and the setup process is
        documented in the <code>docs/</code> folder. Starting up your very own copy of the
        environment is as simple as installing Docker, cloning the repository, and following the
        setup instructions.
      </p>
      <p>
        If you encounter issues during setup or while developing, please{' '}
        <a href="https://github.com/everything2/everything2/issues">open an issue</a> on GitHub
        with detailed debugging information (error messages, logs, steps to reproduce). Even better,
        if you've solved a problem or built a new feature, submit a pull request! The maintainers
        are happy to review contributions and help you get your changes merged.
      </p>

      <hr />
      <a name="edevite"><strong>Q: What is an edevite?</strong></a>
      <p>
        A: Instead of calling somebody "a member of the <a href="/user/edev">edev</a> group"
        or "in the <a href="/user/edev">edev</a> (user)group", I just call them an "edevite".
      </p>

      <hr />
      <a name="edevdoc"><strong>Q: What is an Edevdoc?</strong></a>
      <p>
        A: The <a href="/title/Edevdoc">Edevdoc</a> extends the{' '}
        <a href="/title/document">document</a> nodetype, but allows edevites (and only edevites)
        to create and view it. They are primarily useful in testing out APIs and writing
        Javascript pieces to test out new interfaces and functionality. You can also do it
        entirely in the development environment as well.
      </p>

      <hr />
      <a name="whyjoin"><strong>Q: Why did others (or, why should I) join the edev group?</strong></a>
      <p>
        A from <a href="/user/anotherone">anotherone</a>: I'm in the group because I like to
        take stuff apart, see how it works.{' '}
        <a href="/title/participate in your own manipulation">Understand what's going on</a>.
        I've had a few of my ideas implemented, and it was cool knowing that I'd done something useful.
      </p>
      <p>
        A from <a href="/user/conform">conform</a>: I'm interested (for the moment) on working
        on the theme implementation and I've got some ideas for nodelet UI improvements.
      </p>
      <p>
        A from <a href="/user/N-Wing">N-Wing</a>: I originally (way back in the old days of
        Everything 1) had fun trying to break/hack E1 (and later E2) (hence my previous E2 goal,
        "Breaking Everything"). Around the time I decided to start learning some Perl, the edev
        group was announced, so I was able to learn Perl from working code <strong>and</strong>{' '}
        find more problems in E2 at the same time. (However, it wasn't until later I realized
        that E2 isn't the best place to start learning Perl from. <code>:)</code>)
      </p>

      <hr />
      <a name="improvements"><strong>Q: How do we go about finding tasks here? If we have personal projects for the improvement of E2, what is the appropriate way to get started? Should I verify that what I'm thinking of is useful, or should I make it work and then submit source patches?</strong></a>
      <p>
        A: Generally, feel free to post a message to the group or{' '}
        <a href="https://github.com/everything2/everything2/issues">open an issue</a> on GitHub.
        Check the existing issues to see if someone is already working on something similar,
        or browse for good first issues to tackle. When opening an issue, provide as much detail
        as possible about what you want to build and why. Once you've built something, submit a
        pull request with a clear description of your changes and any relevant testing you've done.
      </p>
    </div>
  );
}
