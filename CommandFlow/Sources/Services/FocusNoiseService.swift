import AVFoundation
import CoreAudio
import Foundation
import OSLog

struct FocusNoiseTrackDescriptor: Identifiable, Equatable, Hashable {
    let id: String
    let displayName: String
    let systemImage: String
    let resourceName: String
    let sortOrder: Int
}

enum FocusNoiseCatalog {
    static let subdirectory = "Sounds/FocusNoise"

    private static let metadataByStem: [String: (title: String, symbol: String, sortOrder: Int)] = [
        "airplane": ("Airplane", "airplane", 0),
        "brown noise": ("Brown Noise", "waveform.path", 1),
        "deep noise": ("Deep Noise", "waveform.path.ecg", 2),
        "calm rain": ("Calm Rain", "cloud.rain", 3),
        "thunder": ("Thunder", "cloud.bolt.rain", 4),
        "waves": ("Waves", "water.waves", 5),
        "underwater": ("Underwater", "water.waves", 6),
        "steam": ("Steam", "humidity", 7),
        "campfire": ("Campfire", "flame", 8),
        "birds": ("Birds", "bird", 9),
        "cafe": ("Cafe", "cup.and.saucer", 10),
        "binaural5": ("Binaural 5 Hz", "waveform", 11),
        "binaural40-42": ("Binaural 40-42 Hz", "waveform", 12),
        "meditiation1": ("Meditation I", "sparkles", 13),
        "meditation2": ("Meditation II", "sparkles", 14),
    ]

    static func bundledTracks(bundle: Bundle = .main) -> [FocusNoiseTrackDescriptor] {
        let urls = bundledTrackURLs(bundle: bundle)
        guard !urls.isEmpty else { return [] }

        return urls
            .compactMap(descriptor(for:))
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.sortOrder < rhs.sortOrder
            }
    }

    static func resourceURL(for track: FocusNoiseTrackDescriptor, bundle: Bundle = .main) -> URL? {
        if let bundledURL = bundle.url(
            forResource: track.resourceName,
            withExtension: "mp3",
            subdirectory: subdirectory
        ) {
            return bundledURL
        }

        return bundle.url(forResource: track.resourceName, withExtension: "mp3")
    }

    private static func bundledTrackURLs(bundle: Bundle) -> [URL] {
        var urls: [URL] = []

        if let subdirectoryURLs = bundle.urls(forResourcesWithExtension: "mp3", subdirectory: subdirectory) {
            urls.append(contentsOf: subdirectoryURLs)
        }

        if let rootURLs = bundle.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
            urls.append(contentsOf: rootURLs)
        }

        return Array(Set(urls))
    }

    private static func descriptor(for url: URL) -> FocusNoiseTrackDescriptor? {
        let stem = url.deletingPathExtension().lastPathComponent
        let normalizedStem = stem
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let metadata = metadataByStem[normalizedStem]
        let displayName = metadata?.title ?? stem.replacingOccurrences(of: "-", with: " ").localizedCapitalized
        let identifier = normalizedStem
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))

        guard !identifier.isEmpty else {
            return nil
        }

        return FocusNoiseTrackDescriptor(
            id: identifier,
            displayName: displayName,
            systemImage: metadata?.symbol ?? "speaker.wave.3",
            resourceName: stem,
            sortOrder: metadata?.sortOrder ?? .max
        )
    }
}

@MainActor
final class FocusNoiseService {
    private final class TrackPlayback {
        let node: AVAudioPlayerNode
        let buffer: AVAudioPCMBuffer
        var isScheduled = false

        init(node: AVAudioPlayerNode, buffer: AVAudioPCMBuffer) {
            self.node = node
            self.buffer = buffer
        }

        func reset() {
            isScheduled = false
        }
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.hugobrun.commandflow.dev",
        category: "focus-noise"
    )

    private let bundle: Bundle
    private let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    private let engine = AVAudioEngine()
    private let maximumLoopDuration: Double = 36

