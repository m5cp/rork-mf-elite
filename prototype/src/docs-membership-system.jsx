// MF Elite — Membership & Progression system docs
// Editorial boards explaining the monetization philosophy, rank ladder,
// retention loop, and the parent brief. Pure system, not screens.

// ─── Shared bits ──────────────────────────────────────────────
function DocFrame({ width, height, eyebrow, title, children, style = {} }) {
  return (
    <div style={{
      width, height, padding: '40px 44px', boxSizing: 'border-box',
      background: '#000', color: '#fff', borderRadius: 24,
      border: `1px solid ${MF.line.hairline}`,
      display: 'flex', flexDirection: 'column', gap: 22,
      position: 'relative', overflow: 'hidden',
      ...style,
    }}>
      {/* faint diagonal field — academy signature */}
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.4, pointerEvents: 'none',
        backgroundImage:
          'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.022) 44px, rgba(255,255,255,0.022) 45px)',
      }}/>
      <div style={{ position: 'relative', zIndex: 1, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <MFMark size={22}/>
          <Eyebrow>{eyebrow}</Eyebrow>
        </div>
        <Eyebrow style={{ color: MF.ink.quaternary }}>MF · INTERNAL DOC</Eyebrow>
      </div>
      <div style={{ position: 'relative', zIndex: 1, ...TYPE.display, color: '#fff', textWrap: 'balance', lineHeight: '40px' }}>
        {title}
      </div>
      <div style={{ position: 'relative', zIndex: 1, flex: 1, minHeight: 0 }}>{children}</div>
    </div>
  );
}

function DocCol({ children, style = {} }) {
  return <div style={{ display: 'flex', flexDirection: 'column', gap: 14, ...style }}>{children}</div>;
}

function DocLead({ children, color = MF.ink.secondary, size = 16 }) {
  return (
    <div style={{
      fontFamily: MF.font.text, fontWeight: 400, fontSize: size, lineHeight: '24px',
      color, textWrap: 'pretty', letterSpacing: -0.1,
    }}>{children}</div>
  );
}

function DocPrinciple({ n, title, body }) {
  return (
    <div style={{ display: 'flex', gap: 16, paddingTop: 14, borderTop: `1px solid ${MF.line.hairline}` }}>
      <div style={{ ...TYPE.num, fontSize: 22, lineHeight: '22px', color: MF.ink.tertiary, width: 28, flexShrink: 0 }}>{n}</div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <div style={{ ...TYPE.title3, color: '#fff' }}>{title}</div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, lineHeight: '18px' }}>{body}</div>
      </div>
    </div>
  );
}

// ─── 1 · DOCTRINE — Free vs Premium tiers, editorial ───
function BrdMembershipDoctrine() {
  return (
    <DocFrame
      width={840} height={1180}
      eyebrow="MEMBERSHIP · DOCTRINE"
      title={<>What you get<br/>What you earn<br/>What you pay for</>}
    >
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 36, height: '100%' }}>
        {/* LEFT — narrative */}
        <DocCol>
          <DocLead size={17}>
            MF Elite is not a subscription. It is admission to a private
            development academy. Three economies run in parallel — none of
            them feel like a paywall.
          </DocLead>

          <SlashRule style={{ margin: '6px 0' }}/>

          <DocPrinciple n="01" title="Money buys access"
            body="The full curriculum, every coach, every Elite Drill, position-specific training — gated behind one calm decision: join the academy."/>
          <DocPrinciple n="02" title="Time earns status"
            body="Streaks, completed drills, and Elite Drill milestones grant XP. XP raises your rank in the academy — Trialist → Cadet → Prospect → Starter → Captain → The Eleven."/>
          <DocPrinciple n="03" title="Rank earns the badge"
            body="Six gamified badges, one per rank, plus dossier prestige — earned through consistency. Never sold. No physical product, no shortcut."/>
          <DocPrinciple n="04" title="Lock screens are admissions desks"
            body="No padlock icons everywhere. A locked drill says 'Reserved for members'. A locked Elite Drill shows the syllabus you have not been admitted to yet."/>
          <DocPrinciple n="05" title="Parents pay for structure"
            body="The premium experience is messaged to parents as a development program — discipline, a coach by name, a written plan — not as more videos."/>
        </DocCol>

        {/* RIGHT — the tier table, editorial style */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
          <Eyebrow>THE TWO TIERS</Eyebrow>
          <TierColumns/>

          <div style={{ marginTop: 14, padding: '14px 16px', border: `1px solid ${MF.line.subtle}`, borderRadius: 14 }}>
            <Eyebrow style={{ color: '#fff' }}>HOUSE RULE</Eyebrow>
            <DocLead size={14}>
              Cosmetic rewards are <i>only</i> earned, never sold.
              Premium buys the program, not the prestige.
            </DocLead>
          </div>
        </div>
      </div>
    </DocFrame>
  );
}

