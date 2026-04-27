import AudioToolbox
import AVFoundation
import Foundation
import OSLog

final class KeyboardSoundService {
    private enum SampleToken: String, CaseIterable {
        case normalDown = "normal_down"
        case normalUp = "normal_up"
        case spaceDown = "space_down"
        case spaceUp = "space_up"
        case returnDown = "return_down"
        case returnUp = "return_up"
        case tabDown = "tab_down"
        case tabUp = "tab_up"
        case deleteDown = "delete_down"
        case deleteUp = "delete_up"

        init?(event: KeyboardStrokeEvent) {
            switch (event.family, event.phase) {
            case (.normal, .down):
                self = .normalDown
            case (.normal, .up):
                self = .normalUp
            case (.space, .down):
                self = .spaceDown
            case (.space, .up):
                self = .spaceUp
            case (.returnKey, .down):
                self = .returnDown
            case (.returnKey, .up):
                self = .returnUp
            case (.tab, .down):
                self = .tabDown
            case (.tab, .up):
                self = .tabUp
            case (.delete, .down):
                self = .deleteDown
            case (.delete, .up):
                self = .deleteUp
            }
        }
    }

    private struct PCMSound {
        let samples: [Float]
        let frameCount: Int
    }

    private final class ActiveSound {
        let pcmSound: PCMSound
        let playbackRate: Float
        let leftGain: Float
        let rightGain: Float
        var framePosition: Float = 0

        init(pcmSound: PCMSound, playbackRate: Float, leftGain: Float, rightGain: Float) {
            self.pcmSound = pcmSound
            self.playbackRate = playbackRate
            self.leftGain = leftGain
            self.rightGain = rightGain
        }

        var isFinished: Bool {
            Int(framePosition) >= pcmSound.frameCount - 1
        }
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.hugobrun.commandflow.dev",
        category: "keyboard-audio"
    )

    private let queueLock = NSLock()
    private let activeSoundsLock = NSLock()
    private let sampleSelectionLock = NSLock()
    private let timerLock = NSLock()

    private let idleTimeout: TimeInterval = 0
    private let framesPerBuffer: UInt32 = 128
    private let numberOfBuffers = 4
    private let sampleRate: Double = 44_100
    private let channelCount: UInt32 = 2

    private var audioQueue: AudioQueueRef?
    private var audioBuffers: [AudioQueueBufferRef] = []
    private var audioFormat = AudioStreamBasicDescription()
    private var soundLibrary: [SampleToken: [PCMSound]] = [:]
    private var activeSounds: [ActiveSound] = []
    private var lastSampleIndexByToken: [SampleToken: Int] = [:]
    private var idleTimer: DispatchSourceTimer?
    private var isQueueRunning = false
    private var isReady = false
    private var isEnabled = false
    private var masterVolume: Float = 0.34

    init() {
        setupAudioFormat()
        preloadBundledSounds()
        createAudioQueue()
    }

    deinit {
        timerLock.lock()
        idleTimer?.cancel()
        idleTimer = nil
        timerLock.unlock()
        disposeAudioQueue()
    }

    func setEnabled(_ enabled: Bool) {
        queueLock.lock()
        isEnabled = enabled
        queueLock.unlock()

        if enabled {
            ensureQueueRunning()
        } else {
            activeSoundsLock.lock()
            activeSounds.removeAll()
            activeSoundsLock.unlock()
            stopQueueIfRunning()
        }
    }

    func setVolume(_ value: Double) {
        queueLock.lock()
        masterVolume = Float(min(max(value, 0), 1))
        queueLock.unlock()
    }

    func handle(_ event: KeyboardStrokeEvent) {
        guard !event.isAutorepeat else {
            return
        }

        queueLock.lock()
        let enabled = isEnabled
        let ready = isReady
        queueLock.unlock()

        guard enabled, ready else {
            return
        }

        guard let token = SampleToken(event: event),
              let pcmSound = nextSound(for: token)
        else {
            return
        }

        ensureQueueRunning()

        let phaseGain: Float = event.phase == .down ? 1.0 : 0.42
        let familyGain: Float = switch event.family {
        case .normal:
            1.0
        case .space:
            1.08
        case .returnKey:
            1.05
        case .tab:
            0.96
        case .delete:
            0.92
        }
        let pitchOffset = Float.random(in: event.phase == .down ? -0.04...0.03 : -0.018...0.018)
        let playbackRate = powf(2, pitchOffset / 12)
        let dynamicGain = Float.random(in: 0.985...1.02) * phaseGain * familyGain
        let pan = max(-1, min(1, event.pan * 0.16))
        let angle = (pan + 1) * Float.pi / 4
        let leftGain = cosf(angle) * dynamicGain
        let rightGain = sinf(angle) * dynamicGain

        let activeSound = ActiveSound(
            pcmSound: pcmSound,
            playbackRate: playbackRate,
            leftGain: leftGain,
            rightGain: rightGain
        )

        activeSoundsLock.lock()
        activeSounds.append(activeSound)
        activeSoundsLock.unlock()
        resetIdleTimer()
    }

