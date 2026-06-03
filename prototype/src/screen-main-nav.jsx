// MF Elite — main navigation screens
// Dashboard / MF Hub / Progress / Profile

// ─── Custom screen header (avatar + MF mark + action) ───
function ScreenHeader({ leading, title, sub, trailing }) {
  return (
    <div style={{
      padding: '64px 20px 16px',
      display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        {leading}
        <div>
          {sub && <div style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{sub}</div>}
          <div style={{ ...TYPE.title3, color: MF.ink.primary, marginTop: sub ? 2 : 0 }}>{title}</div>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>{trailing}</div>
    </div>
  );
}

// ─── DASHBOARD ───
// Editorial · one screen, one action. No metric grid.
function ScrDashboard() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 140 }}>
      {/* Quiet top bar */}
      <div style={{
        padding: '62px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <Avatar size={36} initials="P1"/>
        <MFMark size={20}/>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 1.5a5.5 5.5 0 015.5 5.5v3l1 2.5h-13l1-2.5V7A5.5 5.5 0 018 1.5zM6.5 13a1.5 1.5 0 003 0" stroke="#fff" strokeWidth="1.3" strokeLinecap="round"/></svg>
        </IconButton>
      </div>

      {/* Editorial salutation */}
      <div style={{ padding: '28px 20px 0' }}>
        <Eyebrow>TUE 12 MAR · WEEK 14</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 8, lineHeight: '48px', fontSize: 42, letterSpacing: -1.4 }}>
          Welcome back,<br/>Player One
        </div>
      </div>

      {/* Hero session — full-bleed, owns the screen */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          borderRadius: 26, overflow: 'hidden',
          background: '#0a0a0a', border: `1px solid ${MF.line.hairline}`,
        }}>
          <div style={{ position: 'relative' }}>
            <PhotoPlaceholder height={340} label="TODAY · COACH FILM" style={{ borderRadius: 0, border: 'none' }}>
              <div style={{
                position: 'absolute', inset: 0,
                background: 'linear-gradient(to bottom, rgba(0,0,0,0.35) 0%, rgba(0,0,0,0) 30%, rgba(0,0,0,0) 55%, rgba(0,0,0,0.92) 100%)',
              }}/>
              <div style={{ position: 'absolute', top: 16, left: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ width: 6, height: 6, borderRadius: 3, background: '#fff' }}/>
                <span style={{ ...TYPE.micro, color: '#fff' }}>TODAY · 06:30</span>
              </div>
              <div style={{
                position: 'absolute', top: 16, right: 16,
                padding: '4px 10px', borderRadius: 999,
                background: 'rgba(255,255,255,0.06)', border: '1px solid rgba(255,255,255,0.18)',
                backdropFilter: 'blur(10px)',
                ...TYPE.micro, color: '#fff',
              }}>BLOCK 03 · DAY 02</div>
              <div style={{
                position: 'absolute', left: 22, right: 22, bottom: 22,
              }}>
                <Eyebrow style={{ color: 'rgba(255,255,255,0.65)' }}>SESSION · STRIKER</Eyebrow>
                <div style={{ ...TYPE.display, color: '#fff', marginTop: 8, textWrap: 'balance', lineHeight: '38px' }}>
                  First touch<br/>under pressure
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginTop: 14 }}>
                  <DotMeta label="42 MIN"/>
                  <Sep/>
                  <DotMeta label="7 DRILLS"/>
                  <Sep/>
                  <DotMeta label="LOAD 8.2"/>
                </div>
              </div>
            </PhotoPlaceholder>
          </div>
          {/* CTA strip — elevated pill primary + icon companion */}
          <div style={{ padding: 16, display: 'flex', gap: 10, alignItems: 'stretch' }}>
            <PrimaryButton>
              <svg width="14" height="14" viewBox="0 0 14 14" style={{ marginRight: 4 }}><path d="M3 1l9 6-9 6V1z" fill="#000"/></svg>
              Begin session
            </PrimaryButton>
            <IconButton size={56} style={{ flexShrink: 0 }}>
              <svg width="18" height="18" viewBox="0 0 18 18"><path d="M3 13.5L9 9l6 4.5V3H3v10.5z" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinejoin="round"/></svg>
            </IconButton>
          </div>
        </div>
      </div>

      {/* Block progress — single thin row, no card */}
      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
          <Eyebrow>BLOCK 03 · STRIKER MENTALITY</Eyebrow>
          <span style={{ ...TYPE.micro, color: '#fff' }}>04 / 06</span>
        </div>
        <div style={{ marginTop: 10, height: 3, background: MF.line.subtle, borderRadius: 2, overflow: 'hidden', display: 'flex' }}>
          {[1,2,3,4,5,6].map(i => (
            <div key={i} style={{
              flex: 1, marginRight: i < 6 ? 4 : 0,
              background: i <= 4 ? '#fff' : 'transparent',
            }}/>
          ))}
        </div>
      </div>

      {/* On deck — editorial list, no card chrome */}
      <div style={{ padding: '36px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 18 }}>ON DECK</Eyebrow>
        <DeckRow date="WED 13" title="Acceleration ladders" meta="38 MIN · POWER"/>
        <DeckRow date="THU 14" title="Rondo decisioning"     meta="32 MIN · COGNITION"/>
        <DeckRow date="FRI 15" title="Match-day primer"      meta="22 MIN · RECOVERY" last/>
      </div>
    </div>
  );
}

