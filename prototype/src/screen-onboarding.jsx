// MF Elite — Onboarding · 6 cinematic chapters
// Splash → 00 Code → 01 Identify → 02 Position → 03 Pledge → 04 Number → 05 Passport

// ── 0. Splash (kept) ─────────────────────────────────────────
function ScrSplash() {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative', background: '#000',
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
    }}>
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.4,
        backgroundImage:
          'repeating-linear-gradient(115deg, transparent 0px, transparent 60px, rgba(255,255,255,0.022) 60px, rgba(255,255,255,0.022) 61px)',
      }}/>
      <div style={{ position: 'relative', zIndex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 36 }}>
        <MFMark size={280}/>
      </div>
      <div style={{ position: 'absolute', bottom: 80, left: '50%', transform: 'translateX(-50%)', width: 80, height: 1.5, background: 'rgba(255,255,255,0.18)', overflow: 'hidden' }}>
        <div style={{ width: '40%', height: '100%', background: '#fff' }}/>
      </div>
    </div>
  );
}

// ── Shared helpers ────────────────────────────────────────────
function ChapterEyebrow({ num, label }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
      <span style={{ ...TYPE.micro, color: '#fff', letterSpacing: 2, fontWeight: 700 }}>
        {String(num).padStart(2, '0')}
      </span>
      <span style={{ width: 24, height: 1, background: 'rgba(255,255,255,0.4)' }}/>
      <span style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 2 }}>{label}</span>
    </div>
  );
}

function StepBar({ at, total = 6 }) {
  return (
    <div style={{ display: 'flex', gap: 4 }}>
      {Array.from({ length: total }).map((_, i) => (
        <div key={i} style={{
          flex: 1, height: 2,
          background: i < at ? '#fff' : 'rgba(255,255,255,0.14)',
        }}/>
      ))}
    </div>
  );
}

function ArrowCTA({ children, style = {} }) {
  return (
    <button
      type="button"
      className="mf-btn mf-btn-secondary"
      style={{
        appearance: 'none', border: `1px solid ${MF.line.strong}`, cursor: 'pointer',
        background: 'transparent', color: '#fff',
        padding: '14px 22px', borderRadius: MF.r.pill,
        ...TYPE.foot, fontWeight: 700, letterSpacing: 1.4, textTransform: 'uppercase',
        display: 'inline-flex', alignItems: 'center', gap: 10,
        boxShadow: MF.elev.none,
        ...style,
      }}>
      <span>{children}</span>
      <svg width="14" height="10" viewBox="0 0 14 10"><path d="M1 5h12m0 0L9 1m4 4L9 9" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
    </button>
  );
}

// ── 1. THE CODE — creed slate ────────────────────────────────
function ScrOnboardCode() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.4,
        backgroundImage:
          'repeating-linear-gradient(115deg, transparent 0px, transparent 60px, rgba(255,255,255,0.018) 60px, rgba(255,255,255,0.018) 61px)',
      }}/>
      {/* Top mark — sized for premium presence */}
      <div style={{ position: 'absolute', top: 70, left: 0, right: 0, display: 'flex', justifyContent: 'center' }}>
        <MFMark size={56}/>
      </div>

      {/* Creed */}
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center', padding: '0 30px', textAlign: 'center',
      }}>
        <div style={{ ...TYPE.micro, color: 'rgba(255,255,255,0.75)', letterSpacing: 3, marginBottom: 28 }}>
          THE CODE
        </div>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 800,
          fontSize: 48, lineHeight: '54px', letterSpacing: -1.4, color: '#fff',
          whiteSpace: 'nowrap',
        }}>
          One coach.<br/>One athlete.<br/>One purpose.
        </div>
      </div>

      {/* Footer */}
      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 56, display: 'flex', flexDirection: 'column', gap: 22 }}>
        <SlashRule/>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <ChapterEyebrow num={0} label="THE CODE"/>
          <ArrowCTA>I'm in</ArrowCTA>
        </div>
        <StepBar at={1}/>
      </div>
    </div>
  );
}

