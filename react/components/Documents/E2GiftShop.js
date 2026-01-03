import React, { useState, useCallback } from 'react'
import LinkNode from '../LinkNode'

const styles = {
  container: {
    maxWidth: '800px',
    margin: '0 auto',
    padding: '20px',
  },
  header: {
    textAlign: 'center',
    marginBottom: '30px',
    borderBottom: '2px solid #38495e',
    paddingBottom: '15px',
  },
  title: {
    fontSize: '28px',
    fontWeight: '600',
    color: '#38495e',
    margin: 0,
  },
  section: {
    marginBottom: '30px',
    padding: '20px',
    backgroundColor: '#f8f9fa',
    borderRadius: '8px',
    border: '1px solid #dee2e6',
  },
  sectionTitle: {
    fontSize: '18px',
    fontWeight: '600',
    color: '#38495e',
    marginBottom: '15px',
    paddingBottom: '10px',
    borderBottom: '1px solid #dee2e6',
  },
  divider: {
    border: 'none',
    borderTop: '1px solid #dee2e6',
    margin: '20px auto',
    width: '300px',
  },
  paragraph: {
    marginBottom: '15px',
    lineHeight: '1.6',
    color: '#495057',
  },
  form: {
    marginTop: '15px',
  },
  formRow: {
    display: 'flex',
    flexWrap: 'wrap',
    gap: '10px',
    alignItems: 'center',
    marginBottom: '10px',
  },
  label: {
    color: '#495057',
  },
  input: {
    padding: '8px 12px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    fontSize: '14px',
  },
  inputSmall: {
    width: '80px',
    padding: '8px 12px',
    border: '1px solid #ced4da',
    borderRadius: '4px',
    fontSize: '14px',
  },
  checkbox: {
    marginRight: '5px',
  },
  button: {
    padding: '10px 20px',
    backgroundColor: '#38495e',
    color: '#fff',
    border: 'none',
    borderRadius: '4px',
    cursor: 'pointer',
    fontSize: '14px',
    fontWeight: '500',
  },
  buttonDisabled: {
    backgroundColor: '#adb5bd',
    cursor: 'not-allowed',
  },
  success: {
    backgroundColor: '#d4edda',
    color: '#155724',
    padding: '12px 16px',
    borderRadius: '4px',
    marginTop: '10px',
    border: '1px solid #c3e6cb',
  },
  error: {
    backgroundColor: '#f8d7da',
    color: '#721c24',
    padding: '12px 16px',
    borderRadius: '4px',
    marginTop: '10px',
    border: '1px solid #f5c6cb',
  },
  info: {
    backgroundColor: '#d1ecf1',
    color: '#0c5460',
    padding: '12px 16px',
    borderRadius: '4px',
    marginBottom: '15px',
    border: '1px solid #bee5eb',
  },
  highlight: {
    fontWeight: '600',
  },
  selfExam: {
    marginTop: '30px',
    padding: '20px',
    backgroundColor: '#fff3cd',
    borderRadius: '8px',
    border: '1px solid #ffc107',
  },
}

// Gift of Star section
const GiftOfStar = ({ data, user, onUpdate }) => {
  const [recipient, setRecipient] = useState('')
  const [color, setColor] = useState('Gold')
  const [reason, setReason] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)

  const { userLevel, starCost, gp, gpOptOut } = data

  if (gpOptOut) return null
  if (userLevel < 1) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>The Gift of Star</h3>
        <p style={styles.paragraph}>
          Sorry, you must be at least <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display="Level 1" /> to purchase a Star.
        </p>
      </div>
    )
  }

  const canAfford = gp >= starCost

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/star', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ recipient, color, reason }),
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: result.message })
        setRecipient('')
        setReason('')
        onUpdate({ gp: result.newGP })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>The Gift of Star</h3>
      <p style={styles.paragraph}>
        Because you are Level 1 or higher, you have the power to purchase a Star to reward other users.
        For Level {userLevel} users, Stars currently cost <span style={styles.highlight}>{starCost} GP</span>.
        {starCost > 25 && ' Gain another level to reduce the Star cost by 5 GP.'}
      </p>
      <p style={styles.paragraph}>
        Giving a user a Star sends them a private message telling them that you have given them a Star
        and informing them of the reason why they earned it.
      </p>

      {!canAfford ? (
        <p style={styles.paragraph}>
          Sorry, you do not have enough GP to buy a Star right now. Please come back when you have <span style={styles.highlight}>{starCost} GP</span>.
        </p>
      ) : (
        <>
          <p style={styles.paragraph}>You have <span style={styles.highlight}>{gp} GP</span>.</p>
          <form onSubmit={handleSubmit} style={styles.form}>
            <div style={styles.formRow}>
              <span style={styles.label}>Yes! Please give a</span>
              <input
                type="text"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                style={{ ...styles.input, width: '100px' }}
                placeholder="Gold"
              />
              <span style={styles.label}>Star to noder</span>
              <input
                type="text"
                value={recipient}
                onChange={(e) => setRecipient(e.target.value)}
                style={{ ...styles.input, width: '150px' }}
                placeholder="username"
                required
              />
            </div>
            <div style={styles.formRow}>
              <span style={styles.label}>because</span>
              <input
                type="text"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                style={{ ...styles.input, flex: 1, minWidth: '200px' }}
                placeholder="they wrote a great writeup..."
                required
              />
            </div>
            <button
              type="submit"
              style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
              disabled={loading}
            >
              {loading ? 'Giving Star...' : 'Star Them!'}
            </button>
          </form>
        </>
      )}
      {message && (
        <div style={message.type === 'success' ? styles.success : styles.error}>
          {message.text}
        </div>
      )}
    </div>
  )
}

