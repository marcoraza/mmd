import SwiftUI
import UIKit
import AVFoundation

// MARK: - Permissão de câmera

/// Estado da permissão de câmera, com o caso que o legado não tratava:
/// `AVCaptureDevice.authorizationStatus` nunca era consultado, então em
/// `.notDetermined` a sessão era montada e a prévia ficava preta sem explicação.
enum CameraPermission: Equatable {
    case naoDeterminada
    case autorizada
    case negada
    case restrita

    static func current() -> CameraPermission {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .autorizada
        case .denied: return .negada
        case .restricted: return .restrita
        case .notDetermined: return .naoDeterminada
        @unknown default: return .negada
        }
    }

    var mensagem: String {
        switch self {
        case .naoDeterminada:
            return "O EventPro precisa da câmera para ler o QR Code das etiquetas."
        case .autorizada:
            return ""
        case .negada:
            return "Acesso à câmera negado. Libere em Ajustes do iPhone > EventPro > Câmera."
        case .restrita:
            return "A câmera está bloqueada por restrição do aparelho."
        }
    }
}

// MARK: - QRScanView

/// Leitor de QR por AVFoundation.
///
/// Emite a string lida por `onCodeScanned`. A resolução contra o banco acontece
/// no ViewModel, não aqui: esta view é um emissor de string cru.
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

    static func dismantleUIView(_ uiView: QRScannerUIView, coordinator: QRScanCoordinator) {
        uiView.stopScanning()
    }
}

// MARK: - QRScanCoordinator

final class QRScanCoordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {

    private let onCodeScanned: (String) -> Void
    private var lastScannedCode: String?
    private var lastScanTime: Date = .distantPast

    /// Intervalo mínimo para aceitar o mesmo código de novo.
    private let debounceInterval: TimeInterval = 2.0

    init(onCodeScanned: @escaping (String) -> Void) {
        self.onCodeScanned = onCodeScanned
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let code = object.stringValue
        else { return }

        let now = Date()
        if code == lastScannedCode, now.timeIntervalSince(lastScanTime) < debounceInterval {
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

    /// Configuração e start/stop fora da main thread: `startRunning()` bloqueia.
    private let sessionQueue = DispatchQueue(label: "com.emdash.eventpro.qr.session")

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }

    func startScanning() {
        // Nunca monta a sessão sem permissão concedida: sem isso o iOS entrega
        // uma prévia preta e o operador acha que o app travou.
        guard CameraPermission.current() == .autorizada else { return }

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                self.configure()
            }
            guard self.isConfigured, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    private func configure() {
        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            captureSession.canAddInput(input)
        else { return }

        captureSession.beginConfiguration()
        captureSession.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard captureSession.canAddOutput(output) else {
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(delegate, queue: .main)
        output.metadataObjectTypes = [.qr]
        captureSession.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
            preview.videoGravity = .resizeAspectFill
            preview.frame = self.bounds
            self.layer.addSublayer(preview)
            self.previewLayer = preview
        }

        isConfigured = true
    }
}

// MARK: - Container com permissão

/// Envolve `QRScanView` tratando o ciclo de permissão.
struct QRScannerContainer: View {

    @Binding var isActive: Bool
    var onCodeScanned: (String) -> Void

    @State private var permission: CameraPermission = .current()

    var body: some View {
        Group {
            switch permission {
            case .autorizada:
                ZStack(alignment: .top) {
                    QRScanView(isActive: $isActive, onCodeScanned: onCodeScanned)
                    Text("APONTE PARA O QR CODE")
                        .font(.caption.monospaced())
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .padding(.top, 12)
                }

            case .naoDeterminada:
                VStack(spacing: 12) {
                    Text(permission.mensagem)
                        .multilineTextAlignment(.center)
                    Button("Permitir câmera") {
                        AVCaptureDevice.requestAccess(for: .video) { _ in
                            DispatchQueue.main.async {
                                permission = .current()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

            case .negada, .restrita:
                VStack(spacing: 12) {
                    Text(permission.mensagem)
                        .multilineTextAlignment(.center)
                    if permission == .negada, let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Abrir Ajustes do iPhone", destination: url)
                    }
                }
                .padding()
            }
        }
        .onAppear { permission = .current() }
    }
}
