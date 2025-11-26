import React from 'react'
import LinkNode from '../LinkNode'

/**
 * AboutNobody - "About Nobody" poem generator
 *
 * Generates random sentences about "Nobody" using a set of verbs and direct objects.
 * Originally created by Andrew Lang and Nate Oostendorp.
 *
 * Phase 4a: Content-only document migration from Mason2 to React
 * All data is generated client-side - no server state needed
 */
const AboutNobody = () => {
  const verbs = [
    'talks about',
    'broke',
    'walked',
    'saw you do',
    'cares about',
    'drew on',
    'can breathe under',
    'remembers',
    'cleaned up',
    'does',
    'fell on',
    'thinks badly of',
    'picks up',
    'eats'
  ]

  const dirobjects = [
    'questions',
    'you',
    'the vase',
    'the dog',
    'the walls',
    'water',
    'last year',
    'the yard',
    'Algebra',
    'the sidewalk',
    'you',
    'the slack'
  ]

  // Generate 21 random sentences (matching original Mason template)
  const sentences = React.useMemo(() => {
    const result = []
    for (let i = 0; i < 21; i++) {
      const verb = verbs[Math.floor(Math.random() * verbs.length)]
      const dirobj = dirobjects[Math.floor(Math.random() * dirobjects.length)]
      result.push(`Nobody ${verb} ${dirobj}.`)
    }
    return result
  }, [])

  return (
    <>
      <br />
      <br />
      <p>
        <center>
          <table width="40%">
            <tbody>
              <tr>
                <td>
                  <i>About Nobody</i>
                  <p>
                    {sentences.map((sentence, index) => (
                      <React.Fragment key={index}>
                        {sentence}
                        <br />
                      </React.Fragment>
                    ))}
                  </p>
                </td>
              </tr>
            </tbody>
          </table>
          <br />
          and on and on <LinkNode title="about Nobody" />.
          <p align="right">
            Andrew Lang/<LinkNode title="nate" display="Nate Oostendorp" />
          </p>
        </center>
      </p>
    </>
  )
}

export default AboutNobody