// ── 2. IDENTIFY — name the athlete ───────────────────────────
function ScrOnboardIdentify() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden' }}>
      {/* Top half — portrait */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 440 }}>
        <PhotoPlaceholder height={440} label="ATHLETE · ROOM TONE" style={{ borderRadius: 0, border: 'none' }}>
          <div style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(to bottom, rgba(0,0,0,0.5) 0%, rgba(0,0,0,0) 28%, rgba(0,0,0,0) 60%, #000 100%)',
          }}/>
          <div style={{ position: 'absolute', top: 70, left: 24 }}>
            <MFMark size={20}/>
          </div>
          <div style={{ position: 'absolute', top: 110, left: 24, right: 24 }}>
            <ChapterEyebrow num={1} label="IDENTIFY"/>
          </div>
        </PhotoPlaceholder>
      </div>

      {/* Bottom content */}
      <div style={{ position: 'absolute', top: 380, left: 0, right: 0, bottom: 0, padding: '0 24px 56px', display: 'flex', flexDirection: 'column' }}>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 800,
          fontSize: 44, lineHeight: '46px', letterSpacing: -1.3, color: '#fff',
          textWrap: 'balance',
        }}>
          Enter your<br/>name.
        </div>

        {/* Name input — underline style, editorial */}
        <div style={{ marginTop: 36 }}>
          <Eyebrow style={{ marginBottom: 12 }}>YOUR NAME</Eyebrow>
          <div style={{
            fontFamily: MF.font.display, fontWeight: 700,
            fontSize: 32, lineHeight: '36px', color: '#fff', letterSpacing: -0.8,
            paddingBottom: 14,
            borderBottom: `1.5px solid #fff`,
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          }}>
            <span>Player One<span style={{ color: '#fff', animation: 'mfBlink 1s steps(1) infinite', marginLeft: 4 }}>|</span></span>
            <span style={{ ...TYPE.micro, color: MF.ink.tertiary, fontFamily: MF.font.mono }}>10</span>
          </div>
          <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 12 }}>
            This name appears on your dossier and on every report your coach writes.
          </div>
        </div>

        <div style={{ flex: 1 }}/>
        <PrimaryButton>Continue</PrimaryButton>
        <div style={{ marginTop: 16 }}><StepBar at={2}/></div>
      </div>
    </div>
  );
}

// ── 3. POSITION — cinematic pitch (clickable) ────────────────
function ScrOnboardPosition() {
  // Position keys must be unique (CM/CM/CB-side etc.); names map to display labels.
  const positions = [
    { id: 'ST',   name: 'Striker',         code: 'ST',  x: '50%', y: '14%' },
    { id: 'LW',   name: 'Left Winger',     code: 'LW',  x: '32%', y: '28%' },
    { id: 'RW',   name: 'Right Winger',    code: 'RW',  x: '68%', y: '28%' },
    { id: 'CAM',  name: 'Attacking Mid',   code: 'CAM', x: '50%', y: '44%' },
    { id: 'CM_L', name: 'Centre Mid',      code: 'CM',  x: '32%', y: '56%' },
    { id: 'CM_R', name: 'Centre Mid',      code: 'CM',  x: '68%', y: '56%' },
    { id: 'LB',   name: 'Left Back',       code: 'LB',  x: '22%', y: '74%' },
    { id: 'CB',   name: 'Centre Back',     code: 'CB',  x: '50%', y: '74%' },
    { id: 'RB',   name: 'Right Back',      code: 'RB',  x: '78%', y: '74%' },
    { id: 'GK',   name: 'Goalkeeper',      code: 'GK',  x: '50%', y: '92%' },
  ];
  const [pickedId, setPickedId] = React.useState('ST');
  const picked = positions.find(p => p.id === pickedId) || positions[0];

  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden' }}>
      {/* Header */}
      <div style={{ padding: '70px 24px 0' }}>
        <ChapterEyebrow num={2} label="POSITION"/>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 800,
          fontSize: 40, lineHeight: '42px', letterSpacing: -1.2, color: '#fff',
          marginTop: 14, textWrap: 'balance',
        }}>
          Where you live<br/>on the pitch.
        </div>
      </div>

      {/* Pitch — full-bleed left to right, fades to black */}
      <div style={{
        position: 'absolute', left: 0, right: 0, top: 220, bottom: 180,
        background: '#0a0a0a',
        borderTop: `1px solid ${MF.line.subtle}`,
        borderBottom: `1px solid ${MF.line.subtle}`,
        overflow: 'hidden',
      }}>
        {/* Diagonal slash field underneath */}
        <div style={{
          position: 'absolute', inset: 0, opacity: 0.35,
          backgroundImage:
            'repeating-linear-gradient(115deg, transparent 0px, transparent 22px, rgba(255,255,255,0.05) 22px, rgba(255,255,255,0.05) 23px)',
        }}/>
        {/* Pitch lines */}
        <svg width="100%" height="100%" viewBox="0 0 360 380" preserveAspectRatio="xMidYMid meet" style={{ position: 'absolute', inset: 0 }}>
          <g stroke="rgba(255,255,255,0.28)" strokeWidth="1.2" fill="none">
            <rect x="20" y="14" width="320" height="354"/>
            <line x1="20" y1="191" x2="340" y2="191"/>
            <circle cx="180" cy="191" r="42"/>
            <circle cx="180" cy="191" r="2.5" fill="rgba(255,255,255,0.6)" stroke="none"/>
            <rect x="110" y="14"  width="140" height="48"/>
            <rect x="110" y="320" width="140" height="48"/>
            <rect x="150" y="14"  width="60"  height="18"/>
            <rect x="150" y="350" width="60"  height="18"/>
          </g>
        </svg>
        {/* Position dots — clickable */}
        {positions.map((p) => (
          <PitchDot key={p.id} x={p.x} y={p.y} code={p.code}
            selected={p.id === pickedId}
            onSelect={() => setPickedId(p.id)}/>
        ))}

        {/* Fade edges */}
        <div style={{
          position: 'absolute', inset: 0, pointerEvents: 'none',
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.4) 0%, rgba(0,0,0,0) 12%, rgba(0,0,0,0) 88%, rgba(0,0,0,0.6) 100%)',
        }}/>
      </div>

      {/* Selected reveal */}
      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 138 }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <div>
            <Eyebrow>SELECTED · POST</Eyebrow>
            <div style={{ ...TYPE.title1, color: '#fff', marginTop: 6 }}>{picked.name} · {picked.code}</div>
          </div>
          <div style={{ ...TYPE.micro, color: MF.ink.tertiary }}>TAP TO CHANGE</div>
        </div>
      </div>

      {/* Footer */}
      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 56, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <PrimaryButton>Continue · {picked.name}</PrimaryButton>
        <StepBar at={3}/>
      </div>
    </div>
  );
}

