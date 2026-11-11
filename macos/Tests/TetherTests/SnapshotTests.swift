import AppKit
import SwiftUI
import Testing
@testable import Tether

/// 디자인 확인용. `TETHER_SNAPSHOT_DIR=/경로 swift test --filter Snapshot` 으로만 돈다.
@Suite struct SnapshotTests {
    @MainActor
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TETHER_SNAPSHOT_DIR"] != nil))
    func 팝오버를_이미지로_그린다() throws {
        let dir = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["TETHER_SNAPSHOT_DIR"]))
        let store = DeviceStore(preview: [
            (.dev, [
                Device(id: "1", name: "Galaxy Z Fold4", detail: "SM-F936N · USB", kind: .dev, accent: .android,
                       symbol: "smartphone", battery: 87, copyText: "R3CX00TEST01"),
                Device(id: "2", name: "민지의 iPhone", detail: "iPhone 16 · iOS 26.6.1 · USB", kind: .dev, accent: .ios,
                       symbol: "iphone", copyText: "x"),
                Device(id: "3", name: "iPhone 17 Pro", detail: "시뮬레이터 · iOS 26.2 · 실행 중", kind: .dev,
                       accent: .simulator, symbol: "iphone", copyText: "x"),
                Device(id: "4", name: "ZY22ABCDEF", detail: "USB · USB 디버깅 승인 필요", kind: .dev, accent: .android,
                       symbol: "smartphone", copyText: "x", needsAttention: true),
            ]),
            (.bluetooth, [
                Device(id: "5", name: "AirPods Pro", detail: "헤드폰 · L 90 · R 88 · 케이스 61", kind: .bluetooth,
                       accent: .bluetooth, symbol: "airpodspro", battery: 61),
                Device(id: "6", name: "Keychron K2", detail: "키보드", kind: .bluetooth, accent: .bluetooth,
                       symbol: "keyboard", battery: 19),
                Device(id: "7", name: "Magic Trackpad", detail: "트랙패드", kind: .bluetooth, accent: .bluetooth,
                       symbol: "rectangle.and.hand.point.up.left"),
            ]),
            (.wired, [
                Device(id: "8", name: "EarPods", detail: "Apple · 12 Mb/s", kind: .wired, accent: .usb,
                       symbol: "headphones"),
                Device(id: "9", name: "LG Monitor Controls", detail: "LG Electronics · 12 Mb/s · USB2.1 Hub 경유",
                       kind: .wired, accent: .usb, symbol: "display"),
                Device(id: "10", name: "TS4", detail: "CalDigit · 썬더볼트", kind: .wired, accent: .thunderbolt,
                       symbol: "bolt.horizontal"),
            ]),
        ])

        for (name, scheme, background) in [
            ("dark", ColorScheme.dark, Color(white: 0.13)),
            ("light", ColorScheme.light, Color(white: 0.95)),
        ] {
            let host = NSHostingView(rootView: PopoverView(store: store, refreshOnAppear: false)
                .background(background)
                .environment(\.colorScheme, scheme))
            let size = host.fittingSize
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                                  backing: .buffered, defer: false)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))

            let rep = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: rep)
            let png = try #require(rep.representation(using: .png, properties: [:]))
            try png.write(to: dir.appendingPathComponent("popover-\(name).png"))
        }
    }
}
