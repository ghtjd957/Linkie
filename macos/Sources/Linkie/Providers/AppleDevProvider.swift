import Foundation

enum AppleDevProvider {
    // MARK: 시뮬레이터

    /// `xcrun simctl list devices booted -j` 출력.
    static func parseSimulators(_ data: Data) -> [Device] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runtimes = root["devices"] as? [String: [[String: Any]]]
        else { return [] }

        var devices: [Device] = []
        for (runtime, sims) in runtimes.sorted(by: { $0.key < $1.key }) {
            for sim in sims {
                guard (sim["state"] as? String) == "Booted",
                      let udid = sim["udid"] as? String,
                      let name = sim["name"] as? String
                else { continue }
                devices.append(Device(
                    id: "sim:\(udid)",
                    name: name,
                    detail: ["시뮬레이터", runtimeLabel(runtime), "실행 중"].joined(separator: " · "),
                    kind: .dev,
                    accent: .simulator,
                    symbol: symbol(forName: name),
                    copyText: udid
                ))
            }
        }
        return devices
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-26-2" → "iOS 26.2"
    static func runtimeLabel(_ identifier: String) -> String {
        let tail = identifier.split(separator: ".").last.map(String.init) ?? identifier
        let parts = tail.split(separator: "-").map(String.init)
        guard let platform = parts.first, parts.count > 1 else { return tail }
        return "\(platform) \(parts.dropFirst().joined(separator: "."))"
    }

    // MARK: 실기기

    /// `xcrun devicectl list devices --json-output` 파일 내용.
    /// 과거에 페어링만 해 둔 기기(tunnelState = unavailable)는 지금 연결된 것이 아니라 뺀다.
    static func parseDevicectl(_ data: Data) -> [Device] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let entries = result["devices"] as? [[String: Any]]
        else { return [] }

        return entries.compactMap { entry in
            let connection = entry["connectionProperties"] as? [String: Any] ?? [:]
            let properties = entry["deviceProperties"] as? [String: Any] ?? [:]
            let hardware = entry["hardwareProperties"] as? [String: Any] ?? [:]

            let tunnel = connection["tunnelState"] as? String ?? "unavailable"
            guard tunnel != "unavailable",
                  let udid = hardware["udid"] as? String ?? entry["identifier"] as? String
            else { return nil }

            let model = hardware["marketingName"] as? String ?? hardware["productType"] as? String
            let name = properties["name"] as? String ?? model ?? udid
            let platform = hardware["platform"] as? String
            let version = properties["osVersionNumber"] as? String

            let transport = connection["transportType"] as? String
            let transportLabel: String? = switch transport {
            case "wired": "USB"
            case "localNetwork": "Wi-Fi"
            default: nil
            }

            var parts: [String] = []
            if let model, model != name { parts.append(model) }
            if let platform, let version { parts.append("\(platform) \(version)") }
            if let transportLabel { parts.append(transportLabel) }

            return Device(
                id: "ios:\(udid)",
                name: name,
                detail: parts.joined(separator: " · "),
                kind: .dev,
                accent: .ios,
                symbol: symbol(forName: hardware["deviceType"] as? String ?? model ?? name),
                copyText: udid,
                serial: transport == "wired" ? udid : nil
            )
        }
    }

    static func symbol(forName name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("ipad") { return "ipad" }
        if lower.contains("watch") { return "applewatch" }
        if lower.contains("tv") { return "appletv" }
        if lower.contains("vision") { return "visionpro" }
        return "iphone"
    }

    // MARK: 실행

    private static let xcrun = "/usr/bin/xcrun"

    static func fetchSimulators() async -> [Device]? {
        guard let data = await Shell.run(xcrun, ["simctl", "list", "devices", "booted", "-j"]) else { return nil }
        return parseSimulators(data)
    }

    static func fetchDevices() async -> [Device]? {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("linkie-devicectl-\(ProcessInfo.processInfo.processIdentifier).json")
        defer { try? FileManager.default.removeItem(at: file) }

        guard await Shell.run(xcrun, ["devicectl", "list", "devices", "--json-output", file.path], timeout: 8) != nil,
              let data = try? Data(contentsOf: file)
        else { return nil }
        return parseDevicectl(data)
    }
}
