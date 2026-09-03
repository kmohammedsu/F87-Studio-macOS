import AVFoundation
import Foundation

final class MusicVisualizer: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var callback: (([Double]) -> Void)?
    private var smoothed = [Double](repeating: 0, count: 11)
    private var lastEmission = Date.distantPast
    private let lock = NSLock()
    private var hasTap = false

    func start(callback: @escaping ([Double]) -> Void) throws {
        stop()
        self.callback = callback
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw F87Error.unsupported("No microphone input is available for Music mode.")
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.process(buffer: buffer, sampleRate: format.sampleRate)
        }
        hasTap = true
        engine.prepare()
        try engine.start()
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        callback = nil
        smoothed = [Double](repeating: 0, count: 11)
    }

    private func process(buffer: AVAudioPCMBuffer, sampleRate: Double) {
        lock.lock()
        defer { lock.unlock() }
        guard Date().timeIntervalSince(lastEmission) >= 1.0 / 15.0,
              let channel = buffer.floatChannelData?[0] else { return }
        lastEmission = .now
        let count = min(Int(buffer.frameLength), 1024)
        guard count > 64 else { return }

        let low = log(70.0)
        let high = log(min(12_000.0, sampleRate * 0.42))
        var levels = [Double](repeating: 0, count: 11)
        for band in 0..<11 {
            let fraction = Double(band) / 10.0
            let frequency = exp(low + (high - low) * fraction)
            let omega = 2.0 * Double.pi * frequency / sampleRate
            let coefficient = 2.0 * cos(omega)
            var previous = 0.0
            var previous2 = 0.0
            for index in 0..<count {
                let sample = Double(channel[index])
                let value = sample + coefficient * previous - previous2
                previous2 = previous
                previous = value
            }
            let power = max(1e-12, previous2 * previous2 + previous * previous - coefficient * previous * previous2)
            let decibels = 10.0 * log10(power / Double(count * count))
            let normalized = max(0, min(1, (decibels + 62) / 48))
            smoothed[band] = max(normalized, smoothed[band] * 0.76)
            levels[band] = smoothed[band]
        }
        callback?(levels)
    }
}
