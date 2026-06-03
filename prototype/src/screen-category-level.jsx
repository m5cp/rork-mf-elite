// MF Elite — Academy · Category (mastery levels) + Level (drill list)

// ─── CATEGORY · the mastery-level ladder (Ball Mastery exemplar) ──
// Shows the Skill Certification this category earns, and the levels
// stacked as a ladder the player climbs over weeks.
function ScrCategory() {
  const { discipline: dsc, category: cat } = categoryById('ball-mastery');
  const p = ACADEMY_PROGRESS.categories[cat.id];
  const pct = catProgress(cat);
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0' }}>
        <Crumb>{dsc.name} · Pathway {dsc.no}</Crumb>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 12, marginTop: 16 }}>
          <div style={{ flex: 1 }}>
            <Eyebrow>CATEGORY {cat.letter}</Eyebrow>
            <div style={{ ...TYPE.hero, color: '#fff', marginTop: 6, fontSize: 38, lineHeight: '40px' }}>{cat.name}</div>
            <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 10 }}>{cat.focus}.</div>
          </div>
          <span style={{ ...TYPE.num, fontSize: 64, lineHeight: '56px', color: MF.ink.tertiary, fontStyle: 'italic', fontVariantNumeric: 'normal', flexShrink: 0 }}>{cat.letter}</span>
        </div>
      </div>

      {/* Skill certification banner */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ borderRadius: 18, overflow: 'hidden', border: `1px solid ${MF.line.subtle}` }}>
          <div style={{ padding: '16px 18px', display: 'flex', alignItems: 'center', gap: 14, background: 'rgba(255,255,255,0.02)' }}>
            <CertSeal earned={false} size={48}/>
            <div style={{ flex: 1, minWidth: 0 }}>
              <Eyebrow style={{ color: '#fff' }}>SKILL CERTIFICATION</Eyebrow>
              <div style={{ ...TYPE.title3, color: '#fff', marginTop: 3 }}>{cat.cert} Certified</div>
            </div>
            <div style={{ textAlign: 'right' }}>
              <div style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>{p.done}<span style={{ color: MF.ink.tertiary }}>/{cat.levels.length}</span></div>
              <Eyebrow style={{ fontSize: 9 }}>LEVELS</Eyebrow>
            </div>
          </div>
          <div style={{ height: 3, background: MF.line.subtle }}>
            <div style={{ width: `${pct}%`, height: '100%', background: '#fff' }}/>
          </div>
          <div style={{ padding: '12px 18px', ...TYPE.foot, color: MF.ink.tertiary }}>
            Master all {cat.levels.length} levels to earn the certification · +{CURRICULUM_RULES.xpCategoryCert} XP and a coach signature.
          </div>
        </div>
      </div>

      {/* Mastery level ladder */}
      <div style={{ padding: '28px 0 0' }}>
        <div style={{ padding: '0 20px 6px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>MASTERY LEVELS</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{totalDrills(cat)} DRILLS TOTAL</span>
        </div>
        {cat.levels.map((lv, i) => {
          const state = lv.no <= p.done ? 'done' : lv.no === p.current ? 'current' : 'upcoming';
          const free = lv.no <= CURRICULUM_RULES.freeLevels;
          return <LevelLadderRow key={lv.no} lv={lv} state={state} free={free} last={i === cat.levels.length - 1}/>;
        })}
      </div>
    </div>
  );
}

