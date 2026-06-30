// Central config for the OFFBET macOS shell. Keep in sync with the Windows shell.
export const WEB_APP_URL = "https://my.offbet.app";
export const DASHBOARD_URL = `${WEB_APP_URL}/app/dashboard`;
export const LOGIN_URL = `${WEB_APP_URL}/app/login`;

// Helper IPC (see docs/IPC-CONTRACT.md)
export const HELPER_SOCKET = "/var/run/offbet-helper.sock";

// Min macOS for SMAppService
export const MIN_MACOS = "13.0";
