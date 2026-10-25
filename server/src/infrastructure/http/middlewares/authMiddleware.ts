import { FastifyReply, FastifyRequest } from 'fastify';
import { PinPairingManager } from '../../security/PinPairingManager.js';
import { sendError } from '../utils/httpError.js';

export function isLoopbackRequest(request: FastifyRequest): boolean {
  return (
    request.ip === '127.0.0.1' ||
    request.ip === '::1' ||
    request.ip === '::ffff:127.0.0.1'
  );
}

export async function requireLocalhost(request: FastifyRequest, reply: FastifyReply) {
  if (!isLoopbackRequest(request)) {
    return sendError(reply, 403, 'FORBIDDEN', 'Acesso restrito ao terminal local do servidor.');
  }
}

export function createAuthMiddleware(pairingManager: PinPairingManager) {
  return async function requireAuth(request: FastifyRequest, reply: FastifyReply) {
    const authHeader = request.headers['authorization'];
    if (!authHeader || !pairingManager.isTokenValid(authHeader)) {
      return sendError(
        reply,
        401,
        'UNAUTHORIZED',
        'Dispositivo não autorizado. Pareie o dispositivo novamente via QR Code ou PIN.'
      );
    }
  };
}

export function createLocalOrAuthMiddleware(pairingManager: PinPairingManager) {
  const requireAuth = createAuthMiddleware(pairingManager);
  return async function requireLocalOrAuth(request: FastifyRequest, reply: FastifyReply) {
    if (isLoopbackRequest(request)) return;
    return requireAuth(request, reply);
  };
}
