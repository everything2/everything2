import React from 'react'

/**
 * E2Logo - SVG logo for mobile header
 *
 * Uses actual Decipher font paths extracted via tools/extract-font-svg.js.
 * Saves 24KB bandwidth vs loading the full TTF font file.
 * Matches the exact glyph shapes from the e2 logo.
 *
 * Props:
 * - size: Height in pixels (default: 28)
 * - color: Color for the logo (default: white)
 */
const E2Logo = ({ size = 28, color = '#fff' }) => {
  // The glyph paths occupy y=17.6 to y=32 in the original viewBox
  // Crop viewBox to just that region for tighter fit
  const scale = size / 16.4
  const width = Math.round(40 * scale)

  return (
    <svg
      width={width}
      height={size}
      viewBox="0 15.6 40 16.4"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      aria-label="e2 Logo"
      role="img"
      style={{ display: 'block' }}
    >
      {/* "e" - Decipher font path, raised 2px higher */}
      <g transform="translate(0, -2)">
        <path
          d="M17.60 20.80L17.60 26.56Q17.60 27.20 16.96 27.20L16.96 27.20L7.04 27.20Q6.40 27.20 6.40 27.84L6.40 27.84L6.40 28.16Q6.40 28.80 7.04 28.80L7.04 28.80L9.60 28.80Q11.58 28.80 12.99 29.74Q14.40 30.69 14.40 32L14.40 32L4.80 32Q2.82 32 1.41 31.06Q0 30.11 0 28.80L0 28.80L0 20.80Q0 19.49 1.41 18.54Q2.82 17.60 4.80 17.60L4.80 17.60L12.80 17.60Q14.78 17.60 16.19 18.54Q17.60 19.49 17.60 20.80L17.60 20.80ZM11.20 24.96L11.20 24.96L11.20 20.80Q11.20 20.13 10.74 19.66Q10.27 19.20 9.60 19.20L9.60 19.20L8 19.20Q7.33 19.20 6.86 19.66Q6.40 20.13 6.40 20.80L6.40 20.80L6.40 24.96Q6.40 25.60 7.04 25.60L7.04 25.60L10.56 25.60Q11.20 25.60 11.20 24.96Z"
          fill={color}
          stroke="#000"
          strokeWidth="0.8"
        />
      </g>
      {/* "2" - Decipher font path, smaller and italicized */}
      <g transform="translate(17, 2) scale(0.85) skewX(-8)">
        <path
          d="M19.80 32L19.80 32L2.20 32L2.20 28.80Q2.20 26.02 5.11 24.64L5.11 24.64Q6.78 23.87 10.49 23.36L10.49 23.36Q13.40 22.94 13.40 22.40L13.40 22.40Q13.40 21.73 12.94 21.26Q12.47 20.80 11.80 20.80L11.80 20.80L7 20.80Q5.02 20.80 3.61 19.86Q2.20 18.91 2.20 17.60L2.20 17.60L15 17.60Q16.98 17.60 18.39 18.54Q19.80 19.49 19.80 20.80L19.80 20.80Q19.80 23.62 16.89 24.96L16.89 24.96Q15.22 25.73 11.51 26.24L11.51 26.24Q8.60 26.66 8.60 27.20L8.60 27.20L8.60 28.16Q8.60 28.80 9.24 28.80L9.24 28.80L15 28.80Q16.98 28.80 18.39 29.74Q19.80 30.69 19.80 32Z"
          fill={color}
          stroke="#000"
          strokeWidth="0.8"
        />
      </g>
    </svg>
  )
}

export default E2Logo
