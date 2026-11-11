// 앱 아이콘을 코드로 그려 맥용 .icns, 윈도우용 .ico, README용 PNG 를 만든다.
// 사용(저장소 루트에서): swift scripts/make-icon.swift
//
// 그림: 검은 판 위에 웃는 흰 노트북, 거기서 줄 셋이 뻗어 나가 고리(연결된 기기)에 이어진다.
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
        ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.3))
        ctx.addPath(plate)
        ctx.setFillColor(color(0x808080))
        ctx.fillPath()
        ctx.restoreGState()
    }

    // 바탕: 짙은 회색 → 검정
    ctx.saveGState()
    ctx.addPath(plate)
    ctx.clip()
    let base = CGGradient(colorsSpace: space, colors: [color(0x2C2C2E), color(0x000000)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.minY), options: [])
    ctx.restoreGState()

    // 그림 — 좌표는 바탕판 왼쪽 아래를 (0,0) 으로 하는 824 단위
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: box.minX + x * u, y: box.minY + y * u) }
    func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat) -> CGPath {
        CGPath(
            roundedRect: CGRect(x: box.minX + x * u, y: box.minY + y * u, width: w * u, height: h * u),
            cornerWidth: radius * u, cornerHeight: radius * u, transform: nil
        )
    }
    func dot(_ center: CGPoint, _ radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius * u, y: center.y - radius * u, width: radius * 2 * u, height: radius * 2 * u)
    }
    let white = color(0xFFFFFF), ink = color(0x111113)

    // 화면 위에서 뻗어 나간 줄 셋
    let cables: [(from: CGPoint, c1: CGPoint, c2: CGPoint, to: CGPoint)] = [
        (p(322, 425), p(322, 500), p(262, 535), p(190, 535)),
        (p(412, 425), p(412, 480), p(412, 560), p(412, 625)),
        (p(502, 425), p(502, 500), p(562, 535), p(634, 535)),
    ]
    ctx.setStrokeColor(white)
    ctx.setLineWidth(22 * u)
    ctx.setLineCap(.round)
    for cable in cables {
        ctx.move(to: cable.from)
        ctx.addCurve(to: cable.to, control1: cable.c1, control2: cable.c2)
    }
    ctx.strokePath()

    // 줄 끝의 고리
    for cable in cables {
        ctx.setFillColor(white)
        ctx.fillEllipse(in: dot(cable.to, 66))
        ctx.setFillColor(color(0x1A1A1C))
        ctx.fillEllipse(in: dot(cable.to, 40))
    }

    // 화면이 켜진 노트북 + 받침
    ctx.setFillColor(white)
    ctx.addPath(rounded(232, 185, 360, 240, 34))
    ctx.addPath(rounded(162, 126, 500, 44, 22))
    ctx.fillPath()

    // 웃는 얼굴
    ctx.setFillColor(ink)
    ctx.fillEllipse(in: dot(p(366, 326), 15))
    ctx.fillEllipse(in: dot(p(458, 326), 15))
    ctx.setStrokeColor(ink)
    ctx.setLineWidth(13 * u)
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
