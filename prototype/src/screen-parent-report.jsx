// MF Elite — Academy · Parent progress report + shareable report card
// The cheque-writer's view: development, consistency, discipline,
// accountability, growth — communicated plainly and proudly.

function ScrParentReport() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 1L3 7l6 6" stroke="#fff" strokeWidth="1.5" fill="none"/></svg>
        </IconButton>
        <Eyebrow>FOR PARENTS</Eyebrow>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 1v9m0-9L4 4m3-3l3 3M2 12h10" stroke="#fff" strokeWidth="1.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </IconButton>
      </div>

      {/* Masthead */}
      <div style={{ padding: '22px 20px 0' }}>
        <Eyebrow>MONTHLY REPORT · MARCH 2026</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 10, fontSize: 38, lineHeight: '42px' }}>
          Player One<br/>is developing
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12, lineHeight: '23px' }}>
          A plain-language summary of your child's month at the academy — what they trained,
          how consistently, and what they've earned.
        </div>
      </div>

      {/* Five pillars */}
      <div style={{ padding: '26px 20px 0' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          <PillarCard label="CONSISTENCY" value="86%" sub="19 of 22 planned sessions"/>
          <PillarCard label="DISCIPLINE" value="14" sub="Day streak · trained alone"/>
          <PillarCard label="ACCOUNTABILITY" value="41" sub="Sessions logged honestly"/>
          <PillarCard label="GROWTH" value="+3" sub="Skill certifications this term"/>
        </div>
      </div>

      {/* Development narrative */}
      <div style={{ padding: '28px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>DEVELOPMENT · THIS MONTH</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
          <ValueLine>Mastered Ball Mastery Levels 1–3 — moving at a strong pace.</ValueLine>
          <ValueLine>First Touch certification is two levels away.</ValueLine>
          <ValueLine>Began the Psychological pathway — discipline & focus.</ValueLine>
        </div>
      </div>

      {/* Consistency calendar — months of attendance */}
      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Eyebrow>ATTENDANCE · LAST 8 WEEKS</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>● TRAINED</span>
        </div>
        <div style={{ padding: 16, borderRadius: 16, background: MF.bg.card, border: `1px solid ${MF.line.hairline}` }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 7 }}>
            {Array.from({ length: 56 }).map((_, i) => {
              const trained = [0, 1, 2, 4, 5, 7, 8, 9, 11, 12, 14, 15, 16, 18, 19, 21, 22, 23, 25, 26, 28, 29, 30, 32, 33, 35, 36, 37, 39, 40, 42, 43, 44, 46, 47, 49, 50, 51, 53, 54, 55].includes(i);
              return <div key={i} style={{ aspectRatio: '1', borderRadius: 4, background: trained ? '#fff' : MF.bg.raised, border: `1px solid ${trained ? '#fff' : MF.line.hairline}` }}/>;
            })}
          </div>
          <Hairline style={{ margin: '14px 0' }}/>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <SmallStat label="SESSIONS" value="41"/>
            <SmallStat label="MINUTES" value="1,180" mid/>
            <SmallStat label="MISSED" value="7"/>
          </div>
        </div>
      </div>

      {/* Coach note */}
      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 18, background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <Avatar size={40} initials="MF"/>
            <div>
              <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700 }}>A note from Coach Matteo</div>
              <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>HEAD COACH · MARCH</div>
            </div>
          </div>
          <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 14, lineHeight: '23px', fontStyle: 'italic' }}>
            “Player One is showing real discipline — training on the days most kids skip. The weak-foot
            work is paying off. Next month we push First Touch toward certification.”
          </div>
        </div>
      </div>

      <div style={{ padding: '26px 20px 0' }}>
        <PrimaryButton>View academy report card</PrimaryButton>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, textAlign: 'center', marginTop: 12 }}>
          Sent to parents on the 1st of every month.
        </div>
      </div>
    </div>
  );
}

function PillarCard({ label, value, sub }) {
  return (
    <div style={{ padding: '16px 16px', borderRadius: 16, background: MF.bg.card, border: `1px solid ${MF.line.hairline}` }}>
      <Eyebrow style={{ fontSize: 9 }}>{label}</Eyebrow>
      <div style={{ ...TYPE.num, fontSize: 34, lineHeight: '34px', color: '#fff', marginTop: 10 }}>{value}</div>
      <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 8, lineHeight: '13px' }}>{sub}</div>
    </div>
  );
}

