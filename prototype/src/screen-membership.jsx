// MF Elite — Membership · phone screens
// Free experience · locked states · rank/XP · badges · upgrade moments
// · tier compare · pricing v2 · parent screen · premium welcome.

// ─── Shared progression data ─────────────────────────────────
// XP and rank now come from the single source of truth (MF_XP / MF_RANKS
// in curriculum-data). Badges map 1:1 onto the shared rank ladder, so
// every screen — academy and membership — shows the same numbers.
const PLAYER_XP = MF_XP;
const _badgeMeta = {
  TRIALIST: { kind: 'medal',  note: 'Admitted day one' },
  CADET:    { kind: 'shield', note: 'Cadet rank · 1 500 XP' },
  PROSPECT: { kind: 'star',   note: '3 certs · 30-day streak' },
  STARTER:  { kind: 'hex',    note: '3 diplomas · 90-day streak' },
  CAPTAIN:  { kind: 'wreath', note: 'Full season · every discipline' },
  ELEVEN:   { kind: 'eleven', note: 'Invitation only · 1 of 11' },
};
const BADGE_TIERS = MF_RANKS.map((r) => ({
  kind: _badgeMeta[r.earn].kind,
  name: r.invite ? 'The Eleven' : `${r.name} badge`,
  earn: r.earn, cap: r.cap, note: _badgeMeta[r.earn].note, invite: r.invite,
}));
function badgeStateFor(tier, xp, equippedEarn) {
  if (tier.invite) return 'lock';
  if (xp >= tier.cap) return tier.earn === equippedEarn ? 'on' : 'own';
  return 'lock';
}
function currentRank(xp) {
  let last = BADGE_TIERS[0];
  for (const t of BADGE_TIERS) {
    if (t.invite) break;
    if (xp >= t.cap) last = t;
  }
  return last;
}

// ─── 1 · FREE DASHBOARD ──────────────────────────────────────
// Same editorial layout as the premium dashboard, but with two calm
// gates: the on-deck list shows reserved sessions; one inline brief.
function ScrFreeDashboard() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 140 }}>
      <div style={{ padding: '62px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Avatar size={36} initials="P1"/>
        <MFMark size={20}/>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, padding: '6px 10px', border: `1px solid ${MF.line.subtle}`, borderRadius: 999 }}>TRIALIST · DAY 04</div>
      </div>

      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow>TUE 12 MAR · WEEK 01</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 8, lineHeight: '46px', fontSize: 42 }}>
          Welcome back,<br/>Player One
        </div>
      </div>

      {/* Today's free session — clean and full */}
      <div style={{ padding: '22px 20px 0' }}>
        <div style={{ borderRadius: 24, overflow: 'hidden', background: '#0a0a0a', border: `1px solid ${MF.line.hairline}` }}>
          <PhotoPlaceholder height={260} label="TODAY · OPEN SESSION" style={{ borderRadius: 0, border: 'none' }}>
            <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to bottom, rgba(0,0,0,0.35) 0%, rgba(0,0,0,0) 30%, rgba(0,0,0,0) 55%, rgba(0,0,0,0.92) 100%)' }}/>
            <div style={{ position: 'absolute', left: 16, top: 16, ...TYPE.micro, color: '#fff' }}>● TODAY · 06:30</div>
            <div style={{ position: 'absolute', left: 20, right: 20, bottom: 20 }}>
              <Eyebrow style={{ color: 'rgba(255,255,255,0.65)' }}>OPEN SESSION · TRIALIST</Eyebrow>
              <div style={{ ...TYPE.display, color: '#fff', marginTop: 8, lineHeight: '36px' }}>First touch<br/>Day two</div>
              <div style={{ display: 'flex', gap: 14, marginTop: 12 }}>
                <DotMeta label="28 MIN"/><Sep/><DotMeta label="4 DRILLS"/><Sep/><DotMeta label="FREE"/>
              </div>
            </div>
          </PhotoPlaceholder>
          <div style={{ padding: 14 }}>
            <PrimaryButton>Begin session</PrimaryButton>
          </div>
        </div>
      </div>

      {/* Streak + XP — feels native to the free experience */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ display: 'flex', gap: 14 }}>
          <FreeMini label="STREAK" value="04" unit="days"/>
          <FreeMini label="XP" value="120" unit="trialist"/>
          <FreeMini label="RANK" value="I" unit="trialist"/>
        </div>
      </div>

      {/* On deck — first three rows free-flavoured, then a gated row */}
      <div style={{ padding: '32px 20px 0' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginBottom: 14 }}>
          <Eyebrow>ON DECK</Eyebrow>
          <Eyebrow>04 / 06 · TRIAL WEEK</Eyebrow>
        </div>
        <DeckLine date="WED 13" title="Body shape · receiving" meta="22 MIN · FREE"/>
        <DeckLine date="THU 14" title="Wall passes · solo"     meta="18 MIN · FREE"/>
        <DeckLine date="FRI 15" title="Half-turn · session 1"  meta="32 MIN · MEMBERS" gated/>
        <DeckLine date="SAT 16" title="Cutback finishing"      meta="26 MIN · MEMBERS" gated last/>
      </div>

      {/* Calm membership brief — academy admissions tone */}
      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 18, background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <MFMark size={18}/>
            <Eyebrow>ADMISSIONS · DAY 04 OF 07</Eyebrow>
          </div>
          <div style={{ ...TYPE.title2, color: '#fff', marginTop: 10 }}>
            Three days left of your trial week
          </div>
          <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 8, lineHeight: '18px' }}>
            You’ve completed four sessions and earned 120&nbsp;XP. Joining the
            academy continues your streak and opens the full curriculum,
            every coach, and the full season ahead.
          </div>
          <div style={{ display: 'flex', gap: 10, marginTop: 14 }}>
            <PrimaryButton size="md">Read the program</PrimaryButton>
            <SecondaryButton size="md" style={{ width: 'auto', flexShrink: 0 }}>Later</SecondaryButton>
          </div>
        </div>
      </div>
    </div>
  );
}

