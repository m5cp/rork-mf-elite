// print-canvas.jsx — drop-in replacement for design-canvas.jsx in the print build.
// Same exports (DesignCanvas, DCSection, DCArtboard, DCPostIt) but emits a
// paged layout: section title page + one page per artboard. Each artboard is
// scaled to fit the printable area while preserving its natural pixel size.

function dcFlatten(children) {
  const out = [];
  React.Children.forEach(children, (c) => {
    if (!c) return;
    if (c.type === React.Fragment) out.push(...dcFlatten(c.props.children));
    else out.push(c);
  });
  return out;
}

function DesignCanvas({ children }) {
  return <div className="print-doc">{children}</div>;
}

function DCSection({ id, title, subtitle, children }) {
  const arts = dcFlatten(children).filter((c) => c && c.type === DCArtboard);
  return (
    <>
      <SectionTitlePage title={title} subtitle={subtitle}/>
      {arts.map((ab, i) => (
        <ArtboardPage key={ab.props.id || ab.props.label || i}
          section={title} artboard={ab}/>
      ))}
    </>
  );
}

function DCArtboard() { return null; } // marker only — rendered via ArtboardPage

function DCPostIt() { return null; } // post-its are screen-only annotations

// ── Section title page ───────────────────────────────────────
function SectionTitlePage({ title, subtitle }) {
  return (
    <div className="page page-title">
      <div className="page-corner page-corner-tl">
        <img src="assets/mf-logo-white.png" alt="MF" className="page-mark"/>
        <span>MF · ELITE TRAINING</span>
      </div>
      <div className="page-corner page-corner-tr">
        <span>SECTION</span>
      </div>
      <div className="title-stack">
        <div className="title-eyebrow">SECTION</div>
        <h1>{title}</h1>
        {subtitle && <p>{subtitle}</p>}
      </div>
      <div className="page-corner page-corner-bl"><span>MF ELITE · APP CONCEPT</span></div>
    </div>
  );
}

// ── Artboard page (scales the artboard to fit) ───────────────
function ArtboardPage({ section, artboard }) {
  const { label, width = 402, height = 874, children } = artboard.props;
  // Printable area inside the page (after padding + header):
  //   A4 landscape is 297mm × 210mm.
  //   At 96 dpi, that's ~1123 × 794 px.
  //   Reserve ~14mm top header + 14mm bottom footer + 14mm left/right.
  //   → usable ~1015 × 680 px
  const maxW = 1015, maxH = 680;
  const scale = Math.min(maxW / width, maxH / height, 1.4);
  return (
    <div className="page page-art">
      <div className="page-corner page-corner-tl">
        <img src="assets/mf-logo-white.png" alt="MF" className="page-mark"/>
        <span>{section}</span>
      </div>
      <div className="page-corner page-corner-tr"><span>{label}</span></div>
      <div className="art-frame">
        <div className="art-inner-wrap" style={{
          width: width * scale, height: height * scale,
        }}>
          <div className="art-inner" style={{
            width, height,
            transform: `scale(${scale})`,
            transformOrigin: 'top left',
          }}>
            {children}
          </div>
        </div>
      </div>
      <div className="page-corner page-corner-bl"><span>MF ELITE · APP CONCEPT</span></div>
    </div>
  );
}

Object.assign(window, { DesignCanvas, DCSection, DCArtboard, DCPostIt });
