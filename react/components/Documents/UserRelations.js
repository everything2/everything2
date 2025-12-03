import React from 'react'

/**
 * UserRelations - E2 User Relations help document
 *
 * Explains the e2contact (e2c) and chanops groups, their responsibilities,
 * and how they support both new and existing users.
 */
const UserRelations = ({ data }) => {
  const {
    e2contact_node_id,
    chanops_node_id,
    leader,
    director,
    e2contact_members = [],
    chanops_members = []
  } = data

  // Kernel Blue color scheme
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    background: '#f8f9f9'
  }

  const containerStyle = {
    padding: '20px',
    maxWidth: '900px',
    lineHeight: '1.7',
    color: colors.primary
  }

  const h2Style = {
    textAlign: 'center',
    fontSize: '28px',
    color: colors.primary,
    marginBottom: '30px',
    borderBottom: `2px solid ${colors.primary}`,
    paddingBottom: '15px'
  }

  const h3Style = {
    fontSize: '22px',
    color: colors.primary,
    marginTop: '35px',
    marginBottom: '15px'
  }

  const h5Style = {
    fontSize: '18px',
    color: colors.secondary,
    marginTop: '25px',
    marginBottom: '12px',
    fontWeight: 'bold'
  }

  const paragraphStyle = {
    marginBottom: '16px',
    textAlign: 'justify'
  }

  const linkStyle = {
    color: colors.highlight,
    textDecoration: 'none'
  }

  const listStyle = {
    marginLeft: '30px',
    marginBottom: '16px',
    lineHeight: '1.8'
  }

  const memberListStyle = {
    ...listStyle,
    listStyleType: 'disc'
  }

  const olStyle = {
    ...listStyle,
    listStyleType: 'decimal'
  }

  const highlightBoxStyle = {
    backgroundColor: colors.background,
    padding: '20px',
    borderLeft: `4px solid ${colors.highlight}`,
    marginTop: '30px',
    marginBottom: '30px',
    fontStyle: 'italic'
  }

  return (
    <div style={containerStyle}>
      <h2 style={h2Style}>E2contact (e2c) and chanops</h2>

      <h3 style={h3Style}>What is e2c?</h3>
      <p style={paragraphStyle}>
        {e2contact_node_id ? (
          <a href={`/node/${e2contact_node_id}`} style={linkStyle}>e2contact</a>
        ) : (
          'E2contact'
        )} is a subset of everything2's editorial staff dedicated to user relations,
        for both new and existing users.
      </p>

      <h3 style={h3Style}>Why is e2c necessary?</h3>
      <p style={paragraphStyle}>
        e2 is a diverse and complicated community, which presents challenges for both new and
        established users. In addition to the technical learning curve that new users are expected
        to climb, they must also tackle the social and cultural element of the site, which can
        present as hostile or overwhelming initially. As with any community, there exist tensions
        and relationship issues between established users. By creating a team of staff dedicated to
        user relations, to help new users navigate their paths through their first weeks and to help
        established users get the most out of the site, it is hoped to improve e2's user experience,
        thereby allowing for a more creative and productive site.
      </p>

      <h3 style={h3Style}>Who operates e2c?</h3>
      <p style={paragraphStyle}>
        e2c is currently led by {leader ? (
          <a href={`/node/${leader.node_id}`} style={linkStyle}>{leader.title}</a>
        ) : (
          'mauler'
        )}, everything2's Director of User Relations, who reports into {director ? (
          <a href={`/node/${director.node_id}`} style={linkStyle}>{director.title}</a>
        ) : (
          'Tem42'
        )} as everything2's Director of Operations.
      </p>

      {e2contact_members.length > 0 ? (
        <>
          <p style={paragraphStyle}>They are supported by:</p>
          <ul style={memberListStyle}>
            {e2contact_members.map((member, idx) => (
              <li key={idx}>
                <a href={`/node/${member.node_id}`} style={linkStyle}>{member.title}</a>
              </li>
            ))}
          </ul>
        </>
      ) : (
        <>
          <p style={paragraphStyle}>They are supported by:</p>
          <ul style={memberListStyle}>
            <li><a href="/node/user/Dimview" style={linkStyle}>Dimview</a></li>
            <li><a href="/node/user/karma%20debt" style={linkStyle}>karma debt</a></li>
            <li><a href="/node/user/TheDeadGuy" style={linkStyle}>TheDeadGuy</a></li>
            <li><a href="/node/user/vandewal" style={linkStyle}>vandewal</a></li>
          </ul>
        </>
      )}

      <p style={paragraphStyle}>
        The {chanops_node_id ? (
          <a href={`/node/${chanops_node_id}`} style={linkStyle}>chanops</a>
        ) : (
          'chanops'
        )} group, which acts similarly to IRC channel operators, falls under e2c's umbrella.
        Following the devolution of catbox powers in May 2009, some gods opted to retain their
        catbox operational facilities, and joined chanops, too. More on their work can be found
        under 'Catbox drama' in this document.
      </p>

      {chanops_members.length > 0 ? (
        <>
          <p style={paragraphStyle}>The present members of chanops are:</p>
          <ul style={memberListStyle}>
            {chanops_members.map((member, idx) => (
              <li key={idx}>
                <a href={`/node/${member.node_id}`} style={linkStyle}>{member.title}</a>
              </li>
            ))}
          </ul>
        </>
      ) : (
        <>
          <p style={paragraphStyle}>The present members of chanops are:</p>
          <ul style={memberListStyle}>
            <li><a href="/node/user/BookReader" style={linkStyle}>BookReader</a></li>
            <li><a href="/node/user/GhettoAardvark" style={linkStyle}>GhettoAardvark</a></li>
            <li><a href="/node/user/moosemanmoo" style={linkStyle}>moosemanmoo</a></li>
            <li><a href="/node/user/NanceMuse" style={linkStyle}>NanceMuse</a></li>
            <li><a href="/node/user/Oolong" style={linkStyle}>Oolong</a></li>
            <li><a href="/node/user/riverrun" style={linkStyle}>riverrun</a></li>
          </ul>
        </>
      )}

      <p style={paragraphStyle}>
        All members of e2c and chanops have the ability to flush the chatterbox and drag users into
        other rooms as necessary.
      </p>

      <h3 style={h3Style}>What are e2c's fields of operation?</h3>
      <p style={paragraphStyle}>e2c has four primary spheres of operation:</p>
      <ol style={olStyle}>
        <li>New user interaction</li>
        <li>Existing user relations</li>
        <li>Catbox drama</li>
        <li>The mentoring system</li>
      </ol>

      <h5 style={h5Style}>New user interaction</h5>
      <p style={paragraphStyle}>
        Until recently, new users to the site were greeted by an array of automated or rehearsed
        messages, directing them to the FAQs. e2c has adopted a more simplified approach to greeting
        new users, sending messages only when a new user has begun to interact with the site in some
        way – for example by speaking in the catbox – and then only to say hello and ask if she or
        he would like any help. We would rather that new users have the opportunity to explore, than
        us bombard and overwhelm their first experiences here. For users who weren't welcomed or
        greeted by a member of staff, you'll remember that part if the wonder was being able to wander.
      </p>

      <p style={paragraphStyle}>
        Members of e2c will be available to offer both technical assistance and help of a more
        abstract nature, for example helping new users to understand e2's culture. In particular,
        e2c intends to help new users learn what it is that e2 looks for in a writeup. However, the
        aim is to be personal and personable, rather than just directing someone to the FAQs.
      </p>

      <p style={paragraphStyle}>
        If a new user submits a writeup that is questionable, borderline or otherwise isn't to the
        standards and expectations of the site, she or he will be asked to use the scratchpad facility
        and have her or his draft proofed by an editor prior to submission. New users should also be
        urged towards the mentoring programme. Any persistently difficult or troublesome users should
        be referred directly to either TheDeadGuy or mauler.
      </p>

      <p style={paragraphStyle}>
        Troublesome users are a fact of the site; they are always going to be there. Those users whose
        actions are clearly detrimental to the site and show no willingness or ability to contribute in
        a positive way should be encouraged to move along. However, it is also important to try to see
        through the bravura, the bluster, and the general ignorance of some of these people. Never
        forget that new users have no real vested interest in the site in the way established users do
        and have no real reason to submit their 'good material' unless they are given a reason to.
        Users need to be encouraged, respected, and listened to by staff. For example, just because a
        user submits a series of ridiculous, stupid, or silly writeups does not mean they are incapable
        of more. She or he may very well be incapable of more than that, but many may just land on the
        site thinking: 'What fun! I can submit random shit!' That's what TheDeadGuy did when he first
        came to e2.
      </p>

      <h5 style={h5Style}>Existing user relations</h5>
      <p style={paragraphStyle}>
        e2 is a community. All communities have dynamics, points of inertia, tensions, conflicts,
        tragedies, and celebrations. e2 is no different from any other community in this respect.
        Relationships between users, and between users and site management, can therefore on occasion
        become strained or difficult. For example, it is possible that two users can come into conflict
        with each other, or an existing user can feel unhappy about a change to site policy. Without
        wanting to be seen as some form of marriage guidance counselling service, e2c can be made
        available to help bring some calm and some dialogue in these situations.
      </p>

      <p style={paragraphStyle}>
        There has been a recent suggestion by some older users that the site is not as respectful
        towards them and their concerns as it should be. Quite specifically, there have been accusations
        that their contributions are not valued as much as those of newer and more prolific writers.
        e2c is aimed at user relations, and these concerns are just as valid as the learning experiences
        of a new user; therefore, e2c should be prepared to listen to these points and to act on them
        as appropriate.
      </p>

      <h5 style={h5Style}>Catbox drama</h5>
      <p style={paragraphStyle}>
        From time-to-time, users choose to play out their personal dramas in the public forum of the
        catbox. This can and does distress and arouse alarm in other users. Whilst e2c or chanops can
        have no formal powers of intervention in such situations, there are protocols laid down for
        dealing with situations where users are threatening suicide, and guidance for young users is in
        development. Remaining calm and minimising the situation is key in these instances and members
        of e2c and chanops are expected to act appropriately as such occasions arise.
      </p>

      <p style={paragraphStyle}>
        In addition to site administrators, members of e2c and chanops also have the ability to drag
        users who are behaving inappropriately or offensively in the catbox from the main room to the
        debriefing room. Once dragged to the debriefing room, users are held there for 30 minutes. It
        is not expected for these users to be left alone there, but for she or he to be accompanied by
        a member of staff and the rationale for expulsion explicated. This feature has proved effective
        so far and it is expected for e2c and chanops operators to use it at their discretion.
      </p>

      <h5 style={h5Style}>The mentoring system</h5>
      <p style={paragraphStyle}>
        Also falling in e2c's remit will be the mentoring system, which is planned for a revamp.
        Members of e2c may be asked to volunteer their time and effort into that programme. In the
        past, the mentoring system was an effective mechanism for guiding new users through the site,
        which has fallen into relative disuse recently. There is no reason why it can't operate
        successfully again. New users who indicate a desire or show a need for one-on-one guidance
        will be encouraged towards the mentoring programme.
      </p>

      <p style={paragraphStyle}>
        The mentoring programme is designed to offer longer-term attention to newer users; whereas e2c
        is intended to provide them with more immediate and short-term support.
      </p>

      <h3 style={h3Style}>And finally…</h3>
      <div style={highlightBoxStyle}>
        Throughout everything that we do, it is worth remembering that e2 is people. If we take care
        of the people, the content will take care of itself. That comes from alex, but it has never
        seemed more apt.
      </div>
    </div>
  )
}

export default UserRelations
