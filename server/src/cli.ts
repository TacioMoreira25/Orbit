import { spawn } from 'node:child_process';
import { QrCodePrinter } from './infrastructure/discovery/QrCodePrinter.js';
import { NetworkUtils } from './infrastructure/discovery/NetworkUtils.js';

const PORT = process.env.PORT || '3000';
const BASE_URL = `http://127.0.0.1:${PORT}`;

function formatUptime(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

async function cmdStatus() {
  try {
    const res = await fetch(`${BASE_URL}/status`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data: any = await res.json();
    const localIp = NetworkUtils.getLocalIpAddress();

    console.log('\n============================================================');
    console.log('   🪐 ORBIT CLI - STATUS DO SERVIDOR');
    console.log('============================================================');
    console.log(`🟢 Estado:             ONLINE (v${data.version})`);
    console.log(`💻 Servidor:           ${data.serverName}`);
    console.log(`📡 Endereço LAN:       http://${localIp}:${PORT}`);
    console.log(`⏱️  Uptime:             ${formatUptime(data.uptimeSeconds)}`);
    console.log(`📱 Dispositivos (WS):  ${data.activeConnections} conectado(s)`);
    console.log(`📂 Pasta de Destino:   ${data.downloadDirectory}`);
    console.log('============================================================\n');
  } catch {
    console.error('\n🔴 Servidor Orbit parece estar OFFLINE em 127.0.0.1:' + PORT);
    console.error('💡 Dica: Inicie o daemon com: orbit start  (ou systemctl --user start orbit.service)\n');
    process.exit(1);
  }
}

async function cmdPin(refresh: boolean) {
  try {
    const res = await fetch(`${BASE_URL}/api/local/pin`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh }),
    });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const payload: any = await res.json();

    QrCodePrinter.print({
      ip: payload.ip,
      port: payload.port,
      pin: payload.pin,
      token: payload.token,
      deviceName: payload.deviceName,
      url: payload.url,
    });
  } catch {
    console.error('\n🔴 Não foi possível obter o PIN/QR Code. O servidor Orbit está rodando?');
    console.error('💡 Inicie com: orbit start\n');
    process.exit(1);
  }
}

function runSystemdCmd(args: string[]) {
  const proc = spawn('systemctl', ['--user', ...args], { stdio: 'inherit' });
  proc.on('exit', (code) => process.exit(code ?? 0));
}

function cmdLogs() {
  const proc = spawn('journalctl', ['--user', '-u', 'orbit.service', '-n', '50', '-f'], {
    stdio: 'inherit',
  });
  proc.on('exit', (code) => process.exit(code ?? 0));
}

function printHelp() {
  console.log(`
🪐 Orbit CLI - Gerenciador do Servidor Local Linux

Uso:
  orbit <comando> [opções]

Comandos disponíveis:
  orbit status        Exibe estado, IP da rede, uptime, conexões e pasta de downloads
  orbit pin           Exibe o PIN e o QR Code ativos no terminal para parear o celular
  orbit pin --new     Gera um novo PIN e QR Code imediatamente
  orbit logs          Exibe os logs do daemon em tempo real (journalctl)
  orbit start         Inicia o serviço em segundo plano (systemd)
  orbit stop          Para o serviço em segundo plano
  orbit restart       Reinicia o serviço em segundo plano
`);
}

async function main() {
  const [, , command, flag] = process.argv;

  switch (command) {
    case 'status':
      await cmdStatus();
      break;
    case 'pin':
    case 'qr':
      await cmdPin(flag === '--new' || flag === '-n');
      break;
    case 'logs':
    case 'log':
      cmdLogs();
      break;
    case 'start':
      runSystemdCmd(['start', 'orbit.service']);
      break;
    case 'stop':
      runSystemdCmd(['stop', 'orbit.service']);
      break;
    case 'restart':
      runSystemdCmd(['restart', 'orbit.service']);
      break;
    default:
      printHelp();
      break;
  }
}

main();