// Gift of Sanctity section
const GiftOfSanctity = ({ data, user }) => {
  const { userLevel, isEditor } = data

  if (userLevel < 11 && !isEditor) return null

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>The Gift of Sanctity</h3>
      <p style={styles.paragraph}>
        You are at least <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display="Level 11" />,
        so you have the power to <LinkNode type="superdoc" title="Sanctify user" display="Sanctify" /> other users with GP.
        Would you like to <LinkNode type="superdoc" title="Sanctify user" display="sanctify someone" />?
      </p>
      <p style={styles.paragraph}>
        You may also sanctify other users by clicking on the link on their homenode, or by using the /sanctify command in the Chatterbox.
      </p>
    </div>
  )
}

// Buy Votes section
const BuyVotes = ({ data, user, onUpdate }) => {
  const [amount, setAmount] = useState('')
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)

  const { userLevel, gp, gpOptOut } = data

  if (gpOptOut) return null
  if (userLevel < 2) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>The Gift of Votes</h3>
        <p style={styles.paragraph}>
          You are not a high enough level to buy votes yet. Please come back when you reach <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display="Level 2" />!
        </p>
      </div>
    )
  }

  if (gp < 1) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>The Gift of Votes</h3>
        <p style={styles.paragraph}>
          You do not have enough GP to buy votes at this time. Please come back when you have more GP!
        </p>
      </div>
    )
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/buyvotes', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ amount: parseInt(amount, 10) }),
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: `${result.message} You now have ${result.votesLeft} total votes.` })
        setAmount('')
        onUpdate({ gp: result.newGP, votesLeft: result.votesLeft })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>The Gift of Votes</h3>
      <p style={styles.paragraph}>
        Because you are at least <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display="Level 2" /> you can also buy additional votes.
        Each additional vote costs <span style={styles.highlight}>1 GP</span>. You currently have <span style={styles.highlight}>{gp} GP</span>.
      </p>
      <p style={styles.paragraph}>
        Please note that these votes will expire and reset at the end of the day, just like normal votes.
      </p>
      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <span style={styles.label}>How many votes would you like to buy?</span>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            style={styles.inputSmall}
            min="1"
            max={gp}
            required
          />
          <button
            type="submit"
            style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
            disabled={loading}
          >
            {loading ? 'Buying...' : 'Buy Votes'}
          </button>
        </div>
      </form>
      {message && (
        <div style={message.type === 'success' ? styles.success : styles.error}>
          {message.text}
        </div>
      )}
    </div>
  )
}

