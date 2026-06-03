// MF Elite — Academy · Progression pathway + Certifications gallery
// How a player moves through the academy over months and years.

// Academy rank ladder — derived from the single shared MF_RANKS ladder.
// State (done / current / next / locked) is computed from live XP.
const ACADEMY_RANKS = MF_RANKS.map((r) => {
  const isCurrent = mfRank(MF_XP).earn === r.earn;
  const nx = mfNextRank(MF_XP);
  const isNext = nx && nx.earn === r.earn;
  let state = 'locked';
  if (r.invite) state = 'invite';
  else if (isCurrent) state = 'current';
  else if (isNext) state = 'next';
  else if (MF_XP >= r.cap) state = 'done';
  return { no: r.no, name: r.name, xp: r.cap, when: r.when, state, note: r.note };
});

function ScrAcademyProgress() {
  const xp = ACADEMY_PROGRESS.xp;
  const current = ACADEMY_RANKS.find((r) => r.state === 'current');
  const next = ACADEMY_RANKS.find((r) => r.state === 'next');
  const toNext = next.xp - xp;
  const certs = allCertifications();
  const earnedCerts = certs.filter((c) => c.earned).length;
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between' }}>
        <Eyebrow>ACADEMY PROGRESSION</Eyebrow>
        <Eyebrow>SINCE SEP 2025</Eyebrow>
      </div>

      {/* Standing headline */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 18 }}>
          <Monogram size={104} initials={current.no} kit={ACADEMY_PROGRESS.player.kit}/>
          <div style={{ flex: 1, minWidth: 0 }}>
            <Eyebrow>RANK · {current.no}</Eyebrow>
            <div style={{ ...TYPE.hero, color: '#fff', marginTop: 6, fontSize: 42, lineHeight: '42px' }}>{current.name}</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 10 }}>
              <span style={{ ...TYPE.num, fontSize: 24, color: '#fff' }}>{xp.toLocaleString('en-US')}</span>
              <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>XP</span>
            </div>
          </div>
        </div>
      </div>

      {/* Next rank progress */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 18, background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
            <Eyebrow style={{ color: '#fff' }}>TO RANK {next.no} · {next.name.toUpperCase()}</Eyebrow>
            <span style={{ ...TYPE.micro, color: '#fff' }}>{toNext.toLocaleString('en-US')} XP TO GO</span>
          </div>
          <div style={{ marginTop: 10, height: 4, background: MF.line.subtle, borderRadius: 3, overflow: 'hidden' }}>
            <div style={{ width: `${Math.round((xp / next.xp) * 100)}%`, height: '100%', background: '#fff' }}/>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, ...TYPE.micro, color: MF.ink.tertiary }}>
            <span>{current.name}</span><span>{next.when}</span>
          </div>
        </div>
      </div>

      {/* The pathway — a vertical multi-year timeline */}
      <div style={{ padding: '30px 0 0' }}>
        <Eyebrow style={{ padding: '0 20px 4px' }}>THE PATHWAY · MONTHS & YEARS</Eyebrow>
        <div style={{ padding: '14px 20px 0' }}>
          {ACADEMY_RANKS.map((r, i) => <RankNode key={r.no} r={r} last={i === ACADEMY_RANKS.length - 1}/>)}
        </div>
      </div>

      {/* Mastery overview across disciplines */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Eyebrow>SKILL MASTERY</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{earnedCerts} / {certs.length} CERTIFIED</span>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {CURRICULUM.map((dsc) => {
            const prog = disciplineProgress(dsc);
            return (
              <div key={dsc.id} style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
                <DisciplineMark kind={dsc.mark} size={22}/>
                <span style={{ width: 96, ...TYPE.foot, color: '#fff', fontWeight: 600, flexShrink: 0 }}>{dsc.name}</span>
                <div style={{ flex: 1, height: 6, background: MF.line.subtle, borderRadius: 3, overflow: 'hidden' }}>
                  <div style={{ width: `${prog.pct}%`, height: '100%', background: '#fff' }}/>
                </div>
                <span style={{ ...TYPE.micro, color: MF.ink.tertiary, width: 36, textAlign: 'right', flexShrink: 0 }}>{prog.mastered}/{prog.total}</span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Development milestones */}
      <div style={{ padding: '28px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>DEVELOPMENT MILESTONES</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {[
            ['14', 'Day streak · personal best', 'Active now'],
            ['3', 'Skill certifications earned', 'Ball Mastery in progress'],
            ['148', 'Drills logged this season', 'Across 4 pathways'],
            ['86%', 'Weekly consistency · 12 weeks', 'Sessions completed vs planned'],
          ].map(([n, t, m], i, arr) => (
            <div key={i} style={{ display: 'flex', gap: 16, alignItems: 'center', padding: '14px 0', borderTop: `1px solid ${MF.line.hairline}`, borderBottom: i === arr.length - 1 ? `1px solid ${MF.line.hairline}` : 'none' }}>
              <span style={{ width: 56, ...TYPE.num, fontSize: 26, color: '#fff', flexShrink: 0 }}>{n}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>{t}</div>
                <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 3 }}>{m}</div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function RankNode({ r, last }) {
  const done = r.state === 'done';
  const current = r.state === 'current';
  const invite = r.state === 'invite';
  const dim = r.state === 'locked' || invite;
  return (
    <div style={{ display: 'flex', gap: 16, opacity: dim ? 0.62 : 1 }}>
      {/* Rail + node */}
      <div style={{ width: 40, flexShrink: 0, display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
        <div style={{
          width: 40, height: 40, borderRadius: 20, flexShrink: 0,
          background: done || current ? '#fff' : 'transparent',
          border: `1.5px solid ${done || current ? '#fff' : MF.line.subtle}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <span style={{ ...TYPE.num, fontSize: 14, color: done || current ? '#000' : MF.ink.tertiary, fontVariantNumeric: 'normal' }}>{r.no}</span>
        </div>
        {!last && <div style={{ width: 1.5, flex: 1, minHeight: 34, background: done ? '#fff' : MF.line.subtle, marginTop: 2, marginBottom: 2 }}/>}
      </div>
      {/* Content */}
      <div style={{ flex: 1, minWidth: 0, paddingBottom: last ? 0 : 18 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          <span style={{ ...TYPE.title3, color: '#fff', fontWeight: 700 }}>{r.name}</span>
          {current && <span style={{ ...TYPE.micro, color: '#000', background: '#fff', padding: '2px 7px', borderRadius: 4, fontWeight: 700 }}>YOU ARE HERE</span>}
          {done && <svg width="14" height="14" viewBox="0 0 14 14"><path d="M3 7.5l3 3 5-6" stroke="#fff" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
          {invite && <span style={{ ...TYPE.micro, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '2px 7px', borderRadius: 4 }}>INVITE</span>}
        </div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 4 }}>{r.note}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 7 }}>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{r.when}</span>
          {r.xp != null && <><Sep/><span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{r.xp.toLocaleString('en-US')} XP</span></>}
        </div>
      </div>
    </div>
  );
}

// ─── CERTIFICATIONS GALLERY ─────────────────────────────────────
function ScrCertifications() {
  const certs = allCertifications();
  const earned = certs.filter((c) => c.earned).length;
  const inProg = certs.filter((c) => c.inProgress).length;
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between' }}>
        <Eyebrow>SKILL CERTIFICATIONS</Eyebrow>
        <Eyebrow>{String(earned).padStart(2, '0')} / {certs.length} EARNED</Eyebrow>
      </div>
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{ ...TYPE.hero, color: '#fff', fontSize: 38, lineHeight: '42px' }}>Earned<br/>by mastery</div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 10, maxWidth: 330 }}>
          One certification per category — awarded the moment every mastery level is complete and signed off by your coach. {inProg} in progress now.
        </div>
      </div>

      {/* Grouped by discipline */}
      {CURRICULUM.map((dsc) => {
        const group = certs.filter((c) => c.disciplineId === dsc.id);
        const prog = disciplineProgress(dsc);
        return (
          <div key={dsc.id} style={{ padding: '26px 20px 0' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 14 }}>
              <DisciplineMark kind={dsc.mark} size={20}/>
              <Eyebrow style={{ color: '#fff' }}>{dsc.no} · {dsc.name.toUpperCase()}</Eyebrow>
              <div style={{ flex: 1, height: 1, background: MF.line.hairline }}/>
              <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{prog.mastered}/{prog.total}</span>
            </div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
              {group.map((c) => <CertTile key={c.catId} cert={c}/>)}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function CertTile({ cert }) {
  const earned = cert.earned;
  return (
    <div style={{
      borderRadius: 16, overflow: 'hidden', border: `1px solid ${MF.line.hairline}`,
      background: MF.bg.card, opacity: earned || cert.inProgress ? 1 : 0.66,
      display: 'flex', flexDirection: 'column',
    }}>
      <div style={{ height: 92, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'radial-gradient(120% 90% at 50% 20%, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0) 60%), linear-gradient(160deg, #161616 0%, #050505 100%)' }}>
        <CertSeal earned={earned} size={54}/>
        <div style={{ position: 'absolute', top: 8, right: 8, ...TYPE.micro, color: earned ? '#000' : MF.ink.tertiary, background: earned ? '#fff' : 'transparent', border: earned ? 'none' : `1px solid ${MF.line.subtle}`, padding: '2px 6px', borderRadius: 4, fontWeight: 700 }}>
          {earned ? 'EARNED' : cert.inProgress ? `${cert.done}/${cert.levels}` : 'LOCKED'}
        </div>
      </div>
      <div style={{ padding: '11px 13px 13px' }}>
        <div style={{ ...TYPE.foot, color: '#fff', fontWeight: 700 }}>{cert.name}</div>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>
          {earned ? 'Coach-signed' : cert.inProgress ? `${cert.levels - cert.done} levels to go` : `${cert.levels} levels`}
        </div>
      </div>
    </div>
  );
}

Object.assign(window, {
  ACADEMY_RANKS, ScrAcademyProgress, RankNode, ScrCertifications, CertTile,
});
