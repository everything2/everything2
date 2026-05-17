import React, { Component } from 'react';

// Named HTML colors lookup table
const NAMED_COLORS = {
  snow: '#fffafa', ghostwhite: '#f8f8ff', whitesmoke: '#f5f5f5',
  gainsboro: '#dcdcdc', floralwhite: '#fffaf0', oldlace: '#fdf5e6',
  linen: '#faf0e6', antiquewhite: '#faebd7', papayawhip: '#ffefd5',
  blanchedalmond: '#ffebcd', bisque: '#ffe4c4', peachpuff: '#ffdab9',
  navajowhite: '#ffdead', moccasin: '#ffe4b5', cornsilk: '#fff8dc',
  ivory: '#fffff0', lemonchiffon: '#fffacd', seashell: '#fff5ee',
  honeydew: '#f0fff0', mintcream: '#f5fffa', azure: '#f0ffff',
  aliceblue: '#f0f8ff', lavender: '#e6e6fa', lavenderblush: '#fff0f5',
  mistyrose: '#ffe4e1', white: '#ffffff', black: '#000000',
  darkslategray: '#2f4f4f', dimgray: '#696969', slategray: '#708090',
  lightslategray: '#778899', gray: '#bebebe', lightgray: '#d3d3d3',
  midnightblue: '#191970', cornflowerblue: '#6495ed', darkslateblue: '#483d8b',
  slateblue: '#6a5acd', mediumslateblue: '#7b68ee', mediumblue: '#0000cd',
  royalblue: '#4169e1', blue: '#0000ff', dodgerblue: '#1e90ff',
  deepskyblue: '#00bfff', skyblue: '#87ceeb', lightskyblue: '#87cefa',
  steelblue: '#4682b4', lightsteelblue: '#b0c4de', lightblue: '#add8e6',
  powderblue: '#b0e0e6', paleturquoise: '#afeeee', darkturquoise: '#00ced1',
  mediumturquoise: '#48d1cc', turquoise: '#40e0d0', cyan: '#00ffff',
  lightcyan: '#e0ffff', cadetblue: '#5f9ea0', mediumaquamarine: '#66cdaa',
  aquamarine: '#7fffd4', darkgreen: '#006400', darkolivegreen: '#556b2f',
  darkseagreen: '#8fbc8f', seagreen: '#2e8b57', mediumseagreen: '#3cb371',
  lightseagreen: '#20b2aa', palegreen: '#98fb98', springgreen: '#00ff7f',
  lawngreen: '#7cfc00', chartreuse: '#7fff00', greenyellow: '#adff2f',
  limegreen: '#32cd32', forestgreen: '#228b22', green: '#00ff00',
  olivedrab: '#6b8e23', yellowgreen: '#9acd32', darkkhaki: '#bdb76b',
  palegoldenrod: '#eee8aa', lightgoldenrodyellow: '#fafad2', lightyellow: '#ffffe0',
  yellow: '#ffff00', gold: '#ffd700', goldenrod: '#daa520',
  darkgoldenrod: '#b8860b', rosybrown: '#bc8f8f', indianred: '#cd5c5c',
  saddlebrown: '#8b4513', sienna: '#a0522d', peru: '#cd853f',
  burlywood: '#deb887', beige: '#f5f5dc', wheat: '#f5deb3',
  sandybrown: '#f4a460', tan: '#d2b48c', chocolate: '#d2691e',
  firebrick: '#b22222', brown: '#a52a2a', darksalmon: '#e9967a',
  salmon: '#fa8072', lightsalmon: '#ffa07a', orange: '#ffa500',
  darkorange: '#ff8c00', coral: '#ff7f50', lightcoral: '#f08080',
  tomato: '#ff6347', orangered: '#ff4500', red: '#ff0000',
  hotpink: '#ff69b4', deeppink: '#ff1493', pink: '#ffc0cb',
  lightpink: '#ffb6c1', palevioletred: '#db7093', maroon: '#b03060',
  mediumvioletred: '#c71585', magenta: '#ff00ff', violet: '#ee82ee',
  plum: '#dda0dd', orchid: '#da70d6', mediumorchid: '#ba55d3',
  darkorchid: '#9932cc', darkviolet: '#9400d3', blueviolet: '#8a2be2',
  purple: '#a020f0', mediumpurple: '#9370db', thistle: '#d8bfd8',
  // E2-specific "fake" colors
  wharfkhaki: '#d5d1c1', wharfolive: '#6e6d56', jukkaback: '#ddddbb',
  jukkaodd: '#cccc99', jukkabrown: '#7e7e66'
};

