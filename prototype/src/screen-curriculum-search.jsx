// MF Elite — Academy · Search & browse the whole curriculum
// At 150+ drills (and growing), players need to find work fast.
// Reads the flattened curriculum — scales to any size the coach adds.

function ScrCurriculumSearch() {
  const query = 'weak foot';
  const results = searchDrills(query);          // live filter over all drills
  const total = curriculumTotals().drills;
  const chips = [
    { label: 'All', active: true },
    ...CURRICULUM.map((d) => ({ label: d.name, active: false, mark: d.mark })),
  ];
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 120 }}>
      {/* header */}
      <div style={{ padding: '60px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>SEARCH THE CURRICULUM</Eyebrow>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{total} DRILLS</span>
        </div>

        {/* search field */}
        <div style={{ marginTop: 14, display: 'flex', alignItems: 'center', gap: 12, padding: '13px 16px', borderRadius: 14, background: MF.bg.elevated, border: `1px solid ${MF.line.subtle}` }}>
          <svg width="17" height="17" viewBox="0 0 17 17"><circle cx="7" cy="7" r="5.2" stroke="#fff" strokeWidth="1.5" fill="none"/><path d="M11 11l4 4" stroke="#fff" strokeWidth="1.5" strokeLinecap="round"/></svg>
          <span style={{ flex: 1, ...TYPE.callout, color: '#fff', fontWeight: 500 }}>{query}<span style={{ display: 'inline-block', width: 1.5, height: 16, background: '#fff', marginLeft: 2, verticalAlign: 'middle', animation: 'mfBlink 1.1s step-end infinite' }}/></span>
          <div style={{ width: 18, height: 18, borderRadius: 9, background: MF.bg.raised, border: `1px solid ${MF.line.subtle}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="8" height="8" viewBox="0 0 8 8"><path d="M1 1l6 6M7 1L1 7" stroke="#fff" strokeWidth="1.2" strokeLinecap="round"/></svg>
          </div>
        </div>
      </div>

      {/* discipline filter chips */}
      <div style={{ display: 'flex', gap: 8, overflowX: 'auto', padding: '16px 20px 0', WebkitOverflowScrolling: 'touch' }}>
        {chips.map((c, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 7, flexShrink: 0,
            padding: '8px 14px', borderRadius: 999,
            background: c.active ? '#fff' : 'transparent',
            border: `1px solid ${c.active ? '#fff' : MF.line.subtle}`,
          }}>
            {c.mark && <DisciplineMark kind={c.mark} size={13} color={c.active ? '#000' : '#fff'}/>}
            <span style={{ ...TYPE.micro, color: c.active ? '#000' : '#fff', fontWeight: 700 }}>{c.label.toUpperCase()}</span>
          </div>
        ))}
      </div>

      {/* result count */}
      <div style={{ padding: '22px 20px 0', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
        <Eyebrow>{results.length} RESULTS · “{query.toUpperCase()}”</Eyebrow>
        <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>RELEVANCE</span>
      </div>

      {/* results */}
      <div style={{ padding: '12px 0 0' }}>
        {results.map((r, i) => (
          <div key={r.key} style={{
            display: 'flex', alignItems: 'center', gap: 14, padding: '13px 20px',
            borderTop: `1px solid ${MF.line.hairline}`,
            borderBottom: i === results.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
          }}>
            <div style={{ width: 44, height: 44, flexShrink: 0, borderRadius: 11, border: `1px solid ${MF.line.subtle}`, background: MF.bg.card, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative' }}>
              <DisciplineMark kind={r.mark} size={19}/>
              {r.media === 'video' && <span style={{ position: 'absolute', bottom: -4, right: -4, width: 16, height: 16, borderRadius: 8, background: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><svg width="7" height="7" viewBox="0 0 7 7"><path d="M1 0l6 3.5L1 7V0z" fill="#000"/></svg></span>}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.t}</div>
              <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 3, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.crumb.toUpperCase()}</div>
            </div>
            {!r.free
              ? <svg width="12" height="14" viewBox="0 0 13 15" style={{ flexShrink: 0 }}><path d="M3 7V5a3.5 3.5 0 017 0v2" stroke="rgba(255,255,255,0.55)" strokeWidth="1.3" fill="none"/><rect x="2" y="7" width="9" height="7" rx="1.4" stroke="rgba(255,255,255,0.55)" strokeWidth="1.3" fill="none"/></svg>
              : <svg width="9" height="14" viewBox="0 0 9 14" style={{ flexShrink: 0 }}><path d="M2 1l5 6-5 6" stroke="rgba(255,255,255,0.55)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
          </div>
        ))}
      </div>

      {/* quick browse hint */}
      <div style={{ padding: '26px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>OR BROWSE BY PATHWAY</Eyebrow>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {CURRICULUM.map((d) => (
            <div key={d.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '14px 14px', borderRadius: 14, background: MF.bg.card, border: `1px solid ${MF.line.hairline}` }}>
              <DisciplineMark kind={d.mark} size={18}/>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ ...TYPE.foot, color: '#fff', fontWeight: 700 }}>{d.name}</div>
                <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>{disciplineDrills(d)} DRILLS</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '22px 20px 0', textAlign: 'center' }}>
        <Eyebrow style={{ color: MF.ink.quaternary }}>SEARCHES TITLE · SKILL · COACHING NOTES ACROSS ALL PATHWAYS</Eyebrow>
      </div>
    </div>
  );
}

Object.assign(window, { ScrCurriculumSearch });
