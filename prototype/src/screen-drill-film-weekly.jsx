// MF Elite — Drill screens + Weekly breakdown

// ─── DRILL DETAIL · FILM ───
// Hero video version. No overlap, clean flow, MF brand strip instead of coach.
function ScrDrillDetailFilm() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 40 }}>
      {/* Hero film */}
      <div style={{ position: 'relative' }}>
        <PhotoPlaceholder height={360} label="" style={{ borderRadius: 0, border: 'none' }}>
          <div style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(to bottom, rgba(0,0,0,0.55) 0%, rgba(0,0,0,0) 32%, rgba(0,0,0,0) 55%, #000 100%)',
          }}/>
          {/* Top chrome */}
          <div style={{
            position: 'absolute', top: 62, left: 16, right: 16,
            display: 'flex', justifyContent: 'space-between',
          }}>
            <div style={{
              width: 40, height: 40, borderRadius: 12,
              background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(10px)',
              border: '1px solid rgba(255,255,255,0.12)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <svg width="10" height="16" viewBox="0 0 10 16"><path d="M8 1L2 8l6 7" stroke="#fff" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </div>
            <div style={{
              padding: '6px 12px', borderRadius: 999,
              background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(10px)',
              border: '1px solid rgba(255,255,255,0.12)',
              display: 'flex', alignItems: 'center', gap: 8,
            }}>
              <span style={{ width: 6, height: 6, borderRadius: 3, background: '#fff' }}/>
              <span style={{ ...TYPE.micro, color: '#fff' }}>FILM</span>
            </div>
          </div>
          {/* Centered play */}
          <div style={{
            position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <div style={{
              width: 64, height: 64, borderRadius: 32,
              background: 'rgba(255,255,255,0.92)', backdropFilter: 'blur(10px)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 12px 32px rgba(0,0,0,0.5)',
            }}>
              <svg width="20" height="22" viewBox="0 0 20 22"><path d="M3 1l16 10L3 21V1z" fill="#000"/></svg>
            </div>
          </div>
        </PhotoPlaceholder>
      </div>

      {/* Title block — flows below hero, no overlap */}
      <div style={{ padding: '20px 20px 0' }}>
        <Eyebrow>DRILL 03 OF 07 · BLOCK 03</Eyebrow>
        <div style={{ ...TYPE.title1, color: '#fff', marginTop: 8, textWrap: 'balance' }}>
          First touch under pressure
        </div>
      </div>

      {/* Stat strip */}
      <DrillStats/>

      {/* MF brand strip (replaces "COACHED BY") */}
      <MFBrandStrip/>

      {/* Brief, Steps, Equipment, CTA */}
      <DrillBody/>
    </div>
  );
}

// ─── DRILL DETAIL · TYPE ───
// No-video version. Purely typographic. Editorial feel.
function ScrDrillDetailType() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 40 }}>
      {/* Top chrome */}
      <div style={{
        padding: '62px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{
          width: 40, height: 40, borderRadius: 12,
          background: MF.bg.raised, border: `1px solid ${MF.line.hairline}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="10" height="16" viewBox="0 0 10 16"><path d="M8 1L2 8l6 7" stroke="#fff" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <MFMark size={20}/>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 2 }}>MF · ELITE TRAINING</span>
        </div>
      </div>

      {/* Editorial masthead */}
      <div style={{ padding: '40px 20px 0' }}>
        <Eyebrow>DRILL 03 OF 07 · BLOCK 03</Eyebrow>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 800,
          fontSize: 44, lineHeight: '46px', letterSpacing: -1.4, color: '#fff',
          marginTop: 14, textWrap: 'balance',
        }}>
          First touch<br/>under pressure
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12, maxWidth: 320 }}>
          Quality over speed — the first touch is the rep.
        </div>
      </div>

      {/* Slash rule for editorial pause */}
      <div style={{ padding: '28px 20px 0' }}><SlashRule/></div>

      {/* Stat strip */}
      <DrillStats/>

      {/* MF brand strip */}
      <MFBrandStrip/>

      {/* Brief, Steps, Equipment, CTA */}
      <DrillBody/>
    </div>
  );
}

// ─── Shared training-loop subcomponents ──────────────────────

function DrillStats() {
  return (
    <div style={{ padding: '20px 20px 0' }}>
      <div style={{
        background: MF.bg.elevated, borderRadius: 20, padding: '16px 18px',
        border: `1px solid ${MF.line.hairline}`,
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
      }}>
        {[
          ['DURATION', '6 min'],
          ['REPS', '4 × 4'],
          ['LOAD', '7.5'],
          ['REST', '0:45'],
        ].map(([l, v], i) => (
          <div key={i} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
            borderRight: i < 3 ? `1px solid ${MF.line.hairline}` : 'none',
          }}>
            <span style={{ ...TYPE.num, fontSize: 20, color: '#fff' }}>{v}</span>
            <Eyebrow>{l}</Eyebrow>
          </div>
        ))}
      </div>
    </div>
  );
}

function MFBrandStrip() {
  return (
    <div style={{ padding: '20px 20px 0' }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 14,
        padding: '14px 16px',
        background: MF.bg.card, borderRadius: 16,
        border: `1px solid ${MF.line.hairline}`,
      }}>
        <div style={{
          width: 44, height: 44, borderRadius: 12,
          background: '#000', border: `1px solid ${MF.line.subtle}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          flexShrink: 0,
        }}>
          <MFMark size={20}/>
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <Eyebrow>PROGRAM BY</Eyebrow>
          <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700, marginTop: 2, letterSpacing: 0.2 }}>
            MF Elite Training
          </div>
        </div>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 1.6 }}>
          BLOCK 03
        </div>
      </div>
    </div>
  );
}

