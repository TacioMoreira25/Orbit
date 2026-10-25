import { FastifyInstance } from 'fastify';
import { randomUUID } from 'node:crypto';
import { TransferWebSocketServer } from '../../websocket/TransferWebSocketServer.js';

export function registerWebSocketRoutes(
  app: FastifyInstance,
  wsServer: TransferWebSocketServer
) {
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
}