// Give Votes section
const GiveVotes = ({ data, user, onUpdate }) => {
  const [recipient, setRecipient] = useState('')
  const [amount, setAmount] = useState('')
  const [anonymous, setAnonymous] = useState(false)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)

  const { userLevel, votesLeft } = data

  if (userLevel < 9) return null
  if (votesLeft < 1) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>Give Votes</h3>
        <p style={styles.paragraph}>
          Give the gift of votes! If you happen to have votes to spare, you can give up to 25 of them at a time to another user as a gift.
        </p>
        <p style={styles.paragraph}>
          Sorry, but it looks like you don't have any votes to give away now. Please come back when you have some votes.
        </p>
      </div>
    )
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/givevotes', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ recipient, amount: parseInt(amount, 10), anonymous }),
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: result.message })
        setRecipient('')
        setAmount('')
        onUpdate({ votesLeft: result.votesLeft })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>Give Votes</h3>
      <p style={styles.paragraph}>
        Give the gift of votes! If you happen to have votes to spare, you can give up to 25 of them at a time to another user as a gift. Please use this to encourage newbies.
      </p>
      <p style={styles.paragraph}>You currently have <span style={styles.highlight}>{votesLeft}</span> votes.</p>
      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <span style={styles.label}>Who's the lucky noder?</span>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            style={{ ...styles.input, width: '150px' }}
            placeholder="username"
            required
          />
          <span style={styles.label}>And how many votes?</span>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            style={styles.inputSmall}
            min="1"
            max="25"
            required
          />
        </div>
        <div style={styles.formRow}>
          <label>
            <input
              type="checkbox"
              checked={anonymous}
              onChange={(e) => setAnonymous(e.target.checked)}
              style={styles.checkbox}
            />
            Give anonymously
          </label>
          <button
            type="submit"
            style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
            disabled={loading}
          >
            {loading ? 'Giving...' : 'Give Votes!'}
          </button>
        </div>
      </form>
      {message && (
        <div style={message.type === 'success' ? styles.success : styles.error}>
          {message.text}
        </div>
      )}
    </div>
  )
}

// Gift of Ching section
const GiftOfChing = ({ data, user, onUpdate }) => {
  const [recipient, setRecipient] = useState('')
  const [anonymous, setAnonymous] = useState(false)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)

  const { userLevel, coolsLeft } = data

  if (userLevel < 4) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>The Gift of Ching</h3>
        <p style={styles.paragraph}>
          Sorry, you must be <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display="Level 4" /> to give away C!s.
        </p>
      </div>
    )
  }

  if (coolsLeft < 1) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>The Gift of Ching</h3>
        <p style={styles.paragraph}>
          Give the gift of ching! If you happen to have a C! to spare, why not spread the love and give it to a fellow noder?
        </p>
        <p style={styles.paragraph}>
          Sorry, but you don't have a C! to give away. Please come back when you have a C!.
        </p>
      </div>
    )
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/giveching', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ recipient, anonymous }),
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: result.message })
        setRecipient('')
        onUpdate({ coolsLeft: result.coolsLeft })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>The Gift of Ching</h3>
      <p style={styles.paragraph}>
        Give the gift of ching! If you happen to have a C! to spare, why not spread the love and give it to a fellow noder?
      </p>
      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <span style={styles.label}>Who's the lucky noder?</span>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            style={{ ...styles.input, width: '150px' }}
            placeholder="username"
            required
          />
        </div>
        <div style={styles.formRow}>
          <label>
            <input
              type="checkbox"
              checked={anonymous}
              onChange={(e) => setAnonymous(e.target.checked)}
              style={styles.checkbox}
            />
            Give anonymously
          </label>
          <button
            type="submit"
            style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
            disabled={loading}
          >
            {loading ? 'Giving...' : 'Give C!'}
          </button>
        </div>
      </form>
      {message && (
        <div style={message.type === 'success' ? styles.success : styles.error}>
          {message.text}
        </div>
      )}
    </div>
  )
}

// Buy Ching section
const BuyChing = ({ data, user, onUpdate }) => {
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)

  const { userLevel, gp, gpOptOut, canBuyChing, chingCooldownMinutes } = data

  if (gpOptOut) return null
  if (userLevel < 12) return null

  const cost = 100
  const canAfford = gp >= cost
  const hours = Math.floor(chingCooldownMinutes / 60)
  const mins = chingCooldownMinutes % 60

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/buyching', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: `${result.message} You now have ${result.coolsLeft} C!s.` })
        onUpdate({ gp: result.newGP, coolsLeft: result.coolsLeft, canBuyChing: false })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>Buy C!</h3>
      <p style={styles.paragraph}>
        If you'd like another ching to use or give away, you might be able to buy one for the bargain price of <span style={styles.highlight}>{cost} GP</span>.
        You must be at least <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display="Level 12" />, and you can only buy one C! every 24 hours.
      </p>
      {!canBuyChing ? (
        <p style={styles.paragraph}>
          {chingCooldownMinutes > 0
            ? `You bought your last ching recently. You may buy another in ${hours} hours, ${mins} minutes.`
            : 'You just bought a C! Check back tomorrow for another.'}
        </p>
      ) : !canAfford ? (
        <p style={styles.paragraph}>
          Sorry, you must have at least {cost} GP in order to buy a ching.
        </p>
      ) : (
        <>
          <p style={styles.paragraph}>You currently have <span style={styles.highlight}>{gp} GP</span>.</p>
          <form onSubmit={handleSubmit} style={styles.form}>
            <button
              type="submit"
              style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
              disabled={loading}
            >
              {loading ? 'Buying...' : 'Buy Ching!'}
            </button>
          </form>
        </>
      )}
      {message && (
        <div style={message.type === 'success' ? styles.success : styles.error}>
          {message.text}
        </div>
      )}
    </div>
  )
}

