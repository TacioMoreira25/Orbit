import { FastifyInstance, preHandlerHookHandler } from 'fastify';
import { GetServerStatusUseCase } from '../../../application/use-cases/GetServerStatusUseCase.js';
import { SyncClipboardUseCase } from '../../../application/use-cases/SyncClipboardUseCase.js';
import { NetworkUtils } from '../../discovery/NetworkUtils.js';
import { sendError } from '../utils/httpError.js';
import { renderDashboardHtml } from '../views/dashboardTemplate.js';

export function registerWebDashboardRoutes(
  app: FastifyInstance,
  getServerStatusUseCase: GetServerStatusUseCase,
  syncClipboardUseCase: SyncClipboardUseCase,
  requireLocalOrAuth: preHandlerHookHandler
) {
  // Envio rápido de clipboard a partir do Web Dashboard local do Linux para os celulares
  app.post('/api/local/clipboard', { preHandler: requireLocalOrAuth }, async (request, reply) => {
    const body = (request.body as { content?: string } | null) || {};
    if (!body.content || !body.content.trim()) {
      return sendError(reply, 400, 'EMPTY_CLIPBOARD', 'Conteúdo vazio.');
    }
    const res = await syncClipboardUseCase.execute({
      content: body.content,
      senderDeviceId: 'linux-server',
    });
    return reply.status(200).send(res);
  });

  app.get('/', async (_request, reply) => {
    const status = getServerStatusUseCase.execute();
    const localIp = NetworkUtils.getLocalIpAddress();
    const html = renderDashboardHtml({ status, localIp });

    reply.header('Content-Type', 'text/html; charset=utf-8');
    return reply.status(200).send(html);
  });
}