function TierColumns() {
  const rows = [
    ['Dashboard · today’s session',   'free', 'pro'],
    ['Streak + XP system',                  'free', 'pro'],
    ['Drill library',                       '6 of 80',          'all 80'],
    ['MF Hub · curriculum',                 'Elite Drill 1 only',   '1 — 6'],
    ['Position-specific tracks',            'striker preview',  '11 positions'],
    ['All academy coaches',                 'Matteo · Ch I',    'all coaches'],
    ['Rank ladder · 6 badges',              'Trialist only',    'all 6 ranks'],
    ['Routines · prebuilt',                 'morning only',     'morning · field · recovery'],
    ['Avatar · dossier · monogram',         'basic',            'full + earned'],
    ['Apple Watch · Live Activities',       'no',               'yes'],
    ['Playbook library · PDFs',             '2 of 6 included',  'all included'],
  ];
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '1.4fr 0.9fr 0.9fr', columnGap: 0, rowGap: 0 }}>
      <TierHead label=""/><TierHead label="FREE"/><TierHead label="ELITE"/>
      {rows.map((r, i) => <TierRow key={i} row={r} last={i === rows.length - 1}/>)}
    </div>
  );
}
function TierHead({ label }) {
  return (
    <div style={{
      ...TYPE.micro, color: MF.ink.tertiary, letterSpacing: 1.6,
      padding: '0 0 10px', borderBottom: `1px solid ${MF.line.subtle}`,
    }}>{label}</div>
  );
}
function TierRow({ row, last }) {
  const [label, free, pro] = row;
  const cellSty = {
    padding: '11px 0',
    borderBottom: last ? 'none' : `1px solid ${MF.line.hairline}`,
  };
  const valSty = (kind, value) => {
    if (value === 'no')   return { ...TYPE.foot, color: MF.ink.disabled };
    if (value === 'free' || value === 'pro') return null;
    return { ...TYPE.foot, color: kind === 'pro' ? '#fff' : MF.ink.secondary, fontWeight: 500 };
  };
  const cell = (kind, v) => {
    if (v === 'pro') return <span style={{ ...TYPE.micro, color: '#000', background: '#fff', padding: '2px 6px', borderRadius: 4, fontWeight: 700 }}>YES</span>;
    if (v === 'free')return <span style={{ ...TYPE.micro, color: '#fff', border: `1px solid ${MF.line.subtle}`, padding: '2px 6px', borderRadius: 4 }}>YES</span>;
    if (v === 'no')  return <span style={{ ...TYPE.foot, color: MF.ink.disabled }}>—</span>;
    return <span style={valSty(kind, v)}>{v}</span>;
  };
  return (
    <>
      <div style={{ ...cellSty, ...TYPE.foot, color: MF.ink.secondary, fontWeight: 500 }}>{label}</div>
      <div style={cellSty}>{cell('free', free)}</div>
      <div style={cellSty}>{cell('pro', pro)}</div>
    </>
  );
}