function FreeMini({ label, value, unit }) {
  return (
    <div style={{ flex: 1, padding: '14px 14px', border: `1px solid ${MF.line.hairline}`, borderRadius: 16, background: MF.bg.card }}>
      <Eyebrow>{label}</Eyebrow>
      <div style={{ ...TYPE.num, fontSize: 30, lineHeight: '30px', color: '#fff', marginTop: 8 }}>{value}</div>
      <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 6 }}>{unit}</div>
    </div>
  );
}

function DeckLine({ date, title, meta, gated, last }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'baseline', gap: 18,
      padding: '14px 0',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
      opacity: gated ? 0.7 : 1,
    }}>
      <span style={{ ...TYPE.micro, color: MF.ink.tertiary, width: 56, flexShrink: 0 }}>{date}</span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ ...TYPE.title3, color: '#fff' }}>{title}</div>
        <div style={{ ...TYPE.micro, color: gated ? MF.ink.tertiary : MF.ink.tertiary, marginTop: 4 }}>{meta}</div>
      </div>
      {gated
        ? <span style={{ ...TYPE.micro, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '4px 8px', borderRadius: 4 }}>MEMBERS</span>
        : <svg width="10" height="14" viewBox="0 0 10 14"><path d="M2 1l6 6-6 6" stroke="rgba(255,255,255,0.60)" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
    </div>
  );
}

// ─── 2 · LOCKED DRILL — aspirational, no padlock ─────────────
function ScrLockedDrill() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 40 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 1L3 7l6 6" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinecap="round"/></svg>
        </IconButton>
        <Eyebrow>DRILL · 12 OF 80</Eyebrow>
        <span style={{ width: 36 }}/>
      </div>

      {/* Hero film, dimmed by a calm overlay */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ position: 'relative', borderRadius: 22, overflow: 'hidden', border: `1px solid ${MF.line.hairline}` }}>
          <PhotoPlaceholder height={340} label="MEMBERS · COACH FILM" style={{ borderRadius: 0, border: 'none' }}/>
          <div style={{
            position: 'absolute', inset: 0,
            background: 'linear-gradient(180deg, rgba(0,0,0,0.55) 0%, rgba(0,0,0,0.7) 60%, rgba(0,0,0,0.95) 100%)',
            display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
            padding: 24,
          }}>
            <div style={{ position: 'absolute', top: 20, right: 20, ...TYPE.micro, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '4px 10px', borderRadius: 999 }}>RESERVED · ELITE</div>
            <Eyebrow style={{ color: 'rgba(255,255,255,0.65)' }}>ELITE DRILL 2 · HALF-TURN</Eyebrow>
            <div style={{ ...TYPE.hero, color: '#fff', marginTop: 8, lineHeight: '44px', fontSize: 38 }}>
              Half-turn,<br/>under pressure
            </div>
            <div style={{ ...TYPE.foot, color: MF.ink.secondary, marginTop: 12, maxWidth: 320 }}>
              Three minutes of film. Twelve repetitions on the wall. Coach
              Matteo demos the body shape from two angles.
            </div>
            <div style={{ display: 'flex', gap: 14, marginTop: 14 }}>
              <DotMeta label="12 MIN"/><Sep/><DotMeta label="MEMBERS"/><Sep/><DotMeta label="+25 XP"/>
            </div>
          </div>
        </div>
      </div>

      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow>WHY THIS DRILL IS RESERVED</Eyebrow>
        <div style={{ ...TYPE.body, color: '#fff', marginTop: 10, fontWeight: 500, lineHeight: '22px' }}>
          Reserved drills sit inside member-only Elite Drills. They include
          film, a progression sheet, and earn academy XP. Members complete
          them in sequence with their coach.
        </div>

        <SlashRule style={{ marginTop: 20 }}/>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 14, marginTop: 18 }}>
          <ValueLine>Coach film · two angles · 3:14</ValueLine>
          <ValueLine>Progression sheet · 4 levels</ValueLine>
          <ValueLine>Counts toward Elite Drill 2 completion</ValueLine>
          <ValueLine>+25 XP toward your next rank</ValueLine>
        </div>
      </div>

      <div style={{ padding: '28px 20px 0' }}>
        <PrimaryButton>Join the academy</PrimaryButton>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, textAlign: 'center', marginTop: 12 }}>
          $199.99 / year · 7-day trial · cancel any time
        </div>
      </div>
    </div>
  );
}

// ─── 3 · LOCKED ELITE DRILL — syllabus you have not been admitted to ─
function ScrLockedChapter() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 1L3 7l6 6" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinecap="round"/></svg>
        </IconButton>
        <Eyebrow>ELITE DRILL · 4</Eyebrow>
        <span style={{ width: 36 }}/>
      </div>

      <div style={{ padding: '22px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 14 }}>
          <div>
            <span style={{ ...TYPE.num, fontSize: 96, lineHeight: '88px', color: MF.ink.tertiary, fontStyle: 'italic', fontVariantNumeric: 'normal' }}>4</span>
          </div>
          <span style={{ ...TYPE.micro, color: '#000', background: '#fff', padding: '4px 8px', borderRadius: 4, fontWeight: 700 }}>RESERVED</span>
        </div>

        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 14, lineHeight: '46px', fontSize: 42 }}>
          Finishing<br/>inside the six
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12 }}>
          Five sessions on six-yard composure. The first Elite Drill on the
          academy’s finishing track. Built and filmed by Coach Two.
        </div>

        <SlashRule style={{ marginTop: 22 }}/>
      </div>

      <div style={{ padding: '22px 0 0' }}>
        <div style={{ padding: '0 20px 14px', display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
          <Eyebrow>SYLLABUS</Eyebrow>
          <Eyebrow>05 SESSIONS</Eyebrow>
        </div>
        {[
          ['01', 'The two-touch finish',           '24 MIN'],
          ['02', 'Cutback windows',                '28 MIN'],
          ['03', 'First-time, far post',           '32 MIN'],
          ['04', 'Composure under a closer',       '22 MIN'],
          ['05', 'Live Elite Drill session',           '36 MIN'],
        ].map(([n, t, m], i, arr) => (
          <div key={n} style={{
            display: 'flex', alignItems: 'baseline', gap: 18,
            padding: '14px 20px',
            borderTop: `1px solid ${MF.line.hairline}`,
            borderBottom: i === arr.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
            opacity: 0.7,
          }}>
            <span style={{ ...TYPE.micro, color: MF.ink.tertiary, width: 24 }}>{n}</span>
            <div style={{ flex: 1 }}>
              <div style={{ ...TYPE.title3, color: '#fff' }}>{t}</div>
              <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>{m} · MEMBERS</div>
            </div>
          </div>
        ))}
      </div>

      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 18 }}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            <Avatar size={36} initials="C2"/>
            <div>
              <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>Coach Two</div>
              <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 2 }}>FINISHING · OPENS WITH MEMBERSHIP</div>
            </div>
          </div>
          <PrimaryButton style={{ marginTop: 16 }}>Open Elite Drill 4</PrimaryButton>
        </div>
      </div>
    </div>
  );
}

