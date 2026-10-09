import dotenv from 'dotenv';
import { LocalDiskStorage } from './infrastructure/storage/LocalDiskStorage.js';
import { Sha256StreamValidator } from './infrastructure/security/Sha256StreamValidator.js';
import { PinPairingManager } from './infrastructure/security/PinPairingManager.js';
import { LinuxClipboardService } from './infrastructure/system/LinuxClipboardService.js';
import { LinuxNotifier } from './infrastructure/system/LinuxNotifier.js';
import { SmartClipboardClassifier } from './infrastructure/ai/SmartClipboardClassifier.js';
import { TransferWebSocketServer } from './infrastructure/websocket/TransferWebSocketServer.js';
import { MdnsDiscovery } from './infrastructure/discovery/MdnsDiscovery.js';
import { NetworkUtils } from './infrastructure/discovery/NetworkUtils.js';
import { QrCodePrinter } from './infrastructure/discovery/QrCodePrinter.js';
import { ProcessFileUploadUseCase } from './application/use-cases/ProcessFileUploadUseCase.js';
import { SyncClipboardUseCase } from './application/use-cases/SyncClipboardUseCase.js';
import { AuthenticateDeviceUseCase } from './application/use-cases/AuthenticateDeviceUseCase.js';
import { GetServerStatusUseCase } from './application/use-cases/GetServerStatusUseCase.js';
import { buildServer } from './infrastructure/http/server.js';

dotenv.config();

async function bootstrap() {
  const port = parseInt(process.env.PORT || '3000', 10);
  const host = process.env.HOST || '0.0.0.0';
  const downloadDir = process.env.DOWNLOAD_DIR || '~/Downloads';
  const deviceName = process.env.DEVICE_NAME || 'Orbit-Linux';
  const pinExpiration = parseInt(process.env.PIN_EXPIRATION_SECONDS || '300', 10);

  // 1. Instanciação dos Serviços de Infraestrutura
  const storageService = new LocalDiskStorage(downloadDir);
  const cryptoService = new Sha256StreamValidator();
  const pairingManager = new PinPairingManager(cryptoService, pinExpiration);
  const clipboardService = new LinuxClipboardService();
  const notificationService = new LinuxNotifier();
  const smartClassifier = new SmartClipboardClassifier();
  const wsServer = new TransferWebSocketServer();
  const mdnsDiscovery = new MdnsDiscovery();

  // 2. Composição dos Casos de Uso (Application Layer)
  const processUploadUseCase = new ProcessFileUploadUseCase(storageService, wsServer, notificationService);
  const syncClipboardUseCase = new SyncClipboardUseCase(clipboardService, smartClassifier, notificationService, wsServer);
  const authenticateDeviceUseCase = new AuthenticateDeviceUseCase(pairingManager, deviceName);
  const getServerStatusUseCase = new GetServerStatusUseCase({
    getActiveConnectionsCount: () => wsServer.getActiveConnectionsCount(),
    getDownloadDirectory: () => storageService.getDestinationDirectory(),
    getServerName: () => deviceName,
  });

  // 3. Construção do Servidor Fastify
  const app = buildServer({
    processUploadUseCase,
    syncClipboardUseCase,
    authenticateDeviceUseCase,
    getServerStatusUseCase,
    wsServer,
    pairingManager,
  });

  // 4. Inicialização da Rede e Pareamento
  const localIp = NetworkUtils.getLocalIpAddress();
  const session = pairingManager.generateNewSession();

  // 5. Publicação mDNS
  mdnsDiscovery.publishService(port, deviceName);

  // 6. Início da escuta HTTP/WebSocket
  try {
    await app.listen({ port, host });

    // 7. Impressão do Banner e QR Code no Terminal
    QrCodePrinter.print({
      ip: localIp,
      port,
      pin: session.pin,
      token: session.token,
      deviceName,
      url: `http://${localIp}:${port}`,
    });

    console.log(`[Orbit] Destino de arquivos: ${storageService.getDestinationDirectory()}`);
    console.log(`[Orbit] Servidor escutando em http://${host}:${port}`);
  } catch (err) {
    console.error('[Orbit] Erro fatal ao iniciar o servidor:', err);
    process.exit(1);
  }

  // Graceful shutdown
  const shutdown = async () => {
    console.log('\n[Orbit] Encerrando servidor com segurança...');
    mdnsDiscovery.stop();
    await app.close();
    process.exit(0);
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

bootstrap();