// ─── 2 · RANK LADDER — Trialist → The Eleven ─────────────────
function BrdRankLadder() {
  const ranks = [
    { roman: 'I',   name: 'TRIALIST',  cond: 'Day 1 · admitted',                   reward: 'Passport · dossier opens',  cap: 100 },
    { roman: 'II',  name: 'CADET',     cond: 'Elite Drill 1 complete · 7-day streak',  reward: 'Cadet badge · dossier mark',               cap: 500 },
    { roman: 'III', name: 'PROSPECT',  cond: '3 Elite Drills · 30-day streak',         reward: 'Prospect badge · ladder mark',             cap: 1800 },
    { roman: 'IV',  name: 'STARTER',   cond: '5 Elite Drills · 90-day streak',         reward: 'Starter badge · academy wall entry',       cap: 4500 },
    { roman: 'V',   name: 'CAPTAIN',   cond: 'Full season · 180 days',             reward: 'Captain badge · permanent dossier title',  cap: 9000 },
    { roman: 'VI',  name: 'THE ELEVEN',cond: '365 days · perfect · coach invite',  reward: 'The Eleven badge · 1 of 11',               cap: null, invite: true },
  ];
  return (
    <DocFrame
      width={780} height={980}
      eyebrow="PROGRESSION · RANK"
      title={<>The ladder<br/>Earned, never bought</>}
    >
      <DocLead>
        Six ranks. Each grants kit, dossier prestige and a new tier of academy
        privileges. Money cannot move you up by one step.
      </DocLead>

      <SlashRule/>

      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {ranks.map((r, i) => <RankRow key={r.name} {...r} idx={i} current={i === 1}/>)}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 14, marginTop: 6 }}>
        <RankNote label="XP SOURCES" body="Drill complete · 25 · Elite Drill end · 200 · 7-day streak · 80 · Routine streak · 40"/>
        <RankNote label="DECAY" body="Streak breaks reset to 0. XP banked is never lost. Rank, once earned, is permanent."/>
        <RankNote label="HOUSE RULE" body="No XP boosters. No skip-tier purchases. No paid badges. Pace is the point."/>
      </div>
    </DocFrame>
  );
}

function RankRow({ roman, name, cond, reward, cap, idx, current, invite }) {
  const fill = Math.min(1, (cap ? 0.35 : 0));
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '54px 1fr 1.1fr 110px',
      gap: 18, alignItems: 'center',
      padding: '18px 0',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: idx === 5 ? `1px solid ${MF.line.hairline}` : 'none',
      background: current ? 'rgba(255,255,255,0.04)' : 'transparent',
      paddingLeft: current ? 12 : 0, paddingRight: current ? 12 : 0,
      borderRadius: current ? 12 : 0,
    }}>
      <div style={{
        ...TYPE.num, fontSize: 36, lineHeight: '32px',
        fontStyle: 'italic', fontVariantNumeric: 'normal',
        color: current ? '#fff' : MF.ink.tertiary,
        letterSpacing: -1,
      }}>{roman}</div>
      <div>
        <div style={{ ...TYPE.title3, color: '#fff', letterSpacing: 0.4 }}>{name}</div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 4 }}>{cond}</div>
      </div>
      <div>
        <Eyebrow>REWARD</Eyebrow>
        <div style={{ ...TYPE.foot, color: '#fff', marginTop: 4, fontWeight: 500 }}>{reward}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        {invite
          ? <span style={{ ...TYPE.micro, color: '#000', background: '#fff', padding: '4px 8px', borderRadius: 4, fontWeight: 700 }}>INVITE</span>
          : <>
              <div style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{cap} XP</div>
              <div style={{ marginTop: 6, height: 3, background: MF.line.subtle, borderRadius: 2, overflow: 'hidden' }}>
                <div style={{ width: `${current ? 64 : (idx === 0 ? 100 : 0)}%`, height: '100%', background: '#fff' }}/>
              </div>
            </>}
      </div>
    </div>
  );
}

function RankNote({ label, body }) {
  return (
    <div style={{ padding: '14px 0 0', borderTop: `1px solid ${MF.line.subtle}` }}>
      <Eyebrow style={{ color: '#fff' }}>{label}</Eyebrow>
      <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 8, lineHeight: '17px' }}>{body}</div>
    </div>
  );
}

