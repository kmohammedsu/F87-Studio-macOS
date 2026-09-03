import XCTest
@testable import F87Studio

final class F87ProtocolTests: XCTestCase {
    func testMacFunctionRowDefaultsAndVirtualKeyMapping() {
        XCTAssertEqual(FunctionRowController.macBookDefaults[1], .brightnessDown)
        XCTAssertEqual(FunctionRowController.macBookDefaults[2], .brightnessUp)
        XCTAssertEqual(FunctionRowController.macBookDefaults[5], .dictation)
        XCTAssertEqual(FunctionRowController.macBookDefaults[6], .focusControls)
        XCTAssertEqual(FunctionRowController.macBookDefaults[8], .playPause)
        XCTAssertEqual(FunctionRowController.macBookDefaults[12], .volumeUp)
        XCTAssertEqual(FunctionRowController.functionKey(forVirtualKeyCode: 0x7A), 1)
        XCTAssertEqual(FunctionRowController.functionKey(forVirtualKeyCode: 0x6F), 12)
        XCTAssertNil(FunctionRowController.functionKey(forVirtualKeyCode: 0x00))
        XCTAssertTrue(MacFunctionAction.brightnessDown.isRepeatable)
        XCTAssertTrue(MacFunctionAction.externalBrightnessDown.isRepeatable)
        XCTAssertFalse(MacFunctionAction.playPause.isRepeatable)
    }

    @MainActor
    func testRepeatedHIDEnumerationStaysOnPersistentRunLoop() {
        XCTAssertTrue(Thread.isMainThread)
        for _ in 0..<12 {
            _ = HIDDiscovery.candidates()
        }
    }

    func testFrameChecksumAndShape() {
        let frame = F87Protocol.readRequest()
        XCTAssertEqual(frame.count, 20)
        XCTAssertEqual(frame.prefix(4), [0x13, 0x44, 0x01, 0x00])
        XCTAssertEqual(frame[19], F87Protocol.checksum(frame))
    }

    func testPerKeyPlaneEncoding() {
        let frames = F87Protocol.perKeyFrames(colors: [14: .init(red: 10, green: 20, blue: 30)])
        XCTAssertEqual(frames.count, 28)
        XCTAssertEqual(frames[1][5], 10)
        XCTAssertEqual(frames[10][5], 20)
        XCTAssertEqual(frames[19][5], 30)
        XCTAssertEqual(Array(frames[27][4...8]), [0x06, 0x00, 0x00, 0x5A, 0xA5])
    }

    func testEffectMutationPreservesOtherBytes() throws {
        var config = (0..<10).map { seq in
            F87Protocol.frame(command: F87Protocol.commandRead, subcommand: F87Protocol.subConfig,
                              sequence: UInt8(seq), payload: [0x0e] + [UInt8](repeating: 0, count: 14))
        }
        config[0][12] = 0xBC
        let result = try F87Protocol.updateEffect(config: config, effect: 2, brightness: 3,
                                                  speed: 4, colorful: false, usesCustomColor: true)
        XCTAssertEqual(result[0][12], 0xBC)
        XCTAssertEqual(result[0][15], 2)
        XCTAssertEqual(result[4][9], 3)
        XCTAssertEqual(result[4][10], 0x40)
        XCTAssertTrue(result.allSatisfy { $0[19] == F87Protocol.checksum($0) })
    }

    func testOnlyValidatedReceiverEffectsAreExposed() {
        XCTAssertEqual(F87Protocol.supportedEffectIDs,
                       [0, 1, 2, 3, 4, 5, 7, 8, 10, 11, 12, 13, 15, 16, 17])
        XCTAssertFalse(F87Protocol.supportedEffectIDs.contains(6))
        XCTAssertFalse(F87Protocol.supportedEffectIDs.contains(18))
    }

    func testPaletteCustomColorAndTrailer() {
        let frames = F87Protocol.paletteFrames(color: .init(red: 0x12, green: 0x34, blue: 0x56))
        XCTAssertEqual(frames.count, 37)
        XCTAssertEqual(Array(frames[1][12...14]), [0x12, 0x34, 0x56])
        XCTAssertEqual(frames[1][16], 0xFF)
        XCTAssertEqual(Array(frames[36][4...8]), [0x08, 0x00, 0x00, 0x5A, 0xA5])
        XCTAssertTrue(frames.allSatisfy { $0[19] == F87Protocol.checksum($0) })
    }

    func testFactoryConfigFramesMatchCapturedOEMDefaults() {
        let frames = F87Protocol.factoryConfigFrames()
        XCTAssertEqual(frames.count, 10)
        XCTAssertTrue(frames.enumerated().allSatisfy { index, frame in
            frame.count == 20 && frame[0] == F87Protocol.reportID &&
                frame[1] == F87Protocol.commandWrite && frame[2] == F87Protocol.subConfig &&
                frame[3] == UInt8(index) && frame[19] == F87Protocol.checksum(frame)
        })
        XCTAssertEqual(frames[0][8], 0x01)
        XCTAssertEqual(frames[0][15], 0x00)
        XCTAssertEqual(frames[1][15], 0x0A)
        XCTAssertEqual(Array(frames[9][4...6]), [0x02, 0x5A, 0xA5])
    }

