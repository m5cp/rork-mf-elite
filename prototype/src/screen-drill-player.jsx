// MF Elite — Academy · In-session drill player
// The core action of the app: actually DOING a drill. Curriculum-tied,
// timer + sets, honest self-logging toward the 3× mastery pass.
// No video capture — accountability is the honour code + the log.

// Shared drill context for the player exemplar.
const PLAYER_DRILL = {
  code: 'TEC·A·L2·05',
  discipline: 'Technical', mark: 'square',
  path: 'Ball Mastery · Level 2',
  title: 'Inside–Outside Control',
  sets: 3, work: 60,
  cues: ['Small touches — ball inside your frame', 'Eyes up between touches', 'Balls of your feet, knees soft'],
};

// ─── STATE 1 · GET READY ────────────────────────────────────────
function ScrPlayerReady() {
  const d = PLAYER_DRILL;
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.5, pointerEvents: 'none', backgroundImage: 'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.02) 44px, rgba(255,255,255,0.02) 45px)' }}/>

      {/* top bar */}
      <div style={{ position: 'relative', padding: '58px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <IconButton size={36} style={{ background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="10" height="10" viewBox="0 0 10 10"><path d="M1 1l8 8M9 1L1 9" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/></svg>
        </IconButton>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <DisciplineMark kind={d.mark} size={15}/>
          <Eyebrow>{d.path.toUpperCase()}</Eyebrow>
        </div>
        <div style={{ width: 36 }}/>
      </div>

      {/* drill identity */}
      <div style={{ position: 'relative', padding: '46px 24px 0', textAlign: 'center' }}>
        <Eyebrow style={{ letterSpacing: 2.4 }}>GET READY</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 12, fontSize: 38, lineHeight: '40px', textWrap: 'balance' }}>{d.title}</div>
        <div style={{ display: 'flex', gap: 10, justifyContent: 'center', marginTop: 18 }}>
          <span style={{ ...TYPE.foot, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '7px 13px', borderRadius: 999, fontWeight: 600 }}>{d.sets} SETS</span>
          <span style={{ ...TYPE.foot, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '7px 13px', borderRadius: 999, fontWeight: 600 }}>1:00 EACH</span>
          <span style={{ ...TYPE.foot, color: '#000', background: '#fff', padding: '7px 13px', borderRadius: 999, fontWeight: 700 }}>+25 XP</span>
        </div>
      </div>

      {/* coaching cues to hold in mind */}
      <div style={{ position: 'relative', padding: '40px 24px 0', flex: 1 }}>
        <Eyebrow style={{ marginBottom: 12 }}>HOLD THESE IN MIND</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {d.cues.map((c, i) => (
            <div key={i} style={{ display: 'flex', gap: 14, alignItems: 'center', padding: '13px 0', borderTop: i === 0 ? `1px solid ${MF.line.hairline}` : 'none', borderBottom: `1px solid ${MF.line.hairline}` }}>
              <span style={{ ...TYPE.num, fontSize: 14, color: MF.ink.tertiary, width: 18, fontVariantNumeric: 'normal' }}>{i + 1}</span>
              <span style={{ flex: 1, ...TYPE.callout, color: '#fff', fontWeight: 500 }}>{c}</span>
            </div>
          ))}
        </div>
      </div>

      {/* start */}
      <div style={{ position: 'relative', padding: '14px 24px 36px' }}>
        <FloatingButton hint="SET 1 OF 3">Start set</FloatingButton>
      </div>
    </div>
  );
}