function DeckRow({ date, title, meta, last }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', gap: 18,
      padding: '16px 0',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
    }}>
      <span style={{ ...TYPE.micro, color: MF.ink.tertiary, width: 56, flexShrink: 0 }}>{date}</span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...TYPE.title3, color: '#fff', fontWeight: 600 }}>{title}</div>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>{meta}</div>
      </div>
      <svg width="10" height="14" viewBox="0 0 10 14"><path d="M2 1l6 6-6 6" stroke="rgba(255,255,255,0.60)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
    </div>
  );
}

function DotMeta({ label }) {
  return <span style={{ ...TYPE.micro, color: MF.ink.secondary }}>{label}</span>;
}
function Sep() {
  return <span style={{ width: 3, height: 3, borderRadius: 2, background: MF.ink.disabled }}/>;
}

function UpNext({ day, title, meta }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 14,
      background: MF.bg.card, borderRadius: 18, padding: 14,
      border: `1px solid ${MF.line.hairline}`,
    }}>
      <div style={{
        width: 52, height: 52, borderRadius: 12, border: `1px solid ${MF.line.subtle}`,
        background: MF.bg.elevated,
        display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      }}>
        <span style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 1.5 }}>{day}</span>
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>{title}</div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 2 }}>{meta}</div>
      </div>
      <svg width="14" height="14" viewBox="0 0 14 14"><path d="M5 2l5 5-5 5" stroke="rgba(255,255,255,0.68)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
    </div>
  );
}

