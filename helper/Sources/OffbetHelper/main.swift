import OffbetHelperCore

// Thin executable entry for the privileged root daemon. All logic lives in the
// OffbetHelperCore library (unit-testable). See OffbetHelperCore/Daemon.swift.
OffbetDaemon.run()
