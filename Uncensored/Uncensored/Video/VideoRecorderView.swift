//
//  VideoRecorderView.swift
//  Uncensored
//

import SwiftUI
import AVFoundation

// MARK: - CameraPreviewView

/// A UIView whose backing layer is AVCaptureVideoPreviewLayer so the preview
/// fills the layer automatically on every layout pass.
private final class _CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // swiftlint:disable:next force_cast
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        if let connection = previewLayer.connection,
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> _CameraPreviewUIView {
        let view = _CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: _CameraPreviewUIView, context: Context) {}
}

// MARK: - GestureLayerView

/// A transparent UIView that forwards UIKit tap and pinch gestures to closures.
/// Using UIKit gesture recognisers lets tap-to-focus and pinch-to-zoom coexist
/// without SwiftUI gesture conflicts.
private struct GestureLayerView: UIViewRepresentable {
    /// The camera's current zoom factor at the time the view renders; used to
    /// seed the coordinator's accumulator when no gesture is active.
    var initialZoomFactor: CGFloat
    var onTap: (CGPoint) -> Void
    var onPinchChanged: (CGFloat) -> Void  // absolute zoom value
    var onPinchEnded: (CGFloat) -> Void    // absolute zoom value

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:)))
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator

        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(pinch)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onTap = onTap
        context.coordinator.onPinchChanged = onPinchChanged
        context.coordinator.onPinchEnded = onPinchEnded
        // Sync the accumulated zoom when not actively gesturing so a new pinch
        // picks up from the actual device zoom (e.g. after a camera switch).
        if !context.coordinator.isGesturing {
            context.coordinator.accumulatedZoom = initialZoomFactor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap, onPinchChanged: onPinchChanged, onPinchEnded: onPinchEnded)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onTap: (CGPoint) -> Void
        var onPinchChanged: (CGFloat) -> Void
        var onPinchEnded: (CGFloat) -> Void

        /// Running absolute zoom maintained inside the coordinator so that
        /// each incremental delta is correctly applied to the previous value
        /// without relying on SwiftUI's (potentially deferred) state updates.
        var accumulatedZoom: CGFloat = 1.0
        private(set) var isGesturing = false

        init(onTap: @escaping (CGPoint) -> Void,
             onPinchChanged: @escaping (CGFloat) -> Void,
             onPinchEnded: @escaping (CGFloat) -> Void) {
            self.onTap = onTap
            self.onPinchChanged = onPinchChanged
            self.onPinchEnded = onPinchEnded
        }

        @objc func handleTap(_ r: UITapGestureRecognizer) {
            onTap(r.location(in: r.view))
        }

        @objc func handlePinch(_ r: UIPinchGestureRecognizer) {
            switch r.state {
            case .began:
                isGesturing = true
                r.scale = 1.0
            case .changed:
                let newZoom = max(CameraManager.minZoomFactor,
                                  min(accumulatedZoom * r.scale, CameraManager.maxZoomFactor))
                accumulatedZoom = newZoom
                onPinchChanged(newZoom)
                r.scale = 1.0
            case .ended, .cancelled:
                isGesturing = false
                onPinchEnded(accumulatedZoom)
                r.scale = 1.0
            default:
                break
            }
        }

        func gestureRecognizer(_ a: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith b: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

// MARK: - Recording Speed

enum RecordingSpeed: String, CaseIterable, Identifiable {
    case half    = "0.5×"
    case normal  = "1×"
    case oneHalf = "1.5×"
    case double  = "2×"

    var id: String { rawValue }

    /// Playback speed multiplier relative to normal.
    var factor: Double {
        switch self {
        case .half:    return 0.5
        case .normal:  return 1.0
        case .oneHalf: return 1.5
        case .double:  return 2.0
        }
    }
}

// MARK: - Video Quality

enum VideoQuality: String, CaseIterable, Identifiable {
    case sd   = "480p"
    case hd   = "720p"
    case full = "1080p"

    var id: String { rawValue }

    var sessionPreset: AVCaptureSession.Preset {
        switch self {
        case .sd:   return .vga640x480
        case .hd:   return .hd1280x720
        case .full: return .hd1920x1080
        }
    }
}

// MARK: - CameraManager

/// Manages the AVCaptureSession, recording lifecycle and camera controls.
final class CameraManager: NSObject, ObservableObject {

    // MARK: Zoom bounds (shared with GestureLayerView coordinator)
    static let minZoomFactor: CGFloat = 0.5
    static let maxZoomFactor: CGFloat = 4.0

    // MARK: Published state (always updated on main thread)

    @Published var isAuthorized = false
    @Published var isRecording  = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var segments: [URL] = []
    @Published var error: String?
    @Published var zoomFactor: CGFloat = 1.0
    @Published var isFlashOn = false
    @Published var isFrontCamera = false
    @Published var selectedFilter: VideoFilter = .normal
    @Published var selectedQuality: VideoQuality = .hd
    @Published var selectedSpeed: RecordingSpeed = .normal

    // MARK: Capture objects

    let captureSession = AVCaptureSession()
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let movieOutput = AVCaptureMovieFileOutput()
    private var currentDevice: AVCaptureDevice?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: Private state

    private let sessionQueue = DispatchQueue(label: "com.uncensored.camera.session",
                                             qos: .userInitiated)
    private var timer: Timer?
    private var currentPosition: AVCaptureDevice.Position = .back

    // MARK: - Init / Deinit

    override init() {
        super.init()
        requestPermissions()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Permissions

    private func requestPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestMicPermission()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.requestMicPermission()
                } else {
                    self?.publish { $0.error = "Camera access is required to record videos." }
                }
            }
        default:
            publish { $0.error = "Please enable camera access in Settings." }
        }
    }

    private func requestMicPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            publish { $0.isAuthorized = true }
            sessionQueue.async { self.configureSession() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                // Proceed even if microphone is denied (video-only)
                self?.publish { $0.isAuthorized = true }
                self?.sessionQueue.async { self?.configureSession() }
            }
        default:
            // Allow camera without microphone
            publish { $0.isAuthorized = true }
            sessionQueue.async { self.configureSession() }
        }
    }

    // MARK: - Session Setup

    private func configureSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = selectedQuality.sessionPreset

        // Video input
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: currentPosition) else {
            captureSession.commitConfiguration()
            publish { $0.error = "No camera found on this device." }
            return
        }

        do {
            let vInput = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(vInput) {
                captureSession.addInput(vInput)
                videoInput = vInput
                currentDevice = device
            }
        } catch {
            captureSession.commitConfiguration()
            publish { $0.error = error.localizedDescription }
            return
        }

        // Audio input
        if let audioDevice = AVCaptureDevice.default(for: .audio) {
            if let aInput = try? AVCaptureDeviceInput(device: audioDevice),
               captureSession.canAddInput(aInput) {
                captureSession.addInput(aInput)
                audioInput = aInput
            }
        }

        // Movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }

        captureSession.commitConfiguration()
    }

    // MARK: - Session Lifecycle

    func startSession() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !movieOutput.isRecording else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("seg_\(UUID().uuidString).mp4")
        movieOutput.startRecording(to: url, recordingDelegate: self)
        publish { $0.isRecording = true }
        startTimer()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func stopRecording() {
        guard movieOutput.isRecording else { return }
        movieOutput.stopRecording()
        stopTimer()
        publish { $0.isRecording = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func undoLastSegment() {
        guard !segments.isEmpty, !isRecording else { return }
        let last = segments.removeLast()
        try? FileManager.default.removeItem(at: last)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    // MARK: - Timer

    private func startTimer() {
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.recordingDuration += 0.1
            }
        }
    }

    private func stopTimer() {
        DispatchQueue.main.async {
            self.timer?.invalidate()
            self.timer = nil
        }
    }

    // MARK: - Camera Controls

    func switchCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.captureSession.beginConfiguration()

            if let current = self.videoInput {
                self.captureSession.removeInput(current)
            }

            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: newPosition) else {
                self.captureSession.commitConfiguration()
                return
            }

            if let newInput = try? AVCaptureDeviceInput(device: device),
               self.captureSession.canAddInput(newInput) {
                self.captureSession.addInput(newInput)
                self.videoInput     = newInput
                self.currentDevice  = device
                self.currentPosition = newPosition
                let isFront = newPosition == .front
                self.publish { $0.isFrontCamera = isFront }

                // Mirror front camera connection
                if let connection = self.movieOutput.connection(with: .video) {
                    if connection.isVideoMirroringSupported {
                        connection.isVideoMirrored = isFront
                    }
                }
            }
            self.captureSession.commitConfiguration()
        }
    }

    func toggleFlash() {
        guard let device = currentDevice, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            let newState = !isFlashOn
            device.torchMode = newState ? .on : .off
            device.unlockForConfiguration()
            publish { $0.isFlashOn = newState }
        } catch {
            publish { $0.error = error.localizedDescription }
        }
    }

    /// Adjusts zoom by multiplying the current factor by `delta` (incremental pinch scale).
    func adjustZoom(by delta: CGFloat) {
        guard let device = currentDevice else { return }
        let newFactor = max(Self.minZoomFactor, min(zoomFactor * delta, Self.maxZoomFactor))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = min(newFactor, device.activeFormat.videoMaxZoomFactor)
            device.unlockForConfiguration()
            publish { $0.zoomFactor = newFactor }
        } catch {}
    }

    func setZoom(to factor: CGFloat) {
        guard let device = currentDevice else { return }
        let clamped = max(Self.minZoomFactor, min(factor, Self.maxZoomFactor))
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = min(clamped, device.activeFormat.videoMaxZoomFactor)
            device.unlockForConfiguration()
            publish { $0.zoomFactor = clamped }
        } catch {}
    }

    func focus(at point: CGPoint, previewLayer: AVCaptureVideoPreviewLayer?) {
        guard let device = currentDevice else { return }
        let devicePoint: CGPoint
        if let layer = previewLayer {
            devicePoint = layer.captureDevicePointConverted(fromLayerPoint: point)
        } else {
            devicePoint = point   // fallback (may be inaccurate without layer reference)
        }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {}
    }

    // MARK: - Finalize (merge segments)

    func finalizeRecording() async throws -> URL {
        guard !segments.isEmpty else {
            throw CameraError.noSegments
        }
        if segments.count == 1, let url = segments.first {
            return url
        }
        return try await mergeSegments(segments)
    }

    private func mergeSegments(_ urls: [URL]) async throws -> URL {
        let composition = AVMutableComposition()
        guard
            let videoTrack = composition.addMutableTrack(withMediaType: .video,
                                                         preferredTrackID: kCMPersistentTrackID_Invalid),
            let audioTrack = composition.addMutableTrack(withMediaType: .audio,
                                                         preferredTrackID: kCMPersistentTrackID_Invalid)
        else {
            throw CameraError.compositionFailed
        }

        var insertTime = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)

            if let track = try await asset.loadTracks(withMediaType: .video).first {
                try videoTrack.insertTimeRange(timeRange, of: track, at: insertTime)
            }
            if let track = try await asset.loadTracks(withMediaType: .audio).first {
                try audioTrack.insertTimeRange(timeRange, of: track, at: insertTime)
            }
            insertTime = CMTimeAdd(insertTime, duration)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".mp4")

        guard let exporter = AVAssetExportSession(asset: composition,
                                                  presetName: AVAssetExportPresetHighestQuality) else {
            throw CameraError.exporterFailed
        }
        exporter.outputURL  = outputURL
        exporter.outputFileType = .mp4

        // Apply playback speed via time-range scaling
        let speed = selectedSpeed.factor
        if abs(speed - 1.0) > 0.001 {
            let total = composition.duration
            let scaledDuration = CMTimeMultiplyByFloat64(total, multiplier: 1.0 / speed)
            composition.scaleTimeRange(CMTimeRange(start: .zero, duration: total),
                                       toDuration: scaledDuration)
        }

        // Apply Core Image filter (skip for .normal to avoid unnecessary processing)
        let filter = selectedFilter
        if filter != .normal {
            exporter.videoComposition = AVMutableVideoComposition(
                asset: composition,
                applyingCIFiltersWithHandler: { request in
                    let output = filter.apply(to: request.sourceImage)
                    request.finish(with: output, context: nil)
                })
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            exporter.exportAsynchronously { continuation.resume() }
        }

        if let exportError = exporter.error { throw exportError }
        return outputURL
    }

    // MARK: - Private helper

    /// Thread-safe helper: runs the mutation on the main thread.
    private func publish(_ mutation: @escaping (CameraManager) -> Void) {
        DispatchQueue.main.async { mutation(self) }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error {
            publish { $0.error = error.localizedDescription }
            return
        }
        publish { $0.segments.append(outputFileURL) }
    }
}