// ─── 4 · RANK / XP — your standing in the academy ────────────
function ScrRankProfile() {
  const equipped = currentRank(PLAYER_XP);
  const nextTier = BADGE_TIERS.find((t) => !t.invite && PLAYER_XP < t.cap) || null;
  const xpToNext = nextTier ? nextTier.cap - PLAYER_XP : 0;
  const breakdown = [
    ['Drills mastered',       '44 × 25',  1100],
    ['Mastery levels',        '11 × 120', 1320],
    ['Skill certifications',  '3 × 400',  1200],
  ];
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between' }}>
        <Eyebrow>YOUR STANDING</Eyebrow>
        <Eyebrow>SEASON 24 — 25</Eyebrow>
      </div>

      <div style={{ padding: '22px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 18 }}>
          <Monogram size={108} initials="II" kit="09"/>
          <div style={{ flex: 1, minWidth: 0 }}>
            <Eyebrow>RANK · II</Eyebrow>
            <div style={{ ...TYPE.hero, color: '#fff', marginTop: 6, fontSize: 44, lineHeight: '44px' }}>{equipped.earn}</div>
            <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 8 }}>Earned 02 MAR · 14-day streak</div>
          </div>
        </div>
      </div>

      {/* ACADEMY POINTS — the headline number, accumulated */}
      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 18, background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <Eyebrow style={{ color: '#fff' }}>ACADEMY POINTS</Eyebrow>
            <Eyebrow>SEASON · ACCUMULATED</Eyebrow>
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 12, marginTop: 10 }}>
            <span style={{ ...TYPE.num, fontSize: 56, lineHeight: '52px', color: '#fff', fontVariantNumeric: 'normal' }}>
              {PLAYER_XP.toLocaleString('en-US')}
            </span>
            <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>XP</span>
          </div>
          {nextTier && (
            <React.Fragment>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline', marginTop: 16 }}>
                <Eyebrow>TO {nextTier.earn}</Eyebrow>
                <span style={{ ...TYPE.micro, color: '#fff' }}>{xpToNext.toLocaleString('en-US')} XP TO GO</span>
              </div>
              <div style={{ marginTop: 8, height: 4, background: MF.line.subtle, borderRadius: 3, overflow: 'hidden' }}>
                <div style={{ width: `${Math.min(100, (PLAYER_XP / nextTier.cap) * 100)}%`, height: '100%', background: '#fff' }}/>
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8, ...TYPE.micro, color: MF.ink.tertiary }}>
                <span>{equipped.earn}</span><span>{nextTier.earn}</span>
              </div>
            </React.Fragment>
          )}
          <div style={{ marginTop: 18 }}>
            <Eyebrow>HOW YOU EARNED THEM</Eyebrow>
            <div style={{ marginTop: 8, display: 'flex', flexDirection: 'column' }}>
              {breakdown.map(([label, math, pts], i, arr) => (
                <div key={label} style={{
                  display: 'flex', alignItems: 'baseline', gap: 10,
                  padding: '10px 0',
                  borderTop: `1px solid ${MF.line.hairline}`,
                  borderBottom: i === arr.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
                }}>
                  <span style={{ flex: 1, ...TYPE.foot, color: '#fff', fontWeight: 500 }}>{label}</span>
                  <span style={{ ...TYPE.micro, color: MF.ink.tertiary, fontFamily: MF.font.mono }}>{math}</span>
                  <span style={{ ...TYPE.num, fontSize: 16, color: '#fff', width: 56, textAlign: 'right' }}>+{pts}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* BADGE LADDER — visible proof of progression */}
      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12 }}>
          <Eyebrow>BADGE LADDER</Eyebrow>
          <Eyebrow>{BADGE_TIERS.filter((t) => !t.invite && PLAYER_XP >= t.cap).length.toString().padStart(2,'0')} / 06 ON</Eyebrow>
        </div>
        <div style={{
          display: 'grid', gridTemplateColumns: 'repeat(6, 1fr)', gap: 8,
          padding: 14, borderRadius: 18,
          background: MF.bg.card, border: `1px solid ${MF.line.hairline}`,
        }}>
          {BADGE_TIERS.map((t) => {
            const earned = !t.invite && PLAYER_XP >= t.cap;
            return (
              <div key={t.earn} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <div style={{
                  width: 50, height: 50, borderRadius: 12,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  background: earned ? '#fff' : 'transparent',
                  border: earned ? 'none' : `1px solid ${MF.line.subtle}`,
                  opacity: earned ? 1 : 0.5,
                }}>
                  <BadgeMini earn={t.earn} dark={earned}/>
                </div>
                <Eyebrow style={{ color: earned ? '#fff' : MF.ink.tertiary, fontSize: 9 }}>
                  {({ TRIALIST: 'I', CADET: 'II', PROSPECT: 'III', STARTER: 'IV', CAPTAIN: 'V', ELEVEN: 'XI' }[t.earn] || '')}
                </Eyebrow>
              </div>
            );
          })}
        </div>
      </div>

      <div style={{ padding: '30px 20px 0' }}>
        <Eyebrow>THIS WEEK · +215 XP</Eyebrow>
        <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column' }}>
          {[
            ['MON', 'Half-turn · session 2',  '+45'],
            ['TUE', 'Streak +1 · day 6',      '+15'],
            ['WED', 'Acceleration ladders',   '+45'],
            ['THU', 'Body shape · receiving', '+45'],
            ['FRI', 'Elite Drill 2 · day 4',     '+45'],
            ['SAT', 'Streak +1 · day 10',     '+20'],
          ].map(([d, t, x], i, arr) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'baseline', gap: 16,
              padding: '12px 0',
              borderTop: `1px solid ${MF.line.hairline}`,
              borderBottom: i === arr.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
            }}>
              <Eyebrow style={{ width: 36 }}>{d}</Eyebrow>
              <span style={{ flex: 1, ...TYPE.callout, color: '#fff' }}>{t}</span>
              <span style={{ ...TYPE.num, fontSize: 16, color: '#fff' }}>{x}</span>
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '28px 20px 0' }}>
        <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 18, background: 'rgba(255,255,255,0.02)' }}>
          <Eyebrow style={{ color: '#fff' }}>NEXT · PROSPECT</Eyebrow>
          <div style={{ ...TYPE.title2, color: '#fff', marginTop: 10 }}>Prospect unlocks at 4 000 XP</div>
          <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 8, lineHeight: '18px' }}>
            Just 380 XP to go — about a week at your current pace. Master two more levels and you're there.
          </div>
        </div>
      </div>
    </div>
  );
}

