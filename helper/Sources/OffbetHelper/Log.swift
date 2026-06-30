import Foundation
import os

// Thin logging wrapper (os.Logger). TODO(mac): route to a rotating file under
// /Library/Logs/OFFBET/ as well, for support diagnostics.
enum Log {
    private static let logger = Logger(subsystem: "com.offbet.helper", category: "daemon")
    static func info(_ m: String) { logger.info("\(m, privacy: .public)") }
    static func warn(_ m: String) { logger.warning("\(m, privacy: .public)") }
    static func error(_ m: String) { logger.error("\(m, privacy: .public)") }
}
