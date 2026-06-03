// MF Elite — Phone wrapper + Canvas composition

// Phone shell with optional tab bar overlay
function Phone({ children, tab = null, width = 402, height = 874 }) {
  return (
    <IOSDevice width={width} height={height} dark={true}>
      {/* height:100% so children with height:100% resolve correctly;
          scrollable screens still overflow upward and the IOSDevice
          content div's overflow:auto catches the scroll. */}
      <div style={{ position: 'relative', width: '100%', height: '100%' }}>
        {children}
        {tab && <TabBar active={tab}/>}
      </div>
    </IOSDevice>
  );
}

// A non-phone artboard wrapper that just renders the board directly.
// design_canvas frames it with the chrome we want.

function App() {
  return (
    <DesignCanvas>
      <DCSection id="brand" title="MF Elite Training" subtitle="Brand foundation · the logo and motif">
        <DCArtboard id="brand-board" label="Brand mark · motif" width={720} height={620}>
          <BrandBoard/>
        </DCArtboard>
      </DCSection>

      <DCSection id="academy" title="★ Academy Curriculum System" subtitle="The evolved MF Hub · Discipline → Category → Level → Drill · a scalable player-development pathway built from the curriculum">
        <DCArtboard id="acad-today"   label="Today · curriculum home"       width={402} height={874}><Phone tab="dashboard"><ScrAcademyToday/></Phone></DCArtboard>
        <DCArtboard id="acad-hub"     label="Academy Hub · 4 pathways"      width={402} height={874}><Phone tab="hub"><ScrAcademyHub/></Phone></DCArtboard>
        <DCArtboard id="acad-disc"    label="Pathway · Technical"           width={402} height={874}><Phone tab="hub"><ScrDiscipline/></Phone></DCArtboard>
        <DCArtboard id="acad-cat"     label="Category · Ball Mastery"       width={402} height={874}><Phone tab="hub"><ScrCategory/></Phone></DCArtboard>
        <DCArtboard id="acad-level"   label="Level · drills inside"         width={402} height={874}><Phone tab="hub"><ScrLevel/></Phone></DCArtboard>
        <DCArtboard id="acad-drill"   label="Drill · 6-part video format"   width={402} height={874}><Phone><ScrAcademyDrill/></Phone></DCArtboard>
        <DCArtboard id="acad-master"  label="Moment · Level Mastered"       width={402} height={874}><Phone><ScrLevelMastered/></Phone></DCArtboard>
        <DCArtboard id="acad-award"   label="Moment · Skill Certified"      width={402} height={874}><Phone><ScrCertAward/></Phone></DCArtboard>
        <DCArtboard id="acad-prog"    label="Academy progression · rank"    width={402} height={874}><Phone tab="profile"><ScrAcademyProgress/></Phone></DCArtboard>
        <DCArtboard id="acad-cert"    label="Skill certifications"          width={402} height={874}><Phone tab="profile"><ScrCertifications/></Phone></DCArtboard>
        <DCArtboard id="acad-parent"  label="Parent · progress report"      width={402} height={874}><Phone><ScrParentReport/></Phone></DCArtboard>
        <DCArtboard id="acad-card"    label="Parent · report card"          width={402} height={874}><Phone><ScrReportCard/></Phone></DCArtboard>
        <DCArtboard id="acad-admin"   label="Coach · Curriculum Manager"    width={402} height={874}><Phone><ScrCurriculumAdmin/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="training-loop" title="★ Training & Habit Loop" subtitle="The core action — doing a drill — plus search across 150+ drills and the streak engine that brings players back">
        <DCArtboard id="play-ready"  label="Drill player · get ready"    width={402} height={874}><Phone><ScrPlayerReady/></Phone></DCArtboard>
        <DCArtboard id="play-active" label="Drill player · timer running" width={402} height={874}><Phone><ScrPlayerActive/></Phone></DCArtboard>
        <DCArtboard id="play-logged" label="Drill player · set logged"    width={402} height={874}><Phone><ScrPlayerLogged/></Phone></DCArtboard>
        <DCArtboard id="acad-search" label="Search · all 150+ drills"     width={402} height={874}><Phone tab="hub"><ScrCurriculumSearch/></Phone></DCArtboard>
        <DCArtboard id="streak-detail" label="Streak · detail"           width={402} height={874}><Phone tab="profile"><ScrStreakDetail/></Phone></DCArtboard>
        <DCArtboard id="streak-push"   label="Re-engagement · push"      width={402} height={874}><Phone><ScrStreakNotifications/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="onboarding" title="01 · Onboarding" subtitle="Splash → 6 cinematic Elite Drills · invitation to admission">
        <DCArtboard id="splash"     label="Splash · By invitation" width={402} height={874}><Phone><ScrSplash/></Phone></DCArtboard>
        <DCArtboard id="onb-code"   label="01 · The Code"         width={402} height={874}><Phone><ScrOnboardCode/></Phone></DCArtboard>
        <DCArtboard id="onb-name"   label="02 · Identify"         width={402} height={874}><Phone><ScrOnboardIdentify/></Phone></DCArtboard>
        <DCArtboard id="onb-pos"    label="03 · Position"         width={402} height={874}><Phone><ScrOnboardPosition/></Phone></DCArtboard>
        <DCArtboard id="onb-pledge" label="04 · The Pledge"       width={402} height={874}><Phone><ScrOnboardPledge/></Phone></DCArtboard>
        <DCArtboard id="onb-num"    label="05 · Your number"      width={402} height={874}><Phone><ScrOnboardNumber/></Phone></DCArtboard>
        <DCArtboard id="onb-pass"   label="06 · Passport"         width={402} height={874}><Phone><ScrOnboardPassport/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="core" title="02 · Core navigation" subtitle="Four tabs · Today · MF Hub · Progress · Profile · drill library + routines">
        <DCArtboard id="dashboard"     label="Today · Academy home"     width={402} height={874}><Phone tab="dashboard"><ScrAcademyToday/></Phone></DCArtboard>
        <DCArtboard id="hub"           label="MF Hub · Academy Curriculum" width={402} height={874}><Phone tab="hub"><ScrAcademyHub/></Phone></DCArtboard>
        <DCArtboard id="drill-library" label="Drill library · select"   width={402} height={874}><Phone tab="hub"><ScrDrillLibrary/></Phone></DCArtboard>
        <DCArtboard id="routines"      label="Routines · prebuilt"      width={402} height={874}><Phone tab="hub"><ScrRoutines/></Phone></DCArtboard>
        <DCArtboard id="progress"      label="Progress"                 width={402} height={874}><Phone tab="progress"><ScrProgress/></Phone></DCArtboard>
        <DCArtboard id="profile"       label="Profile"                  width={402} height={874}><Phone tab="profile"><ScrProfile/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="training" title="03 · Training loop" subtitle="Two drill detail versions · active player · weekly breakdown">
        <DCArtboard id="drill-film" label="Drill · with film"  width={402} height={874}><Phone><ScrDrillDetailFilm/></Phone></DCArtboard>
        <DCArtboard id="drill-type" label="Drill · no film"    width={402} height={874}><Phone><ScrDrillDetailType/></Phone></DCArtboard>
        <DCArtboard id="player"     label="Active drill · player" width={402} height={874}><Phone><ScrPlayerActive/></Phone></DCArtboard>
        <DCArtboard id="weekly"     label="Weekly breakdown"   width={402} height={874}><Phone><ScrWeekly/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="commerce" title="04 · Commerce" subtitle="Paywall is the MVP commerce surface · Shop ships in v1.1">
        <DCArtboard id="paywall" label="Paywall · MVP"           width={402} height={874}><Phone><ScrPaywall/></Phone></DCArtboard>
        <DCArtboard id="shop"    label="Playbook library · v1.1" width={402} height={874}><Phone><ScrShop/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="membership-free" title="05 · Free experience" subtitle="The free dashboard, locked drill, and locked Elite Drill — premium-feeling, not frustrating">
        <DCArtboard id="mb-free-home" label="Free dashboard · trialist" width={402} height={874}><Phone tab="dashboard"><ScrFreeDashboard/></Phone></DCArtboard>
        <DCArtboard id="mb-lock-drill" label="Locked drill · reserved" width={402} height={874}><Phone><ScrLockedDrill/></Phone></DCArtboard>
        <DCArtboard id="mb-lock-chap" label="Locked Elite Drill · syllabus" width={402} height={874}><Phone><ScrLockedChapter/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="membership-progression" title="06 · Progression · XP & rank" subtitle="What time and consistency earn · the rank screen and the badges gallery">
        <DCArtboard id="mb-rank"   label="Your standing · rank + XP"  width={402} height={874}><Phone tab="profile"><ScrRankProfile/></Phone></DCArtboard>
        <DCArtboard id="mb-locker" label="Badges · earned by rank"   width={402} height={874}><Phone tab="profile"><ScrLocker/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="membership-upgrade" title="07 · Upgrade moments" subtitle="Natural triggers · streak milestone, Elite Drill gate, side-by-side, pricing">
        <DCArtboard id="mb-up-streak" label="Trigger · 7-day streak" width={402} height={874}><Phone><ScrUpgradeStreak/></Phone></DCArtboard>
        <DCArtboard id="mb-up-chap"   label="Trigger · Elite Drill gate" width={402} height={874}><Phone><ScrUpgradeChapter/></Phone></DCArtboard>
        <DCArtboard id="mb-compare"   label="Free vs Elite"          width={402} height={874}><Phone><ScrTierCompare/></Phone></DCArtboard>
        <DCArtboard id="mb-paywall2"  label="Paywall v2 · annual"    width={402} height={874}><Phone><ScrPaywallV2/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="membership-onboard" title="08 · Premium onboarding · parents" subtitle="Welcome screen after joining · the parent-facing brief inside the app">
        <DCArtboard id="mb-welcome" label="Welcome to the academy"  width={402} height={874}><Phone><ScrPremiumWelcome/></Phone></DCArtboard>
        <DCArtboard id="mb-parent-ui" label="For parents · in-app"  width={402} height={874}><Phone><ScrParentValue/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="admin" title="09 · Settings & Coach" subtitle="Player settings · separate Coach admin entry · expanded coach workspace">
        <DCArtboard id="settings"     label="Settings · player"        width={402} height={874}><Phone><ScrSettings/></Phone></DCArtboard>
        <DCArtboard id="coach-login"  label="Coach login · admin"      width={402} height={874}><Phone><ScrCoachLogin/></Phone></DCArtboard>
        <DCArtboard id="coach"        label="Coach roster · toolbox"   width={402} height={874}><Phone><ScrCoach/></Phone></DCArtboard>
        <DCArtboard id="coach-build"  label="Coach · Build session"    width={402} height={874}><Phone><ScrCoachBuild/></Phone></DCArtboard>
      </DCSection>

      <DCSection id="membership-doc" title="10 · Membership · doctrine" subtitle="The system · what is free · what is earned · what is paid · how parents read it">
        <DCArtboard id="mb-doctrine" label="Doctrine · tier table"  width={840} height={1180}><BrdMembershipDoctrine/></DCArtboard>
        <DCArtboard id="mb-ranks"    label="The rank ladder"        width={780} height={980}><BrdRankLadder/></DCArtboard>
        <DCArtboard id="mb-loop"     label="Retention loop"         width={820} height={820}><BrdRetentionLoop/></DCArtboard>
        <DCArtboard id="mb-parent"   label="Parent brief"           width={780} height={920}><BrdParentBrief/></DCArtboard>
      </DCSection>

      <DCSection id="system" title="11 · Design system" subtitle="Tokens · type · spacing · motion · components">
        <DCArtboard id="palette"     label="Palette"      width={720} height={760}><BrdPalette/></DCArtboard>
        <DCArtboard id="type"        label="Typography"   width={780} height={780}><BrdType/></DCArtboard>
        <DCArtboard id="geo"         label="Spacing · radii · motion" width={780} height={760}><BrdSystem/></DCArtboard>
        <DCArtboard id="components"  label="Components"   width={780} height={820}><BrdComponents/></DCArtboard>
      </DCSection>

      <DCSection id="handoff" title="12 · Flow & handoff" subtitle="User flow map and developer notes">
        <DCArtboard id="flow"     label="User flow"    width={760} height={760}><BrdFlow/></DCArtboard>
        <DCArtboard id="dev"      label="Dev handoff"  width={820} height={920}><BrdHandoff/></DCArtboard>
      </DCSection>

      <DCPostIt top={20} left={'42%'} rotate={-1.5} width={220}>
        Black & white only. No accent hues. Hierarchy comes from <b>density</b>, <b>type weight</b>, and <b>hairlines</b>.
      </DCPostIt>
    </DesignCanvas>
  );
}

