// MF Elite — Settings + Coach/Admin

// ─── SETTINGS ───
function ScrSettings() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: '#000', paddingBottom: 120 }}>
      <div style={{ padding: '64px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: MF.ink.tertiary }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ ...TYPE.foot, fontWeight: 600 }}>Profile</span>
        </div>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 14, lineHeight: '46px' }}>Settings</div>
      </div>

      {/* Account summary */}
      <div style={{ padding: '20px 20px 0' }}>
        <Card padding={18} style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <Avatar size={52} initials="P1"/>
          <div style={{ flex: 1 }}>
            <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700 }}>Player One</div>
            <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 2 }}>player.one@mf.elite · Elite · Annual</div>
          </div>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M5 2l5 5-5 5" stroke="rgba(255,255,255,0.68)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </Card>
      </div>

      {/* Settings groups */}
      <SettingsGroup eyebrow="TRAINING" rows={[
        ['Position', 'Striker · ST'],
        ['Intensity', 'Standard · 4/wk'],
        ['Preferred foot', 'Right'],
        ['Coach', 'Coach Matteo Finazzi'],
      ]}/>
      <SettingsGroup eyebrow="DEVICE & DATA" rows={[
        ['Apple Health', 'Connected', { detailIsToggle: true, on: true }],
        ['Apple Watch', '2 pairs · Latest'],
        ['Live Activity', null, { detailIsToggle: true, on: true }],
        ['Widgets', '3 installed'],
        ['Offline drills', '2.4 GB · Manage'],
      ]}/>
      <SettingsGroup eyebrow="MEMBERSHIP" rows={[
        ['Manage subscription', 'Elite Annual'],
        ['Restore purchases', null],
        ['Redeem code', null],
      ]}/>
      <SettingsGroup eyebrow="NOTIFICATIONS" rows={[
        ['Daily session reminder', '06:15 – Mon–Fri'],
        ['Streak alert', null, { detailIsToggle: true, on: true }],
        ['Match-day prep', null, { detailIsToggle: true, on: true }],
        ['Marketing', null, { detailIsToggle: true, on: false }],
      ]}/>
      <SettingsGroup eyebrow="PRIVACY & LEGAL" rows={[
        ['Privacy Policy', null],
        ['Terms of Service', null],
        ['Subscription Terms', null],
        ['Export my data', null],
        ['Delete account', null, { destructive: true }],
      ]}/>

      <div style={{ padding: '24px 20px 0', textAlign: 'center' }}>
        <Eyebrow style={{ color: MF.ink.quaternary }}>MF ELITE · v1.0 (build 1142)</Eyebrow>
      </div>
    </div>
  );
}

