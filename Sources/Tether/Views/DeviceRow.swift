import AppKit
import SwiftUI

extension DeviceAccent {
    var color: Color {
        switch self {
        case .android: .green
        case .ios: .blue
        case .simulator: .purple
        case .bluetooth: .cyan
        case .usb: .pink
        case .thunderbolt: .orange
        }
    }
}

struct DeviceRow: View {
    let device: Device

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 12) {
                icon
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(copied ? "복사됨 — \(device.copyText ?? "")" : device.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(copied ? AnyShapeStyle(device.accent.color) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: 8)
                trailing
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.primary.opacity(hovering ? 0.08 : 0))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.15), value: hovering)
        .help(device.copyText.map { "클릭해서 복사: \($0)" } ?? device.name)
        .accessibilityElement(children: .combine)
    }

    private var icon: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(device.accent.color.opacity(0.18))
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: device.symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(device.accent.color)
            }
    }

    @ViewBuilder
    private var trailing: some View {
        if hovering, device.copyText != nil, !copied {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .transition(.opacity)
        } else if let battery = device.battery {
            BatteryPill(level: battery)
        } else {
            Circle()
                .fill(device.needsAttention ? Color.orange : Color.green)
                .frame(width: 7, height: 7)
                .padding(.trailing, 4)
        }
    }

    private func copy() {
        guard let text = device.copyText else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation(.easeOut(duration: 0.15)) { copied = true }
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut(duration: 0.2)) { copied = false }
        }
    }
}

struct BatteryPill: View {
    let level: Int

    private var color: Color { level <= 20 ? .orange : .green }

    var body: some View {
        Text("\(level)%")
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.18)))
            .accessibilityLabel("배터리 \(level)퍼센트")
    }
}
