// MF Elite — Drill Library + Routines · Core navigation sub-screens

// ─── DRILL LIBRARY ───
// Selectable drills. Reached from MF Hub > Chapter > Drills.
function ScrDrillLibrary() {
  const drills = [
    { code: 'D003', title: 'First touch under pressure',  focus: 'RECEIVING',  mins: 6,  load: 7.5, on: true },
    { code: 'D012', title: 'Half-turn finishing',         focus: 'FINISHING',  mins: 8,  load: 8.2 },
    { code: 'D018', title: 'Rondo decisioning',           focus: 'COGNITION',  mins: 6,  load: 6.4, on: true },
    { code: 'D024', title: 'Acceleration ladders',        focus: 'POWER',      mins: 5,  load: 9.0 },
    { code: 'D031', title: 'Tight space escape',          focus: 'COGNITION',  mins: 7,  load: 7.8 },
    { code: 'D047', title: 'Six-yard composure',          focus: 'FINISHING',  mins: 6,  load: 8.0, on: true },
    { code: 'D052', title: 'Pressing trigger reads',      focus: 'COGNITION',  mins: 8,  load: 7.2 },
    { code: 'D061', title: 'Body-feint isolation',        focus: 'TECHNIQUE',  mins: 5,  load: 6.8 },
  ];

  const onCount = drills.filter(d => d.on).length;

  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 140 }}>
      {/* Header */}
      <div style={{ padding: '64px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: MF.ink.tertiary }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 2L4 7l5 5" stroke="currentColor" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ ...TYPE.foot, fontWeight: 600 }}>MF Hub · The Method</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', marginTop: 14 }}>
          <div>
            <Eyebrow>ELITE DRILL 3 · TIGHT SPACES</Eyebrow>
            <div style={{ ...TYPE.hero, color: '#fff', marginTop: 6, lineHeight: '46px' }}>
              Drill library
            </div>
            <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 8 }}>
              Choose drills to build your own session — or follow the academy track.
            </div>
          </div>
        </div>
      </div>

      {/* Focus filter */}
      <div style={{ display: 'flex', gap: 8, padding: '20px 20px 0', overflowX: 'auto' }}>
        <Chip active>All · 187</Chip>
        <Chip>Receiving</Chip>
        <Chip>Finishing</Chip>
        <Chip>Cognition</Chip>
        <Chip>Power</Chip>
        <Chip>Technique</Chip>
      </div>

      {/* Selection bar */}
      <div style={{
        margin: '20px 20px 0', padding: '14px 16px',
        background: '#0a0a0a', border: `1px solid ${MF.line.subtle}`, borderRadius: 14,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div>
          <Eyebrow>YOUR SESSION</Eyebrow>
          <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700, marginTop: 4 }}>
            {onCount} drills · {drills.filter(d => d.on).reduce((s, d) => s + d.mins, 0)} min
          </div>
        </div>
        <PrimaryButton
          size="md"
          style={{
            width: 'auto', flexShrink: 0, height: 40,
            padding: '0 18px', ...TYPE.foot, fontWeight: 700, letterSpacing: 0.1,
          }}>
          Build session
        </PrimaryButton>
      </div>

      {/* Drill rows */}
      <div style={{ padding: '24px 0 0' }}>
        <div style={{ padding: '0 20px 12px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>SELECT DRILLS</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{drills.length} OF 187 SHOWN</span>
        </div>
        {drills.map((d, i) => (
          <div key={d.code} style={{
            display: 'flex', alignItems: 'center', gap: 14,
            padding: '14px 20px',
            background: d.on ? '#0a0a0a' : 'transparent',
            borderTop: `1px solid ${MF.line.hairline}`,
            borderBottom: i === drills.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
          }}>
            {/* Mini film thumb */}
            <div style={{
              width: 58, height: 58, flexShrink: 0, borderRadius: 12, overflow: 'hidden',
              background: 'linear-gradient(160deg, #1a1a1a 0%, #0a0a0a 100%)',
              border: `1px solid ${MF.line.subtle}`,
              position: 'relative',
            }}>
              <svg width="58" height="58" viewBox="0 0 58 58" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
                <polygon points="0,0 20,0 14,58 0,58" fill="rgba(255,255,255,0.05)"/>
              </svg>
              <div style={{
                position: 'absolute', inset: 0,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
              }}>
                <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 1l9 6-9 6V1z" fill="#fff" opacity="0.85"/></svg>
              </div>
              <div style={{
                position: 'absolute', left: 4, top: 4,
                ...TYPE.micro, color: 'rgba(255,255,255,0.78)', fontSize: 8, letterSpacing: 1.2,
              }}>{d.code}</div>
            </div>
            {/* Text */}
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {d.title}
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
                <span style={{ ...TYPE.micro, color: '#fff', letterSpacing: 1.4 }}>{d.focus}</span>
                <Sep/>
                <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{d.mins} MIN</span>
                <Sep/>
                <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>LOAD {d.load.toFixed(1)}</span>
              </div>
            </div>
            {/* Add toggle */}
            <button style={{
              appearance: 'none', cursor: 'pointer',
              width: 36, height: 36, borderRadius: 10,
              background: d.on ? '#fff' : 'transparent',
              border: `1px solid ${d.on ? '#fff' : MF.line.subtle}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              flexShrink: 0,
            }}>
              {d.on ? (
                <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 7.5l3 3 5-6" stroke="#000" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              ) : (
                <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 2v10M2 7h10" stroke="#fff" strokeWidth="1.6" strokeLinecap="round"/></svg>
              )}
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── ROUTINES · Prebuilt MF Elite Training Routines ───
function ScrRoutines() {
  const routines = [
    { num: '01', name: 'Tight Spaces',     focus: 'COGNITION',  drills: 6, mins: 38, intensity: 'STANDARD' },
    { num: '02', name: 'Striker Mentality', focus: 'FINISHING', drills: 7, mins: 42, intensity: 'ELITE' },
    { num: '03', name: 'Acceleration Day', focus: 'POWER',      drills: 5, mins: 32, intensity: 'ELITE' },
    { num: '04', name: 'Half-Turn Lab',    focus: 'TECHNIQUE',  drills: 5, mins: 28, intensity: 'STANDARD' },
    { num: '05', name: 'Match-Day Primer', focus: 'PRIMER',     drills: 4, mins: 22, intensity: 'RECOVERY' },
    { num: '06', name: 'Cool Down · Mobility', focus: 'RECOVERY', drills: 3, mins: 18, intensity: 'RECOVERY' },
  ];

  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 140 }}>
      {/* Editorial masthead */}
      <div style={{ padding: '64px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Eyebrow>BY THE ACADEMY</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>12 PREBUILT</span>
        </div>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 8, lineHeight: '46px' }}>
          Routines
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 10, maxWidth: 320 }}>
          Coach-built sessions, ready to run. Pick one — start in two taps.
        </div>
      </div>

      {/* Featured routine */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>FEATURED · TODAY'S MOOD</Eyebrow>
        <div style={{
          borderRadius: 22, overflow: 'hidden',
          background: MF.bg.card, border: `1px solid ${MF.line.hairline}`,
        }}>
          <div style={{
            height: 180, position: 'relative', overflow: 'hidden',
            background:
              'linear-gradient(160deg, #1a1a1a 0%, #0a0a0a 60%, #050505 100%)',
            borderBottom: `1px solid ${MF.line.hairline}`,
          }}>
            <svg width="100%" height="100%" viewBox="0 0 400 180" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
              <polygon points="0,0 140,0 80,180 0,180" fill="rgba(255,255,255,0.05)"/>
              <line x1="0" y1="40" x2="40" y2="0" stroke="rgba(255,255,255,0.06)" strokeWidth="1.2"/>
              <line x1="0" y1="70" x2="70" y2="0" stroke="rgba(255,255,255,0.05)" strokeWidth="1.2"/>
              <line x1="0" y1="100" x2="100" y2="0" stroke="rgba(255,255,255,0.04)" strokeWidth="1.2"/>
            </svg>
            <div style={{ position: 'absolute', left: 22, top: 22, display: 'flex', alignItems: 'center', gap: 10 }}>
              <MFMark size={20}/>
              <span style={{ ...TYPE.micro, color: 'rgba(255,255,255,0.78)', letterSpacing: 2 }}>ROUTINE Nº 02</span>
            </div>
            <div style={{ position: 'absolute', left: 22, right: 22, bottom: 22 }}>
              <div style={{ ...TYPE.title1, color: '#fff', letterSpacing: -0.6 }}>Striker Mentality</div>
              <div style={{ display: 'flex', gap: 12, marginTop: 8 }}>
                <span style={{ ...TYPE.micro, color: '#fff' }}>7 DRILLS</span>
                <Sep/>
                <span style={{ ...TYPE.micro, color: '#fff' }}>42 MIN</span>
                <Sep/>
                <span style={{ ...TYPE.micro, color: '#fff' }}>ELITE</span>
              </div>
            </div>
          </div>
          <div style={{ padding: 16, display: 'flex', gap: 10, alignItems: 'center' }}>
            <PrimaryButton size="md">Start routine</PrimaryButton>
            <IconButton size={50} style={{ flexShrink: 0 }}>
              <svg width="18" height="18" viewBox="0 0 18 18"><path d="M3 13.5L9 9l6 4.5V3H3v10.5z" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinejoin="round"/></svg>
            </IconButton>
          </div>
        </div>
      </div>

      {/* All routines */}
      <div style={{ padding: '28px 0 0' }}>
        <div style={{ padding: '0 20px 12px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>ALL ROUTINES</Eyebrow>
          <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>Filter</span>
        </div>
        {routines.map((r, i) => (
          <div key={r.num} style={{
            display: 'flex', alignItems: 'center', gap: 14,
            padding: '16px 20px',
            borderTop: `1px solid ${MF.line.hairline}`,
            borderBottom: i === routines.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
          }}>
            <div style={{
              width: 36, flexShrink: 0,
              fontFamily: MF.font.display, fontWeight: 800, fontSize: 22,
              color: MF.ink.tertiary, fontStyle: 'italic',
            }}>{r.num}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ ...TYPE.title3, color: '#fff' }}>{r.name}</div>
              <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 6 }}>
                <span style={{ ...TYPE.micro, color: '#fff' }}>{r.focus}</span>
                <Sep/>
                <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{r.drills} DRILLS</span>
                <Sep/>
                <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{r.mins} MIN</span>
              </div>
            </div>
            <div style={{
              padding: '4px 8px', borderRadius: 4,
              border: `1px solid ${MF.line.subtle}`,
              ...TYPE.micro, color: '#fff', letterSpacing: 1.4,
              flexShrink: 0,
            }}>{r.intensity}</div>
            <svg width="10" height="14" viewBox="0 0 10 14"><path d="M2 1l6 6-6 6" stroke="rgba(255,255,255,0.68)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { ScrDrillLibrary, ScrRoutines });
