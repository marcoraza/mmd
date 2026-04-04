import SwiftUI
import AVFoundation

// MARK: - QRScanView

/// Camera-based QR code scanner using AVFoundation.
///
/// Emits scanned code strings via the `onCodeScanned` closure.
/// Resolution against the database happens in the calling ViewModel,
/// not here. This view is a raw string emitter.
struct QRScanView: UIViewRepresentable {

    @Binding var isActive: Bool
    var onCodeScanned: (String) -> Void

    func makeCoordinator() -> QRScanCoordinator {
        QRScanCoordinator(onCodeScanned: onCodeScanned)
    }

    func makeUIView(context: Context) -> QRScannerUIView {
        let view = QRScannerUIView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: QRScannerUIView, context: Context) {
        if isActive {
            uiView.startScanning()
        } else {
            uiView.stopScanning()
        }
    }
}

// MARK: - QRScanCoordinator

final class QRScanCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {

    private let onCodeScanned: (String) -> Void
    private var lastScannedCode: String?
    private var lastScanTime: Date = .distantPast

    /// Minimum interval between accepting the same code again.
    private let debounceInterval: TimeInterval = 2.0

    init(onCodeScanned: @escaping (String) -> Void) {
        self.onCodeScanned = onCodeScanned
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let code = object.stringValue else { return }

        let now = Date()
        if code == lastScannedCode && now.timeIntervalSince(lastScanTime) < debounceInterval {
            return
        }

        lastScannedCode = code
        lastScanTime = now

        DispatchQueue.main.async { [weak self] in
            self?.onCodeScanned(code)
        }
    }
}

// MARK: - QRScannerUIView

final class QRScannerUIView: UIView {

    weak var delegate: QRScanCoordinator?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func startScanning() {
        if !isConfigured {
            configure()
        }
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    func stopScanning() {
        if captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.stopRunning()
            }
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(delegate, queue: .main)
            output.metadataObjectTypes = [.qr]
        }

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = bounds
        layer.addSublayer(preview)
        previewLayer = preview

        isConfigured = true
    }
}

// MARK: - QR Scan Overlay

/// Overlay hint label for the QR scan area.
struct QRScanOverlay: View {

    var body: some View {
        VStack {
            Text("APONTE PARA O QR CODE")
                .font(.spaceMono(11))
                .tracking(11 * 0.08)
                .textCase(.uppercase)
                .foregroundStyle(Color.ndTextSecondary)
                .padding(.horizontal, NDSpacing.medium)
                .padding(.vertical, NDSpacing.base)
                .background(Color.ndBlack.opacity(0.7))
                .padding(.top, NDSpacing.compact)

            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
struct QRScanView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.ndBlack

            VStack {
                Text("QR SCAN")
                    .ndLabel()

                Rectangle()
                    .fill(Color.ndSurfaceRaised)
                    .frame(height: 300)
                    .overlay(
                        Text("CAMERA PREVIEW")
                            .font(.spaceMono(11))
                            .foregroundStyle(Color.ndTextDisabled)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.ndBorderVisible, lineWidth: 1)
                    )
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