// ─── SHAREABLE REPORT CARD — a formal monthly credential ────────
function ScrReportCard() {
  const certs = allCertifications();
  const earned = certs.filter((c) => c.earned);
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 40, position: 'relative', overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.4, pointerEvents: 'none', backgroundImage: 'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.022) 44px, rgba(255,255,255,0.022) 45px)' }}/>

      <div style={{ position: 'relative', padding: '58px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Eyebrow>REPORT CARD</Eyebrow>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 1v9m0-9L4 4m3-3l3 3M2 12h10" stroke="#fff" strokeWidth="1.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </IconButton>
      </div>

      {/* The card itself — white credential */}
      <div style={{ position: 'relative', padding: '20px 20px 0' }}>
        <div style={{ background: '#fff', color: '#000', borderRadius: 10, padding: 22, boxShadow: '0 30px 60px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.16)' }}>
          {/* Letterhead */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <MFMark size={20} dark={false}/>
              <span style={{ ...TYPE.micro, color: '#000', letterSpacing: 2 }}>MF · ACADEMY</span>
            </div>
            <span style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.5)' }}>MARCH 2026</span>
          </div>
          <SlashRule color="rgba(0,0,0,0.14)" style={{ marginTop: 16 }}/>

          {/* Title */}
          <div style={{ marginTop: 18 }}>
            <Eyebrow style={{ color: 'rgba(0,0,0,0.5)' }}>MONTHLY REPORT CARD</Eyebrow>
            <div style={{ ...TYPE.title1, color: '#000', marginTop: 6, letterSpacing: -0.6 }}>Player One</div>
            <div style={{ ...TYPE.foot, color: 'rgba(0,0,0,0.55)', marginTop: 4, fontWeight: 600 }}>Striker · № 09 · Rank II · Cadet</div>
          </div>

          {/* Grades */}
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 0, marginTop: 18, borderTop: '1px solid rgba(0,0,0,0.1)' }}>
            {[['Consistency', 'A'], ['Discipline', 'A'], ['Accountability', 'B+'], ['Growth', 'A−']].map(([k, g], i) => (
              <div key={k} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 0', borderBottom: '1px solid rgba(0,0,0,0.1)', borderRight: i % 2 === 0 ? '1px solid rgba(0,0,0,0.1)' : 'none', paddingRight: i % 2 === 0 ? 16 : 0, paddingLeft: i % 2 === 1 ? 16 : 0 }}>
                <span style={{ ...TYPE.foot, color: 'rgba(0,0,0,0.6)', fontWeight: 600 }}>{k}</span>
                <span style={{ ...TYPE.num, fontSize: 24, color: '#000', fontVariantNumeric: 'normal' }}>{g}</span>
              </div>
            ))}
          </div>

          {/* Certifications earned */}
          <div style={{ marginTop: 18 }}>
            <Eyebrow style={{ color: 'rgba(0,0,0,0.5)' }}>CERTIFICATIONS · {earned.length} EARNED</Eyebrow>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
              {(earned.length ? earned : [{ name: 'In progress' }]).map((c, i) => (
                <span key={i} style={{ ...TYPE.micro, color: '#000', border: '1px solid rgba(0,0,0,0.2)', padding: '5px 9px', borderRadius: 999, fontWeight: 600 }}>{c.name}</span>
              ))}
              {certs.filter((c) => c.inProgress).slice(0, 3).map((c, i) => (
                <span key={`p${i}`} style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.45)', border: '1px dashed rgba(0,0,0,0.22)', padding: '5px 9px', borderRadius: 999, fontWeight: 600 }}>{c.name} · {c.done}/{c.levels}</span>
              ))}
            </div>
          </div>

          {/* Signature */}
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginTop: 22, paddingTop: 16, borderTop: '1px solid rgba(0,0,0,0.1)' }}>
            <div>
              <div style={{ fontFamily: 'Snell Roundhand, "Brush Script MT", cursive', fontSize: 24, color: '#000', lineHeight: '24px' }}>Matteo Finazzi</div>
              <div style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.5)', marginTop: 6 }}>HEAD COACH · SIGNED</div>
            </div>
            <CertSeal earned={true} size={44}/>
          </div>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '22px 20px 0', display: 'flex', gap: 10 }}>
        <SecondaryButton>Download PDF</SecondaryButton>
        <PrimaryButton>Share with family</PrimaryButton>
      </div>
    </div>
  );
}

Object.assign(window, { ScrParentReport, PillarCard, ScrReportCard });
