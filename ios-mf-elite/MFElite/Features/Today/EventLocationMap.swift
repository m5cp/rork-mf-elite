//
//  EventLocationMap.swift
//  MFElite
//
//  A compact, non-interactive map preview for a team event's location plus a
//  "Directions" button that opens Apple Maps. The address is geocoded once on
//  appear; if it can't be found, only the Directions button shows.
//

import SwiftUI
import MapKit

struct EventLocationMap: View {
    let location: String

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var didGeocode = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s8) {
            if let coordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(location, coordinate: coordinate)
                        .tint(DS.Colors.Gold.base)
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .allowsHitTesting(false)
            }
            Button {
                openDirections()
            } label: {
                HStack(spacing: DS.Spacing.s8) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Directions")
                        .style(.foot)
                        .fontWeight(.semibold)
                    Spacer(minLength: 0)
                    Text(location)
                        .style(.micro)
                        .foregroundStyle(DS.Colors.Ink.tertiary)
                        .lineLimit(1)
                }
                .foregroundStyle(DS.Colors.Ink.primary)
                .padding(DS.Spacing.s12)
                .frame(maxWidth: .infinity)
                .background(DS.Colors.Bg.raised)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).stroke(DS.Colors.Line.hairline, lineWidth: 1))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .task {
            guard !didGeocode else { return }
            didGeocode = true
            let placemarks = try? await CLGeocoder().geocodeAddressString(location)
            coordinate = placemarks?.first?.location?.coordinate
        }
    }

    private func openDirections() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let coordinate {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = location
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
        } else {
            let query = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "http://maps.apple.com/?daddr=\(query)") {
                UIApplication.shared.open(url)
            }
        }
    }
}
