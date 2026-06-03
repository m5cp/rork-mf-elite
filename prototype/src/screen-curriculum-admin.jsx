// MF Elite — Coach · Academy Curriculum Manager
// The coach owns the curriculum: drills, films, quotes, announcements,
// XP values, certifications and progression rules — all edited here and
// pushed through Supabase with no App Store update.

function ScrCurriculumAdmin() {
  const t = curriculumTotals();
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      {/* Admin badge bar */}
      <div style={{ margin: '54px 14px 0', padding: '8px 14px', borderRadius: 999, background: '#fff', color: '#000', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <svg width="11" height="13" viewBox="0 0 11 13"><path d="M2.5 6V4a3 3 0 016 0v2" stroke="#000" strokeWidth="1.3" fill="none"/><rect x="1.5" y="6" width="8" height="6" rx="1.2" fill="#000"/></svg>
          <span style={{ ...TYPE.micro, color: '#000', letterSpacing: 1.8, fontWeight: 800 }}>ADMIN · COACH ACCESS</span>
        </div>
        <span style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.55)' }}>Synced · live</span>
      </div>

      {/* Header */}
      <div style={{ padding: '20px 20px 0' }}>
        <Crumb>Coach workspace</Crumb>
        <Eyebrow style={{ marginTop: 14 }}>ACADEMY · CONTENT</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 6, lineHeight: '46px' }}>Curriculum</div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 10, maxWidth: 330 }}>
          Add and edit every drill, film and rule. Changes appear in players' apps within seconds.
        </div>
      </div>

      {/* Live counts */}
      <div style={{ padding: '20px 20px 0' }}>
        <Card padding={18}>
          <Eyebrow>LIBRARY · LIVE</Eyebrow>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', marginTop: 14 }}>
            {[['04', 'PATHWAYS'], [String(t.categories), 'CATEGORIES'], [String(t.levels), 'LEVELS'], [String(t.drills), 'DRILLS']].map(([n, l], i) => (
              <div key={l} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, borderRight: i < 3 ? `1px solid ${MF.line.hairline}` : 'none' }}>
                <span style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>{n}</span>
                <Eyebrow style={{ fontSize: 9 }}>{l}</Eyebrow>
              </div>
            ))}
          </div>
        </Card>
      </div>

      {/* Curriculum tree — editable */}
      <div style={{ padding: '26px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Eyebrow>CONTENT TREE</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>TAP TO EXPAND</span>
        </div>
        <div style={{ background: MF.bg.card, borderRadius: 16, border: `1px solid ${MF.line.hairline}`, overflow: 'hidden' }}>
          {CURRICULUM.map((dsc, i) => (
            <div key={dsc.id} style={{ borderTop: i > 0 ? `1px solid ${MF.line.hairline}` : 'none' }}>
              <div style={{ padding: '14px 16px', display: 'flex', alignItems: 'center', gap: 12, background: dsc.id === 'technical' ? '#0a0a0a' : 'transparent' }}>
                <DisciplineMark kind={dsc.mark} size={20}/>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700 }}>{dsc.no} · {dsc.name}</div>
                  <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>{dsc.categories.length} CATEGORIES · {disciplineDrills(dsc)} DRILLS</div>
                </div>
                <svg width="11" height="11" viewBox="0 0 11 11"><path d={dsc.id === 'technical' ? 'M1 7l4.5-4 4.5 4' : 'M1 4l4.5 4 4.5-4'} stroke="rgba(255,255,255,0.6)" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </div>
              {/* Expanded — Technical's categories */}
              {dsc.id === 'technical' && (
                <div style={{ padding: '0 16px 12px 48px' }}>
                  {dsc.categories.map((cat) => (
                    <div key={cat.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 0', borderTop: `1px solid ${MF.line.hairline}` }}>
                      <span style={{ ...TYPE.micro, color: MF.ink.tertiary, fontFamily: MF.font.mono, width: 14 }}>{cat.letter}</span>
                      <span style={{ flex: 1, ...TYPE.foot, color: '#fff', fontWeight: 600 }}>{cat.name}</span>
                      <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{cat.levels.length}L · {totalDrills(cat)}D</span>
                      <svg width="13" height="13" viewBox="0 0 13 13"><path d="M2 9.5L9 2.5l1.5 1.5L3.5 11H2V9.5z" stroke="rgba(255,255,255,0.55)" strokeWidth="1.2" fill="none" strokeLinejoin="round"/></svg>
                    </div>
                  ))}
                  <button style={{ width: '100%', height: 40, marginTop: 10, appearance: 'none', cursor: 'pointer', border: `1px dashed ${MF.line.strong}`, borderRadius: 10, background: 'transparent', color: '#fff', ...TYPE.micro, fontWeight: 700, letterSpacing: 1.4, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
                    <svg width="12" height="12" viewBox="0 0 12 12"><path d="M6 1.5v9M1.5 6h9" stroke="#fff" strokeWidth="1.5" strokeLinecap="round"/></svg>
                    ADD CATEGORY
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
        <button style={{ width: '100%', height: 48, marginTop: 12, appearance: 'none', cursor: 'pointer', border: 'none', borderRadius: 12, background: '#fff', color: '#000', ...TYPE.foot, fontWeight: 700, letterSpacing: 0.4, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 2v10M2 7h10" stroke="#000" strokeWidth="1.8" strokeLinecap="round"/></svg>
          New drill
        </button>
      </div>

      {/* Progression rules — the coach owns XP and unlocks */}
      <div style={{ padding: '28px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>PROGRESSION RULES</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <RuleField label="XP PER DRILL" value={`${CURRICULUM_RULES.xpPerDrill} XP`}/>
          <RuleField label="LEVEL COMPLETION BONUS" value={`+${CURRICULUM_RULES.xpLevelBonus} XP`}/>
          <RuleField label="CATEGORY CERTIFICATION" value={`+${CURRICULUM_RULES.xpCategoryCert} XP`}/>
          <RuleField label="MASTERY PASSES PER DRILL" value={`${CURRICULUM_RULES.masteryPasses}×`}/>
          <RuleField label="FREE TIER" value={`Level ${CURRICULUM_RULES.freeLevels} of every category`}/>
        </div>
      </div>

      {/* Certifications config */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Eyebrow>CERTIFICATIONS</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{curriculumTotals().categories} DEFINED</span>
        </div>
        <div style={{ padding: '14px 16px', borderRadius: 14, background: MF.bg.card, border: `1px solid ${MF.line.hairline}`, display: 'flex', alignItems: 'center', gap: 12 }}>
          <CertSeal earned={true} size={40}/>
          <div style={{ flex: 1 }}>
            <div style={{ ...TYPE.foot, color: '#fff', fontWeight: 700 }}>One per category · coach-signed</div>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>Auto-awarded when every level is mastered</div>
          </div>
          <Toggle on={true}/>
        </div>
      </div>

      {/* Daily quote + announcement managers */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>DASHBOARD CONTENT</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          <div style={{ padding: '14px 16px', borderRadius: 14, background: '#0a0a0a', border: `1px solid ${MF.line.subtle}` }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <Eyebrow>DAILY MOTIVATION · TODAY</Eyebrow>
              <span style={{ ...TYPE.micro, color: '#fff' }}>EDIT</span>
            </div>
            <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600, marginTop: 8, fontStyle: 'italic' }}>
              “Do it when you don't feel like it. That's the edge.”
            </div>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 8 }}>ROTATES DAILY · 31 IN QUEUE</div>
          </div>
          <div style={{ padding: '14px 16px', borderRadius: 14, background: MF.bg.card, border: `1px solid ${MF.line.hairline}`, display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 36, height: 36, borderRadius: 10, background: MF.bg.raised, border: `1px solid ${MF.line.subtle}`, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <svg width="16" height="16" viewBox="0 0 16 16"><path d="M2 4h12M2 8h12M2 12h7" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/></svg>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ ...TYPE.foot, color: '#fff', fontWeight: 700 }}>Announcements</div>
              <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>Push to all athletes or a squad</div>
            </div>
            <svg width="8" height="14" viewBox="0 0 8 14"><path d="M1 1l6 6-6 6" stroke="rgba(255,255,255,0.55)" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
        </div>
      </div>

      {/* CTA */}
      <div style={{ padding: '28px 20px 0', display: 'flex', gap: 10 }}>
        <SecondaryButton>Preview as player</SecondaryButton>
        <PrimaryButton>Publish changes</PrimaryButton>
      </div>
      <div style={{ padding: '14px 20px 0', textAlign: 'center' }}>
        <Eyebrow style={{ color: MF.ink.quaternary }}>STORED IN SUPABASE · RLS-SECURED · NO APP STORE UPDATE NEEDED</Eyebrow>
      </div>
    </div>
  );
}

function RuleField({ label, value }) {
  return (
    <div style={{ padding: '13px 16px', borderRadius: 14, background: '#0a0a0a', border: `1px solid ${MF.line.subtle}`, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
      <div style={{ ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 1.4 }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ ...TYPE.callout, color: '#fff', fontWeight: 700 }}>{value}</span>
        <svg width="13" height="13" viewBox="0 0 13 13"><path d="M2 9.5L9 2.5l1.5 1.5L3.5 11H2V9.5z" stroke="rgba(255,255,255,0.55)" strokeWidth="1.2" fill="none" strokeLinejoin="round"/></svg>
      </div>
    </div>
  );
}

Object.assign(window, { ScrCurriculumAdmin, RuleField });
