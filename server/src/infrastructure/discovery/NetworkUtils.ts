import os from 'node:os';

export class NetworkUtils {
  static getLocalIpAddress(): string {
    const interfaces = os.networkInterfaces();

    // Prioriza interfaces comuns de Wi-Fi e Ethernet (wlan0, wlp*, eth0, enp*)
    const prioritizedPrefixes = ['wl', 'eth', 'en'];

    const candidates: Array<{ ip: string; priority: number }> = [];

    for (const [name, nets] of Object.entries(interfaces)) {
      if (!nets) continue;

      for (const net of nets) {
        // Ignora loopback e IPv6 para simplicidade na LAN
        if (net.family === 'IPv4' && !net.internal) {
          let priority = 0;
          for (let i = 0; i < prioritizedPrefixes.length; i++) {
            if (name.startsWith(prioritizedPrefixes[i])) {
              priority = prioritizedPrefixes.length - i;
              break;
            }
          }
          candidates.push({ ip: net.address, priority });
        }
      }
    }

    if (candidates.length === 0) {
      return '127.0.0.1';
    }

    candidates.sort((a, b) => b.priority - a.priority);
    return candidates[0].ip;
  }
}
