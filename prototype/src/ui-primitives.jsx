// MF Elite — shared UI primitives

// ─── MF logomark (uses the supplied transparent PNG) ───
function MFMark({ size = 24, dark = true, style = {} }) {
  const src = dark ? 'assets/mf-logo-white.png' : 'assets/mf-logo-black.png';
  return (
    <img
      src={src}
      width={size}
      height={size * (1450 / 1600)}
      alt="MF"
      style={{ display: 'block', objectFit: 'contain', ...style }}
    />
  );
}

// ─── A monospace eyebrow label (uppercase telemetry) ───
function Eyebrow({ children, color, style = {} }) {
  return <div style={{ ...TYPE.micro, color: color ?? MF.ink.tertiary, ...style }}>{children}</div>;
}

// ─── Hairline divider ───
function Hairline({ color, style = {} }) {
  return <div style={{ height: 1, background: color ?? MF.line.hairline, ...style }} />;
}

// ─── Vertical hairline ───
function VLine({ style = {} }) {
  return <div style={{ width: 1, alignSelf: 'stretch', background: MF.line.hairline, ...style }} />;
}

// ─── Diagonal slash divider (echoes the logo's cuts) ───
function SlashRule({ width = '100%', color = MF.line.subtle, style = {} }) {
  return (
    <svg width={width} height="10" viewBox="0 0 200 10" preserveAspectRatio="none" style={{ display:'block', ...style }}>
      {[0, 14, 28, 42, 56, 70, 84, 98, 112, 126, 140, 154, 168, 182].map((x, i) => (
        <line key={i} x1={x} y1="10" x2={x + 18} y2="0" stroke={color} strokeWidth="1" />
      ))}
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────
// Button system — premium elevated minimalism
// ─────────────────────────────────────────────────────────────
// Levels:
//   • PrimaryButton    — elevated pill, hero CTA  (Start Training,
//                        Continue Session, Complete Drill, Upgrade,
//                        Save Progress)
//   • FloatingButton   — same shape, heavier ambient — for sticky
//                        bottom panels and floating sheets
//   • SecondaryButton  — flat outlined pill, paired action
//   • GhostButton      — text-only muted, tertiary
//   • IconButton       — circular hairline, navigation / dismiss
// All share a `.mf-btn` class which drives press / focus / disabled
// behaviour via CSS in MF Elite Training App.html. Inline styles
// here set the resting look; the CSS handles the interaction.
//
// Resting heights:
//   primary / floating  → 56  (hero) ·  48 (compact, via `size`)
//   secondary           → 50  ·  44 compact
//   icon                → 40 (default) · 36 (compact)
// Resting radii: pill (999) on every variant — corners are the
// single most consistent thing across the system.

function PrimaryButton({
  children, hint,
  dark = true,
  size = 'lg',          // 'lg' (56) | 'md' (48)
  floating = false,
  disabled = false,
  onClick, style = {},
}) {
  const tone = dark ? 'light' : 'dark';   // tone of the pill surface
  const h = size === 'md' ? 48 : 56;
  return (
    <button
      className={`mf-btn ${floating ? 'mf-btn-floating' : 'mf-btn-primary'}`}
      data-tone={tone}
      disabled={disabled}
      onClick={onClick}
      style={{
        appearance: 'none', border: 'none', cursor: 'pointer',
        background: dark ? '#fff' : '#000',
        color: dark ? '#000' : '#fff',
        height: h, width: '100%',
        borderRadius: MF.r.pill,
        padding: '0 28px',
        ...TYPE.title3, letterSpacing: 0.1, fontWeight: 700,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 10,
        boxShadow: floating ? MF.elev.floating : (dark ? MF.elev.pillLight : MF.elev.pillDark),
        ...style,
      }}>
      <span>{children}</span>
      {hint && (
        <span style={{
          ...TYPE.micro, color: dark ? 'rgba(0,0,0,0.55)' : 'rgba(255,255,255,0.55)',
        }}>{hint}</span>
      )}
    </button>
  );
}

// Sticky-bottom hero CTA convenience — same shape, bigger shadow.
function FloatingButton(props) {
  return <PrimaryButton {...props} floating={true}/>;
}

// Flat outlined pill — paired secondary action. No shadow.
function SecondaryButton({ children, size = 'lg', disabled = false, onClick, style = {} }) {
  const h = size === 'md' ? 44 : 50;
  return (
    <button
      className="mf-btn mf-btn-secondary"
      disabled={disabled}
      onClick={onClick}
      style={{
        appearance: 'none', cursor: 'pointer',
        background: 'transparent',
        color: '#fff',
        border: `1px solid ${MF.line.subtle}`,
        height: h, width: '100%',
        borderRadius: MF.r.pill,
        padding: '0 22px',
        ...TYPE.callout, fontWeight: 600, letterSpacing: 0.1,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        boxShadow: MF.elev.none,
        ...style,
      }}>
      {children}
    </button>
  );
}

// Text-only muted — tertiary actions ("Later", "Skip", "Keep going free").
function GhostButton({ children, size = 'md', disabled = false, onClick, style = {} }) {
  const h = size === 'md' ? 44 : 48;
  return (
    <button
      className="mf-btn mf-btn-ghost"
      disabled={disabled}
      onClick={onClick}
      style={{
        appearance: 'none', cursor: 'pointer',
        background: 'transparent', border: 'none',
        color: MF.ink.tertiary,
        height: h, padding: '0 12px',
        borderRadius: MF.r.pill,
        ...TYPE.callout, fontWeight: 600, letterSpacing: 0.1,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center', gap: 6,
        ...style,
      }}>
      {children}
    </button>
  );
}

// ─── Small chip (filter / tag) — flat, no shadow ─────────────
function Chip({ children, active = false, onClick, style = {} }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="mf-btn mf-btn-secondary"
      style={{
        ...TYPE.foot, fontWeight: 600,
        padding: '7px 14px', height: 'auto',
        borderRadius: MF.r.pill,
        background: active ? MF.ink.primary : 'transparent',
        color: active ? MF.bg.base : MF.ink.secondary,
        border: `1px solid ${active ? MF.ink.primary : MF.line.subtle}`,
        boxShadow: MF.elev.none,
        whiteSpace: 'nowrap',
        display: 'inline-flex', alignItems: 'center', gap: 6, width: 'auto',
        ...style,
      }}>{children}</button>
  );
}

// ─── Circular icon button — hairline, soft chip-lift ─────────
function IconButton({ children, size = 40, onClick, style = {} }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="mf-btn mf-btn-icon"
      style={{
        width: size, height: size, borderRadius: MF.r.pill,
        background: MF.bg.raised, border: `1px solid ${MF.line.hairline}`,
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        color: MF.ink.primary,
        boxShadow: MF.elev.chip,
        cursor: 'pointer',
        ...style,
      }}>{children}</button>
  );
}