function SettingsGroup({ eyebrow, rows }) {
  return (
    <div style={{ padding: '24px 20px 0' }}>
      <Eyebrow style={{ marginBottom: 10 }}>{eyebrow}</Eyebrow>
      <div style={{
        background: MF.bg.card, borderRadius: 18, overflow: 'hidden',
        border: `1px solid ${MF.line.hairline}`,
      }}>
        {rows.map(([k, v, opts = {}], i) => {
          const last = i === rows.length - 1;
          return (
            <div key={i} style={{
              padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 10,
              borderBottom: last ? 'none' : `1px solid ${MF.line.hairline}`,
            }}>
              <span style={{
                ...TYPE.callout, color: opts.destructive ? '#fff' : MF.ink.primary,
                flex: 1, fontWeight: 500,
              }}>{k}</span>
              {opts.detailIsToggle ? (
                <Toggle on={opts.on}/>
              ) : (
                <>
                  {v && <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 500 }}>{v}</span>}
                  <svg width="8" height="14" viewBox="0 0 8 14"><path d="M1 1l6 6-6 6" stroke="rgba(255,255,255,0.55)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
                </>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function Toggle({ on }) {
  return (
    <div style={{
      width: 44, height: 26, borderRadius: 13, padding: 2,
      background: on ? '#fff' : MF.bg.tint,
      display: 'flex', alignItems: 'center',
      justifyContent: on ? 'flex-end' : 'flex-start',
      border: `1px solid ${on ? '#fff' : MF.line.subtle}`,
    }}>
      <div style={{
        width: 22, height: 22, borderRadius: 11,
        background: on ? '#000' : '#fff',
      }}/>
    </div>
  );
}

// ─── COACH / ADMIN ROSTER ───
function ScrCoach() {
  const roster = [
    { name: 'Player One',   pos: 'ST', drills: 44, mins: 184, xp: 3620, rank: 'II',  status: 'on-track',  initials: 'P1' },
    { name: 'Player Two',   pos: 'CM', drills: 31, mins: 248, xp: 1240, rank: 'II',  status: 'on-track',  initials: 'P2' },
    { name: 'Player Three', pos: 'CB', drills:  7, mins:  52, xp: 180,  rank: 'I',   status: 'lagging',   initials: 'P3' },
    { name: 'Player Four',  pos: 'RW', drills: 38, mins: 308, xp: 1820, rank: 'III', status: 'peaking',   initials: 'P4' },
    { name: 'Player Five',  pos: 'GK', drills: 10, mins:  78, xp: 240,  rank: 'I',   status: 'lagging',   initials: 'P5' },
    { name: 'Player Six',   pos: 'ST', drills: 19, mins: 156, xp: 580,  rank: 'II',  status: 'on-track',  initials: 'P6' },
  ];

  const statusDot = (s) => s === 'peaking' ? '#fff'
    : s === 'on-track' ? 'rgba(255,255,255,0.78)' : MF.ink.disabled;

  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      {/* Admin badge bar */}
      <div style={{
        margin: '54px 14px 0',
        padding: '8px 14px', borderRadius: 999,
        background: '#fff', color: '#000',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="11" height="13" viewBox="0 0 11 13"><path d="M2.5 6V4a3 3 0 016 0v2" stroke="#000" strokeWidth="1.3" fill="none"/><rect x="1.5" y="6" width="8" height="6" rx="1.2" fill="#000"/></svg>
          <span style={{ ...TYPE.micro, color: '#000', letterSpacing: 1.8, fontWeight: 800 }}>
            ADMIN · COACH ACCESS
          </span>
        </div>
        <span style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.55)' }}>Sign out</span>
      </div>

      {/* Header */}
      <div style={{ padding: '20px 20px 0', display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
        <div>
          <Eyebrow>COACH · MATTEO FINAZZI</Eyebrow>
          <div style={{ ...TYPE.hero, color: '#fff', marginTop: 6, lineHeight: '46px' }}>
            The squad
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <IconButton style={{ width: 38, height: 38, borderRadius: 12 }}>
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M12 11.5l-2.5-2.5M10.5 6.5a4 4 0 11-8 0 4 4 0 018 0z" stroke="#fff" strokeWidth="1.4" fill="none"/></svg>
          </IconButton>
          <IconButton style={{ width: 38, height: 38, borderRadius: 12, background: '#fff' }}>
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 1v12M1 7h12" stroke="#000" strokeWidth="1.8" strokeLinecap="round"/></svg>
          </IconButton>
        </div>
      </div>

      {/* Squad telemetry */}
      <div style={{ padding: '20px 20px 0' }}>
        <Card padding={18}>
          <Eyebrow>SQUAD · WEEK 14</Eyebrow>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 0, marginTop: 14 }}>
            {[['ATHLETES','12'],['ACTIVE','9'],['XP AVG','1,180'],['FLAGS','2']].map(([l, v], i) => (
              <div key={i} style={{
                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
                borderRight: i < 3 ? `1px solid ${MF.line.hairline}` : 'none',
              }}>
                <span style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>{v}</span>
                <Eyebrow>{l}</Eyebrow>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* CAPABILITIES — what the coach can do */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Eyebrow>TOOLBOX · COACH WORKSPACE</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>06 TOOLS</span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <ToolTile icon={
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><rect x="2.5" y="3.5" width="15" height="13" rx="2" stroke="#fff" strokeWidth="1.4"/><path d="M2.5 7.5h15M6 1.5v3M14 1.5v3" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/></svg>
          } title="Sessions" sub="Build & schedule" count="14 drafted"/>
          <ToolTile primary icon={
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><circle cx="10" cy="10" r="7" stroke="#000" strokeWidth="1.4"/><path d="M10 5v5l3 2" stroke="#000" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
          } title="Drills" sub="Upload & edit" count="187 in library"/>
          <ToolTile icon={
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><rect x="2.5" y="4.5" width="15" height="11" rx="1.5" stroke="#fff" strokeWidth="1.4"/><path d="M8 8.5l4 2-4 2v-4z" fill="#fff"/></svg>
          } title="Drill film" sub="Coach uploads" count="187 in library"/>
          <ToolTile icon={
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M3 15.5l4-5 3 2 7-8" stroke="#fff" strokeWidth="1.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/><circle cx="17" cy="4.5" r="1.4" fill="#fff"/></svg>
          } title="Reports" sub="Parent recap" count="sent Sunday"/>
          <ToolTile icon={
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><circle cx="10" cy="7" r="3" stroke="#fff" strokeWidth="1.4"/><path d="M3.5 17c1.5-3 3.5-4.5 6.5-4.5s5 1.5 6.5 4.5" stroke="#fff" strokeWidth="1.4" strokeLinecap="round" fill="none"/></svg>
          } title="Roster" sub="12 athletes" count="2 flagged"/>
          <ToolTile icon={
            <svg width="20" height="20" viewBox="0 0 20 20" fill="none"><path d="M10 2v6M10 12v6M2 10h6M12 10h6" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/><circle cx="10" cy="10" r="1.8" fill="#fff"/></svg>
          } title="Routines" sub="Curated sessions" count="12 published"/>
        </div>
      </div>

      {/* Filter */}
      <div style={{ display: 'flex', gap: 8, padding: '24px 20px 0', overflowX: 'auto' }}>
        <Chip active>All · 12</Chip>
        <Chip>Lagging · 2</Chip>
        <Chip>Peaking · 1</Chip>
        <Chip>U-17</Chip>
        <Chip>U-19</Chip>
      </div>

      {/* Roster list */}
      <div style={{ padding: '20px 0 0' }}>
        <div style={{
          display: 'grid', gridTemplateColumns: '10px 1fr 44px 44px 56px 10px',
          padding: '0 20px 8px', alignItems: 'center', gap: 8,
        }}>
          <span></span>
          <Eyebrow>ATHLETE</Eyebrow>
          <Eyebrow style={{ textAlign: 'right' }}>DRILLS</Eyebrow>
          <Eyebrow style={{ textAlign: 'right' }}>MINS</Eyebrow>
          <Eyebrow style={{ textAlign: 'right' }}>XP</Eyebrow>
          <span></span>
        </div>
        {roster.map((p, i) => (
          <div key={i} style={{
            display: 'grid', gridTemplateColumns: '10px 1fr 44px 44px 56px 10px',
            alignItems: 'center', gap: 8,
            padding: '14px 20px',
            borderTop: `1px solid ${MF.line.hairline}`,
            borderBottom: i === roster.length-1 ? `1px solid ${MF.line.hairline}` : 'none',
          }}>
            <span style={{
              width: 8, height: 8, borderRadius: 4, background: statusDot(p.status),
              boxShadow: p.status === 'peaking' ? '0 0 0 3px rgba(255,255,255,0.15)' : 'none',
            }}/>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
              <Avatar size={32} initials={p.initials}/>
              <div style={{ minWidth: 0 }}>
                <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{p.name}</div>
                <Eyebrow>{p.pos} · RANK {p.rank}</Eyebrow>
              </div>
            </div>
            <span style={{ ...TYPE.num, fontSize: 15, color: '#fff', textAlign: 'right', fontWeight: 600 }}>{p.drills}</span>
            <span style={{ ...TYPE.num, fontSize: 15, color: '#fff', textAlign: 'right', fontWeight: 600 }}>{p.mins}</span>
            <span style={{ ...TYPE.num, fontSize: 15, color: '#fff', textAlign: 'right', fontWeight: 600 }}>{p.xp.toLocaleString('en-US')}</span>
            <svg width="8" height="14" viewBox="0 0 8 14"><path d="M1 1l6 6-6 6" stroke="rgba(255,255,255,0.55)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
        ))}
      </div>
    </div>
  );
}

// Toolbox tile — used in the expanded coach view
function ToolTile({ icon, title, sub, count, primary }) {
  return (
    <div style={{
      padding: 14, borderRadius: 16,
      background: primary ? '#fff' : MF.bg.card,
      color: primary ? '#000' : '#fff',
      border: primary ? 'none' : `1px solid ${MF.line.hairline}`,
      minHeight: 110,
      display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
    }}>
      <div style={{
        width: 36, height: 36, borderRadius: 10,
        background: primary ? '#000' : MF.bg.raised,
        border: primary ? 'none' : `1px solid ${MF.line.subtle}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>{icon}</div>
      <div>
        <div style={{ ...TYPE.callout, fontWeight: 700 }}>{title}</div>
        <div style={{ ...TYPE.foot, color: primary ? 'rgba(0,0,0,0.55)' : MF.ink.tertiary, marginTop: 2 }}>{sub}</div>
        <div style={{ ...TYPE.micro, color: primary ? 'rgba(0,0,0,0.45)' : MF.ink.tertiary, marginTop: 8, letterSpacing: 1.4 }}>
          {count}
        </div>
      </div>
    </div>
  );
}

// ─── COACH LOGIN · separate admin entry ───
function ScrCoachLogin() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden' }}>
      {/* faint stripes */}
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.35,
        backgroundImage:
          'repeating-linear-gradient(115deg, transparent 0px, transparent 60px, rgba(255,255,255,0.022) 60px, rgba(255,255,255,0.022) 61px)',
      }}/>
      {/* Restricted bar */}
      <div style={{
        position: 'absolute', top: 56, left: 14, right: 14, zIndex: 2,
        padding: '8px 14px', borderRadius: 999,
        border: `1px solid ${MF.line.strong}`,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="11" height="13" viewBox="0 0 11 13"><path d="M2.5 6V4a3 3 0 016 0v2" stroke="#fff" strokeWidth="1.4" fill="none"/><rect x="1.5" y="6" width="8" height="6" rx="1.2" fill="#fff"/></svg>
          <span style={{ ...TYPE.micro, color: '#fff', letterSpacing: 1.8, fontWeight: 700 }}>RESTRICTED · ADMIN</span>
        </div>
        <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>v1.0</span>
      </div>

      {/* Logo + masthead */}
      <div style={{ position: 'absolute', top: 130, left: 0, right: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
        <MFMark size={84}/>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 3 }}>COACH ACCESS</div>
      </div>

      {/* Form */}
      <div style={{ position: 'absolute', top: 360, left: 24, right: 24, display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ ...TYPE.title1, color: '#fff', textWrap: 'balance' }}>Sign in to the workspace</div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginBottom: 4 }}>
          Coach-only access. Workout & athlete data live in Supabase.
        </div>
        <InputField label="EMAIL" value="matteo@mf.elite"/>
        <InputField label="PASSWORD" value="••••••••••••"/>
        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
          <span style={{ ...TYPE.foot, color: MF.ink.secondary, fontWeight: 600 }}>Reset password</span>
          <span style={{ ...TYPE.foot, color: MF.ink.secondary, fontWeight: 600 }}>2FA</span>
        </div>
      </div>

      {/* Bottom CTAs */}
      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 56, display: 'flex', flexDirection: 'column', gap: 10 }}>
        <PrimaryButton>Sign in</PrimaryButton>
        <SecondaryButton>
          <svg width="16" height="20" viewBox="0 0 16 20" fill="#fff">
            <path d="M11.5 0c.1 1.5-.5 3-1.5 4-1 1-2.5 1.5-3.8 1.4-.1-1.5.5-3 1.5-4C8.7.4 10.2-.1 11.5 0zM14 14.4c-.7 1.5-1 2.2-1.9 3.5-1.2 1.9-3 4.1-5.2 4.1-2 0-2.5-1.3-5.2-1.3-2.7 0-3.3 1.3-5.3 1.3-2.2 0-3.8-2.1-5-3.9C-12 14.7-13 7.6-9 4c2.2-2 5.5-2.4 7.6-1.2 1.8 1 3.4 1 5.4 0 1.4-.7 3.9-1.6 6.3.1-5.6 3.1-4.7 11.2 3.7 11.5z" transform="translate(2 0) scale(0.5)"/>
          </svg>
          <span>Sign in with Apple</span>
        </SecondaryButton>
        <div style={{ textAlign: 'center', marginTop: 6, ...TYPE.foot, color: MF.ink.tertiary }}>
          Not a coach? <span style={{ color: '#fff', fontWeight: 600, textDecoration: 'underline' }}>Player sign-in →</span>
        </div>
      </div>
    </div>
  );
}

function InputField({ label, value }) {
  return (
    <div style={{
      padding: '12px 14px', borderRadius: 14,
      background: '#0a0a0a', border: `1px solid ${MF.line.subtle}`,
    }}>
      <div style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 1.4 }}>{label}</div>
      <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}

// ─── COACH BUILD SESSION · admin workout authoring ───
function ScrCoachBuild() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      {/* Admin badge bar */}
      <div style={{
        margin: '54px 14px 0',
        padding: '8px 14px', borderRadius: 999,
        background: '#fff', color: '#000',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="11" height="13" viewBox="0 0 11 13"><path d="M2.5 6V4a3 3 0 016 0v2" stroke="#000" strokeWidth="1.3" fill="none"/><rect x="1.5" y="6" width="8" height="6" rx="1.2" fill="#000"/></svg>
          <span style={{ ...TYPE.micro, color: '#000', letterSpacing: 1.8, fontWeight: 800 }}>
            ADMIN · COACH ACCESS
          </span>
        </div>
        <span style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.55)' }}>Draft · auto-save</span>
      </div>

      {/* Header */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: MF.ink.tertiary }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ ...TYPE.foot, fontWeight: 600 }}>Workspace</span>
        </div>
        <Eyebrow style={{ marginTop: 14 }}>COACH · WORKSPACE</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 6, lineHeight: '46px' }}>
          Build session
        </div>
      </div>

      {/* SESSION DETAILS */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>SESSION DETAILS</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <InputField label="NAME"     value="Tight Spaces · Wk 14"/>
          <InputField label="SCHEDULE" value="Tue · Mar 18 · 06:30"/>
          <div style={{
            padding: '12px 14px', borderRadius: 14,
            background: '#0a0a0a', border: `1px solid ${MF.line.subtle}`,
          }}>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 1.4 }}>TARGET POSITION</div>
            <div style={{ display: 'flex', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
              <Chip active>ST</Chip>
              <Chip>LW</Chip>
              <Chip active>CAM</Chip>
              <Chip>CM</Chip>
              <Chip>+ more</Chip>
            </div>
          </div>
          <div style={{
            padding: '12px 14px', borderRadius: 14,
            background: '#0a0a0a', border: `1px solid ${MF.line.subtle}`,
          }}>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 1.4 }}>INTENSITY</div>
            <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
              <Chip>Recovery</Chip>
              <Chip active>Standard</Chip>
              <Chip>Elite</Chip>
            </div>
          </div>
        </div>
      </div>

      {/* DRILLS */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Eyebrow>DRILLS · 03</Eyebrow>
          <span style={{ ...TYPE.foot, color: MF.ink.secondary, fontWeight: 600 }}>Reorder</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {[
            ['D003', 'First touch under pressure', '6 min'],
            ['D012', 'Half-turn finishing',        '8 min'],
            ['D018', 'Rondo decisioning',          '6 min'],
          ].map(([code, title, mins], i) => (
            <div key={code} style={{
              display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px',
              borderTop: i === 0 ? `1px solid ${MF.line.hairline}` : 'none',
              borderBottom: `1px solid ${MF.line.hairline}`,
              background: '#0a0a0a',
            }}>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 4h8M3 7h8M3 10h8" stroke="rgba(255,255,255,0.68)" strokeWidth="1.4" strokeLinecap="round"/></svg>
              <span style={{ ...TYPE.micro, color: MF.ink.tertiary, fontFamily: MF.font.mono }}>{code}</span>
              <span style={{ flex: 1, ...TYPE.foot, color: '#fff', fontWeight: 600 }}>{title}</span>
              <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{mins}</span>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 3l8 8M11 3l-8 8" stroke="rgba(255,255,255,0.68)" strokeWidth="1.4" strokeLinecap="round"/></svg>
            </div>
          ))}
        </div>
        <button style={{
          width: '100%', height: 46, marginTop: 10,
          appearance: 'none', cursor: 'pointer',
          border: `1px dashed ${MF.line.strong}`, borderRadius: 12,
          background: 'transparent', color: '#fff',
          ...TYPE.foot, fontWeight: 700, letterSpacing: 1.4,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 2v10M2 7h10" stroke="#fff" strokeWidth="1.6" strokeLinecap="round"/></svg>
          ADD DRILL FROM LIBRARY
        </button>
      </div>

      {/* DRILL FILM UPLOAD — coach adds their demo film to the library */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>DRILL FILM · COACH UPLOAD</Eyebrow>
        <div style={{
          padding: '28px 20px', borderRadius: 16,
          border: `1.5px dashed ${MF.line.strong}`,
          background: 'rgba(255,255,255,0.02)',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, textAlign: 'center',
        }}>
          <div style={{
            width: 44, height: 44, borderRadius: 12,
            background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <svg width="20" height="20" viewBox="0 0 20 20"><path d="M10 3v10m0-10L6 7m4-4l4 4M3 17h14" stroke="#000" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700, marginTop: 4 }}>Drop demo film here or tap to upload</div>
          <div style={{ ...TYPE.foot, color: MF.ink.tertiary, maxWidth: 280 }}>
            Coach-only. Demo film for the drill library. MP4 / MOV up to 500 MB,
            auto-transcoded to Supabase Storage with RLS.
          </div>
        </div>
      </div>

      {/* ASSIGN */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>ASSIGN TO</Eyebrow>
        <div style={{
          padding: '14px 16px', borderRadius: 14,
          background: MF.bg.card, border: `1px solid ${MF.line.hairline}`,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12,
        }}>
          <div>
            <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700 }}>All squad · 12 athletes</div>
            <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 2 }}>Tap to assign to a subset.</div>
          </div>
          <Toggle on={true}/>
        </div>
      </div>

      {/* CTAs */}
      <div style={{ padding: '28px 20px 0', display: 'flex', gap: 10 }}>
        <SecondaryButton>Save draft</SecondaryButton>
        <PrimaryButton>Publish</PrimaryButton>
      </div>

      {/* Backend caption */}
      <div style={{ padding: '14px 20px 0', textAlign: 'center' }}>
        <Eyebrow style={{ color: MF.ink.quaternary }}>
          PUBLISHED VIA SUPABASE · APPEARS IN ATHLETES' DASHBOARDS WITHIN 30 S
        </Eyebrow>
      </div>
    </div>
  );
}

Object.assign(window, { ScrSettings, ScrCoach, ScrCoachLogin, ScrCoachBuild, Toggle, ToolTile, InputField });
