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

    // MARK: 배터리 보조 출처
    // system_profiler 는 에어팟 정도만 배터리를 알려 준다. 나머지는 아래 두 곳에서 채운다.

    /// `ioreg -r -k BatteryPercent -a` 출력(plist) → [정규화한 주소: 잔량]. 애플 매직 기기가 여기 나온다.
    static func parseIORegBatteries(_ data: Data) -> [String: Int] {
        guard let entries = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]]
        else { return [:] }
        var result: [String: Int] = [:]
        for entry in entries {
            guard let percent = entry["BatteryPercent"] as? Int,
                  let address = (entry["DeviceAddress"] as? String) ?? (entry["SerialNumber"] as? String)
            else { continue }
            result[normalizedAddress(address)] = percent
        }
        return result
    }

    /// `pmset -g accps` 출력 → [기기 이름: 잔량]. 배터리 서비스를 가진 일반 블루투스 기기가 여기 나온다.
    /// 줄 형태: ` -Keyboard 1 (id=12345678)\t44%; discharging present: true`
    static func parseAccessoryBatteries(_ output: String) -> [String: Int] {
        var result: [String: Int] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("-"),
                  let idRange = trimmed.range(of: " (id="),
                  let percentEnd = trimmed.range(of: "%;"),
                  let tab = trimmed[..<percentEnd.lowerBound].lastIndex(where: { $0 == "\t" || $0 == " " })
            else { continue }
            let name = String(trimmed[trimmed.index(after: trimmed.startIndex)..<idRange.lowerBound])
            guard !name.isEmpty, !name.hasPrefix("InternalBattery"),
                  let percent = Int(trimmed[trimmed.index(after: tab)..<percentEnd.lowerBound])
            else { continue }
            result[name] = percent
        }
        return result
    }

    /// "aa-00-00-00-00-02" 와 "AA:00:00:00:00:02" 를 같은 값으로.
    static func normalizedAddress(_ raw: String) -> String {
        raw.uppercased().filter { $0.isHexDigit }
    }

    /// 배터리가 비어 있는 기기만 보조 출처로 채운다(주소 우선, 다음 이름).
    static func fillBatteries(_ devices: [Device], byAddress: [String: Int], byName: [String: Int]) -> [Device] {
        devices.map { device in
            guard device.battery == nil else { return device }
            var filled = device
            filled.battery = device.copyText.flatMap { byAddress[normalizedAddress($0)] } ?? byName[device.name]
            return filled
        }
    }

    static func fetch() async -> [Device]? {
        async let profiler = Shell.run("/usr/sbin/system_profiler", ["SPBluetoothDataType", "-json"], timeout: 8)
        async let ioreg = Shell.run("/usr/sbin/ioreg", ["-r", "-k", "BatteryPercent", "-a"], timeout: 3)
        async let pmset = Shell.runText("/usr/bin/pmset", ["-g", "accps"], timeout: 3)

        guard let data = await profiler else { return nil }
        let (ioregData, pmsetText) = await (ioreg, pmset)
        return fillBatteries(
            parse(data),
            byAddress: ioregData.map(parseIORegBatteries) ?? [:],
            byName: pmsetText.map(parseAccessoryBatteries) ?? [:]
        )
    }
}