    func preloadBundledSounds() {
        let allWavURLs = bundledSoundURLs()
        let hasTactileNormalDownPack = allWavURLs.contains { url in
            url.deletingPathExtension().lastPathComponent.hasPrefix("normal_down_tactile_")
        }

        var nextLibrary: [SampleToken: [PCMSound]] = [:]
        for token in SampleToken.allCases {
            let matches = soundURLs(
                for: token,
                from: allWavURLs,
                hasTactileNormalDownPack: hasTactileNormalDownPack
            )

            nextLibrary[token] = matches.compactMap(loadSound)
        }

        soundLibrary = nextLibrary
        lastSampleIndexByToken.removeAll()
        logger.info("Preloaded \(self.soundLibrary.values.flatMap { $0 }.count) keyboard samples")
    }

    private func soundURLs(
        for token: SampleToken,
        from allWavURLs: [URL],
        hasTactileNormalDownPack: Bool
    ) -> [URL] {
        let tactileDownTokens: Set<SampleToken> = [.normalDown, .spaceDown, .returnDown, .tabDown, .deleteDown]
        let tactileSilentUpTokens: Set<SampleToken> = [.normalUp, .spaceUp, .returnUp, .tabUp, .deleteUp]

        if hasTactileNormalDownPack, tactileDownTokens.contains(token) {
            return allWavURLs
                .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix("normal_down_tactile_") }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        if hasTactileNormalDownPack, tactileSilentUpTokens.contains(token) {
            // The tactile recordings already include enough body and release,
            // so keeping the legacy up-samples makes each stroke feel doubled.
            return []
        }

        return allWavURLs
            .filter { $0.deletingPathExtension().lastPathComponent.hasPrefix(token.rawValue + "_") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func setupAudioFormat() {
        audioFormat = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(MemoryLayout<Float>.size) * channelCount,
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(MemoryLayout<Float>.size) * channelCount,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 32,
            mReserved: 0
        )
    }

    private func createAudioQueue() {
        queueLock.lock()
        if audioQueue != nil {
            queueLock.unlock()
            return
        }
        queueLock.unlock()

        let status = AudioQueueNewOutput(
            &audioFormat,
            Self.audioQueueCallback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            nil,
            nil,
            0,
            &audioQueue
        )

        guard status == noErr, let audioQueue else {
            logger.error("Unable to create AudioQueue: \(status)")
            return
        }

        let bufferSize = framesPerBuffer * audioFormat.mBytesPerFrame
        for _ in 0..<numberOfBuffers {
            var buffer: AudioQueueBufferRef?
            let bufferStatus = AudioQueueAllocateBuffer(audioQueue, bufferSize, &buffer)
            guard bufferStatus == noErr, let buffer else {
                logger.error("Unable to allocate audio buffer: \(bufferStatus)")
                continue
            }

            audioBuffers.append(buffer)
        }

        queueLock.lock()
        isReady = true
        queueLock.unlock()
    }

    private func disposeAudioQueue() {
        queueLock.lock()
        let queue = audioQueue
        audioQueue = nil
        audioBuffers.removeAll()
        isQueueRunning = false
        isReady = false
        queueLock.unlock()

        if let queue {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }
    }

    private func ensureQueueRunning() {
        if audioQueue == nil {
            createAudioQueue()
        }

        queueLock.lock()
        let queue = audioQueue
        let shouldRestart = isReady && !isQueueRunning
        queueLock.unlock()

        guard shouldRestart, let queue else {
            resetIdleTimer()
            return
        }

        for buffer in audioBuffers {
            prime(buffer: buffer, queue: queue)
        }

        let status = AudioQueueStart(queue, nil)
        if status == noErr {
            queueLock.lock()
            isQueueRunning = true
            queueLock.unlock()
            logger.debug("AudioQueue restarted")
        } else {
            logger.error("Failed to restart AudioQueue: \(status)")
        }

        resetIdleTimer()
    }

    private func bundledSoundURLs() -> [URL] {
        var urls: [URL] = []

        if let soundsURL = Bundle.main.resourceURL?.appendingPathComponent("Sounds", isDirectory: true) {
            let enumerator = FileManager.default.enumerator(
                at: soundsURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension.caseInsensitiveCompare("wav") == .orderedSame else {
                    continue
                }
                urls.append(fileURL)
            }
        }

        if let rootURLs = Bundle.main.urls(forResourcesWithExtension: "wav", subdirectory: nil) {
            urls.append(contentsOf: rootURLs)
        }

        if urls.isEmpty, let resourceURL = Bundle.main.resourceURL {
            let enumerator = FileManager.default.enumerator(
                at: resourceURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            while let fileURL = enumerator?.nextObject() as? URL {
                guard fileURL.pathExtension.caseInsensitiveCompare("wav") == .orderedSame else {
                    continue
                }
                urls.append(fileURL)
            }
        }

        return Array(Set(urls)).sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func nextSound(for token: SampleToken) -> PCMSound? {
        guard let sounds = soundLibrary[token], !sounds.isEmpty else {
            return nil
        }

        if sounds.count == 1 {
            return sounds[0]
        }

        sampleSelectionLock.lock()
        defer { sampleSelectionLock.unlock() }

        let previousIndex = lastSampleIndexByToken[token]
        var nextIndex = Int.random(in: 0..<sounds.count)
        if let previousIndex, nextIndex == previousIndex {
            nextIndex = (nextIndex + Int.random(in: 1..<sounds.count)) % sounds.count
        }

        lastSampleIndexByToken[token] = nextIndex
        return sounds[nextIndex]
    }

    private func stopQueueIfRunning() {
        timerLock.lock()
        idleTimer?.cancel()
        idleTimer = nil
        timerLock.unlock()

        queueLock.lock()
        let queue = audioQueue
        let shouldStop = isQueueRunning
        queueLock.unlock()

        guard shouldStop, let queue else {
            return
        }

        let status = AudioQueueStop(queue, true)
        if status == noErr {
            queueLock.lock()
            isQueueRunning = false
            queueLock.unlock()
        } else {
            logger.error("Failed to stop AudioQueue: \(status)")
        }
    }

    private func resetIdleTimer() {
        guard idleTimeout > 0 else {
            return
        }

        timerLock.lock()
        idleTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
        timer.schedule(deadline: .now() + idleTimeout, repeating: .never)
        timer.setEventHandler { [weak self] in
            self?.stopQueueAfterIdle()
        }
        idleTimer = timer
        timer.resume()
        timerLock.unlock()
    }

    private func stopQueueAfterIdle() {
        activeSoundsLock.lock()
        let hasActiveSounds = !activeSounds.isEmpty
        activeSoundsLock.unlock()

        guard !hasActiveSounds else {
            return
        }

        queueLock.lock()
        let queue = audioQueue
        let shouldStop = isQueueRunning
        queueLock.unlock()

        guard shouldStop, let queue else {
            return
        }

        let status = AudioQueueStop(queue, true)
        if status == noErr {
            queueLock.lock()
            isQueueRunning = false
            queueLock.unlock()
            logger.debug("AudioQueue stopped after idle timeout")
        }
    }

    private func fillBuffer(_ buffer: AudioQueueBufferRef, queue: AudioQueueRef) {
        let sampleCount = Int(framesPerBuffer * channelCount)
        let byteCount = Int(framesPerBuffer * audioFormat.mBytesPerFrame)
        let outputBuffer = buffer.pointee.mAudioData.assumingMemoryBound(to: Float.self)
        memset(outputBuffer, 0, byteCount)

        activeSoundsLock.lock()

        queueLock.lock()
        let volume = masterVolume
        queueLock.unlock()

        for sound in activeSounds {
            render(sound: sound, into: outputBuffer, frameCount: Int(framesPerBuffer), masterVolume: volume)
        }

        activeSounds.removeAll { $0.isFinished }
        activeSoundsLock.unlock()

        for index in 0..<sampleCount {
            outputBuffer[index] = min(max(outputBuffer[index], -1), 1)
        }

        buffer.pointee.mAudioDataByteSize = UInt32(byteCount)
        let status = AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
        if status != noErr {
            logger.error("Failed to enqueue audio buffer: \(status)")
        }
    }

    private func render(sound: ActiveSound, into outputBuffer: UnsafeMutablePointer<Float>, frameCount: Int, masterVolume: Float) {
        let channelCount = Int(channelCount)
        let pcmSamples = sound.pcmSound.samples
        let sourceFrameCount = sound.pcmSound.frameCount

        for frame in 0..<frameCount {
            let sourcePosition = sound.framePosition + Float(frame) * sound.playbackRate
            let sourceFrame = Int(sourcePosition)

            guard sourceFrame < sourceFrameCount - 1 else {
                sound.framePosition = Float(sourceFrameCount)
                break
            }

            let fraction = sourcePosition - Float(sourceFrame)
            let baseIndex = sourceFrame * channelCount
            let nextIndex = baseIndex + channelCount

            let leftSample = interpolatedSample(
                current: pcmSamples[baseIndex],
                next: pcmSamples[nextIndex],
                fraction: fraction
            )
            let rightSample = interpolatedSample(
                current: pcmSamples[baseIndex + 1],
                next: pcmSamples[nextIndex + 1],
                fraction: fraction
            )

            let outputIndex = frame * channelCount
            outputBuffer[outputIndex] += leftSample * sound.leftGain * masterVolume
            outputBuffer[outputIndex + 1] += rightSample * sound.rightGain * masterVolume
        }

        sound.framePosition += Float(frameCount) * sound.playbackRate
    }

    private func interpolatedSample(current: Float, next: Float, fraction: Float) -> Float {
        current + (next - current) * fraction
    }

    private func prime(buffer: AudioQueueBufferRef, queue: AudioQueueRef) {
        let byteCount = Int(framesPerBuffer * audioFormat.mBytesPerFrame)
        memset(buffer.pointee.mAudioData, 0, byteCount)
        buffer.pointee.mAudioDataByteSize = UInt32(byteCount)
        let status = AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
        if status != noErr {
            logger.error("Failed to prime audio buffer: \(status)")
        }
    }

    private func loadSound(from url: URL) -> PCMSound? {
        do {
            let file = try AVAudioFile(forReading: url)
            let processingFormat = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)

            guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
                return nil
            }

            try file.read(into: buffer)
            guard let samples = convertToStereoFloat(from: buffer) else {
                return nil
            }

            let trimmedSamples = trimLeadingSilence(in: samples)
            return PCMSound(
                samples: trimmedSamples,
                frameCount: trimmedSamples.count / Int(channelCount)
            )
        } catch {
            logger.error("Failed to load keyboard sample \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func convertToStereoFloat(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let floatChannelData = buffer.floatChannelData else {
            return nil
        }

        let frameCount = Int(buffer.frameLength)
        let inputChannelCount = Int(buffer.format.channelCount)
        var stereoSamples: [Float] = []
        stereoSamples.reserveCapacity(frameCount * 2)

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

    private func trimLeadingSilence(in stereoSamples: [Float]) -> [Float] {
        guard !stereoSamples.isEmpty else {
            return stereoSamples
        }

        let channels = Int(channelCount)
        let frameCount = stereoSamples.count / channels
        guard frameCount > 1 else {
            return stereoSamples
        }

        let peak = stereoSamples.reduce(Float(0)) { currentPeak, sample in
            max(currentPeak, abs(sample))
        }
        let threshold = max(0.004, peak * 0.015)

        var firstAudibleFrame = 0
        while firstAudibleFrame < frameCount {
            let index = firstAudibleFrame * channels
            if abs(stereoSamples[index]) >= threshold || abs(stereoSamples[index + 1]) >= threshold {
                break
            }
            firstAudibleFrame += 1
        }

        let prerollFrames = 48
        let trimmedFrame = max(0, firstAudibleFrame - prerollFrames)
        guard trimmedFrame > 0 else {
            return stereoSamples
        }

        return Array(stereoSamples[(trimmedFrame * channels)...])
    }

    private static let audioQueueCallback: AudioQueueOutputCallback = { userData, queue, buffer in
        guard let userData else {
            return
        }

        let service = Unmanaged<KeyboardSoundService>.fromOpaque(userData).takeUnretainedValue()
        service.fillBuffer(buffer, queue: queue)
    }
}
