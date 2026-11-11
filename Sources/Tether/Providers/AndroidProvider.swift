import Foundation

struct AdbEntry: Equatable, Sendable {
    enum Transport: Sendable { case usb, wifi, emulator }

    var serial: String
    /// device / unauthorized / offline …
    var state: String
    var model: String?
    var transport: Transport
}

enum AndroidProvider {
    // MARK: 파서

    /// `adb devices -l` 출력.
    static func parseDevices(_ output: String) -> [AdbEntry] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard fields.count >= 2,
                  !line.hasPrefix("List of devices"),
                  !line.hasPrefix("*") // "* daemon started successfully"
            else { return nil }

            let serial = fields[0]
            var props: [String: String] = [:]
            for field in fields.dropFirst(2) {
                guard let colon = field.firstIndex(of: ":") else { continue }
                props[String(field[..<colon])] = String(field[field.index(after: colon)...])
            }

            let transport: AdbEntry.Transport =
                if serial.hasPrefix("emulator-") { .emulator }
                else if serial.contains(":") || serial.contains("._adb-tls-connect") { .wifi }
                else { .usb }

            return AdbEntry(
                serial: serial,
                state: fields[1],
                model: props["model"]?.replacingOccurrences(of: "_", with: "-"),
                transport: transport
            )
        }
    }

    /// `dumpsys battery` 출력에서 `level:` 값.
    static func parseBatteryLevel(_ output: String) -> Int? {
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("level:") else { continue }
            return Int(trimmed.dropFirst("level:".count).trimmingCharacters(in: .whitespaces))
        }
        return nil
    }

    static func device(from entry: AdbEntry, friendlyName: String?, battery: Int?) -> Device {
        let transportLabel = switch entry.transport {
        case .usb: "USB"
        case .wifi: "Wi-Fi"
        case .emulator: "에뮬레이터"
        }
        let ready = entry.state == "device"
        let stateLabel: String? = switch entry.state {
        case "device": nil
        case "unauthorized": "USB 디버깅 승인 필요"
        case "offline": "오프라인"
        default: entry.state
        }

        let name = friendlyName ?? entry.model ?? entry.serial
        var parts: [String] = []
        if let model = entry.model, model != name { parts.append(model) }
        parts.append(transportLabel)
        if let stateLabel { parts.append(stateLabel) }

        return Device(
            id: "adb:\(entry.serial)",
            name: name,
            detail: parts.joined(separator: " · "),
            kind: .dev,
            accent: .android,
            symbol: entry.transport == .emulator ? "smartphone.badge.play" : "smartphone",
            battery: battery,
            copyText: entry.serial,
            serial: entry.transport == .usb ? entry.serial : nil,
            needsAttention: !ready
        )
    }

    // MARK: 실행

    static func adbPath() -> String? {
        var candidates: [String] = []
        for key in ["ANDROID_HOME", "ANDROID_SDK_ROOT"] {
            if let root = ProcessInfo.processInfo.environment[key] {
                candidates.append("\(root)/platform-tools/adb")
            }
        }
        candidates.append("\(NSHomeDirectory())/Library/Android/sdk/platform-tools/adb")
        candidates.append("/opt/homebrew/bin/adb")
        candidates.append("/usr/local/bin/adb")
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// adb 가 없으면 빈 목록, 명령이 실패하면 nil(직전 값 유지).
    static func fetch(nameCache: inout [String: String]) async -> [Device]? {
        guard let adb = adbPath() else { return [] }
        guard let output = await Shell.runText(adb, ["devices", "-l"]) else { return nil }

        var devices: [Device] = []
        for entry in parseDevices(output) {
            var battery: Int?
            if entry.state == "device" {
                if nameCache[entry.serial] == nil,
                   let raw = await Shell.runText(adb, ["-s", entry.serial, "shell", "settings", "get", "global", "device_name"], timeout: 3)
                {
                    let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty, name != "null" { nameCache[entry.serial] = name }
                }
                if let raw = await Shell.runText(adb, ["-s", entry.serial, "shell", "dumpsys", "battery"], timeout: 3) {
                    battery = parseBatteryLevel(raw)
                }
            }
            devices.append(device(from: entry, friendlyName: nameCache[entry.serial], battery: battery))
        }
        return devices
    }
}
