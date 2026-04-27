import CoreGraphics
import Foundation
import OSLog

enum KeyboardStrokePhase: String, Sendable {
    case down
    case up
}

enum KeyboardSoundFamily: String, Sendable {
    case normal
    case space
    case returnKey
    case tab
    case delete
}

struct KeyboardStrokeEvent: Sendable {
    let keyCode: CGKeyCode
    let phase: KeyboardStrokePhase
    let family: KeyboardSoundFamily
    let isAutorepeat: Bool
    let timestamp: UInt64
    let pan: Float
}

final class KeyboardInputMonitor {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.hugobrun.commandflow.dev",
        category: "keyboard-monitor"
    )

    private let eventHandler: (KeyboardStrokeEvent) -> Void
    private let stateLock = NSLock()
    private let modifierLock = NSLock()

    private var monitorThread: Thread?
    private var runLoop: CFRunLoop?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRunning = false
    private var pressedModifierKeyCodes = Set<CGKeyCode>()

    init(eventHandler: @escaping (KeyboardStrokeEvent) -> Void) {
        self.eventHandler = eventHandler
    }

    deinit {
        stop()
    }

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    private func start() {
        stateLock.lock()
        if isRunning || monitorThread != nil {
            stateLock.unlock()
            return
        }

        let thread = Thread { [weak self] in
            self?.monitorLoop()
        }
        thread.name = "CommandFlow.KeyboardMonitor"
        thread.qualityOfService = .userInteractive
        monitorThread = thread
        stateLock.unlock()
        thread.start()
    }

    private func stop() {
        stateLock.lock()
        let currentRunLoop = runLoop
        let shouldStop = isRunning || eventTap != nil || runLoopSource != nil
        isRunning = false
        runLoop = nil
        monitorThread = nil
        stateLock.unlock()

        modifierLock.lock()
        pressedModifierKeyCodes.removeAll()
        modifierLock.unlock()

        guard shouldStop else {
            return
        }

        if let currentRunLoop {
            CFRunLoopPerformBlock(currentRunLoop, CFRunLoopMode.commonModes.rawValue) { [weak self] in
                self?.invalidateTap()
                CFRunLoopStop(currentRunLoop)
            }
            CFRunLoopWakeUp(currentRunLoop)
        } else {
            invalidateTap()
        }
    }

    private func monitorLoop() {
        autoreleasepool {
            let loop = CFRunLoopGetCurrent()
            stateLock.lock()
            runLoop = loop
            stateLock.unlock()

            guard let tap = createEventTap() else {
                logger.error("Unable to create keyboard event tap; Input Monitoring may still be missing or pending")
                stateLock.lock()
                runLoop = nil
                monitorThread = nil
                stateLock.unlock()
                return
            }

            guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
                logger.error("Unable to create keyboard event run loop source")
                CFMachPortInvalidate(tap)
                stateLock.lock()
                runLoop = nil
                monitorThread = nil
                stateLock.unlock()
                return
            }
            stateLock.lock()
            eventTap = tap
            runLoopSource = source
            isRunning = true
            stateLock.unlock()

            CFRunLoopAddSource(loop, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            logger.info("Keyboard event tap started")

            CFRunLoopRun()

            invalidateTap()
            stateLock.lock()
            isRunning = false
            runLoop = nil
            monitorThread = nil
            stateLock.unlock()
            logger.info("Keyboard event tap stopped")
        }
    }

    private func createEventTap() -> CFMachPort? {
        let eventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        let candidates: [(CGEventTapLocation, CGEventTapPlacement, String)] = [
            (.cghidEventTap, .tailAppendEventTap, "cghidEventTap"),
            (.cgSessionEventTap, .headInsertEventTap, "cgSessionEventTap"),
        ]

        for (tapLocation, placement, label) in candidates {
            if let tap = CGEvent.tapCreate(
                tap: tapLocation,
                place: placement,
                options: .listenOnly,
                eventsOfInterest: eventMask,
                callback: Self.tapCallback,
                userInfo: userInfo
            ) {
                logger.info("Using \(label, privacy: .public) for keyboard monitoring")
                return tap
            }
        }

        return nil
    }

    private func invalidateTap() {
        stateLock.lock()
        let tap = eventTap
        let source = runLoopSource
        eventTap = nil
        runLoopSource = nil
        stateLock.unlock()

        if let source, let currentRunLoop = CFRunLoopGetCurrent() as CFRunLoop? {
            CFRunLoopRemoveSource(currentRunLoop, source, .commonModes)
        }

        if let tap {
            CFMachPortInvalidate(tap)
        }
    }

    private func process(_ event: CGEvent, type: CGEventType) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            stateLock.lock()
            let tap = eventTap
            stateLock.unlock()
            if let tap {
                logger.info("Re-enabling keyboard event tap after temporary disable")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        case .keyDown, .keyUp:
            let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
            let phase: KeyboardStrokePhase = type == .keyDown ? .down : .up
            let keyboardEvent = KeyboardStrokeEvent(
                keyCode: keyCode,
                phase: phase,
                family: Self.family(for: keyCode),
                isAutorepeat: type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
                timestamp: event.timestamp,
                pan: Self.pan(for: keyCode)
            )
            eventHandler(keyboardEvent)
        case .flagsChanged:
            guard let modifierEvent = modifierEvent(from: event) else {
                return
            }
            eventHandler(modifierEvent)
        default:
            return
        }
    }

    private func modifierEvent(from event: CGEvent) -> KeyboardStrokeEvent? {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard let expectedFlag = Self.modifierFlag(for: keyCode) else {
            return nil
        }

        let isPressed = event.flags.contains(expectedFlag)

        modifierLock.lock()
        let phase: KeyboardStrokePhase?
        if isPressed {
            let inserted = pressedModifierKeyCodes.insert(keyCode).inserted
            phase = inserted ? .down : nil
        } else {
            let removed = pressedModifierKeyCodes.remove(keyCode) != nil
            phase = removed ? .up : nil
        }
        modifierLock.unlock()

        guard let phase else {
            return nil
        }

        return KeyboardStrokeEvent(
            keyCode: keyCode,
            phase: phase,
            family: .normal,
            isAutorepeat: false,
            timestamp: event.timestamp,
            pan: Self.pan(for: keyCode)
        )
    }

    private static func family(for keyCode: CGKeyCode) -> KeyboardSoundFamily {
        switch keyCode {
        case 49:
            return .space
        case 36, 76:
            return .returnKey
        case 48:
            return .tab
        case 51, 117:
            return .delete
        default:
            return .normal
        }
    }

    private static func modifierFlag(for keyCode: CGKeyCode) -> CGEventFlags? {
        switch keyCode {
        case 54, 55:
            return .maskCommand
        case 56, 60:
            return .maskShift
        case 58, 61:
            return .maskAlternate
        case 59, 62:
            return .maskControl
        default:
            return nil
        }
    }

    private static func pan(for keyCode: CGKeyCode) -> Float {
        let rows: [[CGKeyCode]] = [
            [53, 50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 33, 30, 42, 51],
            [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 37, 41, 39],
            [59, 58, 57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36],
            [56, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60],
            [61, 55, 49, 54, 62],
        ]

        for row in rows {
            guard let index = row.firstIndex(of: keyCode) else {
                continue
            }

            if row.count == 1 {
                return 0
            }

            let normalized = (Float(index) / Float(row.count - 1)) * 2 - 1
            return normalized * 0.42
        }

        return 0
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<KeyboardInputMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.process(event, type: type)
        return Unmanaged.passUnretained(event)
    }
}
