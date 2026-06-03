// MF Elite — Design system boards + developer handoff
// These render as non-phone artboards inside the design canvas.

// ── Helpers ───────────────────────────────────────────────────
function Board({ title, eyebrow, width = 720, height, children, padding = 40, style = {} }) {
  return (
    <div style={{
      width, minHeight: height, background: MF.bg.base, color: '#fff',
      padding, boxSizing: 'border-box', borderRadius: 24,
      border: `1px solid ${MF.line.hairline}`,
      display: 'flex', flexDirection: 'column', gap: 28,
      ...style,
    }}>
      <div>
        {eyebrow && <Eyebrow>{eyebrow}</Eyebrow>}
        <div style={{ ...TYPE.title1, color: '#fff', marginTop: 6 }}>{title}</div>
      </div>
      {children}
    </div>
  );
}

function ColLabel({ children }) {
  return <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginBottom: 8 }}>{children}</div>;
}

// ── 1. PALETTE BOARD ──────────────────────────────────────────
function BrdPalette() {
  const ladder = [
    ['base',     '#000000', 'App background'],
    ['elevated', '#0A0A0A', 'Sheets · pinned headers'],
    ['card',     '#121212', 'Card surface'],
    ['raised',   '#1A1A1A', 'Buttons · raised UI'],
    ['tint',     '#262626', 'Toggle track · hover'],
  ];
  const lines = [
    ['hairline', 'rgba(255,255,255,0.06)', '1px dividers inside cards'],
    ['subtle',   'rgba(255,255,255,0.10)', 'Card outline · chips'],
    ['strong',   'rgba(255,255,255,0.18)', 'Ghost button border'],
  ];
  const ink = [
    ['primary',    'rgba(255,255,255,1.00)', 'Headlines · primary text'],
    ['secondary',  'rgba(255,255,255,0.90)', 'Body copy on dark'],
    ['tertiary',   'rgba(255,255,255,0.72)', 'Captions · metadata'],
    ['quaternary', 'rgba(255,255,255,0.52)', 'Placeholders'],
    ['disabled',   'rgba(255,255,255,0.32)', 'Disabled states'],
  ];
  return (
    <Board title="Palette" eyebrow="01 · TOKENS" width={720} height={760}>
      <SlashRule />
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32 }}>
        <div>
          <ColLabel>SURFACE LADDER · BG/*</ColLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {ladder.map(([n, v, d]) => (
              <div key={n} style={{
                display: 'flex', alignItems: 'center', gap: 14,
                background: v, border: `1px solid ${MF.line.hairline}`,
                padding: '14px 16px', borderRadius: 12,
              }}>
                <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700, flex: 1 }}>bg.{n}</div>
                <div style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{v}</div>
              </div>
            ))}
          </div>
          <ColLabel style={{ marginTop: 24 }}>LINES · LINE/*</ColLabel>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
            {lines.map(([n, v, d]) => (
              <div key={n} style={{
                background: MF.bg.card, borderRadius: 12, padding: '12px 14px',
                display: 'flex', alignItems: 'center', gap: 12,
              }}>
                <div style={{ width: 28, height: 28, borderRadius: 6, background: 'transparent', border: `1px solid ${v}` }}/>
                <div style={{ flex: 1, ...TYPE.callout, fontWeight: 600, color: '#fff' }}>line.{n}</div>
                <div style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{d}</div>
              </div>
            ))}
          </div>
        </div>
        <div>
          <ColLabel>TEXT ON DARK · INK/*</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 14, padding: 18, display: 'flex', flexDirection: 'column', gap: 14 }}>
            {ink.map(([n, v, d]) => (
              <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <span style={{ width: 96, ...TYPE.foot, fontWeight: 700, color: v }}>ink.{n}</span>
                <span style={{ flex: 1, ...TYPE.foot, color: v }}>The quick brown fox.</span>
                <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{Math.round(parseFloat(v.replace(/.*,([0-9.]+)\).*/,'$1'))*100)}%</span>
              </div>
            ))}
          </div>
          <ColLabel style={{ marginTop: 24 }}>USAGE NOTES</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 14, padding: 18 }}>
            <ul style={{ ...TYPE.body, color: MF.ink.secondary, margin: 0, paddingLeft: 18, display: 'flex', flexDirection: 'column', gap: 8 }}>
              <li>No saturated colors. Pure mono palette only.</li>
              <li>Inverse surfaces (white on black) reserved for primary CTAs and a single hero card per screen.</li>
              <li>Never combine two inverse surfaces side-by-side — keep one focal point.</li>
              <li>Status colors (success/error) ship as <code style={{ ...TYPE.micro, color: '#fff' }}>ink.primary</code> with iconography, not hue.</li>
              <li>Light-mode pair exists but ships v1.1 — dark-mode is the canonical brand.</li>
            </ul>
          </div>
        </div>
      </div>
    </Board>
  );
}