// ─── 3 · RETENTION LOOP — psychology diagram ─────────────────
function BrdRetentionLoop() {
  return (
    <DocFrame
      width={820} height={820}
      eyebrow="RETENTION · LOOP"
      title={<>How the academy<br/>keeps showing up</>}
    >
      <DocLead>
        Five loops nested inside each other — minute, day, week, Elite Drill, season.
        Each loop has a reward the next loop depends on. Quitting at any level
        forfeits one rung of pride, not money.
      </DocLead>

      <div style={{ display: 'grid', gridTemplateColumns: '1.05fr 1fr', gap: 28, marginTop: 6, flex: 1, minHeight: 0 }}>
        <LoopDiagram/>
        <DocCol style={{ gap: 12 }}>
          <LoopRow scale="MINUTE"  hook="Begin session"     payoff="+25 XP · drill complete"      emo="Tiny win"/>
          <LoopRow scale="DAY"     hook="Streak ticks +1"   payoff="Flame on dossier · day stamp" emo="I showed up"/>
          <LoopRow scale="WEEK"    hook="7-day streak"      payoff="+80 XP · weekly recap"        emo="On a run"/>
          <LoopRow scale="ELITE DRILL" hook="Elite Drill complete"  payoff="+200 XP · next Elite Drill opens" emo="I’m advancing"/>
          <LoopRow scale="SEASON"  hook="Rank up"           payoff="New badge · new title · dossier" emo="I am becoming"/>

          <div style={{ marginTop: 12, padding: '14px 16px', border: `1px solid ${MF.line.subtle}`, borderRadius: 14 }}>
            <Eyebrow style={{ color: '#fff' }}>PSYCHOLOGICAL ANCHOR</Eyebrow>
            <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 8, lineHeight: '18px' }}>
              The streak is the heartbeat. The rank is the identity. The
              badge is the proof. Lose any one for too long and the player
              feels the academy slipping — not the app.
            </div>
          </div>
        </DocCol>
      </div>
    </DocFrame>
  );
}

function LoopDiagram() {
  // Five nested rings — radii in a 280px square
  const rings = [
    { r: 130, label: 'SEASON',  ang: 200 },
    { r: 104, label: 'ELITE DRILL', ang: 150 },
    { r:  80, label: 'WEEK',    ang: 100 },
    { r:  56, label: 'DAY',     ang:  50 },
    { r:  32, label: 'MINUTE',  ang:   0 },
  ];
  return (
    <div style={{
      position: 'relative', width: '100%', aspectRatio: '1 / 1',
      background: '#0a0a0a', border: `1px solid ${MF.line.hairline}`, borderRadius: 18,
      display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
    }}>
      <svg viewBox="-160 -160 320 320" width="100%" height="100%">
        {rings.map((rg, i) => (
          <g key={i}>
            <circle cx="0" cy="0" r={rg.r} fill="none" stroke={i === 0 ? '#fff' : 'rgba(255,255,255,0.18)'} strokeWidth={i === 0 ? 1.2 : 0.7} strokeDasharray={i === 0 ? '' : '2 3'}/>
            <text
              x={rg.r * Math.cos(rg.ang * Math.PI / 180)}
              y={rg.r * Math.sin(rg.ang * Math.PI / 180)}
              fill="#fff" fontSize="9" letterSpacing="1.5" fontFamily="ui-monospace, monospace"
              textAnchor="middle" dominantBaseline="middle"
            >{rg.label}</text>
          </g>
        ))}
        {/* center MF mark mock */}
        <circle cx="0" cy="0" r="14" fill="#fff"/>
        <text x="0" y="0" fill="#000" fontSize="10" fontWeight="800" textAnchor="middle" dominantBaseline="middle" fontFamily="-apple-system, system-ui">MF</text>
        {/* arrows hinting clockwise motion on the outer ring */}
        {[0, 72, 144, 216, 288].map((a, i) => (
          <g key={i} transform={`rotate(${a})`}>
            <path d={`M ${130} -4 L ${134} 0 L ${130} 4 Z`} fill="#fff"/>
          </g>
        ))}
      </svg>
    </div>
  );
}