// ─── MF HUB · The Curriculum ───
// Reframed as a private-academy syllabus. Roman-numeral Elite Drills.
function ScrHub() {
  const chapters = [
    { roman: '1', title: 'Receiving',         coach: 'Coach Matteo Finazzi', sessions: 4, status: 'done',     desc: 'The pre-touch scan and body shape.' },
    { roman: '2', title: 'Half-turn',          coach: 'Coach Matteo Finazzi', sessions: 6, status: 'done',     desc: 'Open the field with one touch.' },
    { roman: '3', title: 'Tight spaces',       coach: 'Coach Two', sessions: 6, status: 'current', desc: 'Decide in two beats or less.' },
    { roman: '4', title: 'Finishing inside',   coach: 'Coach Two', sessions: 5, status: 'locked',   desc: 'Six-yard composure.' },
    { roman: '5', title: 'Pressing triggers',  coach: 'Coach Matteo Finazzi', sessions: 4, status: 'locked',   desc: 'When to bite, when to hold.' },
    { roman: '6', title: 'Match craft',        coach: 'Coach Matteo Finazzi', sessions: 6, status: 'locked',   desc: 'Reading the 90.' },
  ];

  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 140 }}>
      {/* Editorial masthead — feels like a printed program */}
      <div style={{ padding: '64px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Eyebrow>SEASON 24 — 25</Eyebrow>
          <Eyebrow>STRIKER TRACK</Eyebrow>
        </div>
        <SlashRule style={{ marginTop: 14 }}/>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 22, lineHeight: '46px', textWrap: 'balance' }}>
          The MF<br/>Method
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12, maxWidth: 320 }}>
          Six Elite Drills. Built by Coach Matteo Finazzi for one-on-one development.
          Move at your pace — your coach unlocks the next.
        </div>
        <SlashRule style={{ marginTop: 22 }}/>
      </div>

      {/* Faculty strip — academy feel */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <Eyebrow style={{ flexShrink: 0 }}>FACULTY</Eyebrow>
          <div style={{ flex: 1, height: 1, background: MF.line.hairline }}/>
        </div>
        <div style={{ display: 'flex', gap: 18, marginTop: 16 }}>
          <FacultyTag initials="MF" name="Coach Matteo Finazzi"   role="HEAD COACH"/>
          <FacultyTag initials="C2" name="Coach Two"   role="FINISHING"/>
          <FacultyTag initials="C3" name="Coach Three" role="PHYSIO"/>
        </div>
      </div>

      {/* Chapter list — long-form, editorial */}
      <div style={{ padding: '36px 0 0' }}>
        <div style={{ padding: '0 20px 18px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>THE CURRICULUM</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>06 ELITE DRILLS · 31 SESSIONS</span>
        </div>
        {chapters.map((c, i) => (
          <ChapterRow key={c.roman} {...c} last={i === chapters.length - 1}/>
        ))}
      </div>
    </div>
  );
}

function FacultyTag({ initials, name, role }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
      <Avatar size={36} initials={initials}/>
      <div style={{ minWidth: 0 }}>
        <div style={{ ...TYPE.foot, color: '#fff', fontWeight: 600, whiteSpace: 'nowrap' }}>{name}</div>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>{role}</div>
      </div>
    </div>
  );
}

function ChapterRow({ roman, title, coach, sessions, status, desc, last }) {
  const isLocked  = status === 'locked';
  const isCurrent = status === 'current';
  const isDone    = status === 'done';

  return (
    <div style={{
      position: 'relative',
      padding: '22px 20px',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
      background: isCurrent ? '#0a0a0a' : 'transparent',
      opacity: isLocked ? 0.55 : 1,
      display: 'flex', gap: 18, alignItems: 'flex-start',
    }}>
      {/* Roman numeral — huge, editorial */}
      <div style={{
        width: 64, flexShrink: 0,
        ...TYPE.num, fontSize: 44, lineHeight: '42px',
        color: isCurrent ? '#fff' : MF.ink.tertiary,
        letterSpacing: -1, fontFamily: MF.font.display,
        fontVariantNumeric: 'normal',
        fontStyle: 'italic',
      }}>{roman}</div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
          <span style={{ ...TYPE.title2, color: '#fff' }}>{title}</span>
          {isCurrent && (
            <span style={{
              padding: '2px 8px', borderRadius: 999, background: '#fff', color: '#000',
              ...TYPE.micro,
            }}>IN PROGRESS</span>
          )}
          {isDone && (
            <svg width="16" height="16" viewBox="0 0 16 16"><path d="M3 8.5l3 3 7-7.5" stroke="#fff" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          )}
        </div>
        <div style={{ ...TYPE.foot, color: MF.ink.secondary, marginTop: 6 }}>{desc}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 12 }}>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>COACH · {coach.toUpperCase()}</span>
          <Sep/>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{sessions} SESSIONS</span>
        </div>
        {isCurrent && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 14 }}>
            <div style={{ flex: 1, height: 2, background: MF.line.subtle, borderRadius: 1, overflow: 'hidden' }}>
              <div style={{ width: '50%', height: '100%', background: '#fff' }}/>
            </div>
            <span style={{ ...TYPE.micro, color: '#fff' }}>03 / 06</span>
          </div>
        )}
      </div>

      <div style={{
        width: 28, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'flex-end',
        paddingTop: 4,
      }}>
        {isLocked ? (
          <svg width="14" height="16" viewBox="0 0 14 16"><path d="M3 7V5a4 4 0 018 0v2" stroke="rgba(255,255,255,0.68)" strokeWidth="1.4" fill="none"/><rect x="2" y="7" width="10" height="8" rx="1.5" stroke="rgba(255,255,255,0.68)" strokeWidth="1.4" fill="none"/></svg>
        ) : (
          <svg width="10" height="14" viewBox="0 0 10 14"><path d="M2 1l6 6-6 6" stroke="rgba(255,255,255,0.68)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        )}
      </div>
    </div>
  );
}