// Gift of Topic section
const GiftOfTopic = ({ data, user, onUpdate }) => {
  const [newTopic, setNewTopic] = useState('')
  const [loadingBuy, setLoadingBuy] = useState(false)
  const [loadingSet, setLoadingSet] = useState(false)
  const [message, setMessage] = useState(null)

  const { userLevel, gp, gpOptOut, tokens, topicSuspended, lastTopicChange, isEditor } = data

  if (userLevel < 6 && !isEditor) return null

  const tokenCost = 25
  const canBuyToken = !gpOptOut && gp >= tokenCost
  const canSetTopic = tokens > 0 || isEditor

  if (topicSuspended) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>The Gift of Topic</h3>
        <p style={styles.paragraph}>You currently have <span style={styles.highlight}>{tokens}</span> token{tokens === 1 ? '' : 's'}.</p>
        <p style={styles.paragraph}>
          Your topic privileges have been suspended. Ask nicely and maybe they will be restored.
        </p>
      </div>
    )
  }

  const handleBuyToken = async (e) => {
    e.preventDefault()
    setLoadingBuy(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/buytoken', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: `${result.message} You now have ${result.tokens} token${result.tokens === 1 ? '' : 's'}.` })
        onUpdate({ gp: result.newGP, tokens: result.tokens })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoadingBuy(false)
    }
  }

  const handleSetTopic = async (e) => {
    e.preventDefault()
    setLoadingSet(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/settopic', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ topic: newTopic }),
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: 'The topic has been updated. Go now and enjoy the fruits of your labor.' })
        setNewTopic('')
        onUpdate({ tokens: result.tokens })
        // Dispatch event to update chatterbox room topic immediately
        if (result.newTopic) {
          window.dispatchEvent(new CustomEvent('e2:roomTopicUpdate', {
            detail: { roomTopic: result.newTopic }
          }))
        }
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoadingSet(false)
    }
  }

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>The Gift of Topic</h3>

      {!canSetTopic && !isEditor ? (
        <>
          <p style={styles.paragraph}>You don't have any tokens right now.</p>
          {canBuyToken ? (
            <>
              <p style={styles.paragraph}>Wanna buy one? Only {tokenCost} GP...</p>
              <form onSubmit={handleBuyToken} style={styles.form}>
                <button
                  type="submit"
                  style={{ ...styles.button, ...(loadingBuy ? styles.buttonDisabled : {}) }}
                  disabled={loadingBuy}
                >
                  {loadingBuy ? 'Buying...' : 'Buy Token'}
                </button>
              </form>
            </>
          ) : (
            <p style={styles.paragraph}>
              You can't buy one right now. You need to be at least <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display="Level 6" /> and have at least <span style={styles.highlight}>{tokenCost} GP</span>.
            </p>
          )}
        </>
      ) : (
        <>
          <p style={styles.paragraph}>
            You currently have <span style={styles.highlight}>{tokens}</span> token{tokens === 1 ? '' : 's'}.
          </p>
          <p style={styles.paragraph}>
            You can update the outside room topic for the low cost of <span style={styles.highlight}>1</span> token
            {isEditor && ' (free for editors)'}.
            The only rules are no insults or harassment of noders, no utter nonsense, and no links to NSFW material.
            Violators will lose their topic-setting privileges.
          </p>
          {lastTopicChange && (
            <p style={styles.paragraph}><strong>Last topic change:</strong> {lastTopicChange}</p>
          )}
          <form onSubmit={handleSetTopic} style={styles.form}>
            <div style={styles.formRow}>
              <input
                type="text"
                value={newTopic}
                onChange={(e) => setNewTopic(e.target.value)}
                style={{ ...styles.input, flex: 1 }}
                placeholder="New Topic"
                maxLength={200}
                required
              />
              <button
                type="submit"
                style={{ ...styles.button, ...(loadingSet ? styles.buttonDisabled : {}) }}
                disabled={loadingSet}
              >
                {loadingSet ? 'Setting...' : 'Set The Topic'}
              </button>
            </div>
          </form>

          {!gpOptOut && userLevel >= 6 && gp >= tokenCost && (
            <>
              <p style={{ ...styles.paragraph, marginTop: '20px' }}>
                Because you are at least Level 6, you can also buy more tokens. One token costs <span style={styles.highlight}>{tokenCost} GP</span>.
              </p>
              <form onSubmit={handleBuyToken} style={styles.form}>
                <button
                  type="submit"
                  style={{ ...styles.button, ...(loadingBuy ? styles.buttonDisabled : {}) }}
                  disabled={loadingBuy}
                >
                  {loadingBuy ? 'Buying...' : 'Buy Token'}
                </button>
              </form>
            </>
          )}
        </>
      )}
      {message && (
        <div style={message.type === 'success' ? styles.success : styles.error}>
          {message.text}
        </div>
      )}
    </div>
  )
}

