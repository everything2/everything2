import React from 'react'

const YourGravatar = ({ data }) => {
  const { gravatars } = data

  return (
    <div className="your-gravatar">
      <h3>Your Gravatar</h3>
      <p>
        The following shows your gravatar in several different sizes. If you haven't actually
        uploaded an avatar to gravatar.com, they have the option of generating a dynamic avatar
        based on your email address (don't worry, we hash it first). These dynamic avatars can be
        generated in one of four styles: default, identicon, monsterid, or wavatar.
      </p>
      <p style={{ fontSize: '0.9em', color: '#666' }}>
        <small>
          If you have an account at gravatar.com, but your avatar isn't showing up correctly below,
          be sure you are using the same email address on E2 that you registered with on gravatar.
          You can change your email address from your homenode.
        </small>
      </p>

      {gravatars.map(({ size, urls }) => (
        <div key={size} style={{ textAlign: 'center', marginBottom: '30px' }}>
          <p style={{ fontWeight: 'bold', marginBottom: '10px' }}>{size} pixels</p>
          <div style={{ display: 'flex', justifyContent: 'center', gap: '10px', flexWrap: 'wrap' }}>
            {urls.map(({ url, style }) => (
              <div key={style} style={{ textAlign: 'center' }}>
                <img src={url} alt={`${style} style`} title={style} />
                <div style={{ fontSize: '0.8em', color: '#888', marginTop: '4px' }}>{style}</div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

export default YourGravatar
