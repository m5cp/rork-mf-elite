//
//  WorkoutRouteRenderer.swift
//  MFElite
//
//  Renders a GPS route into an Apple Fitness-style map image using MKMapSnapshotter,
//  drawing the movement trail over the map. The image is saved to Documents so the
//  calendar and Progress cards load it instantly, even offline.
//

import Foundation
import MapKit
import UIKit

enum WorkoutRouteRenderer {
    /// Render the route points into a map image and save it to Documents.
    /// Returns the saved filename, or nil when there aren't enough points.
    static func renderAndSave(points: [WatchRoutePoint], accentHex: String, id: String) async -> String? {
        let coords = points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        guard coords.count > 1 else { return nil }

        let options = MKMapSnapshotter.Options()
        options.region = region(for: coords)
        options.size = CGSize(width: 600, height: 360)
        options.mapType = .standard
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)

        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }

        let image = draw(route: coords, on: snapshot, accent: UIColor(hex: accentHex))
        return save(image, id: id)
    }

    private static func region(for coords: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = coords[0].latitude, maxLat = coords[0].latitude
        var minLng = coords[0].longitude, maxLng = coords[0].longitude
        for c in coords {
            minLat = min(minLat, c.latitude); maxLat = max(maxLat, c.latitude)
            minLng = min(minLng, c.longitude); maxLng = max(maxLng, c.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.002),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.002)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    private static func draw(route: [CLLocationCoordinate2D], on snapshot: MKMapSnapshotter.Snapshot, accent: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: snapshot.image.size)
        return renderer.image { context in
            snapshot.image.draw(at: .zero)
            let cg = context.cgContext
            cg.setStrokeColor(accent.cgColor)
            cg.setLineWidth(6)
            cg.setLineJoin(.round)
            cg.setLineCap(.round)

            let path = UIBezierPath()
            for (index, coord) in route.enumerated() {
                let point = snapshot.point(for: coord)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            cg.addPath(path.cgPath)
            cg.strokePath()

            // Start (green) and end (red) dots.
            if let first = route.first {
                dot(at: snapshot.point(for: first), color: .systemGreen, in: cg)
            }
            if let last = route.last {
                dot(at: snapshot.point(for: last), color: .systemRed, in: cg)
            }
        }
    }

    private static func dot(at point: CGPoint, color: UIColor, in cg: CGContext) {
        let r: CGFloat = 7
        cg.setFillColor(UIColor.white.cgColor)
        cg.fillEllipse(in: CGRect(x: point.x - r - 2, y: point.y - r - 2, width: (r + 2) * 2, height: (r + 2) * 2))
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
    }

    private static func save(_ image: UIImage, id: String) -> String? {
        guard let data = image.pngData() else { return nil }
        let name = "route_\(id).png"
        let url = directory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("workout_routes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Load a saved route image by filename.
    static func image(named name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: CGFloat((value & 0xFF0000) >> 16) / 255,
            green: CGFloat((value & 0x00FF00) >> 8) / 255,
            blue: CGFloat(value & 0x0000FF) / 255,
            alpha: 1
        )
    }
}
