//
//  WorkoutScannerView.swift
//  MFElite
//
//  Full-screen QR scanner used to import a shared workout. Wraps an
//  AVCaptureSession in a UIViewControllerRepresentable, draws a dimmed overlay
//  with a centered viewfinder, and calls back with the first QR string that
//  parses as an mfelite:// workout link. Non-matching codes are ignored.
//

import SwiftUI
import AVFoundation

struct WorkoutScannerView: View {
    /// Called with a decoded payload when a valid MF Elite workout code is read.
    let onScan: (WorkoutShare.Payload) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var permission: CameraPermission = .unknown
    @State private var didFind = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch permission {
            case .authorized:
                scanner
            case .denied:
                deniedView
            case .unknown:
                Color.clear
            }

            overlay
        }
        .task { await resolvePermission() }
    }

    // MARK: - Camera

    private var scanner: some View {
        QRScannerRepresentable { string in
            guard !didFind else { return }
            guard let url = URL(string: string),
                  let payload = WorkoutShare.decode(url) else { return }
            didFind = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onScan(payload)
            dismiss()
        }
        .ignoresSafeArea()
    }

    /// Dimmed overlay with a clear centered viewfinder window and Cancel button.
    private var overlay: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.66
            ZStack {
                if permission == .authorized {
                    Color.black.opacity(0.55)
                        .reverseMask {
                            RoundedRectangle(cornerRadius: 28)
                                .frame(width: side, height: side)
                        }
                        .ignoresSafeArea()

                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: side, height: side)

                    Text("Point at a workout QR code")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .offset(y: side / 2 + 36)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.4), in: Circle())
                    .contentShape(Circle())
            }
            .padding(.top, DS.Spacing.s8)
            .padding(.trailing, DS.Spacing.s16)
        }
    }

    // MARK: - Permission denied

    private var deniedView: some View {
        VStack(spacing: DS.Spacing.s16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
            Text("Camera access is off")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
            Text("Turn on camera access to scan a teammate's workout QR code.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.s32)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(height: 50)
                    .padding(.horizontal, DS.Spacing.s32)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.pill))
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, DS.Spacing.s4)
        }
        .padding(DS.Spacing.s24)
    }

    private func resolvePermission() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .authorized
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            permission = granted ? .authorized : .denied
        default:
            permission = .denied
        }
    }

    private enum CameraPermission {
        case unknown, authorized, denied
    }
}

// MARK: - Reverse mask helper

private extension View {
    /// Punches a hole in the view using the given mask shape.
    func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle()
                .overlay(mask().blendMode(.destinationOut))
        }
    }
}

// MARK: - AVFoundation bridge

/// UIKit camera preview that reports the first detected QR string.
struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

/// Owns the AVCaptureSession and forwards QR metadata to SwiftUI.
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasReported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        startSession()
    }

    private func startSession() {
        guard !session.isRunning else { return }
        Task.detached { [session] in
            session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else { return }
        Task { @MainActor in
            guard !hasReported else { return }
            hasReported = true
            session.stopRunning()
            onCode?(value)
        }
    }
}