// ─── STATE 2 · ACTIVE SET (timer running) ───────────────────────
function ScrPlayerActive() {
  const d = PLAYER_DRILL;
  const remain = 38, total = 60;       // 0:38 left of 1:00
  const progress = (total - remain) / total;
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      {/* top — set tracker */}
      <div style={{ position: 'relative', padding: '58px 24px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Eyebrow>{d.title.toUpperCase()}</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>WORK</span>
        </div>
        <div style={{ display: 'flex', gap: 7, marginTop: 14 }}>
          {Array.from({ length: d.sets }).map((_, i) => (
            <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: i === 0 ? '#fff' : MF.line.subtle, position: 'relative', overflow: 'hidden' }}>
              {i === 0 && <div style={{ position: 'absolute', inset: 0, width: `${progress * 100}%`, background: '#fff' }}/>}
            </div>
          ))}
        </div>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 8 }}>SET 1 OF {d.sets}</div>
      </div>

      {/* the timer */}
      <div style={{ position: 'relative', flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 36 }}>
        <div style={{ position: 'relative' }}>
          <div style={{ position: 'absolute', inset: -24, borderRadius: '50%', background: 'radial-gradient(circle, rgba(255,255,255,0.08) 0%, rgba(255,255,255,0) 64%)' }}/>
          <PitchRing size={250} stroke={6} progress={progress} value="0:38" label="REMAINING"/>
        </div>
        {/* live coaching cue */}
        <div style={{ textAlign: 'center', padding: '0 36px' }}>
          <Eyebrow style={{ color: MF.ink.tertiary }}>COACHING CUE</Eyebrow>
          <div style={{ ...TYPE.title2, color: '#fff', marginTop: 10, textWrap: 'balance' }}>“{d.cues[0]}”</div>
        </div>
      </div>

      {/* controls — outside the ring */}
      <div style={{ position: 'relative', padding: '0 24px 40px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
        <IconButton size={56} style={{ background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="20" height="20" viewBox="0 0 20 20"><path d="M5 4l11 6-11 6V4z" fill="none" stroke="#fff" strokeWidth="1.4" strokeLinejoin="round"/></svg>
        </IconButton>
        {/* pause — primary */}
        <button style={{ width: 84, height: 84, borderRadius: 42, background: '#fff', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 14px 40px rgba(255,255,255,0.18)' }}>
          <svg width="26" height="26" viewBox="0 0 26 26"><rect x="7" y="5" width="4.5" height="16" rx="1.2" fill="#000"/><rect x="14.5" y="5" width="4.5" height="16" rx="1.2" fill="#000"/></svg>
        </button>
        <IconButton size={56} style={{ background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="18" height="18" viewBox="0 0 18 18"><rect x="4" y="4" width="10" height="10" rx="1.5" fill="#fff"/></svg>
        </IconButton>
      </div>
    </div>
  );
}

// ─── STATE 3 · SET LOGGED → mastery progress ────────────────────
function ScrPlayerLogged() {
  const d = PLAYER_DRILL;
  const passes = 2;           // this set just logged → 2 of 3 toward mastery
  const total = CURRICULUM_RULES.masteryPasses;
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.5, pointerEvents: 'none', backgroundImage: 'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.02) 44px, rgba(255,255,255,0.02) 45px)' }}/>

      <div style={{ position: 'relative', padding: '58px 24px 0', display: 'flex', justifyContent: 'flex-end' }}>
        <IconButton size={36} style={{ background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="10" height="10" viewBox="0 0 10 10"><path d="M1 1l8 8M9 1L1 9" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/></svg>
        </IconButton>
      </div>

      {/* big tick */}
      <div style={{ position: 'relative', padding: '24px 24px 0', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{ width: 96, height: 96, borderRadius: 48, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: '0 14px 44px rgba(255,255,255,0.16)' }}>
          <svg width="44" height="44" viewBox="0 0 44 44"><path d="M12 23l7 7 14-16" stroke="#000" strokeWidth="3.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </div>
        <Eyebrow style={{ marginTop: 24, letterSpacing: 2.4 }}>SET 3 OF 3 · LOGGED</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 12, fontSize: 34, lineHeight: '36px', textAlign: 'center', textWrap: 'balance' }}>{d.title}</div>
        <div style={{ ...TYPE.foot, color: MF.ink.secondary, marginTop: 10, textAlign: 'center' }}>Logged honestly — clean run, no losses.</div>
      </div>

      {/* mastery tracker */}
      <div style={{ position: 'relative', padding: '34px 24px 0', flex: 1 }}>
        <div style={{ padding: 20, borderRadius: 18, border: `1px solid ${MF.line.subtle}`, background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Eyebrow style={{ color: '#fff' }}>DRILL MASTERY</Eyebrow>
            <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{passes} / {total} PASSES</span>
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
            {Array.from({ length: total }).map((_, i) => (
              <div key={i} style={{ flex: 1, height: 10, borderRadius: 5, background: i < passes ? '#fff' : MF.line.subtle }}/>
            ))}
          </div>
          <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 14, lineHeight: '18px' }}>
            One more honest pass to master this drill and tick it on your Level 2 ladder.
          </div>
        </div>

        {/* earned this set */}
        <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
          <div style={{ flex: 1, padding: '14px 16px', borderRadius: 14, background: MF.bg.card, border: `1px solid ${MF.line.hairline}`, textAlign: 'center' }}>
            <div style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>+25</div>
            <Eyebrow style={{ fontSize: 9, marginTop: 4 }}>XP EARNED</Eyebrow>
          </div>
          <div style={{ flex: 1, padding: '14px 16px', borderRadius: 14, background: MF.bg.card, border: `1px solid ${MF.line.hairline}`, textAlign: 'center' }}>
            <div style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>14</div>
            <Eyebrow style={{ fontSize: 9, marginTop: 4 }}>DAY STREAK +1</Eyebrow>
          </div>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '14px 24px 36px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <FloatingButton>Next drill</FloatingButton>
        <GhostButton>Back to level</GhostButton>
      </div>
    </div>
  );
}

Object.assign(window, { PLAYER_DRILL, ScrPlayerReady, ScrPlayerActive, ScrPlayerLogged });
