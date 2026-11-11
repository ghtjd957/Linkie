import Foundation

enum BluetoothProvider {
    /// `system_profiler SPBluetoothDataType -json` 출력. 연결된 기기만.
    static func parse(_ data: Data) -> [Device] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sections = root["SPBluetoothDataType"] as? [[String: Any]]
        else { return [] }

        var devices: [Device] = []
        for section in sections {
            // [{ "기기 이름": { 속성… } }, …]
            guard let connected = section["device_connected"] as? [[String: Any]] else { continue }
            for wrapper in connected {
                for (name, value) in wrapper {
                    guard let info = value as? [String: Any] else { continue }
                    let address = info["device_address"] as? String
                    let type = info["device_minorType"] as? String

                    var parts: [String] = []
                    if let type { parts.append(typeLabel(type)) }
                    let cells = batteryCells(info)
                    if cells.count > 1 {
                        parts.append(cells.map { "\($0.label) \($0.level)" }.joined(separator: " · "))
                    }

                    devices.append(Device(
                        id: "bt:\(address ?? name)",
                        name: name,
                        detail: parts.joined(separator: " · "),
                        kind: .bluetooth,
                        accent: .bluetooth,
                        symbol: symbol(type: type, name: name),
                        battery: cells.map(\.level).min(),
                        copyText: address
                    ))
                }
            }
        }
        return devices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 배터리 키는 기기가 알려 줄 때만 있다. 값은 "85%" 형태.
    static func batteryCells(_ info: [String: Any]) -> [(label: String, level: Int)] {
        let keys: [(String, String)] = [
            ("device_batteryLevelMain", "본체"),
            ("device_batteryLevelLeft", "L"),
            ("device_batteryLevelRight", "R"),
            ("device_batteryLevelCase", "케이스"),
        ]
        return keys.compactMap { key, label in
            guard let raw = info[key] as? String,
                  let level = Int(raw.trimmingCharacters(in: CharacterSet(charactersIn: "% ")))
            else { return nil }
            return (label, level)
        }
    }

    static func typeLabel(_ type: String) -> String {
        switch type {
        case "Keyboard": "키보드"
        case "Mouse": "마우스"
        case "Magic Trackpad", "Trackpad": "트랙패드"
        case "Headphones", "Headset": "헤드폰"
        case "Speaker": "스피커"
        case "Mobile Phone": "휴대폰"
        case "Gamepad": "게임패드"
        default: type
        }
    }

    static func symbol(type: String?, name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        switch type {
        case "Keyboard": return "keyboard"
        case "Mouse": return "computermouse"
        case "Magic Trackpad", "Trackpad": return "rectangle.and.hand.point.up.left"
        case "Headphones", "Headset": return "headphones"
        case "Speaker": return "hifispeaker"
        case "Mobile Phone": return "smartphone"
        case "Gamepad": return "gamecontroller"
        default: return "dot.radiowaves.left.and.right"
        }
    }

    static func fetch() async -> [Device]? {
        guard let data = await Shell.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"], timeout: 8)
        else { return nil }
        return parse(data)
    }
}