// Compact rank glyph for the ladder strip on the rank profile.
function BadgeMini({ earn, dark }) {
  const c = dark ? '#000' : '#fff';
  const label = ({ TRIALIST: 'I', CADET: 'II', PROSPECT: 'III', STARTER: 'IV', CAPTAIN: 'V', ELEVEN: 'XI' }[earn] || '');
  return (
    <svg width="34" height="34" viewBox="0 0 34 34">
      <circle cx="17" cy="17" r="13" stroke={c} strokeWidth="1.2" fill="none"/>
      <text x="17" y="20" fill={c} fontFamily="-apple-system, system-ui"
        fontWeight="800" fontSize={label.length > 2 ? 9 : 12}
        textAnchor="middle" dominantBaseline="middle" letterSpacing="0.4">
        {label}
      </text>
    </svg>
  );
}

// ─── 5 · BADGES — earned by rank, never bought ───────────────
function ScrLocker() {
  const equipped = currentRank(PLAYER_XP).earn;
  const items = BADGE_TIERS.map((t) => ({
    ...t,
    state: badgeStateFor(t, PLAYER_XP, equipped),
    // Replace the "to-go" hint with the live XP gap so progress feels real
    note: !t.invite && PLAYER_XP < t.cap
      ? `${(t.cap - PLAYER_XP).toLocaleString('en-US')} XP to go`
      : (t.earn === equipped ? 'Equipped on dossier' : t.note),
  }));
  const earnedCount = items.filter((it) => it.state !== 'lock').length;
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between' }}>
        <Eyebrow>BADGES</Eyebrow>
        <Eyebrow>{String(earnedCount).padStart(2, '0')} / 06 · EARNED</Eyebrow>
      </div>
      <div style={{ padding: '14px 20px 0' }}>
        <div style={{ ...TYPE.hero, color: '#fff', fontSize: 38, lineHeight: '42px' }}>
          Earned<br/>Never sold
        </div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 10, maxWidth: 320 }}>
          Six gamified badges, one per rank. Each one switches on the
          moment your academy XP crosses its threshold. No purchase
          shortcut, no physical product.
        </div>
      </div>

      {/* XP banner — what unlocks the next badge */}
      <div style={{ padding: '20px 20px 0' }}>
        <div style={{ padding: '14px 16px', borderRadius: 14, border: `1px solid ${MF.line.subtle}`, background: 'rgba(255,255,255,0.02)' }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <Eyebrow>ACADEMY XP</Eyebrow>
            <span style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>{PLAYER_XP.toLocaleString('en-US')}</span>
          </div>
          <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 4 }}>
            Next badge · Prospect at 4 000 XP
          </div>
        </div>
      </div>

      <div style={{ padding: '18px 20px 0', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
        {items.map((it, i) => <LockerTile key={i} {...it}/>)}
      </div>
    </div>
  );
}

function LockerTile({ kind, name, earn, state, note }) {
  const locked = state === 'lock';
  return (
    <div style={{
      borderRadius: 18, overflow: 'hidden', border: `1px solid ${MF.line.hairline}`,
      background: MF.bg.card, opacity: locked ? 0.78 : 1,
      display: 'flex', flexDirection: 'column',
    }}>
      <div style={{
        height: 138, position: 'relative',
        background:
          'radial-gradient(120% 90% at 50% 20%, rgba(255,255,255,0.05) 0%, rgba(255,255,255,0) 60%), linear-gradient(160deg, #161616 0%, #050505 100%)',
        display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
      }}>
        <BadgeGlyph kind={kind} earn={earn} locked={locked}/>
        <div style={{
          position: 'absolute', top: 10, right: 10,
          ...TYPE.micro, color: locked ? MF.ink.tertiary : '#000',
          background: locked ? 'transparent' : '#fff', border: locked ? `1px solid ${MF.line.subtle}` : 'none',
          padding: '3px 7px', borderRadius: 4, fontWeight: 700,
        }}>
          {locked ? earn : 'EARNED'}
        </div>
      </div>
      <div style={{ padding: '12px 14px 14px' }}>
        <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 600 }}>{name}</div>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>{note}</div>
      </div>
    </div>
  );
}