// ─── Stat block: caption above big tabular number ───
function BigStat({ label, value, unit, size = 40, color, style = {} }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 6, ...style }}>
      <Eyebrow>{label}</Eyebrow>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
        <span style={{ ...TYPE.num, fontSize: size, lineHeight: `${size}px`, color: color ?? MF.ink.primary }}>{value}</span>
        {unit && <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>{unit}</span>}
      </div>
    </div>
  );
}

// ─── Avatar (small, round — used in chrome) ───
// Concentric hairline ring + stamped initials over a tonal radial.
function Avatar({ size = 40, initials = 'OK', style = {} }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size / 2, position: 'relative', overflow: 'hidden',
      background:
        'radial-gradient(circle at 30% 25%, #2a2a2a 0%, #161616 55%, #0a0a0a 100%)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      boxShadow:
        '0 0 0 1px rgba(255,255,255,0.18), inset 0 0 0 3px #000, inset 0 0 0 4px rgba(255,255,255,0.10)',
      ...style,
    }}>
      <span style={{
        fontFamily: MF.font.display, fontWeight: 800,
        fontSize: size * 0.36, letterSpacing: 0.6,
        color: '#fff',
      }}>{initials}</span>
    </div>
  );
}

// ─── Monogram (large, square — dossier/player-card treatment) ───
// Stamped initials in heavy display + diagonal slash, kit number corner.
function Monogram({ size = 96, initials = 'OK', kit = '09', style = {} }) {
  return (
    <div style={{
      width: size, height: size, position: 'relative', overflow: 'hidden',
      background:
        'linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 60%, #050505 100%)',
      border: `1px solid ${MF.line.strong}`, borderRadius: 4,
      boxShadow: 'inset 0 0 0 1px rgba(0,0,0,0.6)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      ...style,
    }}>
      {/* diagonal slash motif — bottom-left of the M */}
      <svg width={size} height={size} viewBox="0 0 100 100" preserveAspectRatio="none"
        style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
        <line x1="0"  y1="40" x2="35" y2="0"  stroke="rgba(255,255,255,0.06)" strokeWidth="1.2"/>
        <line x1="0"  y1="55" x2="50" y2="0"  stroke="rgba(255,255,255,0.05)" strokeWidth="1.2"/>
        <line x1="0"  y1="70" x2="65" y2="0"  stroke="rgba(255,255,255,0.04)" strokeWidth="1.2"/>
      </svg>
      <span style={{
        fontFamily: MF.font.display, fontWeight: 800,
        fontSize: size * 0.46, letterSpacing: -1.2,
        color: '#fff', position: 'relative', zIndex: 1,
      }}>{initials}</span>
      {kit && (
        <div style={{
          position: 'absolute', right: 6, top: 6,
          ...TYPE.micro, color: 'rgba(255,255,255,0.78)', letterSpacing: 1.6,
        }}>#{kit}</div>
      )}
    </div>
  );
}

