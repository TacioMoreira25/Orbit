import { FastifyReply } from 'fastify';

export function sendError(
  reply: FastifyReply,
  statusCode: number,
  code: string,
  error: string
) {
  return reply.status(statusCode).send({
    error,
    code,
    statusCode,
    timestamp: new Date().toISOString(),
  });
}