// ─── PROGRESS ───
function ScrProgress() {
  // Sparkline points (week intensity 1..10)
  const pts = [3.4, 5.2, 6.1, 4.8, 7.0, 8.2, 6.4, 7.5, 8.0, 9.1, 8.4, 9.4];
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 140 }}>
      <div style={{ padding: '64px 20px 8px' }}>
        <Eyebrow>BLOCK 03 · WEEK 14</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 6, lineHeight: '46px' }}>
          Progress
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 10 }}>
          You're trending +1.4 intensity vs last block.
        </div>
      </div>

      {/* Cumulative summary */}
      <div style={{ padding: '20px 20px 0' }}>
        <Card padding={20}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <BigStat label="SESSIONS" value="84" size={36}/>
            <BigStat label="MINUTES" value="2,940" size={36}/>
            <BigStat label="DRILLS" value="412" size={36}/>
          </div>
          <Hairline style={{ margin: '18px 0' }}/>
          {/* Intensity line chart */}
          <Eyebrow>INTENSITY · LAST 12 WEEKS</Eyebrow>
          <div style={{ marginTop: 12, height: 110, position: 'relative' }}>
            <svg width="100%" height="110" viewBox="0 0 320 110" preserveAspectRatio="none">
              {[20, 50, 80].map(y => (
                <line key={y} x1="0" y1={y} x2="320" y2={y} stroke={MF.line.hairline} strokeDasharray="3 4"/>
              ))}
              <polyline
                fill="none" stroke="#fff" strokeWidth="2"
                points={pts.map((v, i) => `${(i/(pts.length-1))*320},${100 - (v/10)*90}`).join(' ')}
              />
              {pts.map((v, i) => (
                <circle key={i} cx={(i/(pts.length-1))*320} cy={100 - (v/10)*90} r={i === pts.length-1 ? 4 : 2.2} fill="#fff"/>
              ))}
            </svg>
            <div style={{
              position: 'absolute', right: 0, top: -8, padding: '3px 8px', borderRadius: 6,
              background: '#fff', color: '#000', ...TYPE.micro,
            }}>9.4 · TODAY</div>
          </div>
        </Card>
      </div>

      {/* This week strip */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10 }}>
          <Eyebrow>THIS WEEK</Eyebrow>
          <span style={{ ...TYPE.foot, color: MF.ink.secondary, fontWeight: 600 }}>Week 14 →</span>
        </div>
        <Card padding={0} style={{ overflow: 'hidden' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)' }}>
            {['M','T','W','T','F','S','S'].map((d, i) => {
              const done = i < 2;
              const today = i === 2;
              return (
                <div key={i} style={{
                  padding: '14px 0', display: 'flex', flexDirection: 'column',
                  alignItems: 'center', gap: 8,
                  borderRight: i < 6 ? `1px solid ${MF.line.hairline}` : 'none',
                  background: today ? '#fff' : 'transparent',
                  color: today ? '#000' : '#fff',
                }}>
                  <span style={{ ...TYPE.micro, color: today ? 'rgba(0,0,0,0.55)' : MF.ink.tertiary }}>{d}</span>
                  <span style={{ ...TYPE.title3, fontWeight: 700 }}>{10 + i}</span>
                  <span style={{
                    width: 6, height: 6, borderRadius: 3,
                    background: done ? (today ? '#000' : '#fff') : 'transparent',
                    border: `1px solid ${today ? '#000' : (done ? '#fff' : MF.ink.disabled)}`,
                  }}/>
                </div>
              );
            })}
          </div>
        </Card>
      </div>

      {/* Milestones */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 10 }}>RECENT MILESTONES</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {[
            ['100 hr', 'On-ball volume crossed 100 hours.', '2d ago'],
            ['Block 02', 'Striker Foundations — completed.', '1w ago'],
            ['Sprint PR', '10 m sprint · 1.69s · new personal best.', '2w ago'],
          ].map((m, i) => (
            <div key={i} style={{
              display: 'flex', gap: 14, padding: '14px 0',
              borderBottom: i < 2 ? `1px solid ${MF.line.hairline}` : 'none',
            }}>
              <div style={{
                width: 44, height: 44, borderRadius: 12, flexShrink: 0,
                background: '#fff', color: '#000',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                ...TYPE.foot, fontWeight: 800, letterSpacing: -0.4,
              }}>{m[0]}</div>
              <div style={{ flex: 1 }}>
                <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>{m[1]}</div>
                <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>{m[2]}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── PROFILE · The Player Card ───
// Built around a prominent inverse "Player Card" — the focal element.
// Reads like a credential, mirrors the onboarding Passport (no barcode).
function ScrProfile() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 140 }}>
      {/* Portrait hero — quieter, leaves room for the card */}
      <div style={{ position: 'relative', height: 320 }}>
        <PhotoPlaceholder height={320} label="PLAYER PORTRAIT" style={{ borderRadius: 0, border: 'none' }}>
          <div style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(to bottom, rgba(0,0,0,0.45) 0%, rgba(0,0,0,0) 22%, rgba(0,0,0,0) 50%, rgba(0,0,0,0.85) 92%, #000 100%)',
          }}/>
          {/* Top chrome */}
          <div style={{
            position: 'absolute', top: 62, left: 16, right: 16,
            display: 'flex', justifyContent: 'space-between',
          }}>
            <IconButton style={{
              width: 36, height: 36, borderRadius: 18,
              background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(10px)',
              border: '1px solid rgba(255,255,255,0.12)',
            }}>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M2 3h10M2 7h10M2 11h10" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/></svg>
            </IconButton>
            <IconButton style={{
              width: 36, height: 36, borderRadius: 18,
              background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(10px)',
              border: '1px solid rgba(255,255,255,0.12)',
            }}>
              <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 1v9m0 0L4 7m3 3l3-3M2 12h10" stroke="#fff" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </IconButton>
          </div>
          {/* Nameplate */}
          <div style={{ position: 'absolute', left: 24, right: 24, bottom: 80 }}>
            <Eyebrow style={{ color: 'rgba(255,255,255,0.78)', letterSpacing: 2 }}>
              MF · ELITE · MEMBER № 1142
            </Eyebrow>
            <div style={{ ...TYPE.hero, color: '#fff', marginTop: 8, lineHeight: '44px', fontWeight: 800, letterSpacing: -1.8 }}>
              Player One
            </div>
          </div>
        </PhotoPlaceholder>
      </div>

      {/* THE PLAYER CARD — focal element */}
      <div style={{ padding: '0 20px 0', marginTop: -56, position: 'relative', zIndex: 2 }}>
        <Eyebrow style={{ marginBottom: 10, color: 'rgba(255,255,255,0.7)', letterSpacing: 2 }}>
          THE PLAYER CARD
        </Eyebrow>
        <div style={{
          background: '#fff', color: '#000', borderRadius: 8,
          padding: 20, overflow: 'hidden',
          boxShadow: '0 30px 60px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.18)',
        }}>
          {/* Top bar */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <MFMark size={18} dark={false}/>
              <span style={{ ...TYPE.micro, color: '#000', letterSpacing: 2 }}>MF · ELITE</span>
            </div>
            <span style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.55)' }}>№ 1142 · CLASS 2026</span>
          </div>

          {/* Body — monogram + identity */}
          <div style={{ display: 'flex', gap: 16, marginTop: 18 }}>
            {/* Inverse monogram on the card */}
            <div style={{
              width: 110, height: 132, flexShrink: 0, position: 'relative', overflow: 'hidden',
              background: '#000', borderRadius: 4,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <svg width="110" height="132" viewBox="0 0 100 100" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
                <line x1="0" y1="40" x2="35" y2="0" stroke="rgba(255,255,255,0.10)" strokeWidth="1.2"/>
                <line x1="0" y1="55" x2="50" y2="0" stroke="rgba(255,255,255,0.08)" strokeWidth="1.2"/>
                <line x1="0" y1="70" x2="65" y2="0" stroke="rgba(255,255,255,0.06)" strokeWidth="1.2"/>
              </svg>
              <span style={{
                fontFamily: MF.font.display, fontWeight: 800,
                fontSize: 64, color: '#fff', letterSpacing: -2.4,
                position: 'relative', zIndex: 1,
              }}>09</span>
              <div style={{
                position: 'absolute', right: 6, top: 6,
                ...TYPE.micro, color: 'rgba(255,255,255,0.78)', letterSpacing: 1.6,
              }}>ST</div>
              <div style={{
                position: 'absolute', left: 6, bottom: 6,
                ...TYPE.micro, color: 'rgba(255,255,255,0.72)', letterSpacing: 1.4,
              }}>P1</div>
            </div>

            {/* Identity stack */}
            <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
              <div>
                <Eyebrow style={{ color: 'rgba(0,0,0,0.55)' }}>NAME</Eyebrow>
                <div style={{ ...TYPE.title2, color: '#000', marginTop: 2, letterSpacing: -0.4 }}>Player One</div>
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
                <PCardRow k="POST"  v="Striker"/>
                <PCardRow k="KIT"   v="09"/>
                <PCardRow k="FOOT"  v="Right"/>
                <PCardRow k="HEIGHT" v="1.84 m"/>
              </div>
            </div>
          </div>

          {/* Slash rule + bottom meta (no barcode) */}
          <SlashRule color="rgba(0,0,0,0.15)" style={{ marginTop: 18 }}/>
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginTop: 14 }}>
            <PCardRow k="COACH"   v="Coach Matteo Finazzi"/>
            <PCardRow k="TRACK"   v="Elite · Striker" align="right"/>
          </div>
        </div>
      </div>

      {/* Career numerals */}
      <div style={{ padding: '36px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 20 }}>CAREER · TO DATE</Eyebrow>
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)',
          borderTop: `1px solid ${MF.line.hairline}`,
          borderBottom: `1px solid ${MF.line.hairline}`,
        }}>
          <CareerStat n="84"  l="SESSIONS"/>
          <CareerStat n="49h" l="ON BALL" mid/>
          <CareerStat n="412" l="DRILLS"/>
        </div>
      </div>

      {/* Honors */}
      <div style={{ padding: '32px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 16 }}>HONORS · 12</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <HonorRow date="MAR · 24" title="100 hours on the ball"     meta="Volume milestone"/>
          <HonorRow date="FEB · 24" title="Block II — Half-turn"      meta="Completed · Coach Matteo Finazzi"/>
          <HonorRow date="FEB · 24" title="Sprint personal best"      meta="10 m · 1.69 s"/>
          <HonorRow date="JAN · 24" title="Streak — 21 days"          meta="No missed sessions"/>
          <HonorRow date="JAN · 24" title="Block I — Receiving"       meta="Completed · Coach Matteo Finazzi" last/>
        </div>
      </div>
    </div>
  );
}

