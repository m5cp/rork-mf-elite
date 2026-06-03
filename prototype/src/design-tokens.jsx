// MF Elite — Design tokens
// Pure black & white system. Hierarchy by density, type, hairlines.

const MF = {
  // Background ladder (dark mode primary)
  bg: {
    base:     '#000000',
    elevated: '#0A0A0A',
    card:     '#121212',
    raised:   '#1A1A1A',
    tint:     '#262626',
  },
  // Line / divider
  line: {
    hairline: 'rgba(255,255,255,0.12)',
    subtle:   'rgba(255,255,255,0.20)',
    strong:   'rgba(255,255,255,0.34)',
  },
  // Text on dark — tuned for legibility on pure black.
  // Everything reads as white; only the alpha drops for hierarchy.
  ink: {
    primary:    'rgba(255,255,255,1)',
    secondary:  'rgba(255,255,255,0.90)',
    tertiary:   'rgba(255,255,255,0.72)',
    quaternary: 'rgba(255,255,255,0.52)',
    disabled:   'rgba(255,255,255,0.32)',
  },
  // Text on light surfaces (used for confirmation states, light buttons)
  ground: {
    primary:   '#000000',
    secondary: 'rgba(0,0,0,0.62)',
    tertiary:  'rgba(0,0,0,0.40)',
  },
  // Radii — tight, architectural
  r: { xs: 6, sm: 10, md: 14, lg: 20, xl: 28, pill: 999 },
  // Spacing on 4pt baseline
  s: { 0:0, 1:4, 2:8, 3:12, 4:16, 5:20, 6:24, 7:32, 8:40, 9:48, 10:64, 11:80, 12:96 },
  // Elevation — layered shadows that feel premium-Apple, never neumorphic.
  // Each step keeps a single soft ambient + a tight close shadow + an inner
  // edge highlight; never glossy, never blurred-only.
  elev: {
    // Light pill (white on dark) — the headline elevated CTA
    pillLight:
      'inset 0 1px 0 rgba(255,255,255,0.95), ' +
      'inset 0 -0.5px 0 rgba(0,0,0,0.06), ' +
      '0 1px 0 rgba(0,0,0,0.06), ' +
      '0 2px 4px rgba(0,0,0,0.30), ' +
      '0 10px 24px rgba(0,0,0,0.32)',
    pillLightPressed:
      'inset 0 1px 0 rgba(255,255,255,0.78), ' +
      'inset 0 -0.5px 0 rgba(0,0,0,0.05), ' +
      '0 1px 1px rgba(0,0,0,0.22), ' +
      '0 2px 6px rgba(0,0,0,0.18)',
    // Dark pill (black on light) — inverse of above
    pillDark:
      'inset 0 1px 0 rgba(255,255,255,0.08), ' +
      '0 1px 2px rgba(0,0,0,0.22), ' +
      '0 8px 18px rgba(0,0,0,0.22)',
    // Floating CTA — biggest depth (sticky-bottom hero buttons)
    floating:
      'inset 0 1px 0 rgba(255,255,255,0.95), ' +
      '0 2px 6px rgba(0,0,0,0.34), ' +
      '0 22px 48px rgba(0,0,0,0.42)',
    // Raised surface — for cards that lift slightly from the floor
    raised:
      'inset 0 1px 0 rgba(255,255,255,0.04), ' +
      '0 1px 2px rgba(0,0,0,0.34), ' +
      '0 12px 28px rgba(0,0,0,0.22)',
    // Card (default surface) — minimal but present
    card:
      'inset 0 1px 0 rgba(255,255,255,0.02), ' +
      '0 1px 2px rgba(0,0,0,0.28)',
    // Icon chip — circular hairline w/ tiny lift
    chip:
      'inset 0 1px 0 rgba(255,255,255,0.04), ' +
      '0 1px 2px rgba(0,0,0,0.30)',
    none: 'none',
  },
  // Motion — Apple-feeling curves, three speeds
  dur:  { fast: '140ms', base: '220ms', slow: '360ms' },
  ease: {
    out:    'cubic-bezier(0.22, 0.61, 0.36, 1)',
    inOut:  'cubic-bezier(0.4, 0, 0.2, 1)',
    spring: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
  },
  // Type
  font: {
    display: '-apple-system, "SF Pro Display", "Helvetica Neue", system-ui, sans-serif',
    text:    '-apple-system, "SF Pro Text", "Helvetica Neue", system-ui, sans-serif',
    mono:    '"SF Mono", "JetBrains Mono", "Roboto Mono", ui-monospace, monospace',
  },
  // Z
  z: { base:1, raised:10, sticky:20, nav:30, sheet:40, toast:50 },
};

// Small text style helpers
const TYPE = {
  // Editorial display (hero titles)
  hero:   { fontFamily: MF.font.display, fontSize: 48, lineHeight: '50px', letterSpacing: -1.6, fontWeight: 800 },
  display:{ fontFamily: MF.font.display, fontSize: 36, lineHeight: '38px', letterSpacing: -1.1, fontWeight: 800 },
  title1: { fontFamily: MF.font.display, fontSize: 28, lineHeight: '32px', letterSpacing: -0.6, fontWeight: 700 },
  title2: { fontFamily: MF.font.display, fontSize: 22, lineHeight: '26px', letterSpacing: -0.4, fontWeight: 700 },
  title3: { fontFamily: MF.font.display, fontSize: 17, lineHeight: '22px', letterSpacing: -0.2, fontWeight: 600 },
  body:   { fontFamily: MF.font.text,    fontSize: 16, lineHeight: '22px', letterSpacing: -0.1, fontWeight: 400 },
  callout:{ fontFamily: MF.font.text,    fontSize: 15, lineHeight: '20px', letterSpacing: -0.1, fontWeight: 500 },
  foot:   { fontFamily: MF.font.text,    fontSize: 13, lineHeight: '18px', letterSpacing:  0,   fontWeight: 500 },
  cap:    { fontFamily: MF.font.text,    fontSize: 11, lineHeight: '14px', letterSpacing:  0.2, fontWeight: 500 },
  // Telemetry — uppercase mono
  micro:  { fontFamily: MF.font.mono,    fontSize: 10, lineHeight: '12px', letterSpacing: 1.2, fontWeight: 500, textTransform: 'uppercase' },
  microSm:{ fontFamily: MF.font.mono,    fontSize:  9, lineHeight: '11px', letterSpacing: 1.4, fontWeight: 500, textTransform: 'uppercase' },
  // Big tabular numerals — used everywhere stats appear
  num:    { fontFamily: MF.font.display, fontWeight: 700, fontVariantNumeric: 'tabular-nums', letterSpacing: -1 },
};

Object.assign(window, { MF, TYPE });
