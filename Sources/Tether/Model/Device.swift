import Foundation

/// 팝오버의 섹션 단위.
enum DeviceKind: String, CaseIterable, Sendable {
    case dev
    case bluetooth
    case wired

    var title: String {
        switch self {
        case .dev: "개발 기기"
        case .bluetooth: "블루투스"
        case .wired: "USB · 썬더볼트"
        }
    }
}

/// 행 아이콘 색을 고르는 축. 실제 색은 뷰가 정한다.
enum DeviceAccent: Sendable {
    case android, ios, simulator, bluetooth, usb, thunderbolt
}

struct Device: Identifiable, Equatable, Sendable {
    let id: String
    var name: String
    var detail: String
    var kind: DeviceKind
    var accent: DeviceAccent
    /// SF Symbol 이름.
    var symbol: String
    /// 0~100. 기기가 알려 줄 때만.
    var battery: Int?
    /// 행을 클릭했을 때 복사할 값(시리얼·UDID·주소).
    var copyText: String?
    /// USB 목록과의 중복 제거에 쓰는 하드웨어 시리얼.
    var serial: String?
    /// 연결은 됐지만 바로 쓸 수 없는 상태(디버깅 미승인 등).
    var needsAttention: Bool = false
}

extension Device {
    /// 시리얼 비교용 정규화 — iOS UDID 는 USB 쪽에서 하이픈 없이 나온다.
    static func normalizedSerial(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let cleaned = raw.replacingOccurrences(of: "-", with: "").uppercased()
        return cleaned.isEmpty ? nil : cleaned
    }
}
