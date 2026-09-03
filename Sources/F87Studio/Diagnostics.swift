import Foundation

struct DiagnosticAdvice: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let explanation: String
    let steps: [String]
    let symbol: String
    let opensInputMonitoring: Bool
}

enum ConnectionDiagnostics {
    static let inputMonitoring = DiagnosticAdvice(
        id: "input-monitoring",
        title: "Input Monitoring is blocking access",
        explanation: "macOS can see the AULA control interface, but it will not let F87 Studio open it. Error 0xE00002E2 also means permission was denied.",
        steps: [
            "Quit F87 Studio completely.",
            "Open Privacy & Security → Input Monitoring.",
            "Remove any older F87 Studio entry, add the copy in Applications, and enable it.",
            "Reopen F87 Studio, reconnect the receiver or cable, and scan again."
        ],
        symbol: "hand.raised.fill",
        opensInputMonitoring: true
    )

    static let notFound = DiagnosticAdvice(
        id: "not-found",
        title: "No supported control connection was found",
        explanation: "The keyboard may still type normally even when its vendor configuration interface is unavailable.",
        steps: [
            "For 2.4 GHz, reconnect the receiver and switch the keyboard to receiver mode.",
            "For USB, use a data-capable cable and switch the keyboard to wired mode.",
            "Bluetooth typing is supported by the keyboard, but Bluetooth configuration is not.",
            "Avoid an unpowered USB hub, then scan again."
        ],
        symbol: "magnifyingglass",
        opensInputMonitoring: false
    )

    static let response = DiagnosticAdvice(
        id: "unexpected-response",
        title: "The firmware response was not recognized",
        explanation: "The connected device replied, but its configuration format differs from the verified F87 protocols. No changes were written.",
        steps: [
            "Copy the diagnostic report before reconnecting.",
            "Confirm that the keyboard is an AULA F87 or F87 Pro.",
            "Try wired mode if you are currently using a receiver.",
            "Do not repeatedly apply settings; the app intentionally stopped to protect the keyboard."
        ],
        symbol: "exclamationmark.triangle.fill",
        opensInputMonitoring: false
    )

    static let interruptedWrite = DiagnosticAdvice(
        id: "write-interrupted",
        title: "The connection was interrupted while saving",
        explanation: "The keyboard stopped accepting configuration packets, commonly after a loose cable, receiver interruption, or power-state change.",
        steps: [
            "Reconnect the cable or 2.4 GHz receiver.",
            "Wake the keyboard with a key press.",
            "Scan again and retry the setting once.",
            "Use a direct USB port if the problem repeats."
        ],
        symbol: "bolt.slash.fill",
        opensInputMonitoring: false
    )

    static let verification = DiagnosticAdvice(
        id: "verification",
        title: "The keyboard did not retain the requested setting",
        explanation: "The write completed, but the read-back did not match. F87 Studio reports this instead of claiming that the change succeeded.",
        steps: [
            "Scan again to reload the keyboard’s current state.",
            "Retry the change once with the keyboard awake.",
            "If it repeats, copy the diagnostic report and keep the last working setting."
        ],
        symbol: "checkmark.shield.fill",
        opensInputMonitoring: false
    )

    static let generic = DiagnosticAdvice(
        id: "generic",
        title: "Connection needs attention",
        explanation: "The app could not complete the operation. The copied diagnostic report contains the original error and recent device activity.",
        steps: [
            "Copy the diagnostic report.",
            "Reconnect the receiver or USB cable and wake the keyboard.",
            "Scan again and retry once."
        ],
        symbol: "stethoscope",
        opensInputMonitoring: false
    )

    static let common: [DiagnosticAdvice] = [inputMonitoring, notFound, response, interruptedWrite, verification]

    static func advice(for message: String?) -> DiagnosticAdvice {
        let text = (message ?? "").lowercased()
        if text.contains("input monitoring") || text.contains("not permitted") ||
            text.contains("0xe00002e2") || text.contains("could not open") || text.contains("cannot open") {
            return inputMonitoring
        }
        if text.contains("not found") || text.contains("no configurable") ||
            text.contains("using bluetooth") || text.contains("plug in the usb") {
            return notFound
        }
        if text.contains("unexpected config") || text.contains("unexpected configuration") ||
            text.contains("invalid configuration") || text.contains("unexpected format") {
            return response
        }
        if text.contains("stopped accepting") || text.contains("write failed") ||
            text.contains("connection was interrupted") {
            return interruptedWrite
        }
        if text.contains("verification") || text.contains("did not confirm") ||
            text.contains("did not retain") || text.contains("did not activate") ||
            text.contains("did not enter") {
            return verification
        }
        return generic
    }
}