// ── 2. TYPOGRAPHY BOARD ───────────────────────────────────────
function BrdType() {
  const rows = [
    ['Hero · display.hero',    'Train where the pros train',  TYPE.hero,    '48 / 50 · -1.6 · 800'],
    ['Display · display.36',   'The whole academy. Unlocked', TYPE.display, '36 / 38 · -1.1 · 800'],
    ['Title 1 · title1',       'First touch under pressure',  TYPE.title1,  '28 / 32 · -0.6 · 700'],
    ['Title 2 · title2',       'Build my program',            TYPE.title2,  '22 / 26 · -0.4 · 700'],
    ['Title 3 · title3',       'Acceleration ladders',        TYPE.title3,  '17 / 22 · -0.2 · 600'],
    ['Body · body',            'A closed academy for one-on-one development.', TYPE.body, '16 / 22 · -0.1 · 400'],
    ['Callout · callout',      'Cancel any time',             TYPE.callout, '15 / 20 · -0.1 · 500'],
    ['Foot · foot',            'Coach · Finazzi',                 TYPE.foot,    '13 / 18 · 0 · 500'],
    ['Micro · micro (mono)',   'BLOCK 03 · DAY 02',           TYPE.micro,   '10 / 12 · 1.2 · 500 · mono'],
  ];
  return (
    <Board title="Typography" eyebrow="02 · TYPE" width={780} height={780}>
      <div style={{
        ...TYPE.callout, color: MF.ink.secondary,
      }}>
        Native iOS stack — SF Pro Display for headlines, SF Pro Text for body,
        SF Mono for telemetry. Tabular numerals on every stat.
      </div>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {rows.map(([token, sample, style, meta], i) => (
          <div key={token} style={{
            display: 'grid', gridTemplateColumns: '180px 1fr 200px',
            alignItems: 'center', gap: 24,
            padding: '18px 0',
            borderTop: i === 0 ? `1px solid ${MF.line.hairline}` : 'none',
            borderBottom: `1px solid ${MF.line.hairline}`,
          }}>
            <Eyebrow>{token}</Eyebrow>
            <div style={{ ...style, color: '#fff', overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>{sample}</div>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, textAlign: 'right' }}>{meta}</div>
          </div>
        ))}
      </div>
      <div style={{ display: 'flex', gap: 24, alignItems: 'flex-start' }}>
        <div style={{ flex: 1 }}>
          <ColLabel>NUMERAL TREATMENT</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 16, padding: 24, display: 'flex', alignItems: 'baseline', gap: 14 }}>
            <span style={{ ...TYPE.num, fontSize: 64, color: '#fff' }}>09:34</span>
            <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>tabular-nums · -1 tracking</span>
          </div>
        </div>
        <div style={{ flex: 1 }}>
          <ColLabel>TELEMETRY LABEL</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 16, padding: 24 }}>
            <Eyebrow>BLOCK 03 · DAY 02 · STRIKER</Eyebrow>
            <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 12 }}>
              Always uppercase · mono · 1.2 tracking. Use over data, never over prose.
            </div>
          </div>
        </div>
      </div>
    </Board>
  );
}

