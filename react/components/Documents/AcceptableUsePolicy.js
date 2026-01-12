import React from 'react'
import LinkNode from '../LinkNode'

/**
 * E2 Acceptable Use Policy - Static content page
 *
 * Last revised: 23 April 2008
 */
const AcceptableUsePolicy = () => {
  const sectionStyle = {
    marginBottom: '24px'
  }

  return (
    <div className="document" style={{ maxWidth: '800px' }}>

      <section style={sectionStyle}>
        <p>By using this website, you implicitly agree to the following conditions:</p>

        <ol style={{ lineHeight: '1.8' }}>
          <li style={{ marginBottom: '12px' }}>
            <strong><LinkNode title="Be cool" /></strong>. Do not harass other users in any way (i.e., in the chatterbox, via /msg, in writeups, in the creation of nodeshells or in any other way).
            <p style={{ marginTop: '8px', marginBottom: '4px' }}>"Harassment" is defined as:</p>
            <ul style={{ marginTop: '4px' }}>
              <li>Threatening other user(s) in any way, and/or</li>
              <li>Creating additional accounts intended to annoy other users</li>
            </ul>
          </li>
          <li>
            <strong>Do not spam</strong>. Do not flood the chatterbox or the New Writeups list.
          </li>
        </ol>
      </section>

      <section style={sectionStyle}>
        <p>By willfully violating any of the above conditions (at the discretion of the administration), you may be subjected to the following actions:</p>

        <ul style={{ lineHeight: '1.8' }}>
          <li>You may be forbidden from noding for as long as deemed necessary by the administration.</li>
          <li>You may be forbidden from using the chatterbox for as long as deemed necessary by the administration.</li>
          <li>Your account may be locked and made inaccessible.</li>
          <li>Your IP address/hostname may be banned from accessing our webservers.</li>
          <li>Depending on the severity of the violation(s), a complaint may be made to your internet service provider.</li>
        </ul>
      </section>

      <section style={sectionStyle}>
        <p>
          Attempting to circumvent any disciplinary action <strong>by any means</strong> will most assuredly result in a complaint being made to your internet service provider.
        </p>
      </section>

      <footer style={{ marginTop: '32px', fontSize: '11px', color: '#666', textAlign: 'right' }}>
        Last revised: 23 April 2008
      </footer>
    </div>
  )
}

export default AcceptableUsePolicy