// MARK: - CameraError

private enum CameraError: LocalizedError {
    case noSegments
    case compositionFailed
    case exporterFailed

    var errorDescription: String? {
        switch self {
        case .noSegments:       return "No recorded clips to save."
        case .compositionFailed: return "Could not create video composition."
        case .exporterFailed:   return "Could not start video export."
        }
    }
}

// MARK: - VideoRecorderView

/// Full-screen TikTok-style video recorder.
/// Usage: `VideoRecorderView(onVideoRecorded: { url in … })`
struct VideoRecorderView: View {

    var onVideoRecorded: (URL) -> Void

    @StateObject private var camera = CameraManager()
    @Environment(\.dismiss) private var dismiss

    // UI state
    @State private var showFilters = false
    @State private var showSettings = false
    @State private var recordedVideoURL: URL?
    @State private var showVideoPreview = false
    @State private var isFinalizing = false
    @State private var focusPoint: CGPoint?
    @State private var showFocusRing = false

    // Preview layer reference forwarded from the UIView coordinator
    @State private var capturedPreviewLayer: AVCaptureVideoPreviewLayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAuthorized {
                cameraLayer
                gestureOverlay
                focusRingOverlay
                uiOverlay
            } else if camera.error != nil {
                permissionDeniedView
            } else {
                // Still authorising — show spinner
                ProgressView()
                    .tint(.white)
            }
        }
        .statusBar(hidden: true)
        .onAppear { camera.startSession() }
        .onDisappear { camera.stopSession() }
        .alert("Camera Error", isPresented: Binding(
            get: { camera.error != nil && !camera.isAuthorized },
            set: { if !$0 { camera.error = nil } }
        )) {
            Button("OK") { camera.error = nil }
        } message: {
            Text(camera.error ?? "")
        }
        .fullScreenCover(isPresented: $showVideoPreview) {
            if let url = recordedVideoURL {
                VideoPreviewView(
                    videoURL: url,
                    onRetake: {
                        recordedVideoURL = nil
                        showVideoPreview = false
                    },
                    onUseVideo: { url in
                        onVideoRecorded(url)
                        dismiss()
                    }
                )
            }
        }
        .onValueChange(of: recordedVideoURL) { url in
            if url != nil { showVideoPreview = true }
        }
    }

    // MARK: Camera preview layer

    private var cameraLayer: some View {
        CameraPreviewView(session: camera.captureSession)
            .ignoresSafeArea()
    }

    // MARK: Gesture overlay (tap-to-focus + pinch-to-zoom)

    private var gestureOverlay: some View {
        GestureLayerView(
            initialZoomFactor: camera.zoomFactor,
            onTap: { point in
                camera.focus(at: point, previewLayer: capturedPreviewLayer)
                triggerFocusRing(at: point)
            },
            onPinchChanged: { absoluteZoom in
                camera.setZoom(to: absoluteZoom)
            },
            onPinchEnded: { absoluteZoom in
                camera.setZoom(to: absoluteZoom)
            }
        )
        .ignoresSafeArea()
    }

    // MARK: Focus ring

    @ViewBuilder
    private var focusRingOverlay: some View {
        if showFocusRing, let point = focusPoint {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.yellow, lineWidth: 1.5)
                .frame(width: 72, height: 72)
                .position(point)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.2), value: showFocusRing)
        }
    }

    // MARK: UI overlay (top + bottom bars, filter panel)

    private var uiOverlay: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            HStack(alignment: .bottom, spacing: 0) {
                Spacer()
                if showFilters {
                    VideoFilterView(selectedFilter: $camera.selectedFilter)
                        .padding(.trailing, 10)
                        .padding(.bottom, 110)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            bottomBar
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // Close
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Timer / recording indicator
            if camera.isRecording || !camera.segments.isEmpty {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(camera.isRecording ? 1.0 : 0.3)
                    Text(formatDuration(camera.recordingDuration))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.5))
                .cornerRadius(20)
            }

            Spacer()

            // Flash toggle
            Button { camera.toggleFlash() } label: {
                Image(systemName: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(camera.isFlashOn ? .yellow : .white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.top, 54)
        .padding(.horizontal, 12)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Segment progress track
            if !camera.segments.isEmpty || camera.isRecording {
                segmentTrack
                    .padding(.horizontal, 16)
            }

            // Speed picker
            speedPicker

            // Controls row
            HStack(alignment: .center, spacing: 0) {
                // Effects / filters toggle
                controlButton(icon: "sparkles", label: "Effects") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showFilters.toggle()
                    }
                }

                Spacer()

                // Camera flip
                controlButton(icon: "arrow.triangle.2.circlepath.camera", label: "Flip") {
                    camera.switchCamera()
                }

                Spacer()

                // Record button (hold to record)
                recordButton

                Spacer()

                // Undo last segment
                controlButton(icon: "arrow.uturn.backward.circle",
                              label: "Undo",
                              disabled: camera.segments.isEmpty || camera.isRecording) {
                    camera.undoLastSegment()
                }

                Spacer()

                // Done — finalise and preview
                doneButton
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, Color.black.opacity(0.65)]),
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: Record button (long-press style)

    private var recordButton: some View {
        ZStack {
            Circle()
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 88, height: 88)
            Circle()
                .fill(Color.red)
                .frame(width: camera.isRecording ? 48 : 68,
                       height: camera.isRecording ? 48 : 68)
                .animation(.easeInOut(duration: 0.18), value: camera.isRecording)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !camera.isRecording { camera.startRecording() }
                }
                .onEnded { _ in
                    if camera.isRecording { camera.stopRecording() }
                }
        )
    }

    // MARK: Done button

    private var doneButton: some View {
        let canDone = !camera.segments.isEmpty && !camera.isRecording && !isFinalizing
        return Button {
            guard canDone else { return }
            finalizeRecording()
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(canDone ? Color.white : Color.gray.opacity(0.4))
                        .frame(width: 48, height: 48)
                    if isFinalizing {
                        ProgressView()
                            .tint(.black)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(canDone ? .black : .clear)
                    }
                }
                Text("Done")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(canDone ? .white : .gray)
            }
            .frame(width: 60)
        }
        .disabled(!canDone)
    }

    // MARK: Segment track

    private var segmentTrack: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)
                HStack(spacing: 2) {
                    ForEach(0..<camera.segments.count, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(height: 4)
                    }
                    if camera.isRecording {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.red)
                            .frame(height: 4)
                    }
                }
                .frame(maxWidth: geo.size.width)
            }
        }
        .frame(height: 4)
    }

    // MARK: Speed picker

    private var speedPicker: some View {
        HStack(spacing: 0) {
            ForEach(RecordingSpeed.allCases) { speed in
                Button {
                    camera.selectedSpeed = speed
                } label: {
                    Text(speed.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(camera.selectedSpeed == speed ? .yellow : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            camera.selectedSpeed == speed
                                ? Color.white.opacity(0.15)
                                : Color.clear
                        )
                        .cornerRadius(14)
                }
            }
        }
    }

    // MARK: Permission denied view

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 64))
                .foregroundColor(.white)
            Text("Camera Access Required")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Please enable camera access in Settings to record videos.")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") { dismiss() }
                .foregroundColor(.gray)
                .padding(.top, 8)
        }
    }

    // MARK: Helper: generic control button

    private func controlButton(
        icon: String,
        label: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 10))
            }
            .foregroundColor(disabled ? .gray : .white)
            .frame(width: 60)
        }
        .disabled(disabled)
    }

    // MARK: - Focus ring helpers

    private func triggerFocusRing(at point: CGPoint) {
        focusPoint = point
        withAnimation { showFocusRing = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { showFocusRing = false }
        }
    }

    // MARK: - Duration formatter

    private func formatDuration(_ t: TimeInterval) -> String {
        let minutes = Int(t) / 60
        let seconds = Int(t) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Finalize

    private func finalizeRecording() {
        isFinalizing = true
        Task {
            do {
                let url = try await camera.finalizeRecording()
                await MainActor.run {
                    isFinalizing = false
                    recordedVideoURL = url
                }
            } catch {
                await MainActor.run {
                    isFinalizing = false
                    camera.error = error.localizedDescription
                }
            }
        }
    }
}