function PitchDot({ x, y, code, selected, onSelect }) {
  return (
    <button onClick={onSelect} style={{
      appearance: 'none', border: 'none', background: 'transparent', cursor: 'pointer',
      position: 'absolute', left: x, top: y, transform: 'translate(-50%, -50%)',
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6,
      padding: 4,
    }}>
      <div style={{
        width: selected ? 32 : 20, height: selected ? 32 : 20, borderRadius: 999,
        background: selected ? '#fff' : 'rgba(255,255,255,0.12)',
        border: selected ? 'none' : '1.5px solid rgba(255,255,255,0.55)',
        boxShadow: selected
          ? '0 0 0 6px rgba(255,255,255,0.10), 0 0 28px rgba(255,255,255,0.45)'
          : 'none',
        transition: 'all .22s ease',
      }}/>
      <span style={{
        fontFamily: MF.font.display, fontWeight: 700, fontSize: 12,
        letterSpacing: 1.6,
        color: selected ? '#fff' : 'rgba(255,255,255,0.78)',
      }}>{code}</span>
    </button>
  );
}

// ── 4. PLEDGE — three vows ───────────────────────────────────
function ScrOnboardPledge() {
  const tiers = [
    { id: 'recovery', name: 'Recovery',  meta: '2 / week · 25 min',
      pledge: 'I will keep moving. I will come back stronger than I left.' },
    { id: 'standard', name: 'Standard',  meta: '4 / week · 35 min',
      pledge: 'I will train. I will compete. I will close the gap.', selected: true },
    { id: 'elite',    name: 'Elite',     meta: '6 / week · 45 min',
      pledge: 'I will outwork the room. Every session. No exceptions.' },
  ];
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden' }}>
      <div style={{ padding: '70px 24px 0' }}>
        <ChapterEyebrow num={3} label="THE PLEDGE"/>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 800,
          fontSize: 40, lineHeight: '42px', letterSpacing: -1.2, color: '#fff',
          marginTop: 14, textWrap: 'balance',
        }}>
          How much<br/>will you give?
        </div>
      </div>

      <div style={{ padding: '28px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {tiers.map((t) => (
          <div key={t.id} style={{
            padding: '20px 22px', borderRadius: 4,
            background: t.selected ? '#fff' : 'transparent',
            color: t.selected ? '#000' : '#fff',
            border: t.selected ? '1px solid #fff' : `1px solid ${MF.line.subtle}`,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{ ...TYPE.title2, color: t.selected ? '#000' : '#fff' }}>{t.name}</div>
              <Eyebrow style={{ color: t.selected ? 'rgba(0,0,0,0.55)' : MF.ink.tertiary }}>{t.meta}</Eyebrow>
            </div>
            <div style={{
              ...TYPE.body,
              color: t.selected ? 'rgba(0,0,0,0.7)' : MF.ink.secondary,
              marginTop: 10, fontStyle: 'italic',
              borderLeft: `2px solid ${t.selected ? '#000' : 'rgba(255,255,255,0.18)'}`,
              paddingLeft: 12,
            }}>
              {t.pledge}
            </div>
          </div>
        ))}
      </div>

      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 56, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <PrimaryButton>Sign the pledge</PrimaryButton>
        <StepBar at={4}/>
      </div>
    </div>
  );
}

