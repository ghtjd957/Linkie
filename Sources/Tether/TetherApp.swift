import SwiftUI

@main
struct TetherApp: App {
    @State private var store: DeviceStore

    init() {
        let store = DeviceStore()
        store.start()
        _store = State(initialValue: store)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(store: store)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "cable.connector")
                if store.total > 0 {
                    Text("\(store.total)")
                        .monospacedDigit()
                }
            }
            .accessibilityLabel("연결된 기기 \(store.total)개")
        }
        .menuBarExtraStyle(.window)
    }
}
