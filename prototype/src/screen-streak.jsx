// MF Elite — Academy · Streak & re-engagement (the habit engine)
// Streaks are the retention spine. This screen makes the streak feel
// precious, shows milestones, and gives a way to protect it — plus the
// notification concepts that pull a player back before it breaks.

// ─── STREAK DETAIL ──────────────────────────────────────────────
function ScrStreakDetail() {
  const streak = ACADEMY_PROGRESS.streak;     // 14
  const best = 21;
  const milestones = [
    { d: 7,   label: 'Week One',     state: 'done' },
    { d: 14,  label: 'Fortnight',    state: 'done' },
    { d: 30,  label: 'The Month',    state: 'next' },
    { d: 50,  label: 'Half-Century', state: 'locked' },
    { d: 100, label: 'Centurion',    state: 'locked' },
  ];
  // last 5 weeks of activity (true = trained)
  const weeks = [
    [1,1,1,0,1,1,1],
    [1,1,0,1,1,1,1],
    [1,1,1,1,0,1,1],
    [1,1,1,1,1,1,1],
    [1,1,1,1,1,1,0],
  ];
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between' }}>
        <Eyebrow>DISCIPLINE</Eyebrow>
        <Eyebrow>BEST · {best} DAYS</Eyebrow>
      </div>

      {/* Hero number */}
      <div style={{ padding: '20px 20px 0', textAlign: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'center', gap: 8 }}>
          <span style={{ ...TYPE.num, fontSize: 132, lineHeight: '116px', color: '#fff', fontVariantNumeric: 'normal', letterSpacing: -4 }}>{streak}</span>
        </div>
        <div style={{ ...TYPE.title2, color: '#fff', marginTop: 4 }}>day streak</div>
        <div style={{ ...TYPE.foot, color: MF.ink.secondary, marginTop: 8 }}>Trained every day since 27 February. Don't break the chain.</div>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 8, marginTop: 16, padding: '8px 14px', borderRadius: 999, border: `1px solid ${MF.line.subtle}` }}>
          <span style={{ width: 7, height: 7, borderRadius: 4, background: '#fff' }}/>
          <span style={{ ...TYPE.micro, color: '#fff' }}>TODAY LOGGED · COUNTED</span>
        </div>
      </div>

      {/* Streak freeze tokens */}
      <div style={{ padding: '26px 20px 0' }}>
        <div style={{ padding: '16px 18px', borderRadius: 16, background: '#0a0a0a', border: `1px solid ${MF.line.hairline}`, display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{ display: 'flex', gap: 6 }}>
            {[1, 1, 0].map((on, i) => (
              <div key={i} style={{ width: 26, height: 26, borderRadius: 7, background: on ? '#fff' : 'transparent', border: `1px solid ${on ? '#fff' : MF.line.subtle}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg width="13" height="13" viewBox="0 0 14 14"><path d="M7 1v12M1 7h12M2.8 2.8l8.4 8.4M11.2 2.8l-8.4 8.4" stroke={on ? '#000' : MF.line.strong} strokeWidth="1.1" strokeLinecap="round"/></svg>
              </div>
            ))}
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ ...TYPE.foot, color: '#fff', fontWeight: 700 }}>2 streak freezes</div>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>AUTO-PROTECTS ONE MISSED DAY · EARN MORE BY RANKING UP</div>
          </div>
        </div>
      </div>

      {/* Activity grid */}
      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Eyebrow>LAST 5 WEEKS</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>● TRAINED</span>
        </div>
        <div style={{ padding: 16, borderRadius: 16, background: MF.bg.card, border: `1px solid ${MF.line.hairline}` }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 7, marginBottom: 8 }}>
            {['M','T','W','T','F','S','S'].map((d, i) => <div key={i} style={{ textAlign: 'center', ...TYPE.micro, color: MF.ink.quaternary }}>{d}</div>)}
          </div>
          {weeks.map((wk, wi) => (
            <div key={wi} style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 7, marginBottom: wi < weeks.length - 1 ? 7 : 0 }}>
              {wk.map((on, di) => (
                <div key={di} style={{ aspectRatio: '1', borderRadius: 5, background: on ? '#fff' : MF.bg.raised, border: `1px solid ${on ? '#fff' : MF.line.hairline}` }}/>
              ))}
            </div>
          ))}
        </div>
      </div>

      {/* Milestone ladder */}
      <div style={{ padding: '28px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>STREAK MILESTONES</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {milestones.map((m, i) => {
            const done = m.state === 'done', next = m.state === 'next';
            return (
              <div key={m.d} style={{ display: 'flex', alignItems: 'center', gap: 16, padding: '14px 0', borderTop: `1px solid ${MF.line.hairline}`, borderBottom: i === milestones.length - 1 ? `1px solid ${MF.line.hairline}` : 'none', opacity: m.state === 'locked' ? 0.55 : 1 }}>
                <div style={{ width: 44, height: 44, flexShrink: 0, borderRadius: 22, background: done ? '#fff' : 'transparent', border: `1.5px solid ${done || next ? '#fff' : MF.line.subtle}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {done
                    ? <svg width="18" height="18" viewBox="0 0 18 18"><path d="M4 9.5l3.5 3.5L14 5" stroke="#000" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
                    : <span style={{ ...TYPE.num, fontSize: 15, color: next ? '#fff' : MF.ink.tertiary, fontVariantNumeric: 'normal' }}>{m.d}</span>}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>{m.label}</div>
                  <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 3 }}>{m.d}-DAY STREAK</div>
                </div>
                {next && <span style={{ ...TYPE.micro, color: '#000', background: '#fff', padding: '3px 8px', borderRadius: 4, fontWeight: 700 }}>16 TO GO</span>}
                {done && <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>EARNED</span>}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ─── RE-ENGAGEMENT · lock-screen push concepts ──────────────────
function ScrStreakNotifications() {
  const notes = [
    { tag: 'STREAK AT RISK', time: '8:30 PM', title: 'Your 14-day streak ends at midnight', body: 'One drill keeps it alive. Three minutes is enough.', strong: true },
    { tag: 'DAILY STANDARD', time: '7:00 AM', title: '“Do it when you don\u2019t feel like it.”', body: 'Today\u2019s standard from Coach Matteo. Tap to train.' },
    { tag: 'MILESTONE', time: 'Yesterday', title: 'Fortnight reached — 14 days', body: 'You\u2019re in the top 10% of the academy for consistency.' },
    { tag: 'COACH', time: 'Mon', title: 'New Tactical film added', body: 'Scanning & Awareness · Level 1 is live. Go watch.' },
  ];
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden', background: '#000' }}>
      {/* lock-screen wallpaper — slashed motif, no photo */}
      <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(170deg, #161616 0%, #000 70%)' }}/>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.6, backgroundImage: 'repeating-linear-gradient(115deg, transparent 0px, transparent 40px, rgba(255,255,255,0.025) 40px, rgba(255,255,255,0.025) 41px)' }}/>

      {/* clock */}
      <div style={{ position: 'relative', paddingTop: 76, textAlign: 'center' }}>
        <div style={{ ...TYPE.micro, color: 'rgba(255,255,255,0.7)', letterSpacing: 2 }}>TUESDAY, 12 MARCH</div>
        <div style={{ fontFamily: MF.font.display, fontWeight: 700, color: '#fff', fontSize: 84, lineHeight: '84px', letterSpacing: -2, marginTop: 4 }}>8:31</div>
      </div>

      {/* notification stack */}
      <div style={{ position: 'relative', padding: '40px 14px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {notes.map((n, i) => (
          <div key={i} style={{
            padding: '13px 15px', borderRadius: 18,
            background: n.strong ? 'rgba(255,255,255,0.97)' : 'rgba(28,28,30,0.72)',
            backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
            border: `1px solid ${n.strong ? 'transparent' : 'rgba(255,255,255,0.1)'}`,
            boxShadow: n.strong ? '0 12px 30px rgba(0,0,0,0.4)' : 'none',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
              <div style={{ width: 22, height: 22, borderRadius: 6, background: n.strong ? '#000' : '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                <MFMark size={13} dark={n.strong}/>
              </div>
              <span style={{ ...TYPE.micro, color: n.strong ? 'rgba(0,0,0,0.55)' : 'rgba(255,255,255,0.6)', letterSpacing: 1.4, fontWeight: 700, flex: 1 }}>MF ELITE · {n.tag}</span>
              <span style={{ ...TYPE.micro, color: n.strong ? 'rgba(0,0,0,0.4)' : 'rgba(255,255,255,0.45)' }}>{n.time}</span>
            </div>
            <div style={{ ...TYPE.callout, color: n.strong ? '#000' : '#fff', fontWeight: 700, marginTop: 8, lineHeight: '19px' }}>{n.title}</div>
            <div style={{ ...TYPE.foot, color: n.strong ? 'rgba(0,0,0,0.6)' : 'rgba(255,255,255,0.6)', marginTop: 4, lineHeight: '18px' }}>{n.body}</div>
          </div>
        ))}
      </div>

      {/* caption */}
      <div style={{ position: 'absolute', bottom: 26, left: 0, right: 0, textAlign: 'center' }}>
        <Eyebrow style={{ color: 'rgba(255,255,255,0.4)' }}>RE-ENGAGEMENT · TIMED, EARNED, NEVER SPAMMY</Eyebrow>
      </div>
    </div>
  );
}

Object.assign(window, { ScrStreakDetail, ScrStreakNotifications });
