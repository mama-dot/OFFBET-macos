import Foundation

/// Minimal, fixed-purpose process runner. IMPORTANT: only ever called with
/// hard-coded executable paths + argument arrays built by the helper — never
/// with strings supplied by the shell/renderer or the backend (that would be the
/// BetBlocker sudo-exec anti-pattern, see MAC-BENCHMARK.md).
enum Shell {
    @discardableResult
    static func run(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = out
        do { try p.run(); p.waitUntilExit() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self)
    }
}