// ── 3. SPACING + RADII + COMPONENTS ───────────────────────────
function BrdSystem() {
  return (
    <Board title="Spacing · Radii · Motion" eyebrow="03 · GEOMETRY & MOTION" width={780} height={760}>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 32 }}>
        {/* Spacing */}
        <div>
          <ColLabel>SPACING · 4PT BASELINE</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 16, padding: 20, display: 'flex', flexDirection: 'column', gap: 10 }}>
            {[['s1',4],['s2',8],['s3',12],['s4',16],['s5',20],['s6',24],['s7',32],['s8',40],['s10',64]].map(([n, v]) => (
              <div key={n} style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <span style={{ width: 40, ...TYPE.micro, color: MF.ink.tertiary }}>{n}</span>
                <div style={{ width: v, height: 8, background: '#fff' }}/>
                <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>{v}px</span>
              </div>
            ))}
          </div>
        </div>
        {/* Radii */}
        <div>
          <ColLabel>RADII</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 16, padding: 20, display: 'flex', flexWrap: 'wrap', gap: 14 }}>
            {[['xs',6],['sm',10],['md',14],['lg',20],['xl',28],['pill',999]].map(([n, v]) => (
              <div key={n} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <div style={{ width: 72, height: 72, background: '#fff', borderRadius: v === 999 ? 999 : v }}/>
                <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>r.{n} · {v === 999 ? 'pill' : v}</span>
              </div>
            ))}
          </div>
          <ColLabel style={{ marginTop: 22 }}>SAFE AREAS</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 16, padding: 20, ...TYPE.foot, color: MF.ink.secondary, display: 'flex', flexDirection: 'column', gap: 6 }}>
            <span>• Top content y: <b style={{ color: '#fff' }}>62 pt</b> (below status bar + island)</span>
            <span>• Bottom safe: <b style={{ color: '#fff' }}>34 pt</b> (home indicator)</span>
            <span>• Page gutter: <b style={{ color: '#fff' }}>20 pt</b> · cards: <b style={{ color: '#fff' }}>16 pt</b></span>
            <span>• Tab bar overlays: page bottom pad <b style={{ color: '#fff' }}>120 pt</b></span>
          </div>
        </div>
      </div>

      <div>
        <ColLabel>MOTION · SWIFTUI SPRINGS</ColLabel>
        <div style={{ background: MF.bg.card, borderRadius: 16, padding: 20, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18 }}>
          {[
            ['tap',      '.spring(response: 0.28, dampingFraction: 0.78)', 'Scale 0.97 + 12% subtle haptic'],
            ['present',  '.spring(response: 0.42, dampingFraction: 0.86)', 'Sheets · drill detail enter'],
            ['snap',     '.spring(response: 0.34, dampingFraction: 0.74)', 'Position dot · chip select'],
            ['hero',     '.matchedGeometryEffect()',                        'Card → full screen drill film'],
            ['scrub',    '.linear(duration: 0.18)',                         'Timer · progress ladder'],
            ['punch',    '.spring(response: 0.22, dampingFraction: 0.65)',  'Milestone unlock · ring fill'],
          ].map(([k, v, d]) => (
            <div key={k} style={{
              padding: 14, borderRadius: 12, background: MF.bg.raised,
              border: `1px solid ${MF.line.hairline}`,
            }}>
              <div style={{ ...TYPE.title3, color: '#fff' }}>{k}</div>
              <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 6 }}>{v}</div>
              <div style={{ ...TYPE.foot, color: MF.ink.secondary, marginTop: 8 }}>{d}</div>
            </div>
          ))}
        </div>
      </div>
    </Board>
  );
}