// Buy Eggs section
const BuyEggs = ({ data, user, onUpdate }) => {
  const [loading, setLoading] = useState(false)
  const [loadingFive, setLoadingFive] = useState(false)
  const [message, setMessage] = useState(null)

  const { userLevel, gp, gpOptOut, easterEggs } = data

  if (gpOptOut) return null
  if (userLevel < 7) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>The Gift of Eggs</h3>
        <p style={styles.paragraph}>
          You are not a high enough level to buy easter eggs yet. Please come back when you reach <LinkNode type="superdoc" title="The Everything2 Voting/Experience System" display="Level 7" />.
        </p>
      </div>
    )
  }

  const eggCost = 25
  const canAfford = gp >= eggCost
  const canAffordFive = gp >= eggCost * 5

  if (!canAfford) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>The Gift of Eggs</h3>
        <p style={styles.paragraph}>
          You do not have enough GP to buy an easter egg right now. Please come back when you have at least {eggCost} GP.
        </p>
      </div>
    )
  }

  const handleBuy = async (amount) => {
    const setLoadingFn = amount === 5 ? setLoadingFive : setLoading
    setLoadingFn(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/buyeggs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ amount }),
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: `${result.message} You now have ${result.easterEggs} eggs.` })
        onUpdate({ gp: result.newGP, easterEggs: result.easterEggs })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoadingFn(false)
    }
  }

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>The Gift of Eggs</h3>
      <p style={styles.paragraph}>
        You also can buy Easter Eggs if you want. Only <span style={styles.highlight}>{eggCost} GP</span> per egg!
      </p>
      <p style={styles.paragraph}>
        You currently have <span style={styles.highlight}>{easterEggs || 'no'}</span> Easter Egg{easterEggs === 1 ? '' : 's'}.
      </p>
      <div style={{ display: 'flex', gap: '10px' }}>
        <button
          onClick={() => handleBuy(1)}
          style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
          disabled={loading}
        >
          {loading ? 'Buying...' : 'Buy Easter Egg'}
        </button>
        {canAffordFive && (
          <button
            onClick={() => handleBuy(5)}
            style={{ ...styles.button, ...(loadingFive ? styles.buttonDisabled : {}) }}
            disabled={loadingFive}
          >
            {loadingFive ? 'Buying...' : 'Buy Five (5) Easter Eggs'}
          </button>
        )}
      </div>
      {message && (
        <div style={message.type === 'success' ? styles.success : styles.error}>
          {message.text}
        </div>
      )}
    </div>
  )
}