// Six abstract gamified badge marks — all read as medals/insignia,
// nothing reads as apparel or physical product.
function BadgeGlyph({ kind, earn, locked }) {
  const stroke = '#fff';
  const fill = locked ? 'transparent' : 'rgba(255,255,255,0.06)';
  const muted = 'rgba(255,255,255,0.55)';
  const label = (
    { TRIALIST: 'I', CADET: 'II', PROSPECT: 'III', STARTER: 'IV', CAPTAIN: 'V', ELEVEN: 'XI' }[earn] || ''
  );
  const size = 96;

  const ribbon = (
    <g>
      <path d="M28 12 L40 36 L48 28 L56 36 L68 12"
        stroke={muted} strokeWidth="1.2" fill="none" strokeLinejoin="miter"/>
    </g>
  );

  let shape = null;
  if (kind === 'medal') {
    shape = (
      <g>
        <circle cx="48" cy="58" r="26" stroke={stroke} strokeWidth="1.4" fill={fill}/>
        <circle cx="48" cy="58" r="20" stroke={stroke} strokeWidth="0.8" fill="none" strokeDasharray="2 2" opacity="0.5"/>
      </g>
    );
  } else if (kind === 'shield') {
    shape = (
      <g>
        <path d="M48 30 L74 38 L74 60 C74 76 60 84 48 88 C36 84 22 76 22 60 L22 38 Z"
          stroke={stroke} strokeWidth="1.4" fill={fill} strokeLinejoin="miter"/>
        <path d="M22 54 L74 54" stroke={stroke} strokeWidth="0.9" opacity="0.45"/>
      </g>
    );
  } else if (kind === 'star') {
    const pts = [];
    for (let i = 0; i < 10; i++) {
      const a = (-Math.PI / 2) + (i * Math.PI / 5);
      const r = i % 2 === 0 ? 24 : 10;
      pts.push(`${48 + r * Math.cos(a)},${58 + r * Math.sin(a)}`);
    }
    shape = (
      <g>
        <circle cx="48" cy="58" r="28" stroke={stroke} strokeWidth="1.0" fill="none" opacity="0.5"/>
        <polygon points={pts.join(' ')} stroke={stroke} strokeWidth="1.4" fill={fill} strokeLinejoin="miter"/>
      </g>
    );
  } else if (kind === 'hex') {
    const hex = [];
    for (let i = 0; i < 6; i++) {
      const a = (-Math.PI / 2) + (i * Math.PI / 3);
      hex.push(`${48 + 26 * Math.cos(a)},${58 + 26 * Math.sin(a)}`);
    }
    shape = (
      <g>
        <polygon points={hex.join(' ')} stroke={stroke} strokeWidth="1.4" fill={fill} strokeLinejoin="miter"/>
        <polygon points={hex.map(p => {
          const [x, y] = p.split(',').map(Number);
          return `${48 + (x - 48) * 0.62},${58 + (y - 58) * 0.62}`;
        }).join(' ')} stroke={stroke} strokeWidth="0.8" fill="none" opacity="0.45"/>
      </g>
    );
  } else if (kind === 'wreath') {
    shape = (
      <g>
        <circle cx="48" cy="58" r="22" stroke={stroke} strokeWidth="1.4" fill={fill}/>
        {Array.from({ length: 12 }).map((_, i) => {
          const a = (i / 12) * Math.PI * 2;
          const x1 = 48 + 26 * Math.cos(a);
          const y1 = 58 + 26 * Math.sin(a);
          const x2 = 48 + 32 * Math.cos(a);
          const y2 = 58 + 32 * Math.sin(a);
          return <line key={i} x1={x1} y1={y1} x2={x2} y2={y2} stroke={stroke} strokeWidth="1.1"/>;
        })}
      </g>
    );
  } else if (kind === 'eleven') {
    shape = (
      <g>
        <circle cx="48" cy="58" r="28" stroke={stroke} strokeWidth="1.4" fill={fill}/>
        <circle cx="48" cy="58" r="22" stroke={stroke} strokeWidth="0.8" fill="none" opacity="0.55"/>
        {[0, 90, 180, 270].map((a, i) => (
          <line key={i}
            x1={48 + 28 * Math.cos(a * Math.PI / 180)}
            y1={58 + 28 * Math.sin(a * Math.PI / 180)}
            x2={48 + 34 * Math.cos(a * Math.PI / 180)}
            y2={58 + 34 * Math.sin(a * Math.PI / 180)}
            stroke={stroke} strokeWidth="1.4"/>
        ))}
      </g>
    );
  }

  return (
    <svg width={size} height={size} viewBox="0 0 96 96">
      {ribbon}
      {shape}
      <text x="48" y="62" fill={stroke} fontFamily="-apple-system, system-ui"
        fontWeight="800" fontSize={label.length > 2 ? 16 : 20}
        textAnchor="middle" dominantBaseline="middle" letterSpacing="0.5">
        {label}
      </text>
    </svg>
  );
}

// ─── 6 · UPGRADE MOMENT · STREAK MILESTONE ───────────────────
// Calm modal-style screen after the 7-day streak completes. Clean
// dark surface with the academy diagonal motif, big numeric mark,
// then a calm headline and 3 value lines. No blurred backdrop.
function ScrUpgradeStreak() {
  return (
    <div style={{
      width: '100%', height: '100%', background: '#000',
      position: 'relative', overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.5, pointerEvents: 'none',
        backgroundImage:
          'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.022) 44px, rgba(255,255,255,0.022) 45px)',
      }}/>
      <div style={{
        position: 'absolute', inset: 0, pointerEvents: 'none',
        background:
          'radial-gradient(140% 60% at 50% 0%, rgba(255,255,255,0.06) 0%, rgba(255,255,255,0) 60%)',
      }}/>

      <div style={{
        position: 'relative', padding: '60px 24px 0',
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <MFMark size={22}/>
          <Eyebrow>ACADEMY · MOMENT</Eyebrow>
        </div>
        <IconButton style={{ width: 32, height: 32, borderRadius: 16, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="10" height="10" viewBox="0 0 10 10"><path d="M1 1l8 8M9 1L1 9" stroke="#fff" strokeWidth="1.4" strokeLinecap="round"/></svg>
        </IconButton>
      </div>

      <div style={{ position: 'relative', padding: '36px 24px 0' }}>
        <div style={{
          ...TYPE.num, fontSize: 200, lineHeight: '180px', color: '#fff',
          fontVariantNumeric: 'normal', letterSpacing: -8, fontStyle: 'italic',
        }}>07</div>
        <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 6, letterSpacing: 2.2 }}>
          DAYS IN A ROW · MARCH 12 — 18
        </div>
      </div>

      <div style={{ position: 'relative', padding: '28px 24px 0', flex: 1 }}>
        <div style={{ ...TYPE.hero, color: '#fff', fontSize: 38, lineHeight: '42px' }}>
          Seven days<br/>Cadet earned
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 14, maxWidth: 320, lineHeight: '23px' }}>
          You’ve trained every day this week. The academy notices —
          most players don’t make it past day four.
        </div>

        <SlashRule style={{ margin: '22px 0 16px' }}/>

        <Eyebrow>WHAT HAPPENS NEXT</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginTop: 12 }}>
          <ValueLine>Continue your streak — members get every Elite Drill</ValueLine>
          <ValueLine>All 80 drills · all 11 position tracks</ValueLine>
          <ValueLine>Six gamified badges across the ranks</ValueLine>
        </div>
      </div>

      <div style={{
        position: 'relative', padding: '20px 24px 36px',
        display: 'flex', flexDirection: 'column', gap: 10,
      }}>
        <FloatingButton>Continue as a member</FloatingButton>
        <GhostButton>Keep going free</GhostButton>
      </div>
    </div>
  );
}

