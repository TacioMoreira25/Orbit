import { FastifyInstance, preHandlerHookHandler } from 'fastify';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { randomUUID } from 'node:crypto';
import { IStorageService } from '../../../core/interfaces/IStorageService.js';
import { IWebSocketBroadcaster } from '../../../core/interfaces/IWebSocketBroadcaster.js';
import { LocalDiskStorage } from '../../storage/LocalDiskStorage.js';
import { sendError } from '../utils/httpError.js';

export interface SharedFileMetadata {
  fileId: string;
  filename: string;
  savedPath: string;
  sizeBytes: number;
  sha256: string;
  createdAt: string;
  consumed?: boolean;
}

export function registerDownloadRoutes(
  app: FastifyInstance,
  storageService: IStorageService,
  wsBroadcaster: IWebSocketBroadcaster,
  requireLocalOrAuth: preHandlerHookHandler
) {
  const sharedFiles = new Map<string, SharedFileMetadata>();
  // Diretório temporário exclusivo para staging de envios PC -> Celular (não polui ~/Downloads do PC)
  const outboxDir = path.join(os.tmpdir(), 'orbit-outbox');
  const outboxStorage = new LocalDiskStorage(outboxDir);

  // Lista apenas arquivos pendentes (ainda não baixados pelo celular)
  app.get('/api/files', { preHandler: requireLocalOrAuth }, async (_request, reply) => {
    const list = Array.from(sharedFiles.values()).filter(
      (f) => !f.consumed && fs.existsSync(f.savedPath)
    );
    return reply.status(200).send({ files: list });
  });

  // Upload do PC (Web Dashboard) para compartilhar imediatamente com os celulares conectados
  app.post('/api/share-to-mobile', { preHandler: requireLocalOrAuth }, async (request, reply) => {
    const data = await request.file();
    if (!data) {
      return sendError(reply, 400, 'MISSING_FILE', 'Nenhum arquivo selecionado para envio ao celular.');
    }

    const filename = data.filename || `orbit-pc-${Date.now()}`;
    try {
      const saveResult = await outboxStorage.saveStream(filename, data.file);
      const fileId = randomUUID();
      const metadata: SharedFileMetadata = {
        fileId,
        filename: path.basename(filename),
        savedPath: saveResult.savedPath,
        sizeBytes: saveResult.bytesWritten,
        sha256: saveResult.calculatedHashSha256,
        createdAt: new Date().toISOString(),
      };

      sharedFiles.set(fileId, metadata);

      // Notifica todos os celulares conectados via WebSocket para baixarem o arquivo
      wsBroadcaster.broadcast('FILE_AVAILABLE', {
        fileId,
        filename: metadata.filename,
        sizeBytes: metadata.sizeBytes,
        sha256: metadata.sha256,
        downloadPath: `/api/download/${fileId}`,
      });

      return reply.status(201).send(metadata);
    } catch (err: any) {
      return sendError(reply, 422, 'SHARE_FAILED', err.message || 'Falha ao preparar arquivo para o celular.');
    }
  });

  // Rota de Download via HTTP Stream com suporte a HTTP Range (PC ➔ Celular)
  app.get('/api/download/:fileId', async (request, reply) => {
    const { fileId } = request.params as { fileId: string };
    let fileMeta = sharedFiles.get(fileId);

    // Permite também buscar pelo nome seguro na pasta Downloads se o fileId for o nome de um arquivo existente
    if (!fileMeta) {
      const candidatePath = path.join(storageService.getDestinationDirectory(), path.basename(fileId));
      if (fs.existsSync(candidatePath) && fs.statSync(candidatePath).isFile()) {
        const stat = fs.statSync(candidatePath);
        fileMeta = {
          fileId,
          filename: path.basename(candidatePath),
          savedPath: candidatePath,
          sizeBytes: stat.size,
          sha256: '',
          createdAt: stat.mtime.toISOString(),
        };
      }
    }

    if (!fileMeta || !fs.existsSync(fileMeta.savedPath)) {
      return sendError(reply, 404, 'FILE_NOT_FOUND', 'Arquivo não encontrado no servidor Linux.');
    }

    const stat = await fs.promises.stat(fileMeta.savedPath);
    const totalSize = stat.size;
    const rangeHeader = request.headers.range;

    reply.header('Accept-Ranges', 'bytes');
    reply.header(
      'Content-Disposition',
      `attachment; filename="${encodeURIComponent(fileMeta.filename)}"`
    );
    if (fileMeta.sha256) {
      reply.header('x-file-hash', fileMeta.sha256);
    }

    if (rangeHeader) {
      const parts = rangeHeader.replace(/bytes=/, '').split('-');
      const start = parseInt(parts[0], 10);
      const end = parts[1] ? parseInt(parts[1], 10) : totalSize - 1;

      if (isNaN(start) || isNaN(end) || start >= totalSize || end >= totalSize || start > end) {
        reply.header('Content-Range', `bytes */${totalSize}`);
        return sendError(reply, 416, 'RANGE_NOT_SATISFIABLE', 'Intervalo de bytes inválido.');
      }

      const chunkSize = end - start + 1;
      reply.status(206);
      reply.header('Content-Range', `bytes ${start}-${end}/${totalSize}`);
      reply.header('Content-Length', chunkSize);
      reply.header('Content-Type', 'application/octet-stream');

      const stream = fs.createReadStream(fileMeta.savedPath, { start, end });
      return reply.send(stream);
    }

    reply.status(200);
    reply.header('Content-Length', totalSize);
    reply.header('Content-Type', 'application/octet-stream');

    const stream = fs.createReadStream(fileMeta.savedPath);
    stream.on('close', () => {
      if (sharedFiles.has(fileId)) {
        fileMeta.consumed = true;
      }
    });
    return reply.send(stream);
  });
}