function PCardRow({ k, v, align = 'left' }) {
  return (
    <div style={{ textAlign: align }}>
      <Eyebrow style={{ color: 'rgba(0,0,0,0.5)', fontSize: 9 }}>{k}</Eyebrow>
      <div style={{ ...TYPE.foot, color: '#000', fontWeight: 700, marginTop: 2 }}>{v}</div>
    </div>
  );
}

function CareerStat({ n, l, mid }) {
  return (
    <div style={{
      padding: '24px 0',
      display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 8,
      borderLeft: mid ? `1px solid ${MF.line.hairline}` : 'none',
      borderRight: mid ? `1px solid ${MF.line.hairline}` : 'none',
      paddingLeft: mid ? 20 : 0,
    }}>
      <span style={{ ...TYPE.num, fontSize: 40, lineHeight: '38px', color: '#fff' }}>{n}</span>
      <Eyebrow>{l}</Eyebrow>
    </div>
  );
}

function DossierRow({ k, v, last }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
      padding: '14px 0',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
    }}>
      <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 500 }}>{k}</span>
      <span style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>{v}</span>
    </div>
  );
}

function HonorRow({ date, title, meta, last }) {
  return (
    <div style={{
      display: 'flex', gap: 18, alignItems: 'baseline',
      padding: '16px 0',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
    }}>
      <span style={{ ...TYPE.micro, color: MF.ink.tertiary, width: 62, flexShrink: 0 }}>{date}</span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>{title}</div>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>{meta}</div>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScreenHeader, ScrDashboard, ScrHub, ScrProgress, ScrProfile,
  DotMeta, Sep,
});
