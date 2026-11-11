import ServiceManagement
import SwiftUI

struct PopoverView: View {
    let store: DeviceStore
    var refreshOnAppear = true

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.sections.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(store.sections, id: \.kind) { section in
                            sectionView(section.kind, section.devices)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 12)
                    .animation(.spring(duration: 0.35), value: store.sections.flatMap(\.devices).map(\.id))
                }
                .scrollIndicators(.never)
                .frame(maxHeight: 460)
                .fixedSize(horizontal: false, vertical: true)
            }
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 340)
        .onAppear { if refreshOnAppear { store.refreshNow() } }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("연결된 기기")
                .font(.system(size: 17, weight: .bold))
            if store.total > 0 {
                Text("\(store.total)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
                    .contentTransition(.numericText())
            }
            Spacer()
            Button(action: store.refreshNow) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(
                        store.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default,
                        value: store.isRefreshing
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("새로고침")
            .accessibilityLabel("새로고침")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private func sectionView(_ kind: DeviceKind, _ devices: [Device]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(kind.title) · \(devices.count)")
                .font(.system(size: 10.5, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 10)
                .padding(.bottom, 4)
            ForEach(devices) { device in
                DeviceRow(device: device)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "cable.connector.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("연결된 기기가 없어요")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private var footer: some View {
        HStack {
            Toggle("로그인 시 실행", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .onChange(of: launchAtLogin) { _, enabled in
                    setLaunchAtLogin(enabled)
                }
            Spacer()
            Button("종료") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    /// 앱 번들로 실행했을 때만 등록된다. 실패하면 토글을 실제 상태로 되돌린다.
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Tether: 로그인 항목 변경 실패 — \(error.localizedDescription)")
        }
        let actual = SMAppService.mainApp.status == .enabled
        if actual != launchAtLogin { launchAtLogin = actual }
    }
}
