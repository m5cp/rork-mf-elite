// MF Elite — Academy · Progression moments (the payoff screens)
// These are the emotional peaks of the curriculum: the instant a level
// is mastered, and the instant a skill is certified. Full-bleed, quiet,
// premium — the academy noticing your work.

// Large certification seal — concentric guilloché + filled disc + tick.
function SealLarge({ size = 184, no = '04' }) {
  const c = size / 2;
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      {/* breathing glow */}
      <div style={{
        position: 'absolute', inset: -30, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(255,255,255,0.16) 0%, rgba(255,255,255,0) 62%)',
        animation: 'mfBreath 3.4s ease-in-out infinite',
      }}/>
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`} style={{ position: 'relative' }}>
        {/* outer ring */}
        <circle cx={c} cy={c} r={c - 6} stroke="rgba(255,255,255,0.5)" strokeWidth="1" fill="none"/>
        {/* tick guilloché */}
        {Array.from({ length: 60 }).map((_, i) => {
          const a = (i / 60) * Math.PI * 2;
          const r1 = c - 6, r2 = c - 12;
          return <line key={i} x1={c + r1 * Math.cos(a)} y1={c + r1 * Math.sin(a)} x2={c + r2 * Math.cos(a)} y2={c + r2 * Math.sin(a)} stroke="rgba(255,255,255,0.4)" strokeWidth="0.8"/>;
        })}
        {/* dashed inner ring */}
        <circle cx={c} cy={c} r={c - 22} stroke="rgba(255,255,255,0.32)" strokeWidth="0.8" fill="none" strokeDasharray="2 3"/>
        {/* filled disc */}
        <circle cx={c} cy={c} r={c - 38} fill="#fff"/>
        {/* check */}
        <path d={`M${c - 22} ${c} l14 14 l28 -30`} stroke="#000" strokeWidth="3.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
      <div style={{
        position: 'absolute', bottom: -2, left: '50%', transform: 'translateX(-50%)',
        ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 2, whiteSpace: 'nowrap',
      }}>CERTIFICATE Nº {no}</div>
    </div>
  );
}

// ─── CERTIFICATION AWARD — the flagship moment ──────────────────
function ScrCertAward() {
  const { category: cat } = categoryById('first-touch'); // exemplar just-earned cert
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.5, pointerEvents: 'none', backgroundImage: 'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.022) 44px, rgba(255,255,255,0.022) 45px)' }}/>
      <div style={{ position: 'absolute', inset: 0, pointerEvents: 'none', background: 'radial-gradient(150% 60% at 50% 8%, rgba(255,255,255,0.07) 0%, rgba(255,255,255,0) 55%)' }}/>

      {/* top bar */}
      <div style={{ position: 'relative', padding: '58px 24px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <MFMark size={22}/>
          <Eyebrow>ACADEMY · CERTIFICATION</Eyebrow>
        </div>
        <IconButton style={{ width: 32, height: 32, borderRadius: 16, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="10" height="10" viewBox="0 0 10 10"><path d="M1 1l8 8M9 1L1 9" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/></svg>
        </IconButton>
      </div>

      {/* Seal */}
      <div style={{ position: 'relative', display: 'flex', justifyContent: 'center', marginTop: 44 }}>
        <SealLarge size={186} no="04"/>
      </div>

      {/* Headline */}
      <div style={{ position: 'relative', padding: '40px 24px 0', textAlign: 'center', flex: 1 }}>
        <Eyebrow style={{ letterSpacing: 2.4 }}>SKILL CERTIFIED · TECHNICAL</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 12, fontSize: 40, lineHeight: '42px' }}>
          {cat.cert}<br/>Certified
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 14, maxWidth: 320, marginLeft: 'auto', marginRight: 'auto', lineHeight: '23px' }}>
          You mastered all {cat.levels.length} levels. Coach Matteo has signed off — this certification is on your dossier and your parents' report.
        </div>

        {/* XP + signature row */}
        <div style={{ display: 'flex', gap: 10, justifyContent: 'center', marginTop: 22 }}>
          <span style={{ ...TYPE.foot, color: '#000', background: '#fff', padding: '8px 14px', borderRadius: 999, fontWeight: 700 }}>+{CURRICULUM_RULES.xpCategoryCert} XP</span>
          <span style={{ ...TYPE.foot, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '8px 14px', borderRadius: 999, fontWeight: 600 }}>Coach-signed</span>
        </div>
      </div>

      {/* CTAs */}
      <div style={{ position: 'relative', padding: '14px 24px 36px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <FloatingButton>Share certificate</FloatingButton>
        <GhostButton>Continue training</GhostButton>
      </div>
    </div>
  );
}

// ─── LEVEL MASTERED — the frequent payoff ───────────────────────
function ScrLevelMastered() {
  const { discipline: dsc, category: cat } = categoryById('ball-mastery');
  const lv = cat.levels[2]; // Level 3 just mastered
  const p = ACADEMY_PROGRESS.categories[cat.id];
  const certPct = Math.round((3 / cat.levels.length) * 100);
  const xp = lv.drills.length * CURRICULUM_RULES.xpPerDrill + CURRICULUM_RULES.xpLevelBonus;
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.5, pointerEvents: 'none', backgroundImage: 'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.022) 44px, rgba(255,255,255,0.022) 45px)' }}/>

      <div style={{ position: 'relative', padding: '58px 24px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <DisciplineMark kind={dsc.mark} size={20}/>
          <Eyebrow>{dsc.name.toUpperCase()} · {cat.name.toUpperCase()}</Eyebrow>
        </div>
        <IconButton style={{ width: 32, height: 32, borderRadius: 16, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="10" height="10" viewBox="0 0 10 10"><path d="M1 1l8 8M9 1L1 9" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/></svg>
        </IconButton>
      </div>

      {/* Big numeral */}
      <div style={{ position: 'relative', padding: '40px 24px 0' }}>
        <div style={{ ...TYPE.num, fontSize: 188, lineHeight: '160px', color: '#fff', fontVariantNumeric: 'normal', letterSpacing: -8, fontStyle: 'italic' }}>{lv.no}</div>
        <Eyebrow style={{ marginTop: 8, letterSpacing: 2.2 }}>LEVEL {lv.no} · MASTERED</Eyebrow>
      </div>

      <div style={{ position: 'relative', padding: '26px 24px 0', flex: 1 }}>
        <div style={{ ...TYPE.hero, color: '#fff', fontSize: 36, lineHeight: '40px' }}>{lv.name}</div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12, maxWidth: 320, lineHeight: '23px' }}>
          Every drill logged three times and passed. That's {lv.no} of {cat.levels.length} levels toward your {cat.cert} certification.
        </div>

        {/* Cert progress */}
        <div style={{ marginTop: 22, padding: 16, border: `1px solid ${MF.line.subtle}`, borderRadius: 16, background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <Eyebrow style={{ color: '#fff' }}>{cat.cert.toUpperCase()} CERTIFICATION</Eyebrow>
            <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>3 / {cat.levels.length} LEVELS</span>
          </div>
          <div style={{ marginTop: 10, height: 4, background: MF.line.subtle, borderRadius: 3, overflow: 'hidden' }}>
            <div style={{ width: `${certPct}%`, height: '100%', background: '#fff' }}/>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 10, marginTop: 16 }}>
          <span style={{ ...TYPE.foot, color: '#000', background: '#fff', padding: '8px 14px', borderRadius: 999, fontWeight: 700 }}>+{xp} XP</span>
          <span style={{ ...TYPE.foot, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '8px 14px', borderRadius: 999, fontWeight: 600 }}>Level {lv.no + 1} unlocked</span>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '14px 24px 36px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <FloatingButton>Start Level {lv.no + 1}</FloatingButton>
        <GhostButton>Back to Ball Mastery</GhostButton>
      </div>
    </div>
  );
}

Object.assign(window, { SealLarge, ScrCertAward, ScrLevelMastered });