function LoopRow({ scale, hook, payoff, emo }) {
  return (
    <div style={{
      display: 'grid', gridTemplateColumns: '70px 1fr 1fr 0.8fr',
      gap: 12, alignItems: 'baseline',
      padding: '10px 0', borderTop: `1px solid ${MF.line.hairline}`,
    }}>
      <Eyebrow style={{ color: '#fff' }}>{scale}</Eyebrow>
      <span style={{ ...TYPE.foot, color: '#fff', fontWeight: 500 }}>{hook}</span>
      <span style={{ ...TYPE.foot, color: MF.ink.tertiary }}>{payoff}</span>
      <span style={{ ...TYPE.micro, color: MF.ink.tertiary, textAlign: 'right' }}>{emo}</span>
    </div>
  );
}

// ─── 4 · PARENT BRIEF — language and value, not pricing ──────
function BrdParentBrief() {
  return (
    <DocFrame
      width={780} height={920}
      eyebrow="PARENT · BRIEF"
      title={<>For the people<br/>who write the cheque</>}
    >
      <div style={{ display: 'grid', gridTemplateColumns: '1.1fr 1fr', gap: 28, flex: 1, minHeight: 0 }}>
        <DocCol>
          <DocLead size={17}>
            A 12-year-old does not buy a development program. Their parent does —
            and a parent is not buying drills. They are buying structure,
            accountability and the feeling that someone serious is paying
            attention to their child.
          </DocLead>

          <SlashRule/>

          <DocPrinciple n="01" title="Show the system, not the screens"
            body="The paywall opens to a one-page program brief — six Elite Drills, twelve months, one coach by name, six earned badges — not a feature grid."/>
          <DocPrinciple n="02" title="Discipline is the headline"
            body="The streak, the rank, the Elite Drill ladder — language a parent recognises from school reports and clubs."/>
          <DocPrinciple n="03" title="Coach Matteo by name"
            body="A program written by a person, not an app. Photo, signature, league background — visible on the parent screen."/>
          <DocPrinciple n="04" title="A receipt of effort"
            body="Weekly recap inside the app: minutes trained, drills completed, current rank, streak intact. Parent gets the proof; player keeps the privacy."/>
          <DocPrinciple n="05" title="One number, one promise"
            body="$199.99 / year. 7-day trial. Cancel from any device. No upsells inside. No cosmetic purchases for the child to ask for later."/>
        </DocCol>

        <DocCol>
          <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 16 }}>
            <Eyebrow>WHAT PARENTS HEAR (HEADLINES)</Eyebrow>
            <ul style={{ margin: '10px 0 0', padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 10 }}>
              {[
                'A private coach in your child’s pocket.',
                'A 12-month program, not a video library.',
                'Position-specific training. By role.',
                'Habit, ranked. Discipline, visible.',
                'No advertising. No in-app purchases for kids.',
                'One annual decision. Cancel any time.',
              ].map((s, i) => (
                <li key={i} style={{ display: 'flex', gap: 10 }}>
                  <span style={{ ...TYPE.num, fontSize: 14, color: MF.ink.tertiary, width: 20 }}>0{i+1}</span>
                  <span style={{ ...TYPE.foot, color: '#fff', fontWeight: 500 }}>{s}</span>
                </li>
              ))}
            </ul>
          </div>

          <div style={{ padding: 18, border: `1px solid ${MF.line.subtle}`, borderRadius: 16, marginTop: 4 }}>
            <Eyebrow>WHAT WE NEVER SAY</Eyebrow>
            <ul style={{ margin: '10px 0 0', padding: 0, listStyle: 'none', display: 'flex', flexDirection: 'column', gap: 8 }}>
              {[
                'Unlock', 'Premium', 'Upgrade now',
                'Limited time', 'Free trial ending', 'Don’t miss out',
              ].map((s, i) => (
                <li key={i} style={{ ...TYPE.foot, color: MF.ink.disabled, textDecoration: 'line-through', textDecorationColor: 'rgba(255,255,255,0.25)' }}>{s}</li>
              ))}
            </ul>
          </div>

          <div style={{ marginTop: 6, ...TYPE.foot, color: MF.ink.tertiary, fontStyle: 'italic', lineHeight: '18px' }}>
            The word "academy" appears 11× in the app. The word "subscription" appears zero.
          </div>
        </DocCol>
      </div>
    </DocFrame>
  );
}

Object.assign(window, {
  BrdMembershipDoctrine, BrdRankLadder, BrdRetentionLoop, BrdParentBrief,
});
