// MF Elite — Academy · Drill detail (canonical video format)
// Every drill follows the SAME structure (from the curriculum spec):
//   1 Title · 2 Purpose · 3 Demo · 4 Coaching Points · 5 Challenge · 6 Accountability
// This makes the screen scalable — any drill the coach adds renders here.

function ScrAcademyDrill() {
  // Exemplar drill — the spec's reference example.
  const drill = {
    code: 'TEC·A·L2·05',
    discipline: 'Technical',
    path: 'Ball Mastery · Level 2',
    title: 'Inside–Outside Control',
    purpose: 'Builds the foot coordination to move the ball forward at speed using one foot — the base of every change of direction.',
    coaching: [
      'Small touches — keep the ball inside your frame.',
      'Stay on the balls of your feet, knees soft.',
      'Eyes up between touches, not down at the ball.',
    ],
    challenge: 'Complete 3 sets of 1 minute without losing control.',
    duration: '6 min', sets: '3 × 1:00', xp: 25,
  };
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 40 }}>
      {/* ── DEMO · hero film ── */}
      <div style={{ position: 'relative' }}>
        <PhotoPlaceholder height={300} label="" style={{ borderRadius: 0, border: 'none' }}>
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, rgba(0,0,0,0.5) 0%, rgba(0,0,0,0) 30%, rgba(0,0,0,0) 55%, #000 100%)' }}/>
          {/* Top chrome */}
          <div style={{ position: 'absolute', top: 62, left: 16, right: 16, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ width: 40, height: 40, borderRadius: 12, background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="10" height="16" viewBox="0 0 10 16"><path d="M8 1L2 8l6 7" stroke="#fff" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </div>
            <div style={{ padding: '6px 12px', borderRadius: 999, background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(10px)', border: '1px solid rgba(255,255,255,0.12)', display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ width: 6, height: 6, borderRadius: 3, background: '#fff' }}/>
              <span style={{ ...TYPE.micro, color: '#fff' }}>DEMO · 0:42</span>
            </div>
          </div>
          {/* Centered play */}
          <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <div style={{ width: 64, height: 64, borderRadius: 32, background: 'rgba(255,255,255,0.92)', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 12px 32px rgba(0,0,0,0.5)' }}>
              <svg width="20" height="22" viewBox="0 0 20 22"><path d="M3 1l16 10L3 21V1z" fill="#000"/></svg>
            </div>
          </div>
        </PhotoPlaceholder>
      </div>

      {/* ── TITLE (1) ── */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Eyebrow>{drill.discipline.toUpperCase()}</Eyebrow>
          <Sep/>
          <Eyebrow>{drill.path.toUpperCase()}</Eyebrow>
        </div>
        <div style={{ ...TYPE.title1, color: '#fff', marginTop: 8, textWrap: 'balance', fontSize: 30, lineHeight: '34px' }}>{drill.title}</div>
        <div style={{ ...TYPE.micro, color: MF.ink.quaternary, marginTop: 8, fontFamily: MF.font.mono }}>DRILL {drill.code}</div>
      </div>

      {/* Stat strip */}
      <div style={{ padding: '18px 20px 0' }}>
        <div style={{ background: MF.bg.elevated, borderRadius: 18, padding: '14px 18px', border: `1px solid ${MF.line.hairline}`, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)' }}>
          {[['DURATION', drill.duration], ['SETS', drill.sets], ['EARNS', `+${drill.xp} XP`]].map(([l, v], i) => (
            <div key={l} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, borderRight: i < 2 ? `1px solid ${MF.line.hairline}` : 'none' }}>
              <span style={{ ...TYPE.num, fontSize: 18, color: '#fff' }}>{v}</span>
              <Eyebrow style={{ fontSize: 9 }}>{l}</Eyebrow>
            </div>
          ))}
        </div>
      </div>

      {/* ── PURPOSE (2) ── */}
      <div style={{ padding: '26px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
          <span style={{ ...TYPE.num, fontSize: 16, color: MF.ink.tertiary, fontVariantNumeric: 'normal' }}>01</span>
          <Eyebrow>PURPOSE · WHAT THIS IMPROVES</Eyebrow>
        </div>
        <div style={{ ...TYPE.body, color: '#fff', marginTop: 10, fontWeight: 500, lineHeight: '23px', textWrap: 'pretty' }}>{drill.purpose}</div>
      </div>

      <div style={{ padding: '20px 20px 0' }}><SlashRule/></div>

      {/* ── COACHING POINTS (4) ── */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
          <span style={{ ...TYPE.num, fontSize: 16, color: MF.ink.tertiary, fontVariantNumeric: 'normal' }}>02</span>
          <Eyebrow>COACHING POINTS · {String(drill.coaching.length).padStart(2, '0')}</Eyebrow>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', marginTop: 12 }}>
          {drill.coaching.map((pt, i) => (
            <div key={i} style={{ display: 'flex', gap: 14, padding: '13px 0', borderTop: i === 0 ? `1px solid ${MF.line.hairline}` : 'none', borderBottom: `1px solid ${MF.line.hairline}` }}>
              <span style={{ width: 22, height: 22, borderRadius: 6, background: MF.bg.raised, border: `1px solid ${MF.line.subtle}`, display: 'flex', alignItems: 'center', justifyContent: 'center', ...TYPE.micro, color: '#fff', flexShrink: 0 }}>{i + 1}</span>
              <span style={{ flex: 1, ...TYPE.callout, color: '#fff', fontWeight: 500, lineHeight: '20px' }}>{pt}</span>
            </div>
          ))}
        </div>
      </div>

      {/* ── CHALLENGE (5) ── */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ padding: 18, borderRadius: 18, background: '#fff', color: '#000' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
            <span style={{ ...TYPE.num, fontSize: 16, color: 'rgba(0,0,0,0.45)', fontVariantNumeric: 'normal' }}>03</span>
            <Eyebrow style={{ color: 'rgba(0,0,0,0.55)' }}>THE CHALLENGE</Eyebrow>
          </div>
          <div style={{ ...TYPE.title2, color: '#000', marginTop: 10, textWrap: 'balance' }}>{drill.challenge}</div>
          <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
            <span style={{ ...TYPE.micro, color: '#000', border: '1px solid rgba(0,0,0,0.18)', padding: '5px 9px', borderRadius: 999 }}>3 SETS</span>
            <span style={{ ...TYPE.micro, color: '#000', border: '1px solid rgba(0,0,0,0.18)', padding: '5px 9px', borderRadius: 999 }}>1:00 EACH</span>
            <span style={{ ...TYPE.micro, color: '#000', border: '1px solid rgba(0,0,0,0.18)', padding: '5px 9px', borderRadius: 999 }}>NO LOSS</span>
          </div>
        </div>
      </div>

      {/* ── ACCOUNTABILITY (6) — log your reps honestly (no video) ── */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 12 }}>
          <span style={{ ...TYPE.num, fontSize: 16, color: MF.ink.tertiary, fontVariantNumeric: 'normal' }}>04</span>
          <Eyebrow>ACCOUNTABILITY · LOG YOUR REPS</Eyebrow>
        </div>
        {/* Mastery tracker — 3 honest passes to master the drill */}
        <div style={{ padding: '18px 18px', borderRadius: 16, border: `1px solid ${MF.line.subtle}`, background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Eyebrow style={{ color: '#fff' }}>MASTERY · {CURRICULUM_RULES.masteryPasses} HONEST PASSES</Eyebrow>
            <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>1 / {CURRICULUM_RULES.masteryPasses} LOGGED</span>
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
            {Array.from({ length: CURRICULUM_RULES.masteryPasses }).map((_, i) => (
              <div key={i} style={{
                flex: 1, height: 8, borderRadius: 4,
                background: i < 1 ? '#fff' : MF.line.subtle,
              }}/>
            ))}
          </div>
          <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 12, lineHeight: '18px' }}>
            Log each clean run yourself — the work is yours. Three honest passes master the drill and bank +{CURRICULUM_RULES.xpPerDrill} XP.
          </div>
        </div>
        {/* Honesty note row */}
        <div style={{ marginTop: 12, display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderRadius: 14, background: MF.bg.card, border: `1px solid ${MF.line.hairline}` }}>
          <div style={{ width: 30, height: 30, borderRadius: 8, background: MF.bg.raised, border: `1px solid ${MF.line.subtle}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <svg width="15" height="15" viewBox="0 0 16 16"><path d="M8 1.5l5 2v4c0 3-2 5-5 6-3-1-5-3-5-6v-4l5-2z" stroke="#fff" strokeWidth="1.2" fill="none" strokeLinejoin="round"/><path d="M5.5 8l1.7 1.7L10.5 6" stroke="#fff" strokeWidth="1.3" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ ...TYPE.foot, color: '#fff', fontWeight: 600 }}>The honour code</div>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>ONLY YOU KNOW IF IT WAS YOUR BEST · LOG IT TRUE</div>
          </div>
        </div>
      </div>

      {/* CTA */}
      <div style={{ padding: '26px 20px 0', display: 'flex', gap: 10 }}>
        <button style={{ width: 56, height: 56, borderRadius: 16, background: MF.bg.raised, border: `1px solid ${MF.line.subtle}`, cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <svg width="22" height="22" viewBox="0 0 22 22"><path d="M5 4.5v13l13-6.5L5 4.5z" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinejoin="round"/></svg>
        </button>
        <PrimaryButton hint="6 MIN" style={{ flex: 1 }}>Start drill</PrimaryButton>
      </div>

      <div style={{ padding: '16px 20px 0', textAlign: 'center' }}>
        <Eyebrow style={{ color: MF.ink.quaternary }}>FILM · COACHING POINTS · XP ALL MANAGED BY COACH IN SUPABASE</Eyebrow>
      </div>
    </div>
  );
}

Object.assign(window, { ScrAcademyDrill });