// ── 4. COMPONENTS BOARD ───────────────────────────────────────
function BrdComponents() {
  return (
    <Board title="Components" eyebrow="04 · UI KIT" width={780} height={820}>
      <SlashRule/>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 28 }}>
        {/* Buttons — elevation hierarchy */}
        <div>
          <ColLabel>BUTTONS · ELEVATION HIERARCHY</ColLabel>
          <div style={{ background: MF.bg.card, padding: 22, borderRadius: 16, display: 'flex', flexDirection: 'column', gap: 12 }}>
            <PrimaryButton>Start Training</PrimaryButton>
            <FloatingButton>Upgrade to Premium</FloatingButton>
            <SecondaryButton>Continue Session</SecondaryButton>
            <GhostButton>Skip for now</GhostButton>
            <PrimaryButton disabled>Disabled · Save Progress</PrimaryButton>
            <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 4 }}>
              <PrimaryButton size="md" style={{ width: 'auto', padding: '0 22px' }}>Compact</PrimaryButton>
              <SecondaryButton size="md" style={{ width: 'auto', padding: '0 22px' }}>Compact flat</SecondaryButton>
              <IconButton><svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 1v12M1 7h12" stroke="#fff" strokeWidth="1.8" strokeLinecap="round"/></svg></IconButton>
            </div>
          </div>
        </div>
        {/* Chips */}
        <div>
          <ColLabel>CHIPS · FILTER RAIL</ColLabel>
          <div style={{ background: MF.bg.card, padding: 22, borderRadius: 16, display: 'flex', flexWrap: 'wrap', gap: 8 }}>
            <Chip active>All</Chip>
            <Chip>Striker</Chip>
            <Chip>Cognition</Chip>
            <Chip>Power</Chip>
            <Chip>Recovery</Chip>
          </div>
          <ColLabel style={{ marginTop: 16 }}>TOGGLES</ColLabel>
          <div style={{ background: MF.bg.card, padding: 22, borderRadius: 16, display: 'flex', gap: 18, alignItems: 'center' }}>
            <Toggle on/>
            <Toggle/>
            <span style={{ ...TYPE.foot, color: MF.ink.tertiary }}>Stroke 1.5 · radius 13</span>
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 28 }}>
        <div>
          <ColLabel>STAT CARD</ColLabel>
          <Card padding={18}>
            <Eyebrow>STREAK</Eyebrow>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 8 }}>
              <span style={{ ...TYPE.num, fontSize: 36, color: '#fff' }}>27</span>
              <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>days</span>
            </div>
          </Card>
        </div>
        <div>
          <ColLabel>PITCH RING</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 16, padding: 18, display: 'flex', justifyContent: 'center' }}>
            <PitchRing size={120} progress={0.68} value="68" label="WEEK LOAD"/>
          </div>
        </div>
      </div>

      <div>
        <ColLabel>TAB BAR · LIQUID GLASS</ColLabel>
        <div style={{ background: MF.bg.card, borderRadius: 16, padding: 22, position: 'relative', height: 130, overflow: 'hidden' }}>
          <PhotoPlaceholder height={130} label="" style={{ borderRadius: 12, border: 'none' }}/>
          <div style={{ position: 'absolute', left: 30, right: 30, bottom: 22 }}>
            <div style={{
              height: 64, borderRadius: 28, overflow: 'hidden', position: 'relative',
              background: 'rgba(20,20,20,0.72)', backdropFilter: 'blur(28px) saturate(170%)',
              border: '1px solid rgba(255,255,255,0.08)',
            }}>
              <div style={{ height: '100%', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', alignItems: 'center' }}>
                {[['Today',true],['MF Hub',false],['Progress',false],['Profile',false]].map(([l, a]) => (
                  <div key={l} style={{ ...TYPE.micro, color: a ? '#fff' : MF.ink.tertiary, textAlign: 'center' }}>{l}</div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </Board>
  );
}

// ── 5. USER FLOW BOARD ────────────────────────────────────────
function BrdFlow() {
  const nodes = [
    { id:'splash',   x:50,  y:60,  label:'Splash',     kind:'system' },
    { id:'onb',      x:200, y:60,  label:'Onboarding (3)', kind:'flow' },
    { id:'paywall',  x:380, y:60,  label:'Paywall',    kind:'gate' },
    { id:'home',     x:560, y:60,  label:'Dashboard',  kind:'tab', primary: true },
    { id:'session',  x:50,  y:230, label:'Active drill', kind:'flow' },
    { id:'complete', x:230, y:230, label:'Session complete', kind:'flow' },
    { id:'hub',      x:420, y:230, label:'MF Hub',      kind:'tab' },
    { id:'drill',    x:580, y:230, label:'Drill detail', kind:'flow' },
    { id:'progress', x:50,  y:400, label:'Progress',    kind:'tab' },
    { id:'weekly',   x:215, y:400, label:'Weekly',      kind:'flow' },
    { id:'profile',  x:385, y:400, label:'Profile',     kind:'tab' },
    { id:'shop',     x:535, y:400, label:'Shop',        kind:'flow' },
    { id:'settings', x:50,  y:550, label:'Settings',    kind:'flow' },
    { id:'coach',    x:215, y:550, label:'Coach view',  kind:'admin' },
  ];

  // edges
  const edges = [
    ['splash','onb'],['onb','paywall'],['paywall','home'],
    ['home','session'],['session','complete'],['complete','home'],
    ['home','hub'],['hub','drill'],['drill','session'],
    ['home','progress'],['progress','weekly'],
    ['home','profile'],['profile','shop'],['profile','settings'],
    ['settings','coach'],
  ];
  const byId = Object.fromEntries(nodes.map(n => [n.id, n]));

  return (
    <Board title="User flow" eyebrow="05 · NAVIGATION" width={760} height={760}>
      <div style={{
        position: 'relative', height: 640, background: MF.bg.elevated,
        borderRadius: 18, border: `1px solid ${MF.line.hairline}`, overflow: 'hidden',
      }}>
        {/* faint grid */}
        <div style={{
          position: 'absolute', inset: 0, opacity: 0.5,
          backgroundImage:
            'linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px)',
          backgroundSize: '40px 40px',
        }}/>

        {/* edges */}
        <svg width="100%" height="100%" style={{ position: 'absolute', inset: 0 }}>
          {edges.map(([a, b], i) => {
            const A = byId[a], B = byId[b];
            const x1 = A.x + 80, y1 = A.y + 28, x2 = B.x + 80, y2 = B.y + 28;
            return (
              <line key={i} x1={x1} y1={y1} x2={x2} y2={y2}
                stroke="rgba(255,255,255,0.18)" strokeWidth="1" strokeDasharray="3 4"/>
            );
          })}
        </svg>

        {/* nodes */}
        {nodes.map(n => {
          const isPrimary = n.primary;
          const isTab = n.kind === 'tab';
          const isAdmin = n.kind === 'admin';
          const isGate = n.kind === 'gate';
          return (
            <div key={n.id} style={{
              position: 'absolute', left: n.x, top: n.y, width: 160, height: 56,
              borderRadius: 14,
              background: isPrimary ? '#fff' : isTab ? MF.bg.raised : MF.bg.card,
              color: isPrimary ? '#000' : '#fff',
              border: `1px solid ${isPrimary ? '#fff' : isAdmin ? '#fff' : MF.line.subtle}`,
              padding: '10px 14px',
              display: 'flex', flexDirection: 'column', justifyContent: 'center',
              boxShadow: isPrimary ? '0 10px 24px rgba(255,255,255,0.15)' : 'none',
            }}>
              <span style={{ ...TYPE.micro, color: isPrimary ? 'rgba(0,0,0,0.55)' : MF.ink.tertiary }}>
                {isTab ? 'TAB' : isGate ? 'GATE' : isAdmin ? 'ADMIN' : n.kind.toUpperCase()}
              </span>
              <span style={{ ...TYPE.callout, fontWeight: 700, marginTop: 2 }}>{n.label}</span>
            </div>
          );
        })}
      </div>

      <div style={{ display: 'flex', gap: 14, ...TYPE.micro, color: MF.ink.tertiary }}>
        <LegendDot color="#fff" label="HOME"/>
        <LegendDot ring label="TAB"/>
        <LegendDot dashed label="MODAL · DRILL"/>
        <LegendDot color="rgba(255,255,255,0.7)" label="ADMIN · COACH ROLE"/>
      </div>
    </Board>
  );
}

function LegendDot({ color, ring, dashed, label }) {
  return (
    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 8 }}>
      <span style={{
        width: 18, height: 12, borderRadius: 4,
        background: color || 'transparent',
        border: ring ? '1px solid rgba(255,255,255,0.6)' : dashed ? '1px dashed rgba(255,255,255,0.4)' : 'none',
      }}/>
      {label}
    </span>
  );
}

// ── 6. DEVELOPER HANDOFF BOARD ────────────────────────────────
function BrdHandoff() {
  return (
    <Board title="Developer handoff" eyebrow="06 · BUILD NOTES" width={820} height={920}>
      <SlashRule/>
      <div style={{ ...TYPE.callout, color: MF.ink.secondary }}>
        SwiftUI · iOS 17+ · dark-mode-first. Supabase for data, RevenueCat for billing,
        StoreKit 2 under the hood. No Superwall. No AI surfaces.
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 28 }}>
        {/* File tree */}
        <div>
          <ColLabel>FILE TREE</ColLabel>
          <pre style={{
            ...TYPE.foot, fontFamily: MF.font.mono, color: MF.ink.secondary,
            background: MF.bg.card, padding: 18, borderRadius: 14, margin: 0,
            lineHeight: '20px', whiteSpace: 'pre-wrap',
          }}>{`MFElite/
├─ App/
│  └─ MFEliteApp.swift
├─ Core/
│  ├─ DesignSystem/      ← MFColor, MFType, MFSpace
│  ├─ Components/        ← PrimaryButton, Card, Chip, PitchRing
│  └─ Navigation/        ← AppTabView, Router
├─ Features/
│  ├─ Onboarding/
│  ├─ Dashboard/
│  ├─ Hub/              (MF Hub)
│  ├─ Drill/            (Detail + Player)
│  ├─ Progress/
│  ├─ Profile/
│  ├─ Shop/
│  ├─ Paywall/
│  ├─ Settings/
│  └─ Coach/            (gated by role)
├─ Models/              ← Athlete, Program, Drill, Session
├─ Services/
│  ├─ Auth/             (Supabase Auth + Sign in w/ Apple)
│  ├─ Subscriptions/    (RevenueCat)
│  ├─ Analytics/
│  ├─ Notifications/
│  ├─ Health/           (HealthKit · workouts)
│  └─ Supabase/         (typed client + RLS)
├─ Storage/             (SwiftData local cache)
├─ Widgets/
├─ WatchApp/
└─ Resources/`}</pre>
        </div>

        {/* Integrations */}
        <div>
          <ColLabel>APPLE INTEGRATIONS · MARKED YES</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 14, padding: 18 }}>
            {[
              ['HealthKit · read workouts', true],
              ['Apple Watch · session timer', true],
              ['WidgetKit · Today / Streak', true],
              ['Live Activity · active drill', true],
              ['Sign in with Apple', true],
              ['Push notifications', true],
              ['App Intents / Shortcuts', true],
              ['CoreML / on-device AI', false],
              ['CoreLocation', false],
              ['Camera', false],
            ].map(([n, on], i) => (
              <div key={n} style={{
                display: 'flex', alignItems: 'center', gap: 10,
                padding: '10px 0',
                borderBottom: i < 9 ? `1px solid ${MF.line.hairline}` : 'none',
              }}>
                <span style={{
                  width: 16, height: 16, borderRadius: 4,
                  background: on ? '#fff' : 'transparent',
                  border: `1px solid ${on ? '#fff' : MF.line.subtle}`,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  {on && <svg width="10" height="10" viewBox="0 0 10 10"><path d="M2 5l2 2 4-4" stroke="#000" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
                </span>
                <span style={{ ...TYPE.foot, color: on ? '#fff' : MF.ink.tertiary, fontWeight: on ? 600 : 500 }}>{n}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 28 }}>
        <div>
          <ColLabel>SUPABASE · SCHEMA SKETCH</ColLabel>
          <pre style={{
            ...TYPE.foot, fontFamily: MF.font.mono, color: MF.ink.secondary,
            background: MF.bg.card, padding: 18, borderRadius: 14, margin: 0,
            lineHeight: '20px', whiteSpace: 'pre-wrap',
          }}>{`profiles
  id (uuid · auth.users.id)
  display_name · position · foot · kit
  intensity · coach_id · created_at

programs (public · read)
  id · title · subtitle · cover_url
  coach_id · sessions[] · is_elite_only

drills (public · read)
  id · program_id · order · title
  duration · reps · load · video_url

sessions (RLS user_id = auth.uid())
  id · user_id · scheduled_at
  drills[] · status · load · elapsed

milestones (RLS user_id)
  id · user_id · kind · payload · earned_at

entitlements (mirror · server-write only)
  user_id · tier · expires_at`}</pre>
        </div>
        <div>
          <ColLabel>ANALYTICS EVENTS</ColLabel>
          <pre style={{
            ...TYPE.foot, fontFamily: MF.font.mono, color: MF.ink.secondary,
            background: MF.bg.card, padding: 18, borderRadius: 14, margin: 0,
            lineHeight: '20px', whiteSpace: 'pre-wrap',
          }}>{`app_open
onboarding_started
onboarding_step  { step }
onboarding_completed
paywall_shown
paywall_dismissed
paywall_converted   { plan }
restore_tapped
redeem_tapped
session_started     { program_id, drill_id }
session_completed   { duration, load }
drill_completed     { drill_id, reps, load }
milestone_unlocked  { kind }
shop_view           { product_id }
share_card_generated
subscription_started
subscription_renewed
subscription_cancelled
crash · error`}</pre>
          <ColLabel style={{ marginTop: 18 }}>REVENUECAT</ColLabel>
          <div style={{ background: MF.bg.card, borderRadius: 14, padding: 16, ...TYPE.foot, color: MF.ink.secondary, lineHeight: '20px' }}>
            <div><b style={{ color: '#fff' }}>Entitlement</b>  · <code style={{ fontFamily: MF.font.mono, color: '#fff' }}>elite</code></div>
            <div><b style={{ color: '#fff' }}>Products</b>  · <code style={{ fontFamily: MF.font.mono, color: '#fff' }}>mf.elite.annual</code>, <code style={{ fontFamily: MF.font.mono, color: '#fff' }}>mf.elite.monthly</code></div>
            <div><b style={{ color: '#fff' }}>Trial</b>  · 7 days, annual only</div>
            <div style={{ marginTop: 8 }}>Truth = RevenueCat. Mirror status to Supabase via Edge Function on RC webhook. Never trust client-written <code style={{ fontFamily: MF.font.mono, color: '#fff' }}>is_premium</code>.</div>
          </div>
        </div>
      </div>

      <div>
        <ColLabel>INFO.PLIST USAGE STRINGS</ColLabel>
        <pre style={{
          ...TYPE.foot, fontFamily: MF.font.mono, color: MF.ink.secondary,
          background: MF.bg.card, padding: 18, borderRadius: 14, margin: 0,
          lineHeight: '20px', whiteSpace: 'pre-wrap',
        }}>{`NSHealthShareUsageDescription
  "Read your workouts to log MF Elite sessions to Apple Health."
NSHealthUpdateUsageDescription
  "Write completed sessions and intensity to Apple Health."
NSUserNotificationUsageDescription
  "Daily session reminders and streak alerts."
NSCameraUsageDescription — N/A (camera disabled v1)
NSLocationWhenInUseUsageDescription — N/A (no CoreLocation v1)`}</pre>
      </div>

      <div>
        <ColLabel>SHIP CHECKLIST · APP STORE</ColLabel>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {[
            'PrivacyInfo.xcprivacy filed',
            'Restore Purchases visible on paywall',
            'Redeem Code visible on paywall',
            'Auto-renew terms visible above fold',
            'Account deletion path in Settings',
            'Sign in with Apple alongside email',
            'No external payment links for digital goods',
            'RLS enabled on every Supabase table',
            'Dynamic Type tested at AX5',
            'VoiceOver labels on all icon buttons',
          ].map((s) => (
            <div key={s} style={{
              ...TYPE.foot, color: '#fff', display: 'flex', gap: 10, alignItems: 'flex-start',
              padding: 12, background: MF.bg.card, borderRadius: 10,
              border: `1px solid ${MF.line.hairline}`,
            }}>
              <span style={{
                width: 16, height: 16, borderRadius: 4, background: '#fff', flexShrink: 0, marginTop: 2,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="10" height="10" viewBox="0 0 10 10"><path d="M2 5l2 2 4-4" stroke="#000" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </span>
              <span>{s}</span>
            </div>
          ))}
        </div>
      </div>
    </Board>
  );
}

Object.assign(window, {
  Board, BrdPalette, BrdType, BrdSystem, BrdComponents, BrdFlow, BrdHandoff,
});
