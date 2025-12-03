import React, { useState, useEffect } from 'react'

/**
 * VotingExperienceSystem - Help document explaining E2's voting and XP system
 *
 * Displays comprehensive information about:
 * - Voting mechanics
 * - XP/GP gaining and losing
 * - User levels and requirements
 * - Powers unlocked at each level
 */
const VotingExperienceSystem = ({ data }) => {
  const { levels: initialLevels, first_level: initialFirst, second_level: initialSecond, user_level: userLevel } = data

  const [levels, setLevels] = useState(initialLevels || [])
  const [firstLevel, setFirstLevel] = useState(initialFirst || 0)
  const [secondLevel, setSecondLevel] = useState(initialSecond || 12)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  // Kernel Blue color scheme
  const colors = {
    primary: '#38495e',
    secondary: '#507898',
    highlight: '#4060b0',
    accent: '#3bb5c3',
    background: '#f8f9f9',
    border: '#d3d3d3',
    warning: '#8b4513',
    userLevel: '#fffacd'
  }

  const loadLevels = async (first, second) => {
    setLoading(true)
    setError(null)

    try {
      const response = await fetch(`/api/levels/get_levels?first_level=${first}&second_level=${second}`)
      const result = await response.json()

      if (result.success) {
        setLevels(result.levels || [])
        setFirstLevel(result.first_level)
        setSecondLevel(result.second_level)
      } else {
        setError(result.error || 'Failed to load level data')
      }
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleSubmit = (e) => {
    e.preventDefault()
    const diff = secondLevel - firstLevel
    if (diff > 99) {
      setError('Cannot display more than 100 levels at a time. Please choose fewer levels.')
      return
    }
    if (diff < 0) {
      setError('Second level must be greater than or equal to first level.')
      return
    }
    loadLevels(firstLevel, secondLevel)
  }

  const containerStyle = {
    padding: '20px',
    maxWidth: '900px',
    lineHeight: '1.6'
  }

  const headingStyle = {
    color: colors.primary,
    marginTop: '30px',
    marginBottom: '15px'
  }

  const h1Style = {
    ...headingStyle,
    fontSize: '28px',
    borderBottom: `2px solid ${colors.primary}`,
    paddingBottom: '10px'
  }

  const h2Style = {
    ...headingStyle,
    fontSize: '22px'
  }

  const h3Style = {
    ...headingStyle,
    fontSize: '18px',
    marginTop: '25px'
  }

  const paragraphStyle = {
    marginBottom: '15px',
    color: colors.primary
  }

  const calloutStyle = {
    textAlign: 'center',
    fontSize: '20px',
    fontStyle: 'italic',
    margin: '30px 0',
    padding: '20px',
    backgroundColor: colors.background,
    border: `2px solid ${colors.border}`,
    borderRadius: '8px'
  }

  const formStyle = {
    margin: '20px 0',
    padding: '15px',
    backgroundColor: colors.background,
    border: `1px solid ${colors.border}`,
    borderRadius: '4px'
  }

  const inputStyle = {
    padding: '6px',
    margin: '0 8px',
    border: `1px solid ${colors.border}`,
    borderRadius: '3px',
    width: '80px'
  }

  const buttonStyle = {
    padding: '6px 16px',
    marginLeft: '10px',
    backgroundColor: colors.primary,
    color: '#ffffff',
    border: 'none',
    borderRadius: '3px',
    cursor: 'pointer'
  }

  const tableStyle = {
    width: '100%',
    borderCollapse: 'collapse',
    margin: '20px 0',
    fontSize: '14px'
  }

  const thStyle = {
    backgroundColor: colors.primary,
    color: '#ffffff',
    padding: '10px 8px',
    textAlign: 'left',
    border: `1px solid ${colors.border}`,
    fontWeight: 'bold'
  }

  const tdStyle = {
    border: `1px solid ${colors.border}`,
    padding: '8px'
  }

  const userLevelRowStyle = {
    backgroundColor: colors.userLevel,
    fontWeight: 'bold'
  }

  const ulStyle = {
    marginLeft: '20px',
    lineHeight: '1.8'
  }

  const hrStyle = {
    border: 'none',
    borderTop: `1px solid ${colors.border}`,
    margin: '30px auto',
    width: '250px'
  }

  const errorStyle = {
    color: colors.warning,
    padding: '10px',
    backgroundColor: '#fff3cd',
    border: `1px solid ${colors.warning}`,
    borderRadius: '4px',
    marginBottom: '15px'
  }

  return (
    <div style={containerStyle}>
      <h2 style={h2Style}>An Everything2 Help Document</h2>

      <h1 style={h1Style}>Why it's important to read this before you begin writing</h1>
      <p style={paragraphStyle}>
        Everything2 may be unlike anything you have met before. Writers are rewarded for their writing,
        and gain certain privileges as they gain in experience.
      </p>

      <hr style={hrStyle} />

      <div style={calloutStyle}>
        XP is an <em>imaginary</em> number granted to you by an<br />
        <em>anonymous</em> stranger. Treat it as such.
      </div>

      <h3 style={h3Style}>Votes</h3>
      <p style={paragraphStyle}>
        You begin as a Level 0 user. Level 1 users and up can vote on others' writeups.
        Once you have voted you will see the voting pattern of that writeup.
      </p>
      <p style={paragraphStyle}>
        Use these votes wisely! The reputation of a writeup doesn't mean it will be deleted,
        nor does it mean it will <em>not</em> be deleted, but it acts as one way to qualify
        written work and to help editors find what can often be a weak writeup. If one of your
        writeups is deleted, you will lose the <strong>five</strong> XP you gained when posting it.
      </p>
      <p style={paragraphStyle}>
        Try to vote according to the standard of writing, not because you agree or disagree
        with what someone has written.
      </p>
      <p style={paragraphStyle}>
        Voting and deletion are two ways we try to keep quality writeups coming in - a hastily/poorly
        written writeup will often gain a negative reputation. Conversely, if your writeups are voted
        up by your fellow users, you will gain XP. Details are below.
      </p>
      <p style={paragraphStyle}>
        <strong>Note:</strong> not all powers are gained instantly upon reaching a new level:
        votes and C!s refresh at midnight server time.
      </p>

      <h3 style={h3Style}>C!s</h3>
      <p style={paragraphStyle}>
        One important power is the ability to grant a "C!" (also known as "C!ing" or "chinging").
        Beginning at 4th level, users will get the ability to C! an <em>individual</em> writeup
        by clicking the C! located next to the voting buttons. This will give the author of the
        writeup <strong>twenty</strong> XP, and kick the writeup to the front page and the Cool
        Archive for all to see.
      </p>
      <p style={paragraphStyle}>
        <strong>Use these chings wisely!</strong> Just because you have chings doesn't mean you
        should use them with careless abandon. Most users view a writeup's chings as an endorsement
        of <em>quality</em> regardless of the impulsive reason you may have chosen to bestow that
        "Attaboy". <em>Do you really want your name to be associated with something that we might
        consider to be stupid ten minutes/days/months from now?</em> Think twice before you click
        on that C!; chings spent in haste can be regretted in leisure.
      </p>
      <p style={paragraphStyle}>
        A writeup can be C!d <em>any number of times,</em> but only <strong>once</strong> by any
        given user.
      </p>

      <h3 style={h3Style}>XP</h3>
      <p style={paragraphStyle}>
        Each of your writeups earns you 5 XP in addition to all the XP you get when people vote it
        up or cool it. If created using the guidelines detailed in The perfect node, they will pay
        off many times over in XP.
      </p>

      <h3 style={h3Style}>The voting/level system:</h3>
      <p style={paragraphStyle}>
        (Note: You must meet <em>both</em> requirements to reach a level, and you lose the level
        if you drop below either requirement).
      </p>
      <p style={paragraphStyle}>
        <small>Your user level is highlighted.</small>
      </p>

      {error && <div style={errorStyle}>{error}</div>}

      <form onSubmit={handleSubmit} style={formStyle}>
        <label>
          Show me all levels from Level{' '}
          <input
            type="number"
            value={firstLevel}
            onChange={(e) => setFirstLevel(parseInt(e.target.value, 10) || 0)}
            style={inputStyle}
          />
          {' '}to Level{' '}
          <input
            type="number"
            value={secondLevel}
            onChange={(e) => setSecondLevel(parseInt(e.target.value, 10) || 12)}
            style={inputStyle}
          />
          <button type="submit" style={buttonStyle} disabled={loading}>
            {loading ? 'Loading...' : 'Show Levels!'}
          </button>
        </label>
      </form>

      {loading ? (
        <p>Loading level data...</p>
      ) : (
        <table style={tableStyle}>
          <thead>
            <tr>
              <th style={thStyle}>Level</th>
              <th style={thStyle}>Level Title</th>
              <th style={thStyle}>XP Req</th>
              <th style={thStyle}>Writeups Req</th>
              <th style={thStyle}>Votes per Day</th>
              <th style={thStyle}>C!s per Day</th>
            </tr>
          </thead>
          <tbody>
            {levels.map((level, index) => (
              <tr key={index} style={level.is_user_level ? userLevelRowStyle : {}}>
                <td style={tdStyle}>{level.level}</td>
                <td style={tdStyle}>{level.title}</td>
                <td style={tdStyle}>{level.xp}</td>
                <td style={tdStyle}>{level.writeups}</td>
                <td style={tdStyle}>{level.votes}</td>
                <td style={tdStyle}>{level.cools}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h3 style={h3Style}>Powers:</h3>
      <ul style={ulStyle}>
        <li>Level 0 — Joining Everything2 gives you the ability to contribute writeups, communicate with other members via the Chatterbox and message system, customise your view of the site in User Settings, etc.</li>
        <li>Level 1 — Can vote on E2 writeups by other users. Can give Stars to other users at the E2 Gift Shop. Can display a small (uncopyrighted) image in your home node (Nope, no porn allowed!).</li>
        <li>Level 2 — Can buy additional votes at the E2 Gift Shop; can create categories.</li>
        <li>Level 3 — Can create polls; can post a bounty on Everything's Most Wanted.</li>
        <li>Level 4 — C! power!</li>
        <li>Level 5 — Can display a larger homenode image (up to 400×800), ability to create rooms in the Chatterbox</li>
        <li>Level 6 — Can reset the chatterbox topic by buying a token at the E2 Gift Shop.</li>
        <li>Level 7 — Can buy easter eggs at the E2 Gift Shop, and give them to other users.</li>
        <li>Level 8 — Can create registries.</li>
        <li>Level 9 — Can give votes to other users at the E2 Gift Shop.</li>
        <li>Level 10 — Can Cloak oneself in the Other Users nodelet.</li>
        <li>Level 11 — Can Sanctify other users with GP.</li>
        <li>Level 12 — Can purchase up to one extra C! per day at the E2 Gift Shop</li>
        <li>Level 15 — Fireball! Can "fireball" other users in the chatterbox using the /fireball command.</li>
      </ul>

      <h3 style={h3Style}>You can gain or lose XP in the following ways <em>only</em>:</h3>
      <ul style={ulStyle}>
        <li>Each writeup you turn in gives you five XP. If it's later deleted, you lose that five XP.</li>
        <li>+20 XP each time one of your writeups is C!'d (Chinged by another user and sent to the Cool Archive)</li>
        <li>+1 XP every time another user upvotes one of your writeups.</li>
      </ul>

      <p style={paragraphStyle}>
        <strong>Please note</strong> that under this system, the XP requirement is entirely out of
        proportion to the writeup requirement. There is no correlation between number of writeups
        and the amount of XP one could reasonably be expected to have given that number of writeups.
        The writeup requirement exists solely as a safety net against unusual situations rather than
        a level guideline, and XP is the key value for advancement.
      </p>

      <p style={paragraphStyle}>
        <strong>Note:</strong> If a writeup you've submitted has accrued a positive reputation and
        it is deleted, you <em>will not</em> "lose" any XP you'd already gained for the + votes.
        You will only lose the 5 XP you got when you initially posted the writeup.
      </p>

      <p style={paragraphStyle}>
        Gaining and losing XP for adding and deleting also applies to "housekeeping" write-ups like
        Writeup Deletion Request and Node Title Edit. It can be disconcerting to gain and lose XP
        from these, but that's life.
      </p>

      <h3 style={h3Style}>You can gain or lose GP in the following ways, and possibly others:</h3>
      <ul style={ulStyle}>
        <li>Each time you cast a vote you have a 1 in 3 chance of gaining 1 GP.</li>
        <li>+10 GP every time you are blessed by an administrator.</li>
        <li>+10 GP every time you are sanctified by another user.</li>
        <li>+5 GP every time you are fireballed by another user in the chatterbox.</li>
        <li>+3 GP every time you are egged by another user in the chatterbox.</li>
        <li>variable GP rewards for participating in Quests and contests.</li>
        <li>GP can be spent at the E2 Gift Shop and similar nodes.</li>
      </ul>

      <div style={calloutStyle}>
        <em>The administration does not take the voting and experience point system too terribly seriously.</em>
        <br />
        <u>Woe to those who do.</u>
      </div>

      <hr style={hrStyle} />

      <p style={{ textAlign: 'center', ...paragraphStyle }}>
        If this is not clear, ask questions in the Chatterbox or approach the E2 Staff
      </p>

      <p style={{ textAlign: 'center', fontSize: '18px', ...paragraphStyle }}>
        <em>Back to</em><br />
        <strong>Everything2 Help</strong>
      </p>

      <p style={{ textAlign: 'right', fontSize: '12px', color: colors.secondary, marginTop: '40px' }}>
        If you believe that this document needs updating or correcting, /msg any member of E2Docs<br />
        Last updated on October 9, 2012 by wertperch
      </p>
    </div>
  )
}

export default VotingExperienceSystem
