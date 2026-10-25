import { FastifyInstance, preHandlerHookHandler } from 'fastify';
import { randomUUID } from 'node:crypto';
import { ProcessFileUploadUseCase } from '../../../application/use-cases/ProcessFileUploadUseCase.js';
import { sendError } from '../utils/httpError.js';

export function registerUploadRoutes(
  app: FastifyInstance,
  processUploadUseCase: ProcessFileUploadUseCase,
  requireAuth: preHandlerHookHandler
) {
  app.post('/api/upload', { preHandler: requireAuth }, async (request, reply) => {
    const data = await request.file();
    if (!data) {
      return sendError(reply, 400, 'MISSING_FILE', 'Nenhum arquivo enviado no formulário multipart.');
    }

    const filename = data.filename || `orbit-file-${Date.now()}`;
    const mimeType = data.mimetype;
    const expectedSha256 = (request.headers['x-file-hash'] as string) || undefined;
    const senderDeviceId = (request.headers['x-device-id'] as string) || 'unknown-device';
    const totalSizeBytes = request.headers['x-file-size']
      ? parseInt(request.headers['x-file-size'] as string, 10)
      : undefined;
    const transferId = (request.headers['x-transfer-id'] as string) || randomUUID();

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
      return sendError(
        reply,
        422,
        'STREAM_WRITE_FAILED',
        err.message || 'Falha durante o streaming e gravação do arquivo.'
      );
    }
  });
}