// ── 5. NUMBER — kit number with live monogram + keypad ───────
function ScrOnboardNumber() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden' }}>
      {/* Header */}
      <div style={{ padding: '70px 24px 0' }}>
        <ChapterEyebrow num={4} label="YOUR NUMBER"/>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 800,
          fontSize: 44, lineHeight: '46px', letterSpacing: -1.3, color: '#fff',
          marginTop: 14, textWrap: 'balance',
        }}>
          Pick your<br/>number.
        </div>
      </div>

      {/* Monogram preview — large, centered */}
      <div style={{
        position: 'absolute', left: 0, right: 0, top: 240,
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18,
      }}>
        <div style={{
          width: 168, height: 168, borderRadius: 6, position: 'relative', overflow: 'hidden',
          background: 'linear-gradient(135deg, #1a1a1a 0%, #0a0a0a 60%, #050505 100%)',
          border: `1px solid ${MF.line.strong}`,
        }}>
          <svg width="168" height="168" viewBox="0 0 100 100" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
            <line x1="0" y1="40" x2="35" y2="0" stroke="rgba(255,255,255,0.06)" strokeWidth="1.2"/>
            <line x1="0" y1="55" x2="50" y2="0" stroke="rgba(255,255,255,0.05)" strokeWidth="1.2"/>
            <line x1="0" y1="70" x2="65" y2="0" stroke="rgba(255,255,255,0.04)" strokeWidth="1.2"/>
          </svg>
          <div style={{
            position: 'absolute', inset: 0,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontFamily: MF.font.display, fontWeight: 800,
            fontSize: 110, color: '#fff', letterSpacing: -4,
            fontVariantNumeric: 'tabular-nums',
          }}>09</div>
          <div style={{
            position: 'absolute', right: 10, top: 10,
            ...TYPE.micro, color: 'rgba(255,255,255,0.78)', letterSpacing: 1.8,
          }}>MF · ST</div>
          <div style={{
            position: 'absolute', left: 10, bottom: 10,
            ...TYPE.micro, color: 'rgba(255,255,255,0.72)', letterSpacing: 1.4,
          }}>P1</div>
        </div>
        <Eyebrow>STRIKER · PLAYER ONE</Eyebrow>
      </div>

      {/* Keypad */}
      <div style={{
        position: 'absolute', left: 24, right: 24, bottom: 130,
        display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8,
      }}>
        {['1','2','3','4','5','6','7','8','9','','0','⌫'].map((k, i) => (
          <button key={i} disabled={!k} style={{
            height: 50, borderRadius: 12, cursor: k ? 'pointer' : 'default',
            background: k ? '#0d0d0d' : 'transparent',
            border: k ? `1px solid ${MF.line.subtle}` : 'none',
            color: '#fff',
            fontFamily: MF.font.display, fontWeight: 600, fontSize: 22, letterSpacing: -0.5,
          }}>{k}</button>
        ))}
      </div>

      {/* Footer */}
      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 56, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <PrimaryButton>Take the number</PrimaryButton>
        <StepBar at={5}/>
      </div>
    </div>
  );
}

