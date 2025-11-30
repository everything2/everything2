import React, { useState, useCallback } from 'react'

const RESPONSES = [
  'No.',
  'Yes.',
  'Maybe.',
  "I'm afraid that is classified information.",
  "Does your mother know you're here?",
  'Who wants to know?',
  'No.',
  'Please try again.',
  "I could tell you but then I'd have to kill you. If the Swine Flu doesn't do it first.",
  "No. You're probably Jewish and not allowed to have Swine Flu.",
  'You... INSERT ANOTHER COIN',
  "No. But for aboot tree-fiddy I get you some.",
  "Would you rather have the answer that's behind door number three?",
  'Not yet',
  "No. You don't deserve it.",
  "Yes. You've earned it.",
  'Hast thou eaten of the tree, whereof I commanded thee that thou shouldest not eat? Damn right you have the Swine Flu!',
  "I'm sorry, Dave. I cannot allow this.",
  'Yes. You got it from kissing Al Gore.',
  'Yes. You got it from kissing Janet Reno.',
  'Yes. A tall, dark stranger gave it to you.',
  "Yes. It's part of an evil plot by the E2 gods.",
  'No.',
  'Why does it always have to be about you?',
  'No. Nice shoes!',
  'Yes. And the horse you rode in on',
  'No. You have Avian Flu. Get a clue and know the difference!',
  'No. Your biology is too alien to be infected.',
  "No. You may be a swine but you're not that kind of swine.",
  'No. Just no.',
  'No. Have you made your will yet?',
  'No. But, if you ask nicely, you can have mine.',
  "What, you didn't get yours yet? Here, have some.",
  'You sick puppy, you...',
  "Who's asking? Oh, it's you, ignorant as usual.",
  "I'm not sure. Let's play doctor and find out.",
  "What do you mean, SWINE FLU? Omigod, you were with that floozy again!! What did you catch this time? That's it! I'm taking the kids and am going to my mother's!",
  'Yes. No. Yes. No. Oh, whatever.',
  'Yes. YES. OH GOD YES!',
  "Maybe. What's in it for me?",
  "I know but I'm not telling.",
  'ACCESS DENIED',
  'Do I look like a doctor?',
  'My sources say no',
  'Outlook not so good',
  'Signs point to yes',
  'I see dead people.',
  "Wouldn't you like to know?",
  'No. Swine Flu is not an STD.',
  "No. I'd do something about that rash, though.",
  "No. You're not smart enough to get it.",
  'No.',
  'Yes. Now go away.',
  '42',
  'YES. OH YES! Thank you so much for asking!',
  "Whaddaya mean, do you have Swine Flu? If you don't know, who does?",
  'What do I care if you have Swine Flu?',
  'GUARDS!!!',
  'No.',
  'Yes. No. What was the question again?',
  'No. Can I have your stuff when you die?',
  'GET AWAY FROM ME!!!'
]

const randomResponse = () => RESPONSES[Math.floor(Math.random() * RESPONSES.length)]

const DoIHaveSwineFlu = () => {
  const [response, setResponse] = useState(randomResponse)

  const handleAskAgain = useCallback(() => {
    setResponse(randomResponse())
  }, [])

  const containerStyle = {
    padding: '30px',
    maxWidth: '800px',
    margin: '0 auto'
  }

  const introStyle = {
    fontSize: '1.1rem',
    marginBottom: '20px',
    color: '#333333'
  }

  const responseContainerStyle = {
    textAlign: 'center',
    padding: '40px',
    backgroundColor: '#f8f9f9',
    borderRadius: '8px',
    marginBottom: '30px'
  }

  const responseStyle = {
    fontSize: '1.5rem',
    fontWeight: 'bold',
    color: '#111111'
  }

  const buttonStyle = {
    display: 'block',
    margin: '0 auto',
    padding: '15px 30px',
    fontSize: '1.1rem',
    backgroundColor: '#38495e',
    color: '#ffffff',
    border: 'none',
    borderRadius: '5px',
    cursor: 'pointer'
  }

  return (
    <div style={containerStyle}>
      <p style={introStyle}>
        You walk up to the Everything Oracle, insert your coin, and ask the question
        that&apos;s most on your mind: DO I HAVE SWINE FLU???
      </p>
      <p style={introStyle}>
        The answer instantly flashes on the screen:
      </p>

      <div style={responseContainerStyle}>
        <span
          style={responseStyle}
          dangerouslySetInnerHTML={{ __html: response }}
        />
      </div>

      <button
        style={buttonStyle}
        onClick={handleAskAgain}
        onMouseOver={(e) => e.target.style.backgroundColor = '#4060b0'}
        onMouseOut={(e) => e.target.style.backgroundColor = '#38495e'}
      >
        Insert Another Coin
      </button>
    </div>
  )
}

export default DoIHaveSwineFlu
