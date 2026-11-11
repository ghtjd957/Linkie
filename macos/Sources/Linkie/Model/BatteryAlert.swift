import Foundation
import UserNotifications

/// 어떤 기기에 배터리 부족 알림을 보낼지 정한다. 한 번 알린 기기는 충전돼 올라올 때까지 다시 알리지 않는다.
struct BatteryAlertTracker {
    /// 이 값 이하로 내려가면 알린다.
    var threshold = 20
    /// 임계값 근처에서 잔량이 오르내릴 때 알림이 반복되지 않도록, 이만큼 더 올라와야 다시 알릴 수 있다.
    var rearmMargin = 5

    private(set) var alerted: Set<String> = []

    /// 새로 부족해진 기기만 돌려준다. 목록에 없는 기기(연결 해제)는 상태를 그대로 둔다 —
    /// 블루투스가 잠깐 끊겼다 붙을 때마다 다시 울리지 않게.
    mutating func update(_ devices: [Device]) -> [Device] {
        var fresh: [Device] = []
        for device in devices {
            guard let level = device.battery else { continue }
            if level <= threshold {
                if alerted.insert(device.id).inserted { fresh.append(device) }
            } else if level > threshold + rearmMargin {
                alerted.remove(device.id)
            }
        }
        return fresh
    }
}

enum BatteryNotifier {
    /// 알림 센터는 앱 번들로 실행했을 때만 쓸 수 있다(`swift run`·테스트에서는 건너뛴다).
    private static var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func notifyLow(_ device: Device) {
        guard isAvailable, let level = device.battery else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(device.name) 배터리 \(level)%"
        content.body = "배터리가 얼마 남지 않았어요. 충전해 주세요."
        content.sound = .default
        // 같은 기기의 알림은 하나만 남도록 식별자를 기기 단위로 둔다.
        let request = UNNotificationRequest(identifier: "low-battery:\(device.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
