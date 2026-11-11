import Foundation
import Testing
@testable import Tether

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: "Fixtures/\(name)", withExtension: nil))
    return try Data(contentsOf: url)
}

private func fixtureText(_ name: String) throws -> String {
    try #require(String(data: fixture(name), encoding: .utf8))
}

@Suite struct AndroidParserTests {
    @Test func 실제_adb_출력에서_USB_기기를_읽는다() throws {
        let entries = AndroidProvider.parseDevices(try fixtureText("adb-devices.txt"))
        #expect(entries == [
            AdbEntry(serial: "R3CX00TEST01", state: "device", model: "SM-F936N", transport: .usb),
        ])
    }

    @Test func 에뮬레이터_무선_미승인_기기를_구분한다() {
        let output = """
        * daemon started successfully
        List of devices attached
        emulator-5554          device product:sdk_gphone64_arm64 model:sdk_gphone64_arm64 device:emu64a transport_id:2
        192.168.0.12:5555      device product:panther model:Pixel_7 device:panther transport_id:3
        adb-R3CX._adb-tls-connect._tcp device product:q4q model:SM_F936N device:q4q transport_id:5
        ZY22ABCDEF             unauthorized usb:1-1 transport_id:4

        """
        let entries = AndroidProvider.parseDevices(output)
        #expect(entries.map(\.transport) == [.emulator, .wifi, .wifi, .usb])
        #expect(entries.map(\.state) == ["device", "device", "device", "unauthorized"])
        #expect(entries[3].model == nil)

        let unauthorized = AndroidProvider.device(from: entries[3], friendlyName: nil, battery: nil)
        #expect(unauthorized.needsAttention)
        #expect(unauthorized.detail == "USB · USB 디버깅 승인 필요")
        #expect(unauthorized.name == "ZY22ABCDEF")
    }

    @Test func 배터리_잔량을_읽는다() throws {
        #expect(AndroidProvider.parseBatteryLevel(try fixtureText("adb-battery.txt")) == 87)
        #expect(AndroidProvider.parseBatteryLevel("error: device offline") == nil)
    }

    @Test func 기기_이름이_있으면_모델은_부가정보로_간다() {
        let entry = AdbEntry(serial: "R3CX00TEST01", state: "device", model: "SM-F936N", transport: .usb)
        let device = AndroidProvider.device(from: entry, friendlyName: "Galaxy Z Fold4", battery: 87)
        #expect(device.name == "Galaxy Z Fold4")
        #expect(device.detail == "SM-F936N · USB")
        #expect(device.battery == 87)
        #expect(device.serial == "R3CX00TEST01")
        #expect(!device.needsAttention)
    }
}

@Suite struct AppleDevParserTests {
    @Test func 실행_중인_시뮬레이터가_없으면_빈_목록() throws {
        #expect(AppleDevProvider.parseSimulators(try fixture("simctl-booted.json")).isEmpty)
    }

    @Test func 실행_중인_시뮬레이터를_읽는다() {
        let json = """
        {"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-2":[
          {"udid":"AAAA-1111","name":"iPhone 17 Pro","state":"Booted","isAvailable":true},
          {"udid":"BBBB-2222","name":"iPad Air","state":"Shutdown","isAvailable":true}
        ]}}
        """
        let sims = AppleDevProvider.parseSimulators(Data(json.utf8))
        #expect(sims.count == 1)
        #expect(sims[0].name == "iPhone 17 Pro")
        #expect(sims[0].detail == "시뮬레이터 · iOS 26.2 · 실행 중")
        #expect(sims[0].copyText == "AAAA-1111")
    }

    @Test func 런타임_식별자를_사람이_읽는_이름으로_바꾼다() {
        #expect(AppleDevProvider.runtimeLabel("com.apple.CoreSimulator.SimRuntime.iOS-26-2") == "iOS 26.2")
        #expect(AppleDevProvider.runtimeLabel("com.apple.CoreSimulator.SimRuntime.watchOS-26-2") == "watchOS 26.2")
    }

    @Test func 과거에_페어링만_한_기기는_제외한다() throws {
        // 픽스처: 11대 중 10대는 unavailable, 1대(애플워치)만 같은 네트워크에서 보임.
        let devices = AppleDevProvider.parseDevicectl(try fixture("devicectl.json"))
        #expect(devices.count == 1)
        #expect(devices[0].symbol == "applewatch")
        #expect(devices[0].detail.hasSuffix("Wi-Fi"))
        #expect(devices[0].serial == nil) // 무선이라 USB 중복 제거 대상이 아님
    }
}

@Suite struct BluetoothParserTests {
    @Test func 연결된_기기만_읽는다() throws {
        let devices = BluetoothProvider.parse(try fixture("bluetooth.json"))
        // 정렬 순서는 시스템 언어에 따라 달라지므로 이름으로 찾아 비교한다.
        let byName = Dictionary(uniqueKeysWithValues: devices.map { ($0.name, $0) })
        #expect(Set(byName.keys) == ["Keyboard 1", "Magic Trackpad 2"])
        #expect(byName["Keyboard 1"]?.detail == "키보드")
        #expect(byName["Magic Trackpad 2"]?.detail == "트랙패드")
        #expect(devices.allSatisfy { $0.battery == nil })
        #expect(byName["Keyboard 1"]?.copyText == "AA:00:00:00:00:01")
    }