    private let tracksByID: [String: FocusNoiseTrackDescriptor]
    private var playbacks: [String: TrackPlayback] = [:]
    private var activeTrackIDs: Set<String> = []
    private var trackVolumes: [String: Double] = [:]
    private var masterVolume: Double = 0.52
    private var pauseWhenOtherAudioPlays = false
    private var autoPausedTrackIDs: Set<String> = []
    private var audioOutputPollingTimer: Timer?
    private var lastKnownOtherAudioState = false

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.tracksByID = Dictionary(
            uniqueKeysWithValues: FocusNoiseCatalog.bundledTracks(bundle: bundle).map { ($0.id, $0) }
        )
        _ = engine.mainMixerNode
        _ = engine.outputNode
        logger.notice("Focus noise service initialized with \(self.tracksByID.count) bundled tracks")
    }

    deinit {
        audioOutputPollingTimer?.invalidate()
        playbacks.values.forEach { playback in
            playback.node.stop()
        }
        engine.stop()
    }

    func apply(
        activeTrackIDs: Set<String>,
        trackVolumes: [String: Double],
        masterVolume: Double,
        pauseWhenOtherAudioPlays: Bool
    ) {
        self.activeTrackIDs = Set(activeTrackIDs.filter { tracksByID[$0] != nil })
        self.trackVolumes = trackVolumes
        self.masterVolume = Self.clampedVolume(masterVolume)
        self.pauseWhenOtherAudioPlays = pauseWhenOtherAudioPlays
        logger.notice(
            "Focus noise apply active=\(self.activeTrackIDs.count) master=\(self.masterVolume, format: .fixed(precision: 2)) pauseForOtherAudio=\(self.pauseWhenOtherAudioPlays)"
        )

        updatePollingState()
        syncPlayback(reason: "apply")
    }

    private func updatePollingState() {
        let shouldPoll = pauseWhenOtherAudioPlays && !activeTrackIDs.isEmpty

        guard shouldPoll else {
            audioOutputPollingTimer?.invalidate()
            audioOutputPollingTimer = nil
            lastKnownOtherAudioState = false
            return
        }

        guard audioOutputPollingTimer == nil else {
            return
        }

        audioOutputPollingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncPlayback(reason: "poll")
            }
        }
        audioOutputPollingTimer?.tolerance = 0.18
    }

    private func syncPlayback(reason: String) {
        let otherAudioIsRunning = pauseWhenOtherAudioPlays ? isOtherAudioOutputRunning() : false
        if otherAudioIsRunning != lastKnownOtherAudioState {
            logger.info(
                "Focus noise media state changed (\(reason, privacy: .public)): otherAudio=\(otherAudioIsRunning)"
            )
            lastKnownOtherAudioState = otherAudioIsRunning
        }

        for trackID in activeTrackIDs where playbacks[trackID] == nil {
            loadPlaybackIfNeeded(for: trackID)
        }

        logger.notice(
            "Focus noise sync(\(reason, privacy: .public)) active=\(self.activeTrackIDs.count) loaded=\(self.playbacks.count) otherAudio=\(otherAudioIsRunning)"
        )

        let shouldPlayAnyTrack = !activeTrackIDs.isEmpty && !otherAudioIsRunning
        if shouldPlayAnyTrack {
            startEngineIfNeeded()
        }

        for (trackID, playback) in Array(playbacks) {
            let perTrackVolume = Self.clampedVolume(trackVolumes[trackID] ?? 0.62)
            playback.node.volume = Float(perTrackVolume * masterVolume)

            guard activeTrackIDs.contains(trackID) else {
                autoPausedTrackIDs.remove(trackID)
                stop(playback)
                unloadPlayback(for: trackID, playback: playback)
                continue
            }

            if otherAudioIsRunning {
                if playback.node.isPlaying {
                    playback.node.pause()
                }
                autoPausedTrackIDs.insert(trackID)
                continue
            }

            autoPausedTrackIDs.remove(trackID)
            start(playback)
        }

        if activeTrackIDs.isEmpty {
            engine.pause()
        }
    }

    private func loadPlaybackIfNeeded(for trackID: String) {
        guard playbacks[trackID] == nil else {
            return
        }

        guard let track = tracksByID[trackID] else {
            logger.error("Missing focus noise metadata for track id \(trackID, privacy: .public)")
            return
        }

        guard let url = FocusNoiseCatalog.resourceURL(for: track, bundle: bundle) else {
            logger.error("Missing focus noise resource URL for \(track.displayName, privacy: .public)")
            return
        }

        guard let buffer = loadLoopBuffer(from: url) else {
            logger.error("Unable to load focus noise buffer for \(track.displayName, privacy: .public)")
            return
        }

        let node = AVAudioPlayerNode()
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: buffer.format)
        node.volume = 0
        playbacks[trackID] = TrackPlayback(node: node, buffer: buffer)
        logger.info("Loaded focus noise track \(track.displayName, privacy: .public)")
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else {
            return
        }

        do {
            try engine.start()
        } catch {
            logger.error("Failed to start focus noise engine: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func start(_ playback: TrackPlayback) {
        if !playback.isScheduled {
            playback.node.scheduleBuffer(
                playback.buffer,
                at: nil,
                options: [.loops, .interrupts],
                completionHandler: nil
            )
            playback.isScheduled = true
        }

        if !playback.node.isPlaying {
            logger.notice("Starting focus noise playback")
            playback.node.play()
        }
    }

    private func stop(_ playback: TrackPlayback) {
        playback.node.stop()
        playback.reset()
    }

    private func unloadPlayback(for trackID: String, playback: TrackPlayback) {
        playback.node.stop()
        engine.detach(playback.node)
        playbacks.removeValue(forKey: trackID)
    }

    private func isOtherAudioOutputRunning() -> Bool {
        for processObjectID in audioProcessObjectIDs() {
            guard let processIdentifier = processIdentifier(for: processObjectID),
                  processIdentifier > 0,
                  processIdentifier != ownProcessIdentifier,
                  processHasRunningOutput(processObjectID)
            else {
                continue
            }

            return true
        }

        return false
    }

    private func audioProcessObjectIDs() -> [AudioObjectID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0

        let systemObjectID = AudioObjectID(kAudioObjectSystemObject)
        let sizeStatus = AudioObjectGetPropertyDataSize(systemObjectID, &propertyAddress, 0, nil, &dataSize)
        guard sizeStatus == noErr, dataSize > 0 else {
            return []
        }

        var processObjectIDs = [AudioObjectID](repeating: AudioObjectID(), count: Int(dataSize) / MemoryLayout<AudioObjectID>.size)
        let dataStatus = AudioObjectGetPropertyData(
            systemObjectID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &processObjectIDs
        )

        guard dataStatus == noErr else {
            logger.debug("Audio process list query failed: \(dataStatus)")
            return []
        }

        return processObjectIDs
    }

    private func processIdentifier(for processObjectID: AudioObjectID) -> pid_t? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var processIdentifier: pid_t = 0
        var dataSize = UInt32(MemoryLayout<pid_t>.size)

        let status = AudioObjectGetPropertyData(
            processObjectID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &processIdentifier
        )

        guard status == noErr else {
            return nil
        }

        return processIdentifier
    }

    private func processHasRunningOutput(_ processObjectID: AudioObjectID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var isRunning: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            processObjectID,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &isRunning
        )

        return status == noErr && isRunning != 0
    }

    private func loadLoopBuffer(from url: URL) -> AVAudioPCMBuffer? {
        do {
            let file = try AVAudioFile(forReading: url)
            let processingFormat = file.processingFormat
            let availableFrameCount = AVAudioFramePosition(file.length)
            let maximumLoopFrameCount = AVAudioFramePosition(processingFormat.sampleRate * maximumLoopDuration)
            let targetFrameCount = min(availableFrameCount, maximumLoopFrameCount)

            guard targetFrameCount > 0 else {
                return nil
            }

            let startFrame: AVAudioFramePosition
            if availableFrameCount > targetFrameCount {
                startFrame = (availableFrameCount - targetFrameCount) / 2
            } else {
                startFrame = 0
            }

            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: processingFormat,
                frameCapacity: AVAudioFrameCount(targetFrameCount)
            ) else {
                return nil
            }

            file.framePosition = startFrame
            try file.read(into: buffer, frameCount: AVAudioFrameCount(targetFrameCount))
            guard let stereoSamples = convertToStereoFloat(from: buffer) else {
                logger.error("Unable to decode focus noise track \(url.lastPathComponent, privacy: .public)")
                return nil
            }

            let trimmedSamples = trimLoopBoundaries(in: stereoSamples, sampleRate: processingFormat.sampleRate)
            let conditionedSamples = conditionLoopSeam(in: trimmedSamples, sampleRate: processingFormat.sampleRate)

            guard let loopBuffer = makeStereoBuffer(
                from: conditionedSamples,
                sampleRate: processingFormat.sampleRate
            ) else {
                logger.error("Unable to prepare loop buffer for \(url.lastPathComponent, privacy: .public)")
                return nil
            }

            return loopBuffer
        } catch {
            logger.error("Failed to load focus noise track \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func convertToStereoFloat(from buffer: AVAudioPCMBuffer) -> [Float]? {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else {
            return []
        }

        let inputChannelCount = Int(buffer.format.channelCount)
        var stereoSamples: [Float] = []
        stereoSamples.reserveCapacity(frameCount * 2)

        if let floatChannelData = buffer.floatChannelData {
            if inputChannelCount == 1 {
                let monoChannel = floatChannelData[0]
                for frame in 0..<frameCount {
                    let sample = monoChannel[frame]
                    stereoSamples.append(sample)
                    stereoSamples.append(sample)
                }
            } else {
                let leftChannel = floatChannelData[0]
                let rightChannel = floatChannelData[min(1, inputChannelCount - 1)]
                for frame in 0..<frameCount {
                    stereoSamples.append(leftChannel[frame])
                    stereoSamples.append(rightChannel[frame])
                }
            }

            return stereoSamples
        }

        if let int16ChannelData = buffer.int16ChannelData {
            let normalizationFactor = Float(Int16.max)

            if inputChannelCount == 1 {
                let monoChannel = int16ChannelData[0]
                for frame in 0..<frameCount {
                    let sample = Float(monoChannel[frame]) / normalizationFactor
                    stereoSamples.append(sample)
                    stereoSamples.append(sample)
                }
            } else {
                let leftChannel = int16ChannelData[0]
                let rightChannel = int16ChannelData[min(1, inputChannelCount - 1)]
                for frame in 0..<frameCount {
                    stereoSamples.append(Float(leftChannel[frame]) / normalizationFactor)
                    stereoSamples.append(Float(rightChannel[frame]) / normalizationFactor)
                }
            }

            return stereoSamples
        }

        return nil
    }

    private func trimLoopBoundaries(in stereoSamples: [Float], sampleRate: Double) -> [Float] {
        guard !stereoSamples.isEmpty else {
            return stereoSamples
        }

        let frameCount = stereoSamples.count / 2
        guard frameCount > 1 else {
            return stereoSamples
        }

        let peak = stereoSamples.reduce(Float(0)) { currentPeak, sample in
            max(currentPeak, abs(sample))
        }
        let threshold = max(0.0018, peak * 0.008)

        var firstAudibleFrame = 0
        while firstAudibleFrame < frameCount {
            let sampleIndex = firstAudibleFrame * 2
            let energy = max(abs(stereoSamples[sampleIndex]), abs(stereoSamples[sampleIndex + 1]))
            if energy >= threshold {
                break
            }
            firstAudibleFrame += 1
        }

        var lastAudibleFrame = frameCount - 1
        while lastAudibleFrame > firstAudibleFrame {
            let sampleIndex = lastAudibleFrame * 2
            let energy = max(abs(stereoSamples[sampleIndex]), abs(stereoSamples[sampleIndex + 1]))
            if energy >= threshold {
                break
            }
            lastAudibleFrame -= 1
        }

        let paddingFrames = min(max(Int(sampleRate * 0.015), 96), 960)
        let startFrame = max(0, firstAudibleFrame - paddingFrames)
        let endFrame = min(frameCount - 1, lastAudibleFrame + paddingFrames)

        guard endFrame > startFrame else {
            return stereoSamples
        }

        let trimmed = Array(stereoSamples[(startFrame * 2)...(endFrame * 2 + 1)])
        let trimmedFrameCount = trimmed.count / 2

        guard trimmedFrameCount >= 4_096 else {
            return stereoSamples
        }

        return trimmed
    }

    private func conditionLoopSeam(in stereoSamples: [Float], sampleRate: Double) -> [Float] {
        let frameCount = stereoSamples.count / 2
        guard frameCount > 8_192 else {
            return stereoSamples
        }

        let overlapFrames = min(max(Int(sampleRate * 0.18), 2_048), frameCount / 5)
        guard overlapFrames >= 256 else {
            return stereoSamples
        }

        var conditioned = stereoSamples
        let denominator = Float(max(overlapFrames - 1, 1))

        for frame in 0..<overlapFrames {
            let progress = Float(frame) / denominator
            let fadeIn = sinf(progress * (.pi / 2))
            let fadeOut = cosf(progress * (.pi / 2))
            let tailFrame = frameCount - overlapFrames + frame

            for channel in 0..<2 {
                let headIndex = frame * 2 + channel
                let tailIndex = tailFrame * 2 + channel
                conditioned[tailIndex] = stereoSamples[tailIndex] * fadeOut + stereoSamples[headIndex] * fadeIn
            }
        }

        return conditioned
    }

    private func makeStereoBuffer(from stereoSamples: [Float], sampleRate: Double) -> AVAudioPCMBuffer? {
        let frameCount = stereoSamples.count / 2
        guard frameCount > 0,
              let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: 2,
                interleaved: false
              ),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
              ),
              let channelData = buffer.floatChannelData
        else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)
        let leftChannel = channelData[0]
        let rightChannel = channelData[1]

        for frame in 0..<frameCount {
            leftChannel[frame] = stereoSamples[frame * 2]
            rightChannel[frame] = stereoSamples[frame * 2 + 1]
        }

        return buffer
    }

    private static func clampedVolume(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