// Give Eggs section
const GiveEggs = ({ data, user, onUpdate }) => {
  const [recipient, setRecipient] = useState('')
  const [anonymous, setAnonymous] = useState(false)
  const [loading, setLoading] = useState(false)
  const [message, setMessage] = useState(null)

  const { userLevel, easterEggs } = data

  if (userLevel < 7) return null
  if (easterEggs < 1) {
    return (
      <div style={styles.section}>
        <h3 style={styles.sectionTitle}>Give Eggs</h3>
        <p style={styles.paragraph}>
          Give the gift of eggs! If you happen to have some easter eggs to spare, you can give one to another user as a gift.
        </p>
        <p style={styles.paragraph}>
          Sorry, but it looks like you don't have any eggs to give away now. Please come back when you have an egg.
        </p>
      </div>
    )
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    setLoading(true)
    setMessage(null)

    try {
      const response = await fetch('/api/giftshop/giveegg', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'include',
        body: JSON.stringify({ recipient, anonymous }),
      })
      const result = await response.json()

      if (result.success) {
        setMessage({ type: 'success', text: result.message })
        setRecipient('')
        onUpdate({ easterEggs: result.easterEggs })
      } else {
        setMessage({ type: 'error', text: result.error })
      }
    } catch (err) {
      setMessage({ type: 'error', text: 'An error occurred. Please try again.' })
    } finally {
      setLoading(false)
    }
  }

  return (
    <div style={styles.section}>
      <h3 style={styles.sectionTitle}>Give Eggs</h3>
      <p style={styles.paragraph}>
        Give the gift of eggs! If you happen to have some easter eggs to spare, you can give one to another user as a gift.
        Please use this to encourage newbies.
      </p>
      <form onSubmit={handleSubmit} style={styles.form}>
        <div style={styles.formRow}>
          <span style={styles.label}>Who's the lucky noder?</span>
          <input
            type="text"
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            style={{ ...styles.input, width: '150px' }}
            placeholder="username"
            required
          />
        </div>
        <div style={styles.formRow}>
          <label>
            <input
              type="checkbox"
              checked={anonymous}
              onChange={(e) => setAnonymous(e.target.checked)}
              style={styles.checkbox}
            />
            Give anonymously
          </label>
          <button
            type="submit"
            style={{ ...styles.button, ...(loading ? styles.buttonDisabled : {}) }}
            disabled={loading}
          >
            {loading ? 'Giving...' : 'Egg them!'}
          </button>
        </div>
      </form>
      {message && (
        <div style={message.type === 'success' ? styles.success : styles.error}>
          {message.text}
        </div>
      )}
    </div>
  )
}

// Self Examination section
const SelfExamination = ({ data, user }) => {
  const { gpOptOut, gp, easterEggs, tokens } = data

  return (
    <div style={styles.selfExam}>
      <h3 style={{ ...styles.sectionTitle, borderBottom: '1px solid #ffc107' }}>Self Eggsamination</h3>
      {gpOptOut ? (
        <p style={styles.paragraph}>
          You currently have <span style={styles.highlight}>{easterEggs || 0}</span> easter egg{easterEggs === 1 ? '' : 's'} and <span style={styles.highlight}>{tokens || 0}</span> token{tokens === 1 ? '' : 's'}.
        </p>
      ) : (
        <p style={styles.paragraph}>
          You currently have <span style={styles.highlight}>{gp} GP</span>, <span style={styles.highlight}>{easterEggs || 0}</span> easter egg{easterEggs === 1 ? '' : 's'}, and <span style={styles.highlight}>{tokens || 0}</span> token{tokens === 1 ? '' : 's'}.
        </p>
      )}
    </div>
  )
}

// Main component
const E2GiftShop = ({ data }) => {
  const initialData = data.giftShop || {}
  const [shopData, setShopData] = useState(initialData)
  const user = window.e2?.user || {}

  const handleUpdate = useCallback((updates) => {
    setShopData(prev => ({ ...prev, ...updates }))

    // Dispatch event to update E2ReactRoot state (updates epicenter, etc.)
    // Map gift shop data keys to user object keys
    const userUpdates = {}
    if (updates.gp !== undefined) userUpdates.gp = updates.gp
    if (updates.votesLeft !== undefined) userUpdates.votesleft = updates.votesLeft
    if (updates.coolsLeft !== undefined) userUpdates.coolsleft = updates.coolsLeft

    if (Object.keys(userUpdates).length > 0) {
      window.dispatchEvent(new CustomEvent('e2:userUpdate', { detail: userUpdates }))
    }
  }, [])

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h1 style={styles.title}>Welcome to the Everything2 Gift Shop!</h1>
      </div>

      <GiftOfStar data={shopData} user={user} onUpdate={handleUpdate} />
      <GiftOfSanctity data={shopData} user={user} />
      <BuyVotes data={shopData} user={user} onUpdate={handleUpdate} />
      <GiveVotes data={shopData} user={user} onUpdate={handleUpdate} />
      <GiftOfChing data={shopData} user={user} onUpdate={handleUpdate} />
      <BuyChing data={shopData} user={user} onUpdate={handleUpdate} />
      <GiftOfTopic data={shopData} user={user} onUpdate={handleUpdate} />
      <BuyEggs data={shopData} user={user} onUpdate={handleUpdate} />
      <GiveEggs data={shopData} user={user} onUpdate={handleUpdate} />
      <SelfExamination data={shopData} user={user} />
    </div>
  )
}

export default E2GiftShop