    func testCustomModePreservesConfigurationAndSetsRequiredFlags() throws {
        var config = (0..<10).map { seq in
            F87Protocol.frame(command: F87Protocol.commandRead, subcommand: F87Protocol.subConfig,
                              sequence: UInt8(seq), payload: [0x0E] + [UInt8](repeating: 0, count: 14))
        }
        config[3][10] = 0xAB
        let result = try F87Protocol.customModeConfig(from: config)
        XCTAssertEqual(result[0][8], 0x01)
        XCTAssertEqual(result[0][14], 0x00)
        XCTAssertEqual(result[0][15], F87Protocol.customEffect)
        XCTAssertEqual(result[0][17], 0x01)
        XCTAssertEqual(result[3][10], 0xAB)
        XCTAssertTrue(result.allSatisfy { $0[19] == F87Protocol.checksum($0) })
    }

    func testFeatureConfigWritePreservesUnknownFields() throws {
        var config = [UInt8](repeating: 0, count: 520)
        config[0] = 0x06
        config[1] = 0x84
        config[42] = 0xCC
        config[134] = 0x5A
        config[135] = 0xA5
        let write = try FeatureF87Protocol.configWrite(from: config, effect: 3,
                                                       brightness: 4, speed: 2, colorful: true)
        XCTAssertEqual(write.count, 520)
        XCTAssertEqual(Array(write.prefix(7)), [0x06, 0x04, 0, 0, 1, 0, 0x80])
        XCTAssertEqual(write[18], 3)
        XCTAssertEqual(write[42], 0xCC)
        XCTAssertEqual(write[70], 4)
        XCTAssertEqual(write[71], 0x27)
        XCTAssertEqual(Array(write[134...135]), [0x5A, 0xA5])
    }

    func testFeaturePerKeyPlanes() {
        let data = FeatureF87Protocol.perKeyColors([14: .init(red: 10, green: 20, blue: 30)])
        XCTAssertEqual(data.count, 520)
        XCTAssertEqual(data[22], 10)
        XCTAssertEqual(data[148], 20)
        XCTAssertEqual(data[274], 30)
    }

    func testPermissionFailureGetsInputMonitoringDiagnosis() {
        let advice = ConnectionDiagnostics.advice(
            for: "hid_open_path failed (0xE00002E2) (iokit/common) not permitted"
        )
        XCTAssertEqual(advice.id, "input-monitoring")
        XCTAssertTrue(advice.opensInputMonitoring)
    }

    func testUnknownFirmwareGetsSafeResponseDiagnosis() {
        let advice = ConnectionDiagnostics.advice(for: "Unexpected config response (520 bytes)")
        XCTAssertEqual(advice.id, "unexpected-response")
        XCTAssertTrue(advice.explanation.contains("No changes were written"))
    }

    func testFailedReadBackGetsVerificationDiagnosis() {
        let advice = ConnectionDiagnostics.advice(for: "The keyboard did not retain the requested speed")
        XCTAssertEqual(advice.id, "verification")
    }

    func testAudioIdleFrameMatchesCapturedOEMPacket() {
        let frame = F87Protocol.audioIdleFrame()
        XCTAssertEqual(frame.count, 20)
        XCTAssertEqual(Array(frame.prefix(5)), [0x13, 0x88, 0x01, 0x00, 0x23])
        XCTAssertEqual(frame[19], 0xBF)
    }

    func testAudioFramesAreBoundedAndChecksummed() {
        let colors = Dictionary(uniqueKeysWithValues: F87Layout.allKeys.enumerated().map { index, key in
            (key.led, RGBColor(red: UInt8((index * 17) % 255),
                               green: UInt8((index * 31) % 255),
                               blue: UInt8((index * 47) % 255)))
        })
        let frames = F87Protocol.audioFrames(colors: colors)
        XCTAssertTrue((1...14).contains(frames.count))
        XCTAssertTrue(frames.enumerated().allSatisfy { index, frame in
            frame.count == 20 && frame[0] == 0x13 && frame[1] == 0x88 &&
                frame[2] == UInt8(frames.count) && frame[3] == UInt8(index) &&
                frame[19] == F87Protocol.checksum(frame)
        })
    }

    func testPerKeyHitTestingUsesVisibleLayout() {
        let escape = F87Layout.key(at: CGPoint(x: 30, y: 30), unit: 40)
        XCTAssertEqual(escape?.label, "Esc")
        XCTAssertNil(F87Layout.key(at: CGPoint(x: 10, y: 10), unit: 40))
    }
}