// ─── 7 · UPGRADE MOMENT · ELITE DRILL GATE ───────────────────────
// Triggered the moment a player finishes the last session of an open
// Elite Drill. Confirms the completion first, then introduces the gate
// to the reserved Elite Drills 2 — 6.
function ScrUpgradeChapter() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10" stroke="#fff" strokeWidth="1.5" strokeLinecap="round"/></svg>
        </IconButton>
        <Eyebrow>ELITE DRILL 1 · COMPLETE</Eyebrow>
        <span style={{ width: 36 }}/>
      </div>

      {/* Big completion mark — 04 of 04 sessions done */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{
          padding: '20px 20px',
          borderRadius: 18,
          background: '#fff',
          color: '#000',
          display: 'flex', alignItems: 'center', gap: 16,
        }}>
          <div style={{
            width: 44, height: 44, borderRadius: 22,
            background: '#000', color: '#fff',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0,
          }}>
            <svg width="20" height="20" viewBox="0 0 20 20"><path d="M3 10.5l4 4 10-10" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <Eyebrow style={{ color: 'rgba(0,0,0,0.55)' }}>RECEIVING · ELITE DRILL 1</Eyebrow>
            <div style={{ ...TYPE.title3, color: '#000', marginTop: 2, fontWeight: 700 }}>04 / 04 sessions done</div>
          </div>
          <span style={{ ...TYPE.num, fontSize: 28, color: '#000', fontVariantNumeric: 'normal' }}>+200</span>
        </div>
      </div>

      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ ...TYPE.hero, color: '#fff', fontSize: 38, lineHeight: '42px' }}>
          Elite Drill 1<br/>complete
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12, maxWidth: 320 }}>
          You finished every session of the open Elite Drill. Elite Drills
          2 — 6 live inside the academy. One annual decision opens the
          full season.
        </div>
      </div>

      {/* Elite Drill ladder — visual proof of where you are */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow>YOUR LADDER</Eyebrow>
        <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column' }}>
          {[
            { n: '1', t: 'Receiving',         m: '04 / 04 sessions done', state: 'done' },
            { n: '2', t: 'Half-turn',         m: '06 sessions · reserved', state: 'gate' },
            { n: '3', t: 'Tight spaces',      m: '06 sessions · reserved', state: 'lock' },
            { n: '4', t: 'Finishing inside',  m: '05 sessions · reserved', state: 'lock' },
            { n: '5', t: 'Pressing triggers', m: '04 sessions · reserved', state: 'lock' },
            { n: '6', t: 'Match craft',       m: '06 sessions · reserved', state: 'lock' },
          ].map((r, i, arr) => (
            <div key={r.n} style={{
              display: 'flex', alignItems: 'baseline', gap: 14, padding: '14px 0',
              borderTop: `1px solid ${MF.line.hairline}`,
              borderBottom: i === arr.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
              opacity: r.state === 'lock' ? 0.45 : 1,
            }}>
              <span style={{
                ...TYPE.num, fontStyle: 'italic', fontVariantNumeric: 'normal',
                color: r.state === 'gate' ? '#fff' : MF.ink.tertiary,
                width: 28, fontSize: 24,
              }}>{r.n}</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ ...TYPE.title3, color: '#fff' }}>{r.t}</div>
                <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>{r.m}</div>
              </div>
              {r.state === 'done' && <span style={{ ...TYPE.micro, color: '#000', background: '#fff', padding: '3px 7px', borderRadius: 4, fontWeight: 700 }}>DONE</span>}
              {r.state === 'gate' && <span style={{ ...TYPE.micro, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '3px 7px', borderRadius: 4 }}>NEXT · MEMBERS</span>}
            </div>
          ))}
        </div>
      </div>

      <div style={{ padding: '28px 20px 0' }}>
        <PrimaryButton>Open Elite Drill 2</PrimaryButton>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, textAlign: 'center', marginTop: 12 }}>
          $199.99 / year · 7-day trial · cancel any time
        </div>
      </div>
    </div>
  );
}