// ── 6. PASSPORT — the welcome reveal ─────────────────────────
function ScrOnboardPassport() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden' }}>
      {/* faint stripes */}
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.4,
        backgroundImage:
          'repeating-linear-gradient(115deg, transparent 0px, transparent 60px, rgba(255,255,255,0.018) 60px, rgba(255,255,255,0.018) 61px)',
      }}/>

      {/* Top */}
      <div style={{ padding: '70px 24px 0', position: 'relative', zIndex: 1 }}>
        <ChapterEyebrow num={5} label="WELCOME"/>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 800,
          fontSize: 38, lineHeight: '40px', letterSpacing: -1.1, color: '#fff',
          marginTop: 14, textWrap: 'balance',
        }}>
          Welcome to MF,<br/>Player One.
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12, maxWidth: 300 }}>
          You are now Class of 2026. Your first session is tomorrow at 06:30.
        </div>
      </div>

      {/* Passport card — inverse white card on black */}
      <div style={{
        position: 'absolute', left: 24, right: 24, top: 290, zIndex: 2,
        background: '#fff', color: '#000', borderRadius: 6,
        padding: 18, overflow: 'hidden',
        boxShadow: '0 30px 60px rgba(0,0,0,0.6), 0 0 0 1px rgba(255,255,255,0.18)',
      }}>
        {/* Top bar */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <MFMark size={16} dark={false}/>
            <span style={{ ...TYPE.micro, color: '#000', letterSpacing: 2 }}>MF · MEMBER № 1142</span>
          </div>
          <span style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.55)' }}>CLASS · 2026</span>
        </div>

        <div style={{ display: 'flex', gap: 14, marginTop: 16 }}>
          {/* Portrait */}
          <div style={{
            width: 92, height: 116, flexShrink: 0, position: 'relative', overflow: 'hidden',
            background: 'repeating-linear-gradient(115deg, #e8e8e8 0px, #e8e8e8 8px, #f0f0f0 8px, #f0f0f0 16px)',
            border: '1px solid rgba(0,0,0,0.12)',
          }}>
            <svg width="100%" height="100%" viewBox="0 0 92 116" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
              <polygon points="0,0 30,0 20,116 0,116" fill="rgba(0,0,0,0.10)"/>
            </svg>
            <div style={{
              position: 'absolute', left: 6, bottom: 6,
              ...TYPE.micro, color: 'rgba(0,0,0,0.4)',
            }}>▸ PHOTO</div>
          </div>
          {/* Identity */}
          <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div>
              <Eyebrow style={{ color: 'rgba(0,0,0,0.55)' }}>NAME</Eyebrow>
              <div style={{ ...TYPE.title2, color: '#000', marginTop: 2 }}>Player One</div>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8, marginTop: 8 }}>
              <PassRow k="POST"   v="Striker"/>
              <PassRow k="KIT"    v="09"/>
              <PassRow k="FOOT"   v="Right"/>
              <PassRow k="COACH"  v="Coach Matteo Finazzi"/>
            </div>
          </div>
        </div>

        <SlashRule color="rgba(0,0,0,0.15)" style={{ marginTop: 16 }}/>

        {/* Bottom strip — Coach + Block */}
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginTop: 14 }}>
          <div>
            <Eyebrow style={{ color: 'rgba(0,0,0,0.55)' }}>COACH</Eyebrow>
            <div style={{ ...TYPE.foot, color: '#000', fontWeight: 700, marginTop: 2 }}>Coach Matteo Finazzi</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <Eyebrow style={{ color: 'rgba(0,0,0,0.55)' }}>BLOCK</Eyebrow>
            <div style={{ ...TYPE.num, fontSize: 22, color: '#000', marginTop: 2 }}>01 / 06</div>
          </div>
        </div>
      </div>

      {/* Footer */}
      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 56, display: 'flex', flexDirection: 'column', gap: 14, zIndex: 1 }}>
        <PrimaryButton>Enter the academy</PrimaryButton>
        <StepBar at={6}/>
      </div>
    </div>
  );
}

function PassRow({ k, v }) {
  return (
    <div>
      <Eyebrow style={{ color: 'rgba(0,0,0,0.5)', fontSize: 9 }}>{k}</Eyebrow>
      <div style={{ ...TYPE.foot, color: '#000', fontWeight: 700, marginTop: 2 }}>{v}</div>
    </div>
  );
}

function Barcode() {
  // Deterministic pseudo-barcode pattern — looks real without being a real code
  const w = [2,1,2,3,1,2,1,1,3,2,1,2,1,3,1,2,1,1,2,3,1,2,2,1,1,3,1,2,1,2];
  return (
    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 1, height: 28 }}>
      {w.map((bw, i) => (
        <div key={i} style={{ width: bw, height: '100%', background: i % 2 === 0 ? '#000' : 'transparent' }}/>
      ))}
      <span style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.55)', fontFamily: MF.font.mono, marginLeft: 10 }}>
        MF · OK09 · 2026
      </span>
    </div>
  );
}

Object.assign(window, {
  ScrSplash,
  ScrOnboardCode, ScrOnboardIdentify, ScrOnboardPosition, ScrOnboardPledge,
  ScrOnboardNumber, ScrOnboardPassport,
  ChapterEyebrow, StepBar, ArrowCTA, PitchDot, PassRow, Barcode,
});