// Abstract certification seal — concentric ring + tick/letter, no illustration
function CertSeal({ earned, size = 48, label }) {
  const c = earned ? '#000' : '#fff';
  const bg = earned ? '#fff' : 'transparent';
  return (
    <div style={{
      width: size, height: size, borderRadius: size / 2, flexShrink: 0,
      background: bg, border: earned ? 'none' : `1px solid ${MF.line.subtle}`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <svg width={size * 0.62} height={size * 0.62} viewBox="0 0 30 30">
        <circle cx="15" cy="15" r="11" stroke={c} strokeWidth="1" fill="none"/>
        {Array.from({ length: 24 }).map((_, i) => {
          const a = (i / 24) * Math.PI * 2;
          return <line key={i} x1={15 + 11 * Math.cos(a)} y1={15 + 11 * Math.sin(a)} x2={15 + 13 * Math.cos(a)} y2={15 + 13 * Math.sin(a)} stroke={c} strokeWidth="0.8" opacity="0.6"/>;
        })}
        {earned
          ? <path d="M10 15l3.5 3.5L21 11" stroke={c} strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
          : (label ? <text x="15" y="19" fill={c} fontFamily="-apple-system, system-ui" fontWeight="800" fontSize="11" textAnchor="middle">{label}</text>
                   : <circle cx="15" cy="15" r="4" stroke={c} strokeWidth="1.2" fill="none" opacity="0.5"/>)}
      </svg>
    </div>
  );
}

function LevelLadderRow({ lv, state, free, last }) {
  const done = state === 'done';
  const current = state === 'current';
  const locked = state === 'upcoming' && !free;
  const xp = lv.drills.length * CURRICULUM_RULES.xpPerDrill + CURRICULUM_RULES.xpLevelBonus;
  return (
    <div style={{
      position: 'relative', padding: '18px 20px',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
      background: current ? '#0a0a0a' : 'transparent',
      opacity: locked ? 0.55 : 1,
      display: 'flex', gap: 16, alignItems: 'flex-start',
    }}>
      {/* Level numeral node */}
      <div style={{ width: 46, flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
        <div style={{
          width: 40, height: 40, borderRadius: 20,
          background: done ? '#fff' : 'transparent',
          border: `1.5px solid ${done ? '#fff' : current ? '#fff' : MF.line.subtle}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          {done
            ? <svg width="18" height="18" viewBox="0 0 18 18"><path d="M4 9.5l3.5 3.5L14 5" stroke="#000" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
            : <span style={{ ...TYPE.num, fontSize: 18, color: current ? '#fff' : MF.ink.tertiary, fontVariantNumeric: 'normal' }}>{lv.no}</span>}
        </div>
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <Eyebrow>LEVEL {lv.no}</Eyebrow>
          {current && <span style={{ ...TYPE.micro, color: '#000', background: '#fff', padding: '2px 7px', borderRadius: 4, fontWeight: 700 }}>IN PROGRESS</span>}
          {done && <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>MASTERED</span>}
          {locked && <span style={{ ...TYPE.micro, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '2px 7px', borderRadius: 4 }}>MEMBERS</span>}
          {free && !done && <span style={{ ...TYPE.micro, color: MF.ink.tertiary, border: `1px solid ${MF.line.subtle}`, padding: '2px 7px', borderRadius: 4 }}>FREE</span>}
        </div>
        <div style={{ ...TYPE.title3, color: '#fff', marginTop: 6 }}>{lv.name}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 8 }}>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{lv.drills.length} DRILLS</span>
          <Sep/>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>+{xp} XP</span>
        </div>
        {current && (
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 12 }}>
            <div style={{ flex: 1, height: 2, background: MF.line.subtle, borderRadius: 1, overflow: 'hidden' }}>
              <div style={{ width: '50%', height: '100%', background: '#fff' }}/>
            </div>
            <span style={{ ...TYPE.micro, color: '#fff' }}>02 / {String(lv.drills.length).padStart(2, '0')}</span>
          </div>
        )}
      </div>
      <div style={{ width: 22, flexShrink: 0, display: 'flex', justifyContent: 'flex-end', paddingTop: 10 }}>
        {locked
          ? <svg width="13" height="15" viewBox="0 0 13 15"><path d="M3 7V5a3.5 3.5 0 017 0v2" stroke="rgba(255,255,255,0.6)" strokeWidth="1.3" fill="none"/><rect x="2" y="7" width="9" height="7" rx="1.4" stroke="rgba(255,255,255,0.6)" strokeWidth="1.3" fill="none"/></svg>
          : <svg width="9" height="14" viewBox="0 0 9 14"><path d="M2 1l5 6-5 6" stroke="rgba(255,255,255,0.55)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
      </div>
    </div>
  );
}

// ─── LEVEL · scalable drill list inside one mastery level ────────
// Exemplar: Ball Mastery · Level 4 (current). Each drill is one piece
// of content; the list renders any number of them.
function ScrLevel() {
  const { discipline: dsc, category: cat } = categoryById('ball-mastery');
  const lv = cat.levels[3]; // Level 4 · Weak Foot & Coordination
  const completed = [true, true, false, false]; // demo state
  const doneCount = completed.filter(Boolean).length;
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 120 }}>
      <div style={{ padding: '60px 20px 0' }}>
        <Crumb>{cat.name}</Crumb>
        <Eyebrow style={{ marginTop: 16 }}>{dsc.name.toUpperCase()} · {cat.name.toUpperCase()}</Eyebrow>
        <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginTop: 8 }}>
          <span style={{ ...TYPE.num, fontSize: 56, lineHeight: '50px', color: '#fff', fontStyle: 'italic', fontVariantNumeric: 'normal' }}>{lv.no}</span>
          <div style={{ ...TYPE.title1, color: '#fff', lineHeight: '28px' }}>{lv.name}</div>
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12 }}>
          Log each drill {CURRICULUM_RULES.masteryPasses}× to master the level. The level mark switches on when all drills are passed.
        </div>
      </div>

      {/* Level progress strip */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{
          background: MF.bg.elevated, borderRadius: 18, padding: '16px 18px',
          border: `1px solid ${MF.line.hairline}`,
          display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)',
        }}>
          {[['DRILLS', `${doneCount}/${lv.drills.length}`], ['THEME', lv.theme], ['EARNS', `+${lv.drills.length * CURRICULUM_RULES.xpPerDrill + CURRICULUM_RULES.xpLevelBonus}`]].map(([l, v], i) => (
            <div key={l} style={{
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
              borderRight: i < 2 ? `1px solid ${MF.line.hairline}` : 'none',
            }}>
              <span style={{ ...TYPE.num, fontSize: 18, color: '#fff' }}>{v}</span>
              <Eyebrow style={{ fontSize: 9 }}>{l}</Eyebrow>
            </div>
          ))}
        </div>
      </div>

      {/* Drill list */}
      <div style={{ padding: '26px 0 0' }}>
        <div style={{ padding: '0 20px 8px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>DRILLS · {String(lv.drills.length).padStart(2, '0')}</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{dsc.media === 'video' ? 'WATCH & LEARN' : 'TRAIN & LOG'}</span>
        </div>
        {lv.drills.map((dr, i) => (
          <DrillRow key={i} dr={dr} index={i + 1} done={completed[i]} current={i === doneCount} media={dsc.media} last={i === lv.drills.length - 1}/>
        ))}
      </div>

      {/* Footer note */}
      <div style={{ padding: '24px 20px 0', textAlign: 'center' }}>
        <Eyebrow style={{ color: MF.ink.quaternary }}>DRILLS SYNCED FROM SUPABASE · COACH CAN ADD MORE ANY TIME</Eyebrow>
      </div>
    </div>
  );
}

function DrillRow({ dr, index, done, current, media, last }) {
  const passes = done ? 3 : current ? 1 : 0;
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 14,
      padding: '14px 20px',
      background: current ? '#0a0a0a' : 'transparent',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
    }}>
      {/* Thumb */}
      <div style={{
        width: 56, height: 56, flexShrink: 0, borderRadius: 12, overflow: 'hidden',
        background: 'linear-gradient(160deg, #1a1a1a 0%, #0a0a0a 100%)',
        border: `1px solid ${MF.line.subtle}`, position: 'relative',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <svg width="56" height="56" viewBox="0 0 56 56" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
          <polygon points="0,0 18,0 12,56 0,56" fill="rgba(255,255,255,0.05)"/>
        </svg>
        {media === 'video'
          ? <svg width="16" height="16" viewBox="0 0 16 16" style={{ position: 'relative' }}><path d="M4 2l9 6-9 6V2z" fill="#fff" opacity="0.9"/></svg>
          : <svg width="14" height="14" viewBox="0 0 14 14" style={{ position: 'relative' }}><path d="M3 1l9 6-9 6V1z" fill="#fff" opacity="0.85"/></svg>}
      </div>
      {/* Text */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{dr.t}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
          <span style={{ ...TYPE.micro, color: '#fff', letterSpacing: 1.2 }}>{dr.f.toUpperCase()}</span>
        </div>
        {/* mastery passes dots */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 7 }}>
          {Array.from({ length: 3 }).map((_, i) => (
            <span key={i} style={{
              width: 14, height: 4, borderRadius: 2,
              background: i < passes ? '#fff' : MF.line.subtle,
            }}/>
          ))}
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary, marginLeft: 4 }}>{passes}/3 LOGGED</span>
        </div>
      </div>
      {/* State */}
      {done
        ? <div style={{ width: 28, height: 28, borderRadius: 14, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 7.5l3 3 5-6" stroke="#000" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
        : <svg width="9" height="14" viewBox="0 0 9 14" style={{ flexShrink: 0 }}><path d="M2 1l5 6-5 6" stroke="rgba(255,255,255,0.55)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
    </div>
  );
}

Object.assign(window, {
  ScrCategory, CertSeal, LevelLadderRow, ScrLevel, DrillRow,
});