// ─── Athletic photo placeholder ───
// Slashed / striped surface — never a real photo, always reads as "drop image here"
function PhotoPlaceholder({ height = 200, label = 'COACH FILM', tone = 'dark', style = {}, children }) {
  const stripes = tone === 'dark'
    ? 'repeating-linear-gradient(115deg, #0e0e0e 0px, #0e0e0e 18px, #141414 18px, #141414 36px)'
    : 'repeating-linear-gradient(115deg, #e8e8e8 0px, #e8e8e8 18px, #f3f3f3 18px, #f3f3f3 36px)';
  return (
    <div style={{
      width: '100%', height, borderRadius: 18, overflow: 'hidden', position: 'relative',
      background: stripes,
      border: `1px solid ${tone === 'dark' ? MF.line.hairline : 'rgba(0,0,0,0.06)'}`,
      ...style,
    }}>
      {/* Diagonal cut overlay echoing the logo */}
      <svg width="100%" height="100%" viewBox="0 0 400 200" preserveAspectRatio="none"
        style={{ position: 'absolute', inset: 0, opacity: 0.6 }}>
        <polygon points="0,0 120,0 80,200 0,200" fill="rgba(0,0,0,0.18)"/>
        <polygon points="400,0 400,200 320,200 360,0" fill="rgba(0,0,0,0.12)"/>
      </svg>
      {label && (
        <div style={{ position: 'absolute', left: 14, bottom: 14, ...TYPE.micro, color: 'rgba(255,255,255,0.78)' }}>
          ▸ {label}
        </div>
      )}
      {children}
    </div>
  );
}

