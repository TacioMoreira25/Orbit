import { FastifyInstance } from 'fastify';
import { AuthenticateDeviceUseCase } from '../../../application/use-cases/AuthenticateDeviceUseCase.js';
import { PinPairingManager } from '../../security/PinPairingManager.js';
import { NetworkUtils } from '../../discovery/NetworkUtils.js';
import { PairRequestSchema } from '../schemas.js';
import { requireLocalhost } from '../middlewares/authMiddleware.js';
import { sendError } from '../utils/httpError.js';

export function registerPairingRoutes(
  app: FastifyInstance,
  authenticateDeviceUseCase: AuthenticateDeviceUseCase,
  pairingManager: PinPairingManager,
  serverDeviceName: string = 'Orbit-Linux'
) {
  app.post('/api/pair', async (request, reply) => {
    const parseResult = PairRequestSchema.safeParse(request.body);
    if (!parseResult.success) {
      return sendError(reply, 400, 'VALIDATION_ERROR', parseResult.error.errors[0].message);
    }

    const { pin, deviceName, platform } = parseResult.data;
    const authResult = await authenticateDeviceUseCase.execute({
      pin,
      deviceName,
      platform,
      ipAddress: request.ip,
    });

    if (!authResult.success) {
      return sendError(
        reply,
        401,
        'INVALID_PIN',
        authResult.message || 'PIN de pareamento incorreto ou expirado.'
      );
    }

    return reply.status(200).send(authResult);
  });

  // Rota exclusiva para a CLI local (apenas loopback 127.0.0.1 / ::1) consultar ou renovar o PIN/QR Code
  app.post('/api/local/pin', { preHandler: requireLocalhost }, async (request, reply) => {
    const body = (request.body as { refresh?: boolean } | null) || {};
    let session = body.refresh ? null : pairingManager.getCurrentSession();
    if (!session) {
      session = pairingManager.generateNewSession();
    }

    const localIp = NetworkUtils.getLocalIpAddress();
    const port = parseInt(process.env.PORT || '3000', 10);

    return reply.status(200).send({
      ip: localIp,
      port,
      pin: session.pin,
      token: session.token,
      deviceName: serverDeviceName,
      url: `http://${localIp}:${port}`,
      expiresAt: session.expiresAt.toISOString(),
    });
  });
}
