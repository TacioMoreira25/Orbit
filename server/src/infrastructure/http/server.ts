import Fastify, { FastifyInstance } from 'fastify';
import cors from '@fastify/cors';
import multipart from '@fastify/multipart';
import websocket from '@fastify/websocket';
import { randomUUID } from 'node:crypto';

import { ProcessFileUploadUseCase } from '../../application/use-cases/ProcessFileUploadUseCase.js';
import { SyncClipboardUseCase } from '../../application/use-cases/SyncClipboardUseCase.js';
import { AuthenticateDeviceUseCase } from '../../application/use-cases/AuthenticateDeviceUseCase.js';
import { GetServerStatusUseCase } from '../../application/use-cases/GetServerStatusUseCase.js';
import { TransferWebSocketServer } from '../websocket/TransferWebSocketServer.js';
import { PinPairingManager } from '../security/PinPairingManager.js';
import { ClipboardSyncSchema, PairRequestSchema } from './schemas.js';

export interface ServerDependencies {
  processUploadUseCase: ProcessFileUploadUseCase;
  syncClipboardUseCase: SyncClipboardUseCase;
  authenticateDeviceUseCase: AuthenticateDeviceUseCase;
  getServerStatusUseCase: GetServerStatusUseCase;
  wsServer: TransferWebSocketServer;
  pairingManager: PinPairingManager;
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
    return reply.status(statusCode).send({
      error: error.message || 'Erro interno no servidor Orbit.',
      code: error.code || 'INTERNAL_SERVER_ERROR',
      statusCode,
      timestamp: new Date().toISOString(),
    });
  });

  // Middleware de autorização Bearer Token
  const requireAuth = async (request: any, reply: any) => {
    const authHeader = request.headers['authorization'];
    if (!authHeader || !pairingManager.isTokenValid(authHeader)) {
      return reply.status(401).send({
        error: 'Dispositivo não autorizado. Pareie o dispositivo novamente via QR Code ou PIN.',
        code: 'UNAUTHORIZED',
        statusCode: 401,
        timestamp: new Date().toISOString(),
      });
    }
  };

  // Status e Healthcheck
  app.get('/health', async () => ({ status: 'ok', timestamp: new Date().toISOString() }));
  app.get('/status', async () => getServerStatusUseCase.execute());

  // Rota de Pareamento (Handshake com PIN)
  app.post('/api/pair', async (request, reply) => {
    const parseResult = PairRequestSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        error: parseResult.error.errors[0].message,
        code: 'VALIDATION_ERROR',
        statusCode: 400,
        timestamp: new Date().toISOString(),
      });
    }

    const { pin, deviceName, platform } = parseResult.data;
    const ipAddress = request.ip;

    const authResult = await authenticateDeviceUseCase.execute({
      pin,
      deviceName,
      platform,
      ipAddress,
    });

    if (!authResult.success) {
      return reply.status(401).send({
        error: authResult.message || 'PIN de pareamento incorreto ou expirado.',
        code: 'INVALID_PIN',
        statusCode: 401,
        timestamp: new Date().toISOString(),
      });
    }

    return reply.status(200).send(authResult);
  });

  // Rota de Sincronização do Clipboard (protegida com Bearer Token)
  app.post('/api/clipboard', { preHandler: requireAuth }, async (request, reply) => {
    const parseResult = ClipboardSyncSchema.safeParse(request.body);
    if (!parseResult.success) {
      return reply.status(400).send({
        error: parseResult.error.errors[0].message,
        code: 'VALIDATION_ERROR',
        statusCode: 400,
        timestamp: new Date().toISOString(),
      });
    }

    const result = await syncClipboardUseCase.execute(parseResult.data);
    return reply.status(200).send(result);
  });

  // Rota de Upload de Arquivos via Streaming Contínuo (protegida com Bearer Token)
  app.post('/api/upload', { preHandler: requireAuth }, async (request, reply) => {
    const data = await request.file();
    if (!data) {
      return reply.status(400).send({
        error: 'Nenhum arquivo enviado no formulário multipart.',
        code: 'MISSING_FILE',
        statusCode: 400,
        timestamp: new Date().toISOString(),
      });
    }

    const filename = data.filename || `orbit-file-${Date.now()}`;
    const mimeType = data.mimetype;
    const expectedSha256 = (request.headers['x-file-hash'] as string) || undefined;
    const senderDeviceId = (request.headers['x-device-id'] as string) || 'unknown-device';
    const totalSizeBytes = request.headers['x-file-size']
      ? parseInt(request.headers['x-file-size'] as string, 10)
      : undefined;

    const transferId = randomUUID();

    try {
      const output = await processUploadUseCase.execute({
        transferId,
        filename,
        mimeType,
        fileStream: data.file,
        totalSizeBytes,
        expectedSha256,
        senderDeviceId,
      });

      return reply.status(201).send(output);
    } catch (err: any) {
      return reply.status(422).send({
        error: err.message || 'Falha durante o streaming e gravação do arquivo.',
        code: 'STREAM_WRITE_FAILED',
        statusCode: 422,
        timestamp: new Date().toISOString(),
      });
    }
  });

  // Rota WebSocket duplex
  app.register(async function (fastify) {
    fastify.get('/ws', { websocket: true }, (connection: any, _req) => {
      const socket = connection.socket ?? connection;
      const clientId = randomUUID();

      wsServer.addClient(clientId, socket);

      socket.on('message', (messageRaw: any) => {
        try {
          const data = JSON.parse(messageRaw.toString());
          if (data.type === 'IDENTIFY' && data.payload?.deviceId) {
            wsServer.setClientDeviceId(clientId, data.payload.deviceId);
            socket.send(
              JSON.stringify({
                type: 'IDENTIFIED',
                payload: { clientId, deviceId: data.payload.deviceId },
                timestamp: new Date().toISOString(),
              })
            );
          }
        } catch {}
      });
    });
  });

  return app;
}
