import * as net from "net";
import { HELPER_SOCKET } from "../config";

// Client for the privileged helper daemon. Newline-delimited JSON over a
// root-owned unix socket. See docs/IPC-CONTRACT.md.
//
// TODO(mac): handshake/auth with the per-install shared secret; reconnect logic;
//            push-event stream (state/incident).

export interface ProtectionStatus {
  active: boolean;
  dnsPinned: boolean;
  pfActive: boolean;
  browserPolicy: boolean;
  blocklistSize: number;
  lastHeartbeatOk: boolean;
}

export class HelperClient {
  private send<T>(cmd: string, args: Record<string, unknown> = {}): Promise<T> {
    return new Promise((resolve, reject) => {
      const sock = net.createConnection(HELPER_SOCKET);
      let buf = "";
      sock.on("connect", () => sock.write(JSON.stringify({ cmd, args }) + "\n"));
      sock.on("data", (d) => {
        buf += d.toString();
        const nl = buf.indexOf("\n");
        if (nl >= 0) {
          try {
            resolve(JSON.parse(buf.slice(0, nl)) as T);
          } catch (e) {
            reject(e);
          }
          sock.end();
        }
      });
      sock.on("error", reject);
    });
  }

  status(): Promise<ProtectionStatus> {
    return this.send<ProtectionStatus>("status");
  }
  enable(): Promise<{ ok: boolean }> {
    return this.send("enable");
  }
  disable(pinToken: string): Promise<{ ok: boolean; error?: string }> {
    return this.send("disable", { pinToken });
  }
  pinSet(hash: string, hidden = false, resetDelay = "h24"): Promise<{ ok: boolean }> {
    return this.send("pin.set", { hash, hidden, resetDelay });
  }
  pinVerify(candidateHash: string): Promise<{ ok: boolean }> {
    return this.send("pin.verify", { candidateHash });
  }
  blocklistRefresh(): Promise<{ ok: boolean; size?: number }> {
    return this.send("blocklist.refresh");
  }
  uninstallRequest(): Promise<{ ok: boolean; eligibleAt?: number }> {
    return this.send("uninstall.request");
  }
}