function DrillBody() {
  return (
    <>
      {/* Brief */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow>BRIEF</Eyebrow>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 8, textWrap: 'pretty' }}>
          Receive on the half-turn, kill the ball with the back foot, exit the cone box before the
          chase defender resets. Quality over speed — the first touch is the rep.
        </div>
      </div>

      {/* Steps */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>STEPS · 04</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {[
            ['Set', 'Four cones · 3 m apart · pass server at 12 m'],
            ['Receive', 'Half-turn touch with back foot, hips open to goal'],
            ['Exit', 'Two-touch escape past the marker cone'],
            ['Finish', 'Place into the small goal · alternate feet'],
          ].map(([k, v], i) => (
            <div key={i} style={{
              display: 'flex', gap: 14, padding: '14px 0',
              borderBottom: i < 3 ? `1px solid ${MF.line.hairline}` : 'none',
            }}>
              <div style={{
                width: 28, height: 28, borderRadius: 8, background: MF.bg.raised,
                border: `1px solid ${MF.line.subtle}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                ...TYPE.micro, color: MF.ink.primary, flexShrink: 0,
              }}>{String(i+1).padStart(2,'0')}</div>
              <div style={{ flex: 1 }}>
                <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>{k}</div>
                <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 2 }}>{v}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Equipment */}
      <div style={{ padding: '20px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 10 }}>EQUIPMENT</Eyebrow>
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {['4× cones', '1× ball', '1× marker', 'small goal'].map((e) => (
            <Chip key={e}>{e}</Chip>
          ))}
        </div>
      </div>

      {/* In-flow CTA — no absolute positioning, no overlap */}
      <div style={{ padding: '28px 20px 0', display: 'flex', gap: 10 }}>
        <button style={{
          width: 56, height: 56, borderRadius: 16,
          background: MF.bg.raised, border: `1px solid ${MF.line.subtle}`, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
        }}>
          <svg width="22" height="22" viewBox="0 0 22 22"><path d="M5 4.5v13l13-6.5L5 4.5z" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinejoin="round"/></svg>
        </button>
        <PrimaryButton hint="6 MIN" style={{ flex: 1 }}>Start drill</PrimaryButton>
      </div>
    </>
  );
}

// ─── DRILL PLAYER (in-session) ───
function ScrDrillPlayer() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden' }}>
      {/* Full-bleed film */}
      <PhotoPlaceholder height={874} label="ACTIVE · 4× ZOOM · LOOP" style={{ borderRadius: 0, border: 'none', height: '100%' }}>
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(to bottom, rgba(0,0,0,0.55) 0%, rgba(0,0,0,0) 26%, rgba(0,0,0,0) 62%, rgba(0,0,0,0.92) 100%)',
        }}/>

        {/* Top HUD */}
        <div style={{ position: 'absolute', top: 56, left: 16, right: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{
            padding: '6px 10px', borderRadius: 999, background: 'rgba(0,0,0,0.55)',
            backdropFilter: 'blur(10px)', display: 'flex', alignItems: 'center', gap: 8,
            border: '1px solid rgba(255,255,255,0.12)',
          }}>
            <span style={{ width: 7, height: 7, borderRadius: 4, background: '#fff', animation: 'mfPulse 1.2s infinite' }}/>
            <span style={{ ...TYPE.micro, color: '#fff' }}>SET 2 OF 4</span>
          </div>
          <div style={{
            padding: '6px 10px', borderRadius: 999, background: 'rgba(0,0,0,0.55)',
            backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.12)',
          }}>
            <span style={{ ...TYPE.micro, color: '#fff' }}>END SESSION</span>
          </div>
        </div>

        {/* Big timer */}
        <div style={{
          position: 'absolute', top: 130, left: 0, right: 0, display: 'flex',
          flexDirection: 'column', alignItems: 'center', gap: 10,
        }}>
          <Eyebrow style={{ color: 'rgba(255,255,255,0.6)' }}>WORK</Eyebrow>
          <div style={{ ...TYPE.num, fontSize: 96, lineHeight: '96px', color: '#fff', letterSpacing: -3 }}>
            01:24
          </div>
          <div style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>Rest in 1:26 · Set 2 / 4</div>
        </div>

        {/* Drill title at center */}
        <div style={{
          position: 'absolute', top: 380, left: 24, right: 24, textAlign: 'center',
        }}>
          <div style={{ ...TYPE.title2, color: '#fff' }}>First touch under pressure</div>
        </div>

        {/* Set ladder */}
        <div style={{
          position: 'absolute', left: 24, right: 24, bottom: 250,
          display: 'flex', gap: 8,
        }}>
          {[1,2,3,4].map(n => (
            <div key={n} style={{
              flex: 1, height: 6, borderRadius: 3,
              background: n < 2 ? '#fff' : n === 2 ? 'rgba(255,255,255,0.45)' : 'rgba(255,255,255,0.14)',
              position: 'relative',
            }}>
              {n === 2 && <div style={{ width: '40%', height: '100%', borderRadius: 3, background: '#fff' }}/>}
            </div>
          ))}
        </div>

        {/* Telemetry strip */}
        <div style={{
          position: 'absolute', left: 20, right: 20, bottom: 160,
          background: 'rgba(15,15,15,0.7)', backdropFilter: 'blur(20px)',
          border: '1px solid rgba(255,255,255,0.08)', borderRadius: 18,
          padding: '14px 16px',
          display: 'grid', gridTemplateColumns: '1fr 1fr 1fr',
        }}>
          {[['REPS','7'], ['ELAPSED','4:12'], ['HR','148']].map(([l,v], i) => (
            <div key={i} style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
              borderRight: i < 2 ? '1px solid rgba(255,255,255,0.06)' : 'none',
            }}>
              <span style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>{v}</span>
              <Eyebrow>{l}</Eyebrow>
            </div>
          ))}
        </div>

        {/* Bottom controls */}
        <div style={{
          position: 'absolute', left: 20, right: 20, bottom: 56,
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18,
        }}>
          <CircleBtn>
            <svg width="20" height="20" viewBox="0 0 20 20"><path d="M14 4L6 10l8 6V4z" fill="#fff"/></svg>
          </CircleBtn>
          <CircleBtn size={88} primary>
            <svg width="22" height="26" viewBox="0 0 22 26"><rect x="3" y="3" width="6" height="20" fill="#000"/><rect x="13" y="3" width="6" height="20" fill="#000"/></svg>
          </CircleBtn>
          <CircleBtn>
            <svg width="20" height="20" viewBox="0 0 20 20"><path d="M6 4l8 6-8 6V4z" fill="#fff"/></svg>
          </CircleBtn>
        </div>
      </PhotoPlaceholder>
    </div>
  );
}

function CircleBtn({ children, primary, size = 60 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size / 2,
      background: primary ? '#fff' : 'rgba(20,20,20,0.85)',
      backdropFilter: 'blur(20px)',
      border: primary ? 'none' : '1px solid rgba(255,255,255,0.12)',
      boxShadow: primary ? '0 10px 30px rgba(255,255,255,0.18)' : 'none',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>{children}</div>
  );
}

// ─── WEEKLY BREAKDOWN ───
function ScrWeekly() {
  const days = [
    { d: 'MON', date: 10, status: 'done',   load: 7.2, name: 'First touch under pressure',  time: '42 min', drills: 7 },
    { d: 'TUE', date: 11, status: 'done',   load: 6.4, name: 'Half-turn finishing',          time: '34 min', drills: 6 },
    { d: 'WED', date: 12, status: 'today',  load: 8.2, name: 'Tight spaces & decisioning',   time: '42 min', drills: 7 },
    { d: 'THU', date: 13, status: 'queued', load: 6.8, name: 'Acceleration ladders',         time: '38 min', drills: 5 },
    { d: 'FRI', date: 14, status: 'queued', load: 5.0, name: 'Match-day primer',             time: '22 min', drills: 4 },
    { d: 'SAT', date: 15, status: 'rest',   load: 0,   name: 'Match day · Whitestone 16:00', time: '90 min', drills: 0 },
    { d: 'SUN', date: 16, status: 'rest',   load: 2.0, name: 'Recovery walk + mobility',     time: '20 min', drills: 2 },
  ];

  const statusColor = (s) => (
    s === 'done' ? '#fff' : s === 'today' ? '#fff' :
    s === 'queued' ? MF.ink.tertiary : MF.ink.disabled
  );

  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 120 }}>
      {/* Header w/ week selector */}
      <div style={{ padding: '64px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: MF.ink.tertiary }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ ...TYPE.foot, fontWeight: 600 }}>Progress</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 14 }}>
          <span style={{ ...TYPE.hero, color: '#fff', lineHeight: '46px' }}>Week 14</span>
          <span style={{ ...TYPE.title3, color: MF.ink.tertiary }}>Mar 10 — 16</span>
        </div>
        {/* Mini scroll of weeks */}
        <div style={{ display: 'flex', gap: 8, marginTop: 16 }}>
          {['12','13','14','15','16'].map(w => (
            <div key={w} style={{
              ...TYPE.foot, fontWeight: 600,
              padding: '6px 12px', borderRadius: 999,
              background: w === '14' ? '#fff' : 'transparent',
              color: w === '14' ? '#000' : MF.ink.secondary,
              border: `1px solid ${w === '14' ? '#fff' : MF.line.subtle}`,
            }}>W{w}</div>
          ))}
        </div>
      </div>

      {/* Summary row */}
      <div style={{ padding: '20px 20px 0' }}>
        <Card padding={18}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <div>
              <Eyebrow>WEEK COMPLETE</Eyebrow>
              <div style={{ ...TYPE.num, fontSize: 36, color: '#fff', marginTop: 6 }}>
                3<span style={{ color: MF.ink.tertiary }}>/7</span>
              </div>
            </div>
            <PitchRing size={84} progress={0.43} stroke={6} value="43" label="LOAD %"/>
          </div>
          <Hairline style={{ margin: '14px 0' }}/>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr' }}>
            <SmallStat label="MIN" value="118"/>
            <SmallStat label="DRILLS" value="19" mid/>
            <SmallStat label="AVG LOAD" value="7.3"/>
          </div>
        </Card>
      </div>

      {/* Day-by-day */}
      <div style={{ padding: '24px 0 0' }}>
        <Eyebrow style={{ padding: '0 20px 12px' }}>EVERY DAY · WEEK 14</Eyebrow>
        <div>
          {days.map((d, i) => (
            <div key={i} style={{
              padding: '16px 20px',
              borderTop: `1px solid ${MF.line.hairline}`,
              borderBottom: i === days.length-1 ? `1px solid ${MF.line.hairline}` : 'none',
              background: d.status === 'today' ? '#0c0c0c' : 'transparent',
              display: 'flex', alignItems: 'center', gap: 14,
            }}>
              {/* Day glyph */}
              <div style={{
                width: 48, height: 56, flexShrink: 0,
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 2,
                border: `1px solid ${d.status === 'today' ? '#fff' : MF.line.hairline}`,
                borderRadius: 10,
                background: d.status === 'today' ? '#fff' : 'transparent',
                color: d.status === 'today' ? '#000' : '#fff',
              }}>
                <span style={{ ...TYPE.micro, color: d.status === 'today' ? 'rgba(0,0,0,0.6)' : MF.ink.tertiary }}>{d.d}</span>
                <span style={{ ...TYPE.title3, lineHeight: '20px' }}>{d.date}</span>
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600, textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                  {d.name}
                </div>
                <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginTop: 4 }}>
                  <span style={{ ...TYPE.micro, color: statusColor(d.status) }}>
                    {d.status === 'done' ? 'COMPLETED' : d.status === 'today' ? 'IN PROGRESS' : d.status === 'queued' ? 'QUEUED' : 'REST'}
                  </span>
                  <Sep/>
                  <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{d.time}</span>
                  {d.drills > 0 && <><Sep/><span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{d.drills} DRILLS</span></>}
                </div>
              </div>
              {/* Load mini-bar */}
              <div style={{ width: 36, display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
                <span style={{ ...TYPE.num, fontSize: 16, color: '#fff' }}>{d.load.toFixed(1)}</span>
                <div style={{ width: 36, height: 3, background: MF.line.subtle, borderRadius: 2, overflow: 'hidden' }}>
                  <div style={{ width: `${(d.load/10)*100}%`, height: '100%', background: '#fff' }}/>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '24px 20px 0' }}>
        <GhostButton>Export week to PDF</GhostButton>
      </div>
    </div>
  );
}

function SmallStat({ label, value, mid }) {
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
      borderLeft: mid ? `1px solid ${MF.line.hairline}` : 'none',
      borderRight: mid ? `1px solid ${MF.line.hairline}` : 'none',
    }}>
      <span style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>{value}</span>
      <Eyebrow>{label}</Eyebrow>
    </div>
  );
}

Object.assign(window, {
  ScrDrillDetailFilm, ScrDrillDetailType, ScrDrillPlayer, ScrWeekly,
  CircleBtn, SmallStat, DrillStats, DrillBody, MFBrandStrip,
});
