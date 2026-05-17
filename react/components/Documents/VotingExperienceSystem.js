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

  return (
    <div className="voting-experience">
      <h2 className="voting-experience__heading voting-experience__h2">An Everything2 Help Document</h2>

      <h1 className="voting-experience__heading voting-experience__h1">Why it's important to read this before you begin writing</h1>
      <p className="voting-experience__paragraph">
        Everything2 may be unlike anything you have met before. Writers are rewarded for their writing,
        and gain certain privileges as they gain in experience.
      </p>

      <hr className="voting-experience__hr" />

      <div className="voting-experience__callout">
        XP is an <em>imaginary</em> number granted to you by an<br />
        <em>anonymous</em> stranger. Treat it as such.
      </div>

      <h3 className="voting-experience__heading voting-experience__h3">Votes</h3>
      <p className="voting-experience__paragraph">
        You begin as a Level 0 user. Level 1 users and up can vote on others' writeups.
        Once you have voted you will see the voting pattern of that writeup.
      </p>
      <p className="voting-experience__paragraph">
        Use these votes wisely! The reputation of a writeup doesn't mean it will be deleted,
        nor does it mean it will <em>not</em> be deleted, but it acts as one way to qualify
        written work and to help editors find what can often be a weak writeup. If one of your
        writeups is deleted, you will lose the <strong>five</strong> XP you gained when posting it.
      </p>
      <p className="voting-experience__paragraph">
        Try to vote according to the standard of writing, not because you agree or disagree
        with what someone has written.
      </p>
      <p className="voting-experience__paragraph">
        Voting and deletion are two ways we try to keep quality writeups coming in - a hastily/poorly
        written writeup will often gain a negative reputation. Conversely, if your writeups are voted
        up by your fellow users, you will gain XP. Details are below.
      </p>
      <p className="voting-experience__paragraph">
        <strong>Note:</strong> not all powers are gained instantly upon reaching a new level:
        votes and C!s refresh at midnight server time.
      </p>

      <h3 className="voting-experience__heading voting-experience__h3">C!s</h3>
      <p className="voting-experience__paragraph">
        One important power is the ability to grant a "C!" (also known as "C!ing" or "chinging").
        Beginning at 4th level, users will get the ability to C! an <em>individual</em> writeup
        by clicking the C! located next to the voting buttons. This will give the author of the
        writeup <strong>twenty</strong> XP, and kick the writeup to the front page and the Cool
        Archive for all to see.
      </p>
      <p className="voting-experience__paragraph">
        <strong>Use these chings wisely!</strong> Just because you have chings doesn't mean you
        should use them with careless abandon. Most users view a writeup's chings as an endorsement
        of <em>quality</em> regardless of the impulsive reason you may have chosen to bestow that
        "Attaboy". <em>Do you really want your name to be associated with something that we might
        consider to be stupid ten minutes/days/months from now?</em> Think twice before you click
        on that C!; chings spent in haste can be regretted in leisure.
      </p>
      <p className="voting-experience__paragraph">
        A writeup can be C!d <em>any number of times,</em> but only <strong>once</strong> by any
        given user.
      </p>

      <h3 className="voting-experience__heading voting-experience__h3">XP</h3>
      <p className="voting-experience__paragraph">
        Each of your writeups earns you 5 XP in addition to all the XP you get when people vote it
        up or cool it. If created using the guidelines detailed in The perfect node, they will pay
        off many times over in XP.
      </p>

      <h3 className="voting-experience__heading voting-experience__h3">The voting/level system:</h3>
      <p className="voting-experience__paragraph">
        (Note: You must meet <em>both</em> requirements to reach a level, and you lose the level
        if you drop below either requirement).
      </p>
      <p className="voting-experience__paragraph">
        <small>Your user level is highlighted.</small>
      </p>

      {error && <div className="voting-experience__error">{error}</div>}

      <form onSubmit={handleSubmit} className="voting-experience__form">
        <label>
          Show me all levels from Level{' '}
          <input
            type="number"
            value={firstLevel}
            onChange={(e) => setFirstLevel(parseInt(e.target.value, 10) || 0)}
            className="voting-experience__input"
          />
          {' '}to Level{' '}
          <input
            type="number"
            value={secondLevel}
            onChange={(e) => setSecondLevel(parseInt(e.target.value, 10) || 12)}
            className="voting-experience__input"
          />
          <button type="submit" className="voting-experience__button" disabled={loading}>
            {loading ? 'Loading...' : 'Show Levels!'}
          </button>
        </label>
      </form>

      {loading ? (
        <p>Loading level data...</p>
      ) : (
        <table className="voting-experience__table">
          <thead>
            <tr>
              <th className="voting-experience__th">Level</th>
              <th className="voting-experience__th">Level Title</th>
              <th className="voting-experience__th">XP Req</th>
              <th className="voting-experience__th">Writeups Req</th>
              <th className="voting-experience__th">Votes per Day</th>
              <th className="voting-experience__th">C!s per Day</th>
            </tr>
          </thead>
          <tbody>
            {levels.map((level, index) => (
              <tr key={index} className={level.is_user_level ? 'voting-experience__row--user-level' : ''}>
                <td className="voting-experience__td">{level.level}</td>
                <td className="voting-experience__td">{level.title}</td>
                <td className="voting-experience__td">{level.xp}</td>
                <td className="voting-experience__td">{level.writeups}</td>
                <td className="voting-experience__td">{level.votes}</td>
                <td className="voting-experience__td">{level.cools}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}

      <h3 className="voting-experience__heading voting-experience__h3">Powers:</h3>
      <ul className="voting-experience__list">
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

      <h3 className="voting-experience__heading voting-experience__h3">You can gain or lose XP in the following ways <em>only</em>:</h3>
      <ul className="voting-experience__list">
        <li>Each writeup you turn in gives you five XP. If it's later deleted, you lose that five XP.</li>
        <li>+20 XP each time one of your writeups is C!'d (Chinged by another user and sent to the Cool Archive)</li>
        <li>+1 XP every time another user upvotes one of your writeups.</li>
      </ul>

      <p className="voting-experience__paragraph">
        <strong>Please note</strong> that under this system, the XP requirement is entirely out of
        proportion to the writeup requirement. There is no correlation between number of writeups
        and the amount of XP one could reasonably be expected to have given that number of writeups.
        The writeup requirement exists solely as a safety net against unusual situations rather than
        a level guideline, and XP is the key value for advancement.
      </p>

      <p className="voting-experience__paragraph">
        <strong>Note:</strong> If a writeup you've submitted has accrued a positive reputation and
        it is deleted, you <em>will not</em> "lose" any XP you'd already gained for the + votes.
        You will only lose the 5 XP you got when you initially posted the writeup.
      </p>

      <p className="voting-experience__paragraph">
        Gaining and losing XP for adding and deleting also applies to "housekeeping" write-ups like
        Writeup Deletion Request and Node Title Edit. It can be disconcerting to gain and lose XP
        from these, but that's life.
      </p>

      <h3 className="voting-experience__heading voting-experience__h3">You can gain or lose GP in the following ways, and possibly others:</h3>
      <ul className="voting-experience__list">
        <li>Each time you cast a vote you have a 1 in 3 chance of gaining 1 GP.</li>
        <li>+10 GP every time you are blessed by an administrator.</li>
        <li>+10 GP every time you are sanctified by another user.</li>
        <li>+5 GP every time you are fireballed by another user in the chatterbox.</li>
        <li>+3 GP every time you are egged by another user in the chatterbox.</li>
        <li>variable GP rewards for participating in Quests and contests.</li>
        <li>GP can be spent at the E2 Gift Shop and similar nodes.</li>
      </ul>

      <div className="voting-experience__callout">
        <em>The administration does not take the voting and experience point system too terribly seriously.</em>
        <br />
        <u>Woe to those who do.</u>
      </div>

      <hr className="voting-experience__hr" />

      <p className="voting-experience__paragraph voting-experience__center">
        If this is not clear, ask questions in the Chatterbox or approach the E2 Staff
      </p>

      <p className="voting-experience__paragraph voting-experience__center voting-experience__back-link">
        <em>Back to</em><br />
        <strong>Everything2 Help</strong>
      </p>

      <p className="voting-experience__footer">
        If you believe that this document needs updating or correcting, /msg any member of E2Docs<br />
        Last updated on October 9, 2012 by wertperch
      </p>
    </div>
  )
}

export default VotingExperienceSystem
