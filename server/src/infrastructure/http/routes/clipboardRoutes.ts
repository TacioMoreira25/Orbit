import { FastifyInstance, preHandlerHookHandler } from 'fastify';
import { SyncClipboardUseCase } from '../../../application/use-cases/SyncClipboardUseCase.js';
import { ClipboardSyncSchema } from '../schemas.js';
import { sendError } from '../utils/httpError.js';

export function registerClipboardRoutes(
  app: FastifyInstance,
  syncClipboardUseCase: SyncClipboardUseCase,
  requireAuth: preHandlerHookHandler
) {
  app.post('/api/clipboard', { preHandler: requireAuth }, async (request, reply) => {
    const parseResult = ClipboardSyncSchema.safeParse(request.body);
    if (!parseResult.success) {
      return sendError(reply, 400, 'VALIDATION_ERROR', parseResult.error.errors[0].message);
    }

    const result = await syncClipboardUseCase.execute(parseResult.data);
    return reply.status(200).send(result);
  });
}
