//
//  ShareCardDebugPreviewView.swift
//  MFElite
//
//  TEMPORARY, DEBUG-ONLY harness for Phase 1 of the share-card system. Renders
//  every moment across every theme / format so the rendering layer, footer QR,
//  and auto-fit can be verified before the gallery / editor land. This whole file
//  compiles out of Release builds.
//

#if DEBUG
import SwiftUI

struct ShareCardDebugPreviewView: View {
    @State private var themeID: String = ShareTheme.gold.id
    @State private var formatID: String = ShareFormat.story.id
    @State private var backdrop: ShareBackdrop = .solid
    @State private var showName = true
    @State private var showStats = true
    @State private var showDate = true
    @State private var photoAllowed = false
    @State private var exported: ShareableImage?

    private var theme: ShareTheme { ShareTheme.theme(id: themeID) }
    private var format: ShareFormat { ShareFormat.format(id: formatID) }
    private var show: ShareShow { ShareShow(name: showName, stats: showStats, date: showDate) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.s20) {
                controls
                if !ShareFont.isDisplayAvailable {
                    Text("⚠️ Anton display font is not registered — falling back to system.")
                        .style(.foot)
                        .foregroundStyle(Color(hex: "#FF5A5A"))
                        .padding(.horizontal, DS.Spacing.s16)
                }
                ForEach(ShareMomentKind.allCases) { kind in
                    momentSection(kind)
                }
            }
            .padding(.vertical, DS.Spacing.s16)
            .padding(.bottom, 80)
        }
        .background(DS.Colors.Bg.base)
        .navigationTitle("Share Cards (Debug)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $exported) { item in
            ShareSheet(items: [item.image])
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s12) {
            picker(title: "Theme", selection: $themeID, options: ShareTheme.all.map { ($0.id, $0.name) })
            picker(title: "Format", selection: $formatID, options: ShareFormat.all.map { ($0.id, "\($0.name) \($0.ratio)") })

            Picker("Backdrop", selection: $backdrop) {
                ForEach(ShareBackdrop.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: DS.Spacing.s16) {
                Toggle("Name", isOn: $showName)
                Toggle("Stats", isOn: $showStats)
                Toggle("Date", isOn: $showDate)
            }
            .toggleStyle(.button)

            Toggle("Photo permission (parent)", isOn: $photoAllowed)
                .toggleStyle(.switch)
                .tint(theme.accent)
        }
        .style(.foot)
        .foregroundStyle(DS.Colors.Ink.secondary)
        .padding(.horizontal, DS.Spacing.s16)
    }

    private func picker(title: String, selection: Binding<String>, options: [(String, String)]) -> some View {
        Picker(title, selection: selection) {
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
        .pickerStyle(.segmented)
    }

    // MARK: Moment section

    private func momentSection(_ kind: ShareMomentKind) -> some View {
        let moment = ShareMoment.sample(kind)
        let displayWidth = UIScreen.main.bounds.width - 32
        let scale = displayWidth / format.width
        let card = MFShareCardV2(
            moment: moment, theme: theme, format: format,
            backdrop: backdrop, show: show, photoAllowed: photoAllowed
        )

        return VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            HStack {
                Text(kind.label)
                    .style(.title3)
                    .foregroundStyle(DS.Colors.Ink.primary)
                Spacer()
                Button {
                    exported = ShareCardRenderer.renderCard(card, format: format).map { ShareableImage(image: $0) }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, DS.Spacing.s16)

            card
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: displayWidth, height: format.height * scale)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    NavigationStack {
        ShareCardDebugPreviewView()
    }
    .preferredColorScheme(.dark)
}
#endif
