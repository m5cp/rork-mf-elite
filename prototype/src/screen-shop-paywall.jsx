// MF Elite — Shop + Paywall

// ─── DIGITAL SHOP · The Playbook Library ───
// PDFs / digital coaching guides only. Future-release feature; paywall remains
// the primary commerce surface in MVP.
function ScrShop() {
  const playbooks = [
    {
      title: 'The Striker Playbook',
      author: 'Coach Matteo Finazzi',
      pages: 184, mb: 24,
      desc: 'Pressure, half-turn, finish — the complete striker manual.',
      tag: 'INCLUDED · ELITE',
      free: true,
    },
    {
      title: 'The Half-Turn · A Manual',
      author: 'Coach Matteo Finazzi',
      pages: 62, mb: 12,
      desc: 'One touch to open the field. Twelve drills with film.',
      tag: 'MEMBERS · $9',
    },
    {
      title: 'First-Touch Drills · Coach Notes',
      author: 'Coach Matteo Finazzi',
      pages: 48, mb: 9,
      desc: 'Receiving under pressure. Solo + with-server progressions.',
      tag: 'MEMBERS · $9',
    },
    {
      title: 'Set Pieces · Field Guide',
      author: 'Coach Two',
      pages: 72, mb: 14,
      desc: 'Attacking corners, free kicks, throw-in routines.',
      tag: 'MEMBERS · $12',
    },
    {
      title: 'Match Day · Mental Primer',
      author: 'Coach Matteo Finazzi',
      pages: 24, mb: 6,
      desc: 'A 24-page warmup for the head before the body.',
      tag: 'INCLUDED · ELITE',
      free: true,
    },
    {
      title: 'Recovery & Mobility · Pocket Guide',
      author: 'Coach Three',
      pages: 38, mb: 7,
      desc: 'Daily routines for the body that gets you through a season.',
      tag: 'MEMBERS · $9',
    },
  ];

  return (
    <div style={{ width: '100%', minHeight: '100%', background: MF.bg.base, paddingBottom: 60 }}>
      {/* Future-feature banner */}
      <div style={{
        margin: '54px 14px 0', padding: '10px 14px',
        background: 'rgba(255,255,255,0.06)',
        border: `1px solid ${MF.line.subtle}`,
        borderRadius: 999,
        display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 10,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{ width: 6, height: 6, borderRadius: 3, background: '#fff' }}/>
          <span style={{ ...TYPE.micro, color: '#fff', letterSpacing: 1.6, fontWeight: 700 }}>
            COMING IN V1.1 · NOT IN MVP
          </span>
        </div>
        <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>PREVIEW</span>
      </div>

      {/* Editorial masthead */}
      <div style={{ padding: '24px 20px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <Eyebrow>THE PLAYBOOK LIBRARY</Eyebrow>
          <IconButton style={{
            width: 34, height: 34, borderRadius: 17, background: 'transparent',
            border: `1px solid ${MF.line.subtle}`,
          }}>
            <svg width="14" height="14" viewBox="0 0 14 14"><path d="M12 11.5l-2.5-2.5M10.5 6.5a4 4 0 11-8 0 4 4 0 018 0z" stroke="#fff" strokeWidth="1.4" fill="none"/></svg>
          </IconButton>
        </div>
        <div style={{ ...TYPE.hero, color: '#fff', marginTop: 8, lineHeight: '46px' }}>
          Read off the<br/>pitch
        </div>
        <div style={{ ...TYPE.body, color: MF.ink.secondary, marginTop: 10, maxWidth: 320 }}>
          Coach-written playbooks and guides. Downloadable PDFs you can read on any device.
        </div>
      </div>

      {/* Topic filters */}
      <div style={{ display: 'flex', gap: 8, padding: '8px 20px 0', overflowX: 'auto' }}>
        <Chip active>All · 6</Chip>
        <Chip>Striker</Chip>
        <Chip>Cognition</Chip>
        <Chip>Set pieces</Chip>
        <Chip>Recovery</Chip>
      </div>

      {/* Featured playbook — large PDF cover treatment */}
      <div style={{ padding: '24px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 12 }}>FEATURED · INCLUDED WITH ELITE</Eyebrow>
        <div style={{
          borderRadius: 22, overflow: 'hidden',
          background: MF.bg.card, border: `1px solid ${MF.line.hairline}`,
        }}>
          <PDFCover title="The Striker Playbook" author="Coach Matteo Finazzi" height={260} hero/>
          <div style={{ padding: 18 }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 12 }}>
              <div style={{ minWidth: 0 }}>
                <div style={{ ...TYPE.title2, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  The Striker Playbook
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6 }}>
                  <PDFBadge/>
                  <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>184 PAGES</span>
                  <Sep/>
                  <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>24 MB</span>
                </div>
              </div>
              <DownloadButton/>
            </div>
          </div>
        </div>
      </div>

      {/* PDF rows */}
      <div style={{ padding: '28px 20px 0' }}>
        <Eyebrow style={{ marginBottom: 14 }}>ALL PLAYBOOKS · 06</Eyebrow>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          {playbooks.slice(1).map((p, i) => (
            <PlaybookRow key={i} {...p} last={i === playbooks.length - 2}/>
          ))}
        </div>
      </div>
    </div>
  );
}

function PDFCover({ title, author, height = 200, hero = false }) {
  return (
    <div style={{
      width: '100%', height, position: 'relative', overflow: 'hidden',
      background:
        'linear-gradient(160deg, #1a1a1a 0%, #0a0a0a 70%, #050505 100%)',
      borderBottom: hero ? `1px solid ${MF.line.hairline}` : 'none',
    }}>
      {/* Diagonal slash motif — echoes the logo */}
      <svg width="100%" height="100%" viewBox="0 0 400 260" preserveAspectRatio="none"
        style={{ position: 'absolute', inset: 0 }}>
        <polygon points="0,0 140,0 80,260 0,260" fill="rgba(255,255,255,0.04)"/>
        <line x1="0"  y1="60"  x2="60"  y2="0" stroke="rgba(255,255,255,0.06)" strokeWidth="1.2"/>
        <line x1="0"  y1="100" x2="100" y2="0" stroke="rgba(255,255,255,0.05)" strokeWidth="1.2"/>
        <line x1="0"  y1="140" x2="140" y2="0" stroke="rgba(255,255,255,0.04)" strokeWidth="1.2"/>
      </svg>
      {/* Cover content */}
      <div style={{ position: 'absolute', left: 24, top: 24, right: 24, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <MFMark size={22}/>
        <span style={{ ...TYPE.micro, color: 'rgba(255,255,255,0.72)', letterSpacing: 2 }}>VOL. I</span>
      </div>
      <div style={{ position: 'absolute', left: 24, right: 24, bottom: 24 }}>
        <Eyebrow style={{ color: 'rgba(255,255,255,0.72)', letterSpacing: 2 }}>THE STRIKER PLAYBOOK</Eyebrow>
        <div style={{
          fontFamily: MF.font.display, fontWeight: 800,
          fontSize: hero ? 34 : 24, lineHeight: hero ? '36px' : '26px',
          letterSpacing: -1, color: '#fff', marginTop: 8,
        }}>
          Pressure.<br/>Half-turn.<br/>Finish.
        </div>
      </div>
    </div>
  );
}

function PDFBadge() {
  return (
    <span style={{
      padding: '2px 6px', borderRadius: 4,
      background: '#fff', color: '#000',
      ...TYPE.micro, fontWeight: 700, letterSpacing: 1.6,
    }}>PDF</span>
  );
}

function DownloadButton({ disabled = false }) {
  return (
    <button style={{
      appearance: 'none', border: 'none', cursor: disabled ? 'default' : 'pointer',
      height: 44, padding: '0 18px', borderRadius: 14,
      background: disabled ? MF.bg.raised : '#fff',
      color: disabled ? MF.ink.tertiary : '#000',
      ...TYPE.callout, fontWeight: 700,
      display: 'inline-flex', alignItems: 'center', gap: 8, flexShrink: 0,
    }}>
      <svg width="14" height="14" viewBox="0 0 14 14">
        <path d="M7 1v9m0 0L4 7m3 3l3-3M2 13h10" stroke={disabled ? 'currentColor' : '#000'} strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
      Download
    </button>
  );
}

function PlaybookRow({ title, author, pages, mb, desc, tag, free, last }) {
  return (
    <div style={{
      display: 'flex', gap: 14, padding: '16px 0',
      borderTop: `1px solid ${MF.line.hairline}`,
      borderBottom: last ? `1px solid ${MF.line.hairline}` : 'none',
    }}>
      {/* Mini PDF cover */}
      <div style={{
        width: 64, height: 84, flexShrink: 0, position: 'relative', overflow: 'hidden',
        background: 'linear-gradient(160deg, #1a1a1a 0%, #050505 100%)',
        border: `1px solid ${MF.line.subtle}`, borderRadius: 4,
      }}>
        <svg width="64" height="84" viewBox="0 0 64 84" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0 }}>
          <polygon points="0,0 22,0 14,84 0,84" fill="rgba(255,255,255,0.05)"/>
          <line x1="0" y1="18" x2="18" y2="0" stroke="rgba(255,255,255,0.06)" strokeWidth="0.8"/>
          <line x1="0" y1="32" x2="32" y2="0" stroke="rgba(255,255,255,0.05)" strokeWidth="0.8"/>
        </svg>
        <div style={{
          position: 'absolute', left: 6, top: 6,
          ...TYPE.micro, color: 'rgba(255,255,255,0.72)', fontSize: 7, letterSpacing: 1.2,
        }}>MF</div>
        <div style={{
          position: 'absolute', left: 6, right: 6, bottom: 6,
          ...TYPE.foot, color: '#fff', fontWeight: 700, fontSize: 9, lineHeight: '10px',
        }}>{title.split('·')[0].slice(0, 14)}</div>
      </div>

      {/* Title + meta */}
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 6, paddingTop: 2 }}>
        <div style={{ ...TYPE.callout, color: '#fff', fontWeight: 700, letterSpacing: -0.1 }}>{title}</div>
        <div style={{ ...TYPE.foot, color: MF.ink.tertiary }}>{desc}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
          <PDFBadge/>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{pages} PAGES</span>
          <Sep/>
          <span style={{ ...TYPE.micro, color: MF.ink.tertiary }}>{mb} MB</span>
        </div>
      </div>

      {/* Right column — tag + download */}
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', justifyContent: 'space-between', gap: 10, paddingTop: 4 }}>
        <span style={{
          ...TYPE.micro, color: free ? '#000' : '#fff',
          background: free ? '#fff' : 'transparent',
          border: free ? 'none' : `1px solid ${MF.line.subtle}`,
          padding: '3px 8px', borderRadius: 4, letterSpacing: 1.4,
          whiteSpace: 'nowrap', fontWeight: 700,
        }}>{tag}</span>
        <button style={{
          appearance: 'none', cursor: 'pointer',
          width: 40, height: 40, borderRadius: 12,
          background: MF.bg.raised, border: `1px solid ${MF.line.subtle}`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <svg width="14" height="14" viewBox="0 0 14 14">
            <path d="M7 1v9m0 0L4 7m3 3l3-3M2 13h10" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
        </button>
      </div>
    </div>
  );
}

// ─── PAYWALL ───
// Flex column layout — no absolute positioning, no overlap.
function ScrPaywall() {
  return (
    <div style={{
      width: '100%', height: '100%', background: MF.bg.base,
      position: 'relative', overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Faint diagonal stripe field */}
      <div style={{
        position: 'absolute', inset: 0, opacity: 0.5, pointerEvents: 'none',
        backgroundImage:
          'repeating-linear-gradient(115deg, transparent 0px, transparent 44px, rgba(255,255,255,0.022) 44px, rgba(255,255,255,0.022) 45px)',
      }}/>

      {/* Top bar — close + restore */}
      <div style={{
        position: 'relative', zIndex: 2,
        padding: '60px 20px 0', display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      }}>
        <span style={{ ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600 }}>Restore</span>
        <IconButton style={{
          width: 36, height: 36, borderRadius: 18,
          background: 'transparent', border: `1px solid ${MF.line.subtle}`,
        }}>
          <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2 2l8 8M10 2L2 10" stroke="#fff" strokeWidth="1.5" strokeLinecap="round"/></svg>
        </IconButton>
      </div>

      {/* Hero block — flex grows to fill */}
      <div style={{
        position: 'relative', zIndex: 1, flex: 1,
        padding: '32px 24px 0',
        display: 'flex', flexDirection: 'column', gap: 22, minHeight: 0,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <MFMark size={28}/>
          <Eyebrow>MF · ELITE MEMBERSHIP</Eyebrow>
        </div>
        <div style={{ ...TYPE.hero, color: '#fff', lineHeight: '46px', textWrap: 'balance' }}>
          The whole<br/>academy<br/>Unlocked
        </div>
        <SlashRule/>
        {/* Value bullets — tight, 4 max */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          <ValueLine>Every Elite Drill · every coach · every drill</ValueLine>
          <ValueLine>All 11 position-specific tracks</ValueLine>
          <ValueLine>Six earned badges across the rank ladder</ValueLine>
          <ValueLine>Apple Watch · Live Activities · Widgets</ValueLine>
        </div>
      </div>

      {/* Bottom panel — flows in normal layout, no overlap */}
      <div style={{
        position: 'relative', zIndex: 2,
        padding: '24px 24px 32px',
        background: 'linear-gradient(to bottom, transparent 0%, #000 18%)',
        display: 'flex', flexDirection: 'column', gap: 10,
      }}>
        {/* Annual (selected, inverse) */}
        <div style={{
          background: '#fff', color: '#000', borderRadius: 18, padding: 16,
          display: 'flex', alignItems: 'center', gap: 14, position: 'relative',
        }}>
          <div style={{
            width: 22, height: 22, borderRadius: 11, background: '#000',
            display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0,
          }}>
            <svg width="11" height="11" viewBox="0 0 11 11"><path d="M2 5.8l2.2 2.2L9 3" stroke="#fff" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ ...TYPE.callout, color: '#000', fontWeight: 700 }}>Annual</span>
              <span style={{
                ...TYPE.micro, color: '#fff', background: '#000', padding: '2px 6px', borderRadius: 4,
              }}>SAVE 38%</span>
            </div>
            <div style={{ ...TYPE.foot, color: 'rgba(0,0,0,0.55)', marginTop: 2 }}>$199.99 / year · ≈ $16.67 mo</div>
          </div>
        </div>

        {/* Monthly */}
        <div style={{
          background: 'transparent', border: `1px solid ${MF.line.subtle}`, borderRadius: 18, padding: 16,
          display: 'flex', alignItems: 'center', gap: 14,
        }}>
          <div style={{
            width: 22, height: 22, borderRadius: 11,
            border: `1.5px solid ${MF.line.strong}`, flexShrink: 0,
          }}/>
          <div style={{ flex: 1, minWidth: 0 }}>
            <span style={{ ...TYPE.callout, color: '#fff', fontWeight: 700 }}>Monthly</span>
            <div style={{ ...TYPE.foot, color: MF.ink.tertiary, marginTop: 2 }}>$26.99 / month · cancel any time</div>
          </div>
        </div>

        <PrimaryButton style={{ marginTop: 6 }}>Start 7-day trial</PrimaryButton>

        {/* iOS-required links */}
        <div style={{
          display: 'flex', justifyContent: 'center', gap: 14,
          marginTop: 4, ...TYPE.foot, color: MF.ink.tertiary, fontWeight: 600,
        }}>
          <span>Redeem code</span><Sep/><span>Terms</span><Sep/><span>Privacy</span>
        </div>
        <div style={{
          ...TYPE.cap, color: MF.ink.quaternary, textAlign: 'center', lineHeight: '14px',
          padding: '0 16px',
        }}>
          Auto-renewing. $199.99/yr after 7-day trial unless cancelled 24h prior.
        </div>
      </div>
    </div>
  );
}

function ValueLine({ children }) {
  return (
    <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
      <div style={{
        width: 18, height: 18, borderRadius: 9, background: '#fff', flexShrink: 0, marginTop: 2,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <svg width="9" height="9" viewBox="0 0 9 9"><path d="M1.5 4.8l1.6 1.7L7 2.2" stroke="#000" strokeWidth="1.6" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
      </div>
      <span style={{ ...TYPE.callout, color: '#fff', textWrap: 'pretty', lineHeight: '20px' }}>{children}</span>
    </div>
  );
}

Object.assign(window, { ScrShop, ScrPaywall, ValueLine });
