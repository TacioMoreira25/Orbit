import { Bonjour } from 'bonjour-service';

export class MdnsDiscovery {
  private bonjour: Bonjour | null = null;

  publishService(port: number, deviceName: string): void {
    try {
      this.bonjour = new Bonjour();
      this.bonjour.publish({
        name: `Orbit-${deviceName}`,
        type: 'orbit',
        port,
        txt: {
          version: '1.0.0',
          proto: 'http',
        },
      });
      console.log(`[mDNS] Anunciando serviço na rede local: orbit.local / _orbit._tcp`);
    } catch (err) {
      console.warn('[mDNS] Não foi possível iniciar mDNS na interface de rede.', err);
    }
  }

  stop(): void {
    if (this.bonjour) {
      this.bonjour.destroy();
      this.bonjour = null;
    }
  }
}