// ─── 8 · TIER COMPARE — elegant, single screen ───────────────
function ScrTierCompare() {
  const sections = [
    {
      head: 'TRAINING',
      rows: [
        ['Today’s session',           'yes', 'yes'],
        ['Drill library',                  '6 / 80', 'all 80'],
        ['MF Hub curriculum',              'Elite Drill 1', '1 — 6'],
        ['Position tracks',                'striker', 'all 11'],
        ['Routines (prebuilt)',            'morning', 'all 6'],
      ],
    },
    {
      head: 'COACHING',
      rows: [
        ['Coach Matteo · curriculum',      'Elite Drill 1',  '1 — 6'],
        ['All academy coaches',            'no',         'yes'],
        ['Position-specific tracks',       'striker',    '11 positions'],
      ],
    },
    {
      head: 'PROGRESSION (EARNED)',
      rows: [
        ['Streak + XP',                    'yes', 'yes'],
        ['Rank ladder',                    'I — II',  '1 — 6'],
        ['Badges',                         'Trialist', 'all 6 ranks'],
      ],
    },
  ];
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between' }}>
        <Eyebrow>THE TWO TIERS</Eyebrow>
        <Eyebrow>SIDE BY SIDE</Eyebrow>
      </div>

      <div style={{ padding: '18px 20px 0' }}>
        <div style={{ ...TYPE.hero, color: '#fff', lineHeight: '46px', fontSize: 42 }}>
          Free is real<br/>Elite is the academy
        </div>
      </div>

      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 0.85fr 0.85fr', alignItems: 'center', paddingBottom: 12, borderBottom: `1px solid ${MF.line.strong}` }}>
          <span/>
          <div>
            <div style={{ ...TYPE.title3, color: '#fff' }}>Free</div>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>TRIALIST · OPEN</div>
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ ...TYPE.title3, color: '#fff' }}>Elite</span>
              <span style={{ ...TYPE.micro, color: '#000', background: '#fff', padding: '2px 6px', borderRadius: 4, fontWeight: 700 }}>$199.99/YR</span>
            </div>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>MEMBER · 7-DAY TRIAL</div>
          </div>
        </div>
      </div>

      <div style={{ padding: '8px 20px 0' }}>
        {sections.map((s) => (
          <div key={s.head} style={{ paddingTop: 18 }}>
            <Eyebrow>{s.head}</Eyebrow>
            <div style={{ marginTop: 8 }}>
              {s.rows.map(([label, free, pro], i, arr) => (
                <div key={label} style={{
                  display: 'grid', gridTemplateColumns: '1.4fr 0.85fr 0.85fr',
                  alignItems: 'center', padding: '12px 0',
                  borderTop: `1px solid ${MF.line.hairline}`,
                  borderBottom: i === arr.length - 1 ? `1px solid ${MF.line.hairline}` : 'none',
                }}>
                  <span style={{ ...TYPE.foot, color: MF.ink.secondary, fontWeight: 500 }}>{label}</span>
                  <CmpCell v={free} kind="free"/>
                  <CmpCell v={pro}  kind="pro"/>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div style={{ padding: '28px 20px 0' }}>
        <PrimaryButton>Start 7-day trial</PrimaryButton>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, textAlign: 'center', marginTop: 12 }}>
          $199.99 / year · cancel any time
        </div>
      </div>
    </div>
  );
}
function CmpCell({ v, kind }) {
  if (v === 'no')  return <span style={{ ...TYPE.foot, color: MF.ink.disabled }}>—</span>;
  if (v === 'yes') return (
    <span style={{
      ...TYPE.micro, color: kind === 'pro' ? '#000' : '#fff',
      background: kind === 'pro' ? '#fff' : 'transparent',
      border: kind === 'pro' ? 'none' : `1px solid ${MF.line.subtle}`,
      padding: '3px 7px', borderRadius: 4, fontWeight: 700, width: 'fit-content',
    }}>YES</span>
  );
  return <span style={{ ...TYPE.foot, color: kind === 'pro' ? '#fff' : MF.ink.secondary, fontWeight: 500 }}>{v}</span>;
}

// ─── 9 · PRICING V2 — annual is the program, monthly is access ─
function ScrPaywallV2() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 32, position: 'relative', overflow: 'hidden' }}>
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.45, pointerEvents: 'none',
        backgroundImage: 'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.022) 44px, rgba(255,255,255,0.022) 45px)',
      }}/>

      <div style={{ position: 'relative', padding: '60px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>Restore</span>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10" stroke="#fff" strokeWidth="1.5" strokeLinecap="round"/></svg>
        </IconButton>
      </div>

      <div style={{ position: 'relative', padding: '28px 22px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <MFMark size={24}/>
          <Eyebrow>ELITE · ADMISSIONS</Eyebrow>
        </div>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 14, lineHeight: '46px', fontSize: 44 }}>
          A 12-month<br/>program
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 12, maxWidth: 320 }}>
          Built by Coach Matteo Finazzi. Six Elite Drills, thirty-one sessions,
          eleven position tracks, six earned badges.
        </div>
      </div>

      <div style={{ position: 'relative', padding: '24px 22px 0' }}>
        <div style={{ background: '#fff', color: '#000', borderRadius: 22, padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div style={{ ...TYPE.micro, color: 'rgba(0,0,0,0.6)' }}>ANNUAL · THE PROGRAM</div>
            <span style={{ ...TYPE.micro, color: '#fff', background: '#000', padding: '3px 7px', borderRadius: 4, fontWeight: 700 }}>SAVE 38%</span>
          </div>
          <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 14 }}>
            <span style={{ ...TYPE.num, fontSize: 56, lineHeight: '52px' }}>$199.99</span>
            <span style={{ ...TYPE.foot, color: 'rgba(0,0,0,0.55)', fontWeight: 600 }}>/ year · ≈ $16.67 mo</span>
          </div>
          <div style={{ height: 1, background: 'rgba(0,0,0,0.1)', margin: '14px 0' }}/>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            <PvLine>Full season · six Elite Drills</PvLine>
            <PvLine>All eleven position tracks</PvLine>
            <PvLine>Six earned badges across the ranks</PvLine>
            <PvLine>Streak, XP and rank ladder</PvLine>
          </div>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '12px 22px 0' }}>
        <div style={{ border: `1px solid ${MF.line.subtle}`, borderRadius: 22, padding: 16, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700 }}>Monthly access</div>
            <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 2 }}>For trying it out · cancel any time</div>
          </div>
          <div style={{ ...TYPE.num, fontSize: 22, color: '#fff' }}>$26.99</div>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '22px 22px 0' }}>
        <div style={{ display: 'flex', gap: 10 }}>
          <TrustChip>7-day trial</TrustChip>
          <TrustChip>Cancel any time</TrustChip>
          <TrustChip>No in-app ads</TrustChip>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '22px 22px 0' }}>
        <PrimaryButton>Begin 7-day trial</PrimaryButton>
        <div style={{ display: 'flex', justifyContent: 'center', gap: 14, marginTop: 12, ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>
          <span>Redeem code</span><Sep/><span>Terms</span><Sep/><span>Privacy</span>
        </div>
        <div style={{ ...TYPE.cap, color: MF.ink.quaternary, textAlign: 'center', marginTop: 8, padding: '0 12px' }}>
          Auto-renewing. $199.99/yr after trial unless cancelled 24h prior.
        </div>
      </div>
    </div>
  );
}

