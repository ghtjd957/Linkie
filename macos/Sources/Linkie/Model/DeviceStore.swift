import Foundation
import Observation

@MainActor
@Observable
final class DeviceStore {
    private(set) var sections: [(kind: DeviceKind, devices: [Device])] = []
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false

    var total: Int { sections.reduce(0) { $0 + $1.devices.count } }

    // 출처별 직전 값 — 한 출처가 실패해도 나머지는 그대로 둔다.
    private var android: [Device] = []
    private var simulators: [Device] = []
    private var appleDevices: [Device] = []
    private var bluetooth: [Device] = []
    private var wired: [Device] = []
    private var androidNames: [String: String] = [:]
    private var batteryAlerts = BatteryAlertTracker()

    private var loops: [Task<Void, Never>] = []

    init() {}

    /// 미리보기·스냅숏용 — 갱신 루프 없이 고정된 목록을 보여준다.
    init(preview sections: [(kind: DeviceKind, devices: [Device])]) {
        self.sections = sections
        lastUpdated = .now
    }

    func start() {
        guard loops.isEmpty else { return }
        BatteryNotifier.requestAuthorization()
        loops = [
            Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refreshDev()
                    try? await Task.sleep(for: .seconds(3))
                }
            },
            Task { [weak self] in
                while !Task.isCancelled {
                    await self?.refreshPeripherals()
                    try? await Task.sleep(for: .seconds(10))
                }
            },
        ]
    }

    /// 팝오버를 열거나 새로고침을 눌렀을 때.
    func refreshNow() {
        Task {
            isRefreshing = true
            async let dev: Void = refreshDev()
            async let peripherals: Void = refreshPeripherals()
            _ = await (dev, peripherals)
            isRefreshing = false
        }
    }

    private func refreshDev() async {
        var names = androidNames
        async let simulatorResult = AppleDevProvider.fetchSimulators()
        async let appleResult = AppleDevProvider.fetchDevices()
        let androidResult = await AndroidProvider.fetch(nameCache: &names)
        let (sims, apple) = await (simulatorResult, appleResult)

        androidNames = names
        if let androidResult { android = androidResult }
        if let sims { simulators = sims }
        if let apple { appleDevices = apple }
        publish()
    }

    private func refreshPeripherals() async {
        async let bluetoothResult = BluetoothProvider.fetch()
        async let wiredResult = USBProvider.fetch()
        let (bt, usb) = await (bluetoothResult, wiredResult)

        if let bt { bluetooth = bt }
        if let usb { wired = usb }
        publish()
    }

    private func publish() {
        let merged = Self.merge(dev: android + appleDevices + simulators, bluetooth: bluetooth, wired: wired)
        if merged.map(\.devices) != sections.map(\.devices) {
            sections = merged
        }
        lastUpdated = .now

        for device in batteryAlerts.update(merged.flatMap(\.devices)) {
            BatteryNotifier.notifyLow(device)
        }
    }

    /// 섹션으로 묶고, 케이블로 꽂은 개발 기기가 USB 목록에 한 번 더 나오는 것을 지운다.
    nonisolated static func merge(
        dev: [Device], bluetooth: [Device], wired: [Device]
    ) -> [(kind: DeviceKind, devices: [Device])] {
        let devSerials = Set(dev.compactMap { Device.normalizedSerial($0.serial) })
        let uniqueWired = wired.filter { device in
            guard let serial = Device.normalizedSerial(device.serial) else { return true }
            return !devSerials.contains(serial)
        }
        return [(DeviceKind.dev, dev), (.bluetooth, bluetooth), (.wired, uniqueWired)]
            .filter { !$0.1.isEmpty }
            .map { (kind: $0.0, devices: $0.1) }
    }
}
