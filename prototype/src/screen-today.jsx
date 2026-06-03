// MF Elite — Academy · Today (curriculum-driven home)
// Delivers the brief's dashboard: daily motivational quote that changes,
// XP + level summary, day streak + daily goals, and training ideas
// recommended straight from the drills database.

function ScrAcademyToday() {
  const focus = currentFocus();
  const recs = recommendations(3);
  const quote = quoteOfDay();
  const goalsDone = 2, goalsTotal = 3;
  const ringPct = goalsDone / goalsTotal;

  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 140 }}>
      {/* Quiet top bar */}
      <div style={{ padding: '62px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Avatar size={36} initials="P1"/>
        <MFMark size={20}/>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7, padding: '6px 12px', border: `1px solid ${MF.line.subtle}`, borderRadius: 999 }}>
          <StreakGlyph/>
          <span style={{ ...TYPE.micro, color: '#fff' }}>{ACADEMY_PROGRESS.streak}</span>
        </div>
      </div>

      {/* Salutation */}
      <div style={{ padding: '22px 20px 0' }}>
        <Eyebrow>TUE 12 MAR · SEASON 25—26</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 8, fontSize: 38, lineHeight: '40px', letterSpacing: -1.4 }}>
          Good morning,<br/>Player One
        </div>
      </div>

      {/* ── DAILY STANDARD · the quote that changes every day ── */}
      <div style={{ padding: '26px 20px 0' }}>
        <SlashRule/>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 18, letterSpacing: 2 }}>TODAY'S STANDARD</div>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 700, color: '#fff',
          fontSize: 27, lineHeight: '32px', letterSpacing: -0.6, marginTop: 12, textWrap: 'balance',
        }}>
          “{quote}”
        </div>
        <SlashRule style={{ marginTop: 20 }}/>
      </div>

      {/* ── DAILY GOALS + standing ── */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          background: '#0a0a0a', border: `1px solid ${MF.line.hairline}`, borderRadius: 20,
          padding: 18, display: 'flex', alignItems: 'center', gap: 18,
        }}>
          {/* Goal ring */}
          <div style={{ position: 'relative', flexShrink: 0 }}>
            <PitchRing size={92} progress={ringPct} stroke={7} value={`${goalsDone}/${goalsTotal}`} label="GOALS"/>
          </div>
          {/* Standing */}
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <Eyebrow>RANK {ACADEMY_PROGRESS.player.rankNo}</Eyebrow>
              <span style={{ ...TYPE.foot, color: '#fff', fontWeight: 700 }}>{ACADEMY_PROGRESS.player.rankName}</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 8 }}>
              <span style={{ ...TYPE.num, fontSize: 30, lineHeight: '28px', color: '#fff' }}>{ACADEMY_PROGRESS.xp.toLocaleString('en-US')}</span>
              <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>XP</span>
            </div>
            <div style={{ marginTop: 12, display: 'flex', flexDirection: 'column', gap: 7 }}>
              <GoalLine done label="Ball Mastery · 1 drill"/>
              <GoalLine done label="Daily film · watched"/>
              <GoalLine label="Mind · 1 exercise"/>
            </div>
          </div>
        </div>
      </div>

      {/* ── CONTINUE YOUR PATHWAY · today's session ── */}
      {focus && (
        <div style={{ padding: '26px 20px 0' }}>
          <Eyebrow style={{ marginBottom: 12 }}>CONTINUE YOUR PATHWAY</Eyebrow>
          <div style={{ borderRadius: 24, overflow: 'hidden', background: '#0a0a0a', border: `1px solid ${MF.line.hairline}` }}>
            <PhotoPlaceholder height={250} label="TODAY · COACH FILM" style={{ borderRadius: 0, border: 'none' }}>
              <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, rgba(0,0,0,0.4) 0%, rgba(0,0,0,0) 28%, rgba(0,0,0,0) 52%, rgba(0,0,0,0.94) 100%)' }}/>
              <div style={{ position: 'absolute', top: 16, left: 16, display: 'flex', alignItems: 'center', gap: 8 }}>
                <DisciplineMark kind={focus.discipline.mark} size={16}/>
                <span style={{ ...TYPE.micro, color: '#fff' }}>{focus.discipline.name.toUpperCase()} · {focus.category.name.toUpperCase()}</span>
              </div>
              <div style={{ position: 'absolute', top: 16, right: 16, padding: '4px 10px', borderRadius: 999, background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.18)', backdropFilter: 'blur(10px)', ...TYPE.micro, color: '#fff' }}>
                LEVEL {focus.level.no}
              </div>
              <div style={{ position: 'absolute', left: 20, right: 20, bottom: 18 }}>
                <Eyebrow style={{ color: 'rgba(255,255,255,0.65)' }}>LEVEL {focus.level.no} · {focus.level.theme.toUpperCase()}</Eyebrow>
                <div style={{ ...TYPE.display, color: '#fff', marginTop: 6, fontSize: 30, lineHeight: '32px', textWrap: 'balance' }}>{focus.level.name}</div>
                <div style={{ display: 'flex', gap: 12, marginTop: 12 }}>
                  <DotMeta label={`${focus.level.drills.length} DRILLS`}/><Sep/>
                  <DotMeta label="2 / 4 DONE"/><Sep/>
                  <DotMeta label="+25 XP EACH"/>
                </div>
              </div>
            </PhotoPlaceholder>
            <div style={{ padding: 14, display: 'flex', gap: 10, alignItems: 'stretch' }}>
              <PrimaryButton>
                <svg width="14" height="14" viewBox="0 0 14 14" style={{ marginRight: 4 }}><path d="M3 1l9 6-9 6V1z" fill="#000"/></svg>
                Resume level
              </PrimaryButton>
              <IconButton size={56} style={{ flexShrink: 0 }}>
                <svg width="18" height="18" viewBox="0 0 18 18"><path d="M3 13.5L9 9l6 4.5V3H3v10.5z" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinejoin="round"/></svg>
              </IconButton>
            </div>
          </div>
        </div>
      )}

      {/* ── RECOMMENDED · training ideas from the drills database ── */}
      <div style={{ padding: '30px 0 0' }}>
        <div style={{ padding: '0 20px 14px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>RECOMMENDED FOR YOU</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>FROM {curriculumTotals().drills} DRILLS</span>
        </div>
        {recs.map((r, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 14, padding: '14px 20px',
            borderTop: `1px solid ${MF.line.hairline}`,
            borderBottom: i === recs.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
          }}>
            <div style={{ width: 44, height: 44, flexShrink: 0, borderRadius: 12, border: `1px solid ${MF.line.subtle}`, background: MF.bg.card, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <DisciplineMark kind={r.discipline.mark} size={20}/>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.drill.t}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
                <span style={{ ...TYPE.micro, color: '#fff' }}>{r.discipline.name.toUpperCase()}</span>
                <Sep/>
                <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{r.reason.toUpperCase()}</span>
              </div>
            </div>
            <svg width="9" height="14" viewBox="0 0 9 14" style={{ flexShrink: 0 }}><path d="M2 1l5 6-5 6" stroke="rgba(255,255,255,0.55)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
        ))}
      </div>
    </div>
  );
}

// Small flame-free streak mark (a rising bar trio — on-brand, no emoji)
function StreakGlyph() {
  return (
    <svg width="11" height="11" viewBox="0 0 11 11">
      <rect x="0" y="6" width="2.4" height="5" fill="#fff"/>
      <rect x="4.3" y="3" width="2.4" height="8" fill="#fff"/>
      <rect x="8.6" y="0" width="2.4" height="11" fill="#fff"/>
    </svg>
  );
}

function GoalLine({ label, done }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
      <span style={{
        width: 16, height: 16, borderRadius: 5, flexShrink: 0,
        background: done ? '#fff' : 'transparent',
        border: `1px solid ${done ? '#fff' : MF.line.subtle}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        {done && <svg width="9" height="9" viewBox="0 0 9 9"><path d="M1.5 4.5l2 2L7.5 2" stroke="#000" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
      </span>
      <span style={{ ...TYPE.foot, color: done ? MF.ink.secondary : '#fff', fontWeight: 500, textDecoration: done ? 'none' : 'none' }}>{label}</span>
    </div>
  );
}

Object.assign(window, { ScrAcademyToday, StreakGlyph, GoalLine });
