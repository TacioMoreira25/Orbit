import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import websocket from '@fastify/websocket';

import { ProcessFileUploadUseCase } from '../../application/use-cases/ProcessFileUploadUseCase.js';
import { SyncClipboardUseCase } from '../../application/use-cases/SyncClipboardUseCase.js';
import { AuthenticateDeviceUseCase } from '../../application/use-cases/AuthenticateDeviceUseCase.js';
import { GetServerStatusUseCase } from '../../application/use-cases/GetServerStatusUseCase.js';
import { IStorageService } from '../../core/interfaces/IStorageService.js';
import { LocalDiskStorage } from '../storage/LocalDiskStorage.js';
import { TransferWebSocketServer } from '../websocket/TransferWebSocketServer.js';
import { PinPairingManager } from '../security/PinPairingManager.js';
import { createAuthMiddleware, createLocalOrAuthMiddleware } from './middlewares/authMiddleware.js';
import { sendError } from './utils/httpError.js';
import { registerPairingRoutes } from './routes/pairingRoutes.js';
import { registerClipboardRoutes } from './routes/clipboardRoutes.js';
import { registerUploadRoutes } from './routes/uploadRoutes.js';
import { registerDownloadRoutes } from './routes/downloadRoutes.js';
import { registerWebDashboardRoutes } from './routes/webDashboardRoutes.js';
import { registerWebSocketRoutes } from './routes/wsRoutes.js';

export interface ServerDependencies {
  processUploadUseCase: ProcessFileUploadUseCase;
  syncClipboardUseCase: SyncClipboardUseCase;
  authenticateDeviceUseCase: AuthenticateDeviceUseCase;
  getServerStatusUseCase: GetServerStatusUseCase;
  wsServer: TransferWebSocketServer;
  pairingManager: PinPairingManager;
  storageService?: IStorageService;
}

export function buildServer(dependencies: ServerDependencies): FastifyInstance {
  const {
    processUploadUseCase,
    syncClipboardUseCase,
    authenticateDeviceUseCase,
    getServerStatusUseCase,
    wsServer,
    pairingManager,
  } = dependencies;

  const statusSnapshot = getServerStatusUseCase.execute();
  const storageService =
    dependencies.storageService ?? new LocalDiskStorage(statusSnapshot.downloadDirectory);

  const app = Fastify({
    logger: false,
    bodyLimit: 1048576 * 10, // 10MB para JSON payloads (ex: textos longos)
  });

  // Registra plugins
  app.register(cors, { origin: '*' });
  app.register(multipart, {
    limits: {
      fileSize: 1024 * 1024 * 1024 * 50, // Permite arquivos de até 50GB via streaming contínuo
    },
  });
  app.register(websocket);

  // Tratamento de erros centralizado e padronizado
  app.setErrorHandler((error, _request, reply) => {
    const statusCode = error.statusCode || 500;
    return sendError(
      reply,
      statusCode,
      error.code || 'INTERNAL_SERVER_ERROR',
      error.message || 'Erro interno no servidor Orbit.'
    );
  });

  const requireAuth = createAuthMiddleware(pairingManager);
  const requireLocalOrAuth = createLocalOrAuthMiddleware(pairingManager);

  // Status e Healthcheck
  app.get('/health', async () => ({ status: 'ok', timestamp: new Date().toISOString() }));
  app.get('/status', async () => getServerStatusUseCase.execute());

  // Registro modular de rotas por domínio
  registerWebDashboardRoutes(app, getServerStatusUseCase, syncClipboardUseCase, requireLocalOrAuth);
  registerPairingRoutes(
    app,
    authenticateDeviceUseCase,
    pairingManager,
    statusSnapshot.serverName
  );
  registerClipboardRoutes(app, syncClipboardUseCase, requireAuth);
  registerUploadRoutes(app, processUploadUseCase, requireAuth);
  registerDownloadRoutes(app, storageService, wsServer, requireLocalOrAuth);
  registerWebSocketRoutes(app, wsServer);

  return app;
}