// Color utility class
class Color {
  constructor(r = 0, g = 0, b = 0) {
    this.r = r;
    this.g = g;
    this.b = b;
  }

  static fromRGB(r, g, b) {
    const color = new Color();
    color.r = Color.clampRGB(r);
    color.g = Color.clampRGB(g);
    color.b = Color.clampRGB(b);
    return color;
  }

  static fromString(s) {
    const color = new Color();
    s = String(s || '').toLowerCase().trim();

    // Check if it's a named color
    if (s.charAt(0) !== '#') {
      s = NAMED_COLORS[s] || '#000000';
    }

    // Remove # and pad to 6 chars
    s = s.replace(/^#/, '').padStart(6, '0');

    // Parse hex values
    color.r = Color.clampRGB(parseInt(s.substring(0, 2), 16) || 0);
    color.g = Color.clampRGB(parseInt(s.substring(2, 4), 16) || 0);
    color.b = Color.clampRGB(parseInt(s.substring(4, 6), 16) || 0);

    return color;
  }

  static fromHSB(hue, sat, bright) {
    // Convert from 0-419 range to 0-360
    const h360 = (hue / 419) * 360;
    sat = sat / 100;
    bright = bright / 100;

    if (sat === 0) {
      const v = Math.round(bright * 255);
      return Color.fromRGB(v, v, v);
    }

    const h = h360 / 60;
    const i = Math.floor(h);
    const f = h - i;
    const p = bright * (1.0 - sat);
    const q = bright * (1.0 - sat * f);
    const t = bright * (1.0 - sat * (1.0 - f));

    let r, g, b;
    switch (i % 6) {
      case 0: r = bright; g = t; b = p; break;
      case 1: r = q; g = bright; b = p; break;
      case 2: r = p; g = bright; b = t; break;
      case 3: r = p; g = q; b = bright; break;
      case 4: r = t; g = p; b = bright; break;
      default: r = bright; g = p; b = q; break;
    }

    return Color.fromRGB(
      Math.round(r * 255),
      Math.round(g * 255),
      Math.round(b * 255)
    );
  }

  static clampRGB(v) {
    v = parseInt(v, 10);
    if (isNaN(v)) return 0;
    return Math.max(0, Math.min(255, v));
  }

  static clampHue(v) {
    v = parseInt(v, 10);
    if (isNaN(v)) return 0;
    return Math.max(0, Math.min(419, v));
  }

  static clampSatBri(v) {
    v = parseInt(v, 10);
    if (isNaN(v)) return 0;
    return Math.max(0, Math.min(100, v));
  }

  toHex() {
    const toHex = (n) => n.toString(16).padStart(2, '0');
    return `#${toHex(this.r)}${toHex(this.g)}${toHex(this.b)}`;
  }

  toHSB() {
    const r = this.r / 255;
    const g = this.g / 255;
    const b = this.b / 255;

    const max = Math.max(r, g, b);
    const min = Math.min(r, g, b);
    const delta = max - min;

    let h = 0;
    let s = max === 0 ? 0 : delta / max;
    let v = max;

    if (delta !== 0) {
      if (max === r) {
        h = ((g - b) / delta) % 6;
      } else if (max === g) {
        h = (b - r) / delta + 2;
      } else {
        h = (r - g) / delta + 4;
      }
      h *= 60;
      if (h < 0) h += 360;
    }

    return {
      h: Math.round(h * 419 / 360), // Scale to 0-419 range
      s: Math.round(s * 100),
      b: Math.round(v * 100)
    };
  }

  // Calculate relative luminance for contrast calculations
  getLuminance() {
    const rsRGB = this.r / 255;
    const gsRGB = this.g / 255;
    const bsRGB = this.b / 255;

    const r = rsRGB <= 0.03928 ? rsRGB / 12.92 : Math.pow((rsRGB + 0.055) / 1.055, 2.4);
    const g = gsRGB <= 0.03928 ? gsRGB / 12.92 : Math.pow((gsRGB + 0.055) / 1.055, 2.4);
    const b = bsRGB <= 0.03928 ? bsRGB / 12.92 : Math.pow((bsRGB + 0.055) / 1.055, 2.4);

    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  // Get contrasting text color (black or white)
  getContrastColor() {
    return this.getLuminance() > 0.179 ? '#000000' : '#ffffff';
  }
}

// Dynamic styles that must remain inline (depend on runtime color values)
// All other styles are now in CSS classes (colortoy__*)

class E2ColorToy extends Component {
  constructor(props) {
    super(props);
    this.state = {
      // HSB values
      hue: 210,
      sat: 70,
      bright: 70,
      // RGB values
      r: 54,
      g: 96,
      b: 176,
      // Hex value
      hex: '#3660b0',
      // Current preview color
      previewColor: '#3660b0',
      // Gradient values
      gradFrom: '#ffffff',
      gradTo: '#000000',
      gradSteps: 16,
      gradColors: Array(16).fill('#ffffff'),
      gradOutput: '',
      // Checkboxes
      nameToHex: true,
      gradNameToHex: true,
      // Copy feedback
      copyFeedback: '',
    };
  }

  componentDidMount() {
    // Initialize with a nice E2-themed blue
    this.useHSB();
  }

  syncFromColor = (color) => {
    const hex = color.toHex();
    const hsb = color.toHSB();
    this.setState({
      r: color.r,
      g: color.g,
      b: color.b,
      hue: hsb.h,
      sat: hsb.s,
      bright: hsb.b,
      hex: hex,
      previewColor: hex,
    });
  };

  handleHSBChange = (field, value) => {
    this.setState({ [field]: value }, () => {
      // Auto-sync when using sliders
      if (typeof value === 'number') {
        this.useHSB();
      }
    });
  };

  useHSB = () => {
    const { hue, sat, bright } = this.state;
    const h = Color.clampHue(hue);
    const s = Color.clampSatBri(sat);
    const b = Color.clampSatBri(bright);

    const color = Color.fromHSB(h, s, b);
    const hex = color.toHex();

    this.setState({
      hue: h,
      sat: s,
      bright: b,
      r: color.r,
      g: color.g,
      b: color.b,
      hex: hex,
      previewColor: hex
    });
  };

  handleRGBChange = (field, value) => {
    this.setState({ [field]: value });
  };

  useRGB = () => {
    const r = Color.clampRGB(this.state.r);
    const g = Color.clampRGB(this.state.g);
    const b = Color.clampRGB(this.state.b);

    const color = Color.fromRGB(r, g, b);
    this.syncFromColor(color);
  };

  handleHexChange = (value) => {
    this.setState({ hex: value });
  };

  useHex = () => {
    const { hex, nameToHex } = this.state;
    const color = Color.fromString(hex);
    const hsb = color.toHSB();
    const hexValue = color.toHex();

    this.setState({
      r: color.r,
      g: color.g,
      b: color.b,
      hue: hsb.h,
      sat: hsb.s,
      bright: hsb.b,
      hex: nameToHex ? hexValue : hex,
      previewColor: hexValue
    });
  };

  handleKeyPress = (e, action) => {
    if (e.key === 'Enter') {
      action();
    }
  };

  copyToClipboard = async (text, type) => {
    try {
      await navigator.clipboard.writeText(text);
      this.setState({ copyFeedback: type }, () => {
        setTimeout(() => this.setState({ copyFeedback: '' }), 1500);
      });
    } catch (err) {
      // Fallback for older browsers
      const textArea = document.createElement('textarea');
      textArea.value = text;
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);
      this.setState({ copyFeedback: type }, () => {
        setTimeout(() => this.setState({ copyFeedback: '' }), 1500);
      });
    }
  };

  useForGradFrom = () => {
    this.setState({ gradFrom: this.state.hex }, this.generateGradient);
  };

  useForGradTo = () => {
    this.setState({ gradTo: this.state.hex }, this.generateGradient);
  };

  generateGradient = () => {
    const { gradFrom, gradTo, gradSteps, gradNameToHex } = this.state;
    const from = Color.fromString(gradFrom);
    const to = Color.fromString(gradTo);
    const steps = Math.max(2, Math.min(32, parseInt(gradSteps, 10) || 16));

    const incR = (to.r - from.r) / (steps - 1);
    const incG = (to.g - from.g) / (steps - 1);
    const incB = (to.b - from.b) / (steps - 1);

    const colors = [];
    let output = '';
    let r = from.r;
    let g = from.g;
    let b = from.b;

    for (let i = 0; i < steps - 1; i++) {
      const color = Color.fromRGB(Math.round(r), Math.round(g), Math.round(b));
      colors.push(color.toHex());
      output += color.toHex() + '\n';
      r += incR;
      g += incG;
      b += incB;
    }

    colors.push(to.toHex());
    output += to.toHex() + '\n';

    this.setState({
      gradSteps: steps,
      gradColors: colors,
      gradOutput: output,
      gradFrom: gradNameToHex ? from.toHex() : gradFrom,
      gradTo: gradNameToHex ? to.toHex() : gradTo
    });
  };

  selectGradientColor = (hex) => {
    const color = Color.fromString(hex);
    this.syncFromColor(color);
  };

  selectFakeColor = (name) => {
    const hex = NAMED_COLORS[name];
    const color = Color.fromString(hex);
    this.syncFromColor(color);
    this.setState({ hex: name });
  };

  render() {
    const {
      hue, sat, bright,
      r, g, b,
      hex, previewColor,
      gradFrom, gradTo, gradSteps, gradColors, gradOutput,
      nameToHex, gradNameToHex,
      copyFeedback
    } = this.state;

    const previewColorObj = Color.fromString(previewColor);
    const contrastColor = previewColorObj.getContrastColor();

    return (
      <div className="colortoy">
        {/* Main Preview */}
        <div className="colortoy__main-preview">
          <div
            className="colortoy__preview-swatch"
            style={{ backgroundColor: previewColor, color: contrastColor }}
          >
            {previewColor}
          </div>
          <div className="colortoy__preview-info">
            <div className="colortoy__color-value">
              <span className="colortoy__color-value-label">Hex:</span>
              <code
                className={`colortoy__color-value-code${copyFeedback === 'hex' ? ' colortoy__color-value-code--copied' : ''}`}
                onClick={() => this.copyToClipboard(previewColor, 'hex')}
                title="Click to copy"
              >
                {previewColor}
              </code>
              {copyFeedback === 'hex' && <span className="colortoy__copied-text">Copied!</span>}
            </div>
            <div className="colortoy__color-value">
              <span className="colortoy__color-value-label">RGB:</span>
              <code
                className={`colortoy__color-value-code${copyFeedback === 'rgb' ? ' colortoy__color-value-code--copied' : ''}`}
                onClick={() => this.copyToClipboard(`rgb(${r}, ${g}, ${b})`, 'rgb')}
                title="Click to copy"
              >
                rgb({r}, {g}, {b})
              </code>
            </div>
            <div className="colortoy__color-value">
              <span className="colortoy__color-value-label">HSB:</span>
              <code className="colortoy__color-value-code">
                {hue}, {sat}%, {bright}%
              </code>
            </div>
          </div>
        </div>

        <div className="colortoy__two-column">
          {/* HSB Controls */}
          <div className="colortoy__card">
            <div className="colortoy__card-header">HSB (Hue, Saturation, Brightness)</div>

            <div className="colortoy__slider-row">
              <span className="colortoy__slider-label">Hue</span>
              <input
                type="range"
                min="0"
                max="419"
                value={hue}
                onChange={(e) => this.handleHSBChange('hue', parseInt(e.target.value, 10))}
                className="colortoy__slider colortoy__slider--hue"
              />
              <span className="colortoy__slider-value">{hue}</span>
            </div>

            <div className="colortoy__slider-row">
              <span className="colortoy__slider-label">Saturation</span>
              <input
                type="range"
                min="0"
                max="100"
                value={sat}
                onChange={(e) => this.handleHSBChange('sat', parseInt(e.target.value, 10))}
                className="colortoy__slider"
              />
              <span className="colortoy__slider-value">{sat}%</span>
            </div>

            <div className="colortoy__slider-row">
              <span className="colortoy__slider-label">Brightness</span>
              <input
                type="range"
                min="0"
                max="100"
                value={bright}
                onChange={(e) => this.handleHSBChange('bright', parseInt(e.target.value, 10))}
                className="colortoy__slider"
              />
              <span className="colortoy__slider-value">{bright}%</span>
            </div>

            <div className="colortoy__input-group">
              <div className="colortoy__input-wrapper">
                <label className="colortoy__input-label">H (0-419)</label>
                <input
                  type="text"
                  value={hue}
                  onChange={(e) => this.setState({ hue: e.target.value })}
                  onKeyPress={(e) => this.handleKeyPress(e, this.useHSB)}
                  className="colortoy__input"
                />
              </div>
              <div className="colortoy__input-wrapper">
                <label className="colortoy__input-label">S (0-100)</label>
                <input
                  type="text"
                  value={sat}
                  onChange={(e) => this.setState({ sat: e.target.value })}
                  onKeyPress={(e) => this.handleKeyPress(e, this.useHSB)}
                  className="colortoy__input"
                />
              </div>
              <div className="colortoy__input-wrapper">
                <label className="colortoy__input-label">B (0-100)</label>
                <input
                  type="text"
                  value={bright}
                  onChange={(e) => this.setState({ bright: e.target.value })}
                  onKeyPress={(e) => this.handleKeyPress(e, this.useHSB)}
                  className="colortoy__input"
                />
              </div>
              <button onClick={this.useHSB} className="colortoy__btn">
                Apply
              </button>
            </div>
          </div>

          {/* RGB Controls */}
          <div className="colortoy__card">
            <div className="colortoy__card-header">RGB (Red, Green, Blue)</div>

            <div className="colortoy__slider-row">
              <span className="colortoy__slider-label colortoy__slider-label--red">Red</span>
              <input
                type="range"
                min="0"
                max="255"
                value={r}
                onChange={(e) => {
                  const val = parseInt(e.target.value, 10);
                  this.setState({ r: val }, () => this.useRGB());
                }}
                className="colortoy__slider colortoy__slider--red"
              />
              <span className="colortoy__slider-value">{r}</span>
            </div>

            <div className="colortoy__slider-row">
              <span className="colortoy__slider-label colortoy__slider-label--green">Green</span>
              <input
                type="range"
                min="0"
                max="255"
                value={g}
                onChange={(e) => {
                  const val = parseInt(e.target.value, 10);
                  this.setState({ g: val }, () => this.useRGB());
                }}
                className="colortoy__slider colortoy__slider--green"
              />
              <span className="colortoy__slider-value">{g}</span>
            </div>

            <div className="colortoy__slider-row">
              <span className="colortoy__slider-label colortoy__slider-label--blue">Blue</span>
              <input
                type="range"
                min="0"
                max="255"
                value={b}
                onChange={(e) => {
                  const val = parseInt(e.target.value, 10);
                  this.setState({ b: val }, () => this.useRGB());
                }}
                className="colortoy__slider colortoy__slider--blue"
              />
              <span className="colortoy__slider-value">{b}</span>
            </div>

            <div className="colortoy__input-group">
              <div className="colortoy__input-wrapper">
                <label className="colortoy__input-label colortoy__input-label--red">R (0-255)</label>
                <input
                  type="text"
                  value={r}
                  onChange={(e) => this.handleRGBChange('r', e.target.value)}
                  onKeyPress={(e) => this.handleKeyPress(e, this.useRGB)}
                  className="colortoy__input"
                />
              </div>
              <div className="colortoy__input-wrapper">
                <label className="colortoy__input-label colortoy__input-label--green">G (0-255)</label>
                <input
                  type="text"
                  value={g}
                  onChange={(e) => this.handleRGBChange('g', e.target.value)}
                  onKeyPress={(e) => this.handleKeyPress(e, this.useRGB)}
                  className="colortoy__input"
                />
              </div>
              <div className="colortoy__input-wrapper">
                <label className="colortoy__input-label colortoy__input-label--blue">B (0-255)</label>
                <input
                  type="text"
                  value={b}
                  onChange={(e) => this.handleRGBChange('b', e.target.value)}
                  onKeyPress={(e) => this.handleKeyPress(e, this.useRGB)}
                  className="colortoy__input"
                />
              </div>
              <button onClick={this.useRGB} className="colortoy__btn">
                Apply
              </button>
            </div>
          </div>
        </div>

        {/* Hex/Named Input */}
        <div className="colortoy__card">
          <div className="colortoy__card-header">Hex / Named Color</div>
          <div className="colortoy__input-group">
            <div className="colortoy__input-wrapper">
              <label className="colortoy__input-label">Hex or Color Name</label>
              <input
                type="text"
                value={hex}
                onChange={(e) => this.handleHexChange(e.target.value)}
                onKeyPress={(e) => this.handleKeyPress(e, this.useHex)}
                className="colortoy__input colortoy__input--wide"
                placeholder="#ff6600 or orange"
              />
            </div>
            <button onClick={this.useHex} className="colortoy__btn">
              Apply
            </button>
            <label className="colortoy__checkbox">
              <input
                type="checkbox"
                checked={nameToHex}
                onChange={(e) => this.setState({ nameToHex: e.target.checked })}
              />
              Convert names to hex
            </label>
          </div>
          <p className="colortoy__help-text">
            Accepts hex codes (#ff6600) or <a href="/title/Named+HTML+Colors">HTML color names</a> like <code>dodgerblue</code>, <code>coral</code>, etc.
          </p>

          {/* E2 Fake Colors */}
          <div className="colortoy__section">
            <div className="colortoy__section-label">E2 Custom Colors:</div>
            <div className="colortoy__fake-colors">
              {['wharfkhaki', 'wharfolive', 'jukkaback', 'jukkaodd', 'jukkabrown'].map(name => {
                const colorHex = NAMED_COLORS[name];
                const colorObj = Color.fromString(colorHex);
                return (
                  <div
                    key={name}
                    className="colortoy__fake-color-swatch"
                    style={{ backgroundColor: colorHex, color: colorObj.getContrastColor() }}
                    onClick={() => this.selectFakeColor(name)}
                    title={`${name} (${colorHex})`}
                  >
                    {name}
                  </div>
                );
              })}
            </div>
          </div>
        </div>

        {/* Gradient Generator */}
        <div className="colortoy__card">
          <div className="colortoy__card-header">Gradient Generator</div>

          <div className="colortoy__input-group">
            <div className="colortoy__input-wrapper">
              <label className="colortoy__input-label">From</label>
              <input
                type="text"
                value={gradFrom}
                onChange={(e) => this.setState({ gradFrom: e.target.value })}
                onKeyPress={(e) => this.handleKeyPress(e, this.generateGradient)}
                className="colortoy__input colortoy__input--wide"
              />
            </div>
            <button onClick={this.useForGradFrom} className="colortoy__btn--secondary">
              Use Current
            </button>
            <div className="colortoy__input-wrapper">
              <label className="colortoy__input-label">To</label>
              <input
                type="text"
                value={gradTo}
                onChange={(e) => this.setState({ gradTo: e.target.value })}
                onKeyPress={(e) => this.handleKeyPress(e, this.generateGradient)}
                className="colortoy__input colortoy__input--wide"
              />
            </div>
            <button onClick={this.useForGradTo} className="colortoy__btn--secondary">
              Use Current
            </button>
            <div className="colortoy__input-wrapper">
              <label className="colortoy__input-label">Steps</label>
              <input
                type="text"
                value={gradSteps}
                onChange={(e) => this.setState({ gradSteps: e.target.value })}
                onKeyPress={(e) => this.handleKeyPress(e, this.generateGradient)}
                className="colortoy__input colortoy__input--narrow"
              />
            </div>
            <button onClick={this.generateGradient} className="colortoy__btn">
              Generate
            </button>
          </div>

          <label className="colortoy__checkbox colortoy__checkbox--margin">
            <input
              type="checkbox"
              checked={gradNameToHex}
              onChange={(e) => this.setState({ gradNameToHex: e.target.checked })}
            />
            Convert named colors to hex
          </label>

          {/* Gradient Preview Strip */}
          <div className="colortoy__gradient-strip">
            {gradColors.map((color, idx) => {
              const colorObj = Color.fromString(color);
              return (
                <div
                  key={idx}
                  className="colortoy__gradient-swatch"
                  style={{ backgroundColor: color, color: colorObj.getContrastColor() }}
                  onClick={() => this.selectGradientColor(color)}
                  title={`Click to select ${color}`}
                >
                  {gradColors.length <= 16 ? idx + 1 : ''}
                </div>
              );
            })}
          </div>

          {/* Gradient Output */}
          <div className="colortoy__output-header">
            <span className="colortoy__output-label">Output (one hex per line):</span>
            <button
              onClick={() => this.copyToClipboard(gradOutput, 'gradient')}
              className="colortoy__copy-btn"
            >
              {copyFeedback === 'gradient' ? 'Copied!' : 'Copy All'}
            </button>
          </div>
          <textarea
            value={gradOutput}
            readOnly
            rows={Math.min(gradColors.length + 1, 12)}
            className="colortoy__textarea"
          />
        </div>
      </div>
    );
  }
}

export default E2ColorToy;