// ─── Liquid-glass tab bar (iOS 26 style) ───
// Layered: glass surface · top shine · inner edges · active-tab lens
function TabBar({ active = 'dashboard' }) {
  const tabs = [
    { id: 'dashboard', label: 'Today',    icon: tabIcon('home') },
    { id: 'hub',       label: 'MF Hub',   icon: tabIcon('hub') },
    { id: 'progress',  label: 'Progress', icon: tabIcon('progress') },
    { id: 'profile',   label: 'Profile',  icon: tabIcon('profile') },
  ];
  return (
    <div style={{
      position: 'absolute', left: 14, right: 14, bottom: 26, zIndex: 30,
      height: 68, borderRadius: 34,
      // Layered ambient + lift shadow
      boxShadow:
        '0 24px 56px rgba(0,0,0,0.55), ' +
        '0 6px 18px rgba(0,0,0,0.32), ' +
        '0 1px 0 rgba(0,0,0,0.6)',
    }}>
      {/* Glass surface — the actual liquid */}
      <div style={{
        position: 'absolute', inset: 0, borderRadius: 34, overflow: 'hidden',
        background:
          'linear-gradient(180deg, rgba(46,46,48,0.42) 0%, rgba(22,22,24,0.55) 100%)',
        backdropFilter: 'blur(42px) saturate(200%) brightness(1.04)',
        WebkitBackdropFilter: 'blur(42px) saturate(200%) brightness(1.04)',
        // Lensing — inner rim of light + dark to give it dimension
        boxShadow:
          'inset 0 1.5px 0 rgba(255,255,255,0.22), ' +
          'inset 0 -1px 0 rgba(0,0,0,0.34), ' +
          'inset 1px 0 0 rgba(255,255,255,0.06), ' +
          'inset -1px 0 0 rgba(255,255,255,0.06)',
      }}>
        {/* Top shine — the diagnostic specular of liquid glass */}
        <div style={{
          position: 'absolute', top: 0, left: 12, right: 12, height: 18,
          background:
            'linear-gradient(180deg, rgba(255,255,255,0.22) 0%, rgba(255,255,255,0) 100%)',
          borderRadius: '34px 34px 0 0',
          pointerEvents: 'none',
        }}/>
        {/* Bottom dark vignette */}
        <div style={{
          position: 'absolute', bottom: 0, left: 12, right: 12, height: 14,
          background:
            'linear-gradient(0deg, rgba(0,0,0,0.18) 0%, rgba(0,0,0,0) 100%)',
          pointerEvents: 'none',
        }}/>

        {/* Tabs */}
        <div style={{
          position: 'relative', zIndex: 1, height: '100%',
          display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
        }}>
          {tabs.map((t) => {
            const isActive = t.id === active;
            return (
              <div key={t.id} style={{ position: 'relative' }}>
                {/* Active-tab "lens" — refracted highlight under the active icon */}
                {isActive && (
                  <>
                    <div style={{
                      position: 'absolute', inset: 6, borderRadius: 22,
                      background:
                        'radial-gradient(120% 90% at 50% 30%, rgba(255,255,255,0.22) 0%, rgba(255,255,255,0.06) 45%, transparent 75%)',
                      pointerEvents: 'none',
                    }}/>
                    {/* Top hairline indicator */}
                    <div style={{
                      position: 'absolute', top: 4, left: '50%', transform: 'translateX(-50%)',
                      width: 22, height: 2, borderRadius: 1,
                      background: '#fff',
                      boxShadow: '0 0 12px rgba(255,255,255,0.6)',
                    }}/>
                  </>
                )}
                <div style={{
                  position: 'relative', height: '100%',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4,
                  color: isActive ? '#fff' : 'rgba(255,255,255,0.50)',
                }}>
                  {t.icon(isActive ? '#fff' : 'rgba(255,255,255,0.50)')}
                  <span style={{
                    fontFamily: MF.font.mono, fontSize: 9, letterSpacing: 1.2,
                    fontWeight: 600, textTransform: 'uppercase',
                  }}>{t.label}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function tabIcon(kind) {
  return (color) => {
    if (kind === 'home') return (
      <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
        <path d="M3 9.5L11 3l8 6.5V18a1 1 0 01-1 1h-4v-6h-6v6H4a1 1 0 01-1-1V9.5z"
          stroke={color} strokeWidth="1.6" strokeLinejoin="round"/>
      </svg>
    );
    if (kind === 'hub') return (
      <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
        <rect x="3" y="3" width="7" height="7" rx="1.5" stroke={color} strokeWidth="1.6"/>
        <rect x="12" y="3" width="7" height="7" rx="1.5" stroke={color} strokeWidth="1.6"/>
        <rect x="3" y="12" width="7" height="7" rx="1.5" stroke={color} strokeWidth="1.6"/>
        <rect x="12" y="12" width="7" height="7" rx="1.5" stroke={color} strokeWidth="1.6"/>
      </svg>
    );
    if (kind === 'progress') return (
      <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
        <path d="M3 17l5-6 4 3 7-9" stroke={color} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/>
        <circle cx="19" cy="5" r="1.6" fill={color}/>
      </svg>
    );
    if (kind === 'profile') return (
      <svg width="22" height="22" viewBox="0 0 22 22" fill="none">
        <circle cx="11" cy="8" r="3.4" stroke={color} strokeWidth="1.6"/>
        <path d="M4 19c1.5-3 4-4.5 7-4.5s5.5 1.5 7 4.5" stroke={color} strokeWidth="1.6" strokeLinecap="round"/>
      </svg>
    );
  };
}

// ─── Pitch-line ring (clean stroked progress ring — no gradient) ───
function PitchRing({ size = 110, progress = 0.68, stroke = 8, value = '68', label = 'WEEK LOAD' }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  return (
    <div style={{ width: size, height: size, position: 'relative' }}>
      <svg width={size} height={size}>
        <circle cx={size/2} cy={size/2} r={r} stroke={MF.line.subtle} strokeWidth={stroke} fill="none"/>
        <circle cx={size/2} cy={size/2} r={r}
          stroke="#fff" strokeWidth={stroke} strokeLinecap="butt" fill="none"
          strokeDasharray={`${c * progress} ${c}`}
          transform={`rotate(-90 ${size/2} ${size/2})`}/>
      </svg>
      <div style={{
        position: 'absolute', inset: 0, display: 'flex',
        flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      }}>
        <span style={{ ...TYPE.num, fontSize: size * 0.32, lineHeight: 1, color: MF.ink.primary }}>{value}</span>
        <span style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>{label}</span>
      </div>
    </div>
  );
}

// ─── Card surface (consistent radius + hairline + soft lift) ───
function Card({ children, padding = 20, raised = false, style = {} }) {
  return (
    <div style={{
      background: MF.bg.card, borderRadius: 22,
      border: `1px solid ${MF.line.hairline}`, padding,
      boxShadow: raised ? MF.elev.raised : MF.elev.card,
      ...style,
    }}>{children}</div>
  );
}

// ─── Section heading (mono eyebrow + display title) ───
function SectionHead({ eyebrow, title, style = {} }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8, ...style }}>
      {eyebrow && <Eyebrow>{eyebrow}</Eyebrow>}
      <div style={{ ...TYPE.title2, color: MF.ink.primary }}>{title}</div>
    </div>
  );
}

Object.assign(window, {
  MFMark, Eyebrow, Hairline, VLine, SlashRule,
  PrimaryButton, FloatingButton, SecondaryButton, GhostButton,
  Chip, BigStat, IconButton, Avatar, Monogram,
  PhotoPlaceholder, TabBar, PitchRing, Card, SectionHead,
});