// ─── Brand board (logo + motif) ───
function BrandBoard() {
  return (
    <div style={{
      width: 720, height: 620, padding: 40, boxSizing: 'border-box',
      background: '#000', color: '#fff', borderRadius: 24,
      border: `1px solid ${MF.line.hairline}`,
      display: 'grid', gridTemplateColumns: '300px 1fr', gap: 36,
    }}>
      {/* Logo on dark */}
      <div style={{
        background: '#000', borderRadius: 18, border: `1px solid ${MF.line.hairline}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative', overflow: 'hidden',
      }}>
        <div style={{
          position: 'absolute', inset: 0, opacity: 0.6,
          backgroundImage:
            'repeating-linear-gradient(115deg, transparent 0px, transparent 30px, rgba(255,255,255,0.03) 30px, rgba(255,255,255,0.03) 31px)',
        }}/>
        <MFMark size={180}/>
      </div>

      {/* Right column */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
        <Eyebrow>BRAND · MARK</Eyebrow>
        <div style={{ ...TYPE.title1, color: '#fff' }}>MF Elite Training</div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, textWrap: 'pretty' }}>
          The mark's sliced top-left echoes a striker's first step. Use it solo as the
          logo, and as motif: diagonal cuts, slash dividers, half-shadowed photo overlays.
        </div>

        <SlashRule/>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
          <div style={{ background: '#000', border: `1px solid ${MF.line.hairline}`, borderRadius: 12, padding: '20px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <MFMark size={72} dark={true}/>
          </div>
          <div style={{ background: '#fff', border: `1px solid ${MF.line.hairline}`, borderRadius: 12, padding: '20px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <MFMark size={72} dark={false}/>
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <Eyebrow>PROTECTED AREA</Eyebrow>
          <div style={{ ...TYPE.foot, color: MF.ink.secondary }}>
            Clear space on all sides ≥ height of the "F" stem. Never tint, gradient, or outline the mark.
          </div>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          <Eyebrow>MINIMUM SIZE</Eyebrow>
          <div style={{ ...TYPE.foot, color: MF.ink.secondary }}>
            App icon · 1024 pt. In-product mark · 22 pt. Nav mark · 26 pt.
          </div>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { App, Phone, BrandBoard });

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(<App/>);
