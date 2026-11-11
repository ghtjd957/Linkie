import Foundation

enum USBProvider {
    // MARK: USB

    /// `system_profiler SPUSBHostDataType -json` 출력.
    /// 최상위는 맥 내장 버스라 건너뛰고, 허브는 숨기되 그 아래 장치에 "허브 경유"를 남긴다.
    static func parseUSB(_ data: Data) -> [Device] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buses = root["SPUSBHostDataType"] as? [[String: Any]]
        else { return [] }

        var devices: [Device] = []
        func walk(_ node: [String: Any], via hub: String?) {
            let name = node["_name"] as? String ?? "USB 장치"
            let children = node["_items"] as? [[String: Any]] ?? []
            let isHub = !children.isEmpty || name.localizedCaseInsensitiveContains("hub")

            if isHub {
                children.forEach { walk($0, via: name) }
                return
            }

            let serial = (node["USBDeviceKeySerialNumber"] as? String).flatMap { $0 == "Not Provided" ? nil : $0 }
            let location = node["USBKeyLocationID"] as? String ?? name

            var parts: [String] = []
            if let vendor = node["USBDeviceKeyVendorName"] as? String { parts.append(cleanVendor(vendor)) }
            if let speed = node["USBDeviceKeyLinkSpeed"] as? String { parts.append(speed) }
            if let hub { parts.append("\(hub) 경유") }

            devices.append(Device(
                id: "usb:\(location)",
                name: name,
                detail: parts.joined(separator: " · "),
                kind: .wired,
                accent: .usb,
                symbol: symbol(forName: name),
                copyText: serial,
                serial: serial
            ))
        }

        for bus in buses {
            (bus["_items"] as? [[String: Any]] ?? []).forEach { walk($0, via: nil) }
        }
        return devices
    }

    /// "Apple, Inc." → "Apple", "LG Electronics Inc." → "LG Electronics"
    static func cleanVendor(_ raw: String) -> String {
        var vendor = raw
        for suffix in [", Inc.", " Inc.", ", Ltd.", " Ltd.", " Co.,", " Corp."] {
            vendor = vendor.replacingOccurrences(of: suffix, with: "")
        }
        return vendor.trimmingCharacters(in: .whitespaces)
    }

    static func symbol(forName name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("earpods") || lower.contains("headset") || lower.contains("audio") { return "headphones" }
        if lower.contains("monitor") || lower.contains("display") { return "display" }
        if lower.contains("keyboard") { return "keyboard" }
        if lower.contains("mouse") { return "computermouse" }
        if lower.contains("camera") || lower.contains("webcam") { return "web.camera" }
        if lower.contains("android") || lower.contains("iphone") || lower.contains("phone") { return "smartphone" }
        if lower.contains("ipad") { return "ipad" }
        if lower.contains("disk") || lower.contains("ssd") || lower.contains("storage") || lower.contains("drive") {
            return "externaldrive"
        }
        return "cable.connector"
    }

    // MARK: 썬더볼트

    /// `system_profiler SPThunderboltDataType -json` 출력.
    /// 최상위는 맥 자신의 포트라 건너뛰고, 그 아래 `_items` 에 실제 장치가 달린다.
    static func parseThunderbolt(_ data: Data) -> [Device] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buses = root["SPThunderboltDataType"] as? [[String: Any]]
        else { return [] }

        var devices: [Device] = []
        func walk(_ node: [String: Any]) {
            let name = node["device_name_key"] as? String ?? node["_name"] as? String ?? "썬더볼트 장치"
            let uid = node["switch_uid_key"] as? String ?? name

            var parts: [String] = []
            if let vendor = node["vendor_name_key"] as? String { parts.append(cleanVendor(vendor)) }
            parts.append("썬더볼트")

            devices.append(Device(
                id: "tb:\(uid)",
                name: name,
                detail: parts.joined(separator: " · "),
                kind: .wired,
                accent: .thunderbolt,
                symbol: symbol(forName: name) == "cable.connector" ? "bolt.horizontal" : symbol(forName: name),
                copyText: node["switch_uid_key"] as? String
            ))
            (node["_items"] as? [[String: Any]] ?? []).forEach(walk)
        }

        for bus in buses {
            (bus["_items"] as? [[String: Any]] ?? []).forEach(walk)
        }
        return devices
    }

    // MARK: 실행

    static func fetch() async -> [Device]? {
        let profiler = "/usr/sbin/system_profiler"
        async let usbData = Shell.run(profiler, ["SPUSBHostDataType", "-json"], timeout: 8)
        async let thunderboltData = Shell.run(profiler, ["SPThunderboltDataType", "-json"], timeout: 8)

        let (usb, thunderbolt) = await (usbData, thunderboltData)
        guard usb != nil || thunderbolt != nil else { return nil }
        return (usb.map(parseUSB) ?? []) + (thunderbolt.map(parseThunderbolt) ?? [])
    }
}