    @Test func 배터리가_여러_칸이면_가장_낮은_값을_알약에_쓴다() {
        let json = """
        {"SPBluetoothDataType":[{"device_connected":[{"AirPods Pro":{
          "device_address":"AA:BB","device_minorType":"Headphones",
          "device_batteryLevelLeft":"90%","device_batteryLevelRight":"88%","device_batteryLevelCase":"61%"
        }},{"Mouse":{"device_address":"CC:DD","device_minorType":"Mouse","device_batteryLevelMain":"19%"}}]}]}
        """
        let devices = BluetoothProvider.parse(Data(json.utf8))
        #expect(devices[0].battery == 61)
        #expect(devices[0].detail == "헤드폰 · L 90 · R 88 · 케이스 61")
        #expect(devices[0].symbol == "airpodspro")
        #expect(devices[1].battery == 19)
        #expect(devices[1].detail == "마우스")
    }
}

@Suite struct BluetoothBatteryTests {
    @Test func ioreg에서_주소별_잔량을_읽는다() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><array><dict>
          <key>Product</key><string>Magic Trackpad</string>
          <key>BatteryPercent</key><integer>72</integer>
          <key>DeviceAddress</key><string>aa-00-00-00-00-02</string>
        </dict></array></plist>
        """
        #expect(BluetoothProvider.parseIORegBatteries(Data(plist.utf8)) == ["AA0000000002": 72])
        #expect(BluetoothProvider.parseIORegBatteries(Data()).isEmpty)
    }

    @Test func pmset에서_이름별_잔량을_읽고_내장_배터리는_건너뛴다() {
        let output = "Now drawing from 'AC Power'\n"
            + " -InternalBattery-0 (id=23920739)\t80%; AC attached; not charging present: true\n"
            + " - (id=-496238592)\t72%; discharging present: true\n"
            + " -Keyboard 1 (id=41030546)\t44%; \n"
        #expect(BluetoothProvider.parseAccessoryBatteries(output) == ["Keyboard 1": 44])
    }

    @Test func 비어_있는_배터리만_주소_우선으로_채운다() throws {
        let devices = BluetoothProvider.parse(try fixture("bluetooth.json"))
        let filled = BluetoothProvider.fillBatteries(
            devices,
            byAddress: ["AA0000000002": 72],
            byName: ["Keyboard 1": 44, "Magic Trackpad 2": 1]
        )
        let byName = Dictionary(uniqueKeysWithValues: filled.map { ($0.name, $0.battery) })
        #expect(byName == ["Keyboard 1": 44, "Magic Trackpad 2": 72])
    }
}

@Suite struct USBParserTests {
    @Test func 버스와_허브는_숨기고_장치만_남긴다() throws {
        let devices = USBProvider.parseUSB(try fixture("usb.json"))
        #expect(devices.map(\.name) == ["EarPods", "LG Monitor Controls", "SAMSUNG_Android"])
        #expect(devices[0].detail == "Apple · 12 Mb/s")
        #expect(devices[1].detail == "LG Electronics · 12 Mb/s · USB2.1 Hub 경유")
        #expect(devices[2].serial == "R3CX00TEST01")
    }

    @Test func 썬더볼트_포트에_장치가_없으면_빈_목록() throws {
        #expect(USBProvider.parseThunderbolt(try fixture("thunderbolt.json")).isEmpty)
    }

    @Test func 썬더볼트_포트_아래_장치를_읽는다() {
        let json = """
        {"SPThunderboltDataType":[{"_name":"thunderboltusb4_bus_1","device_name_key":"MacBook Pro","_items":[
          {"_name":"CalDigit TS4","device_name_key":"TS4","vendor_name_key":"CalDigit, Inc.","switch_uid_key":"0x1"}
        ]}]}
        """
        let devices = USBProvider.parseThunderbolt(Data(json.utf8))
        #expect(devices.count == 1)
        #expect(devices[0].name == "TS4")
        #expect(devices[0].detail == "CalDigit · 썬더볼트")
    }
}

@Suite struct MergeTests {
    @Test func 케이블로_꽂은_개발_기기는_USB_목록에서_지운다() throws {
        let adb = AndroidProvider.parseDevices(try fixtureText("adb-devices.txt"))
            .map { AndroidProvider.device(from: $0, friendlyName: nil, battery: nil) }
        let usb = USBProvider.parseUSB(try fixture("usb.json"))

        let sections = DeviceStore.merge(dev: adb, bluetooth: [], wired: usb)
        #expect(sections.map(\.kind) == [.dev, .wired]) // 빈 블루투스 섹션은 숨김
        #expect(sections[1].devices.map(\.name) == ["EarPods", "LG Monitor Controls"])
    }

    @Test func 아이폰_UDID는_하이픈_유무와_상관없이_같은_기기로_본다() {
        let phone = Device(id: "ios:1", name: "iPhone", detail: "", kind: .dev, accent: .ios,
                           symbol: "iphone", serial: "00008000-00000000000000AB")
        let usb = Device(id: "usb:1", name: "iPhone", detail: "", kind: .wired, accent: .usb,
                         symbol: "smartphone", serial: "0000800000000000000000AB")
        let sections = DeviceStore.merge(dev: [phone], bluetooth: [], wired: [usb])
        #expect(sections.map(\.kind) == [.dev])
    }

    @Test func 전부_비면_섹션이_없다() {
        #expect(DeviceStore.merge(dev: [], bluetooth: [], wired: []).isEmpty)
    }
}
