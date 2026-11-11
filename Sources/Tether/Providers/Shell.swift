import Foundation

enum Shell {
    /// 명령을 실행해 표준 출력을 돌려준다. 실행 실패·비정상 종료·타임아웃이면 nil.
    static func run(_ path: String, _ args: [String], timeout: TimeInterval = 5) async -> Data? {
        guard FileManager.default.isExecutableFile(atPath: path) else { return nil }
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                let stdout = Pipe()
                process.standardOutput = stdout
                process.standardError = FileHandle.nullDevice
                process.standardInput = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: nil)
                    return
                }

                let killer = DispatchWorkItem {
                    if process.isRunning { process.terminate() }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: killer)

                // 파이프 버퍼가 차서 멈추지 않도록 종료를 기다리기 전에 끝까지 읽는다.
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                killer.cancel()

                let ok = process.terminationReason == .exit && process.terminationStatus == 0
                continuation.resume(returning: ok ? data : nil)
            }
        }
    }

    static func runText(_ path: String, _ args: [String], timeout: TimeInterval = 5) async -> String? {
        guard let data = await run(path, args, timeout: timeout) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
