// 앱 아이콘을 코드로 그려 맥용 .icns, 윈도우용 .ico, README용 PNG 를 만든다.
// 사용(저장소 루트에서): swift scripts/make-icon.swift
//
// 그림: 웃는 노트북에서 줄이 뻗어 나가 세 개의 색 점(개발 기기·블루투스·USB)에 이어진다.
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

/// - Parameter fullBleed: true 면 여백 없이 캔버스를 꽉 채운다(윈도우). false 면 맥 아이콘 규격대로 여백과 그림자를 둔다.
func render(size: Int, fullBleed: Bool) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024) // 1024 기준으로 그린다(y 는 위쪽이 +)

    let box = fullBleed ? CGRect(x: 0, y: 0, width: 1024, height: 1024) : CGRect(x: 100, y: 100, width: 824, height: 824)
    let u = box.width / 824
    let plate = CGPath(roundedRect: box, cornerWidth: box.width * 0.225, cornerHeight: box.width * 0.225, transform: nil)

    if !fullBleed {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
        ctx.addPath(plate)
        ctx.setFillColor(color(0x1B1D2E))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // 바탕: 짙은 남색 → 보라, 구석에 은은한 빛
    ctx.saveGState()
    ctx.addPath(plate)
    ctx.clip()
    let base = CGGradient(colorsSpace: space, colors: [color(0x2B2F5E), color(0x191A2C)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: box.minX, y: box.maxY), end: CGPoint(x: box.maxX, y: box.minY), options: [])
    for (center, tint, radius) in [
        (CGPoint(x: box.minX + 170 * u, y: box.maxY - 120 * u), color(0x6D6BFF, 0.55), 520 * u),
        (CGPoint(x: box.maxX - 120 * u, y: box.minY + 90 * u), color(0x22C3B0, 0.38), 460 * u),
    ] {
        let glow = CGGradient(colorsSpace: space, colors: [tint, tint.copy(alpha: 0)!] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }
    // 위쪽 가장자리의 얇은 반사광
    let sheen = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.16), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(sheen, start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.maxY - 260 * u), options: [])
    ctx.restoreGState()

    // 그림 — 좌표는 바탕판 왼쪽 아래를 (0,0) 으로 하는 824 단위
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: box.minX + x * u, y: box.minY + y * u) }
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: box.minX + x * u, y: box.minY + y * u, width: w * u, height: h * u)
    }
    func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
        CGPath(roundedRect: r, cornerWidth: radius * u, cornerHeight: radius * u, transform: nil)
    }
    func dot(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius * u, y: center.y - radius * u, width: radius * 2 * u, height: radius * 2 * u)
    }

    // 노트북 화면 위에서 뻗어 나간 줄 끝에 달린 기기 셋: 개발 기기·블루투스·USB
    let devices: [(from: CGPoint, c1: CGPoint, c2: CGPoint, to: CGPoint, fill: UInt32)] = [
        (p(322, 425), p(322, 500), p(262, 535), p(190, 535), 0x34D399),
        (p(412, 425), p(412, 480), p(412, 560), p(412, 625), 0x60A5FA),
        (p(502, 425), p(502, 500), p(562, 535), p(634, 535), 0xF472B6),
    ]

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8 * u), blur: 22 * u, color: color(0x000000, 0.35))

    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineWidth(26 * u)
    ctx.setLineCap(.round)
    for device in devices {
        ctx.move(to: device.from)
        ctx.addCurve(to: device.to, control1: device.c1, control2: device.c2)
    }
    ctx.strokePath()

    for device in devices {
        ctx.setFillColor(color(0xFFFFFF))
        ctx.fillEllipse(in: dot(device.to, 70))
        ctx.setFillColor(color(device.fill))
        ctx.fillEllipse(in: dot(device.to, 51))
    }

    // 노트북: 화면 테두리 + 받침
    ctx.setFillColor(color(0xFFFFFF))
    ctx.addPath(rounded(rect(232, 185, 360, 240), 34))
    ctx.addPath(rounded(rect(162, 126, 500, 44), 22))
    ctx.fillPath()
    ctx.restoreGState()

    // 화면 안쪽
    ctx.saveGState()
    let screen = rounded(rect(256, 209, 312, 192), 16)
    ctx.addPath(screen)
    ctx.clip()
    let screenFill = CGGradient(colorsSpace: space, colors: [color(0x3A3F86), color(0x20223F)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(screenFill, start: p(256, 401), end: p(568, 209), options: [])
    ctx.restoreGState()

    // 화면 속 웃는 얼굴
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillEllipse(in: dot(p(366, 326), 15))
    ctx.fillEllipse(in: dot(p(458, 326), 15))
    ctx.setStrokeColor(color(0xFFFFFF))
    ctx.setLineWidth(13 * u)
    ctx.setLineCap(.round)
    ctx.addArc(center: p(412, 300), radius: 38 * u, startAngle: 205 * .pi / 180, endAngle: 335 * .pi / 180, clockwise: false)
    ctx.strokePath()

    let image = ctx.makeImage()!
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
}

/// PNG 를 그대로 담는 ICO(윈도우 비스타 이후 지원).
func ico(from pngs: [(size: Int, data: Data)]) -> Data {
    func le16(_ v: Int) -> [UInt8] { [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)] }
    func le32(_ v: Int) -> [UInt8] { (0..<4).map { UInt8((v >> (8 * $0)) & 0xFF) } }

    var header = Data(le16(0) + le16(1) + le16(pngs.count))
    var body = Data()
    var offset = 6 + 16 * pngs.count
    for png in pngs {
        let side = UInt8(png.size >= 256 ? 0 : png.size) // 0 은 256 을 뜻한다
        header.append(contentsOf: [side, side, 0, 0] + le16(1) + le16(32) + le32(png.data.count) + le32(offset))
        body.append(png.data)
        offset += png.data.count
    }
    return header + body
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
guard fm.fileExists(atPath: root.appendingPathComponent("macos/Package.swift").path) else {
    FileHandle.standardError.write(Data("저장소 루트에서 실행하세요: swift scripts/make-icon.swift\n".utf8))
    exit(1)
}

// 맥: iconset → icns
let iconset = fm.temporaryDirectory.appendingPathComponent("Linkie-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(size: points, fullBleed: false).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(size: points * 2, fullBleed: false).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let resources = root.appendingPathComponent("macos/Resources")
try fm.createDirectory(at: resources, withIntermediateDirectories: true)
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
try? fm.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { exit(1) }

// 윈도우: ico
let icoData = ico(from: [16, 24, 32, 48, 64, 256].map { ($0, render(size: $0, fullBleed: true)) })
try icoData.write(to: root.appendingPathComponent("windows/Linkie.App/Linkie.ico"))

// README
try fm.createDirectory(at: root.appendingPathComponent("docs"), withIntermediateDirectories: true)
try render(size: 512, fullBleed: false).write(to: root.appendingPathComponent("docs/icon.png"))

print("만듦: macos/Resources/AppIcon.icns, windows/Linkie.App/Linkie.ico, docs/icon.png")