function PvLine({ children }) {
  return (
    <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start' }}>
      <div style={{ width: 14, height: 14, borderRadius: 7, background: '#000', flexShrink: 0, marginTop: 3, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <svg width="7" height="7" viewBox="0 0 7 7"><path d="M1 4l1.5 1.5L6 1.5" stroke="#fff" strokeWidth="1.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
      </div>
      <span style={{ ...TYPE.callout, color: '#000', fontWeight: 500, lineHeight: '20px' }}>{children}</span>
    </div>
  );
}
function TrustChip({ children }) {
  return (
    <span style={{ ...TYPE.foot, color: '#fff', fontWeight: 600, padding: '8px 12px', borderRadius: 999, border: `1px solid ${MF.line.subtle}`, whiteSpace: 'nowrap' }}>{children}</span>
  );
}

// ─── 10 · PARENT VALUE — inside the app, for the cheque-writer ─
function ScrParentValue() {
  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      <div style={{ padding: '60px 20px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <IconButton style={{ width: 36, height: 36, borderRadius: 18, background: 'transparent', border: `1px solid ${MF.line.subtle}` }}>
          <svg width="14" height="14" viewBox="0 0 14 14"><path d="M9 1L3 7l6 6" stroke="#fff" strokeWidth="1.5" fill="none"/></svg>
        </IconButton>
        <Eyebrow>FOR PARENTS</Eyebrow>
        <span style={{ width: 36 }}/>
      </div>

      <div style={{ padding: '22px 20px 0' }}>
        <Eyebrow>A NOTE FROM THE COACH</Eyebrow>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 12, fontSize: 38, lineHeight: '42px' }}>
          The program<br/>not the app
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 14, lineHeight: '23px' }}>
          MF Elite is a 12-month one-on-one development program for serious
          young players. Your child trains; the academy keeps the receipts.
        </div>
      </div>

      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 18, display: 'flex', alignItems: 'center', gap: 14 }}>
          <Monogram size={64} initials="MF" kit={null}/>
          <div style={{ flex: 1 }}>
            <div style={{ ...TYPE.title3, color: '#fff' }}>Coach Matteo Finazzi</div>
            <div style={{ ...TYPE.micro, color: MF.ink.tertiary, marginTop: 4 }}>HEAD COACH · MF ELITE ACADEMY</div>
          </div>
        </div>
      </div>

      <div style={{ padding: '28px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 14 }}>WHAT YOUR CHILD GETS</Eyebrow>
        <ParentRow n="01" t="A written plan" b="Six Elite Drills across the season. Sessions scheduled by week."/>
        <ParentRow n="02" t="A real coach by name" b="Curriculum and film built by Coach Matteo Finazzi."/>
        <ParentRow n="03" t="Position-specific training" b="Eleven position tracks. Your child trains for the role they play."/>
        <ParentRow n="04" t="Habit, ranked" b="Streaks, XP and ranks make consistency visible. No casino mechanics."/>
        <ParentRow n="05" t="Badges, earned" b="Six gamified badges across the rank ladder. Never bought, never shipped." last/>
      </div>

      <div style={{ padding: '28px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 14 }}>WHAT YOU SEE EACH SUNDAY</Eyebrow>
        <div style={{ border: `1px solid ${MF.line.hairline}`, borderRadius: 18, padding: 18, background: MF.bg.card }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <Eyebrow>WEEKLY RECAP · WEEK 12</Eyebrow>
            <Eyebrow>SUN 17 MAR</Eyebrow>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 14, marginTop: 14 }}>
            <BigStat label="MINUTES" value="184"/>
            <BigStat label="DRILLS" value="22"/>
            <BigStat label="STREAK" value="12"/>
          </div>
          <div style={{ ...TYPE.foot, color: MF.ink.secondary, marginTop: 14, lineHeight: '19px' }}>
            Three drills closer to Prospect. The half-turn Elite Drill is on
            track to close by the end of next week.
          </div>
        </div>
      </div>

      <div style={{ padding: '24px 20px 0' }}>
        <PrimaryButton>$199.99 / year · begin the program</PrimaryButton>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, textAlign: 'center', marginTop: 12 }}>
          7-day trial · cancel from any device
        </div>
      </div>
    </div>
  );
}

function ParentRow({ n, t, b, last }) {
  return (
    <div style={{
      display: 'flex', gap: 14, padding: '14px 0',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
    }}>
      <span style={{ ...TYPE.num, fontSize: 18, color: MF.ink.tertiary, width: 26, flexShrink: 0 }}>{n}</span>
      <div>
        <div style={{ ...TYPE.title3, color: '#fff' }}>{t}</div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 4, lineHeight: '18px' }}>{b}</div>
      </div>
    </div>
  );
}

// ─── 11 · PREMIUM WELCOME — first screen after joining ────────
function ScrPremiumWelcome() {
  return (
    <div style={{ width: '100%', height: '100%', background: '#000', position: 'relative', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.45,
        backgroundImage: 'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.025) 44px, rgba(255,255,255,0.025) 45px)',
      }}/>

      <div style={{ position: 'relative', padding: '60px 24px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Eyebrow>WELCOME TO THE ACADEMY</Eyebrow>
        <Eyebrow>DAY ONE</Eyebrow>
      </div>

      <div style={{ position: 'relative', padding: '40px 24px 0', flex: 1, display: 'flex', flexDirection: 'column', gap: 22 }}>
        <MFMark size={64}/>
        <div style={{ ...TYPE.hero, color: '#fff', lineHeight: '50px', fontSize: 50, letterSpacing: -1.8 }}>
          You’re in
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, maxWidth: 320, lineHeight: '23px' }}>
          From today, your training is part of a program. Six Elite Drills. One
          coach. Your streak does not pause.
        </div>

        <SlashRule style={{ margin: '8px 0' }}/>

        <Eyebrow>WHAT YOU’VE JUST UNLOCKED</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <ValueLine>Six Elite Drills of the MF Method</ValueLine>
          <ValueLine>Eleven position tracks · pick your role</ValueLine>
          <ValueLine>Streak, XP and the six-rank ladder</ValueLine>
          <ValueLine>Badges — earned by rank, never bought</ValueLine>
        </div>
      </div>

      <div style={{ position: 'relative', padding: '24px 24px 36px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        <PrimaryButton>Open Elite Drill 1</PrimaryButton>
        <GhostButton>Tour the academy first</GhostButton>
      </div>
    </div>
  );
}

Object.assign(window, {
  ScrFreeDashboard, ScrLockedDrill, ScrLockedChapter,
  ScrRankProfile, ScrLocker,
  ScrUpgradeStreak, ScrUpgradeChapter,
  ScrTierCompare, ScrPaywallV2,
  ScrParentValue, ScrPremiumWelcome,
});
