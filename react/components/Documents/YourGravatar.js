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
      <p className="your-gravatar__note">
        <small>
          If you have an account at gravatar.com, but your avatar isn't showing up correctly below,
          be sure you are using the same email address on E2 that you registered with on gravatar.
          You can change your email address from your homenode.
        </small>
      </p>

      {gravatars.map(({ size, urls }) => (
        <div key={size} className="your-gravatar__size-section">
          <p className="your-gravatar__size-label">{size} pixels</p>
          <div className="your-gravatar__grid">
            {urls.map(({ url, style }) => (
              <div key={style} className="your-gravatar__item">
                <img src={url} alt={`${style} style`} title={style} />
                <div className="your-gravatar__style-label">{style}</div>
              </div>
            ))}
          </div>
        </div>
      ))}
    </div>
  )
}

export default YourGravatar
