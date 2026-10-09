import { WebSocket } from 'ws';
import {
  IWebSocketBroadcaster,
  WebSocketEventType,
  WebSocketMessage,
} from '../../core/interfaces/IWebSocketBroadcaster.js';

interface ConnectedClient {
  id: string;
  socket: WebSocket;
  deviceId?: string;
  authenticated: boolean;
}

export class TransferWebSocketServer implements IWebSocketBroadcaster {
  private readonly clients = new Map<string, ConnectedClient>();

  addClient(id: string, socket: WebSocket): void {
    const client: ConnectedClient = {
      id,
      socket,
      authenticated: false,
    };

    this.clients.set(id, client);

    socket.on('close', () => {
      this.clients.delete(id);
    });

    socket.on('error', () => {
      this.clients.delete(id);
    });
  }

  setClientDeviceId(clientId: string, deviceId: string): void {
    const client = this.clients.get(clientId);
    if (client) {
      client.deviceId = deviceId;
      client.authenticated = true;
    }
  }

  getActiveConnectionsCount(): number {
    return this.clients.size;
  }

  broadcast<T>(type: WebSocketEventType, payload: T): void {
    const message = this.createMessage(type, payload);
    const serialized = JSON.stringify(message);

    for (const client of this.clients.values()) {
      if (client.socket.readyState === WebSocket.OPEN) {
        client.socket.send(serialized);
      }
    }
  }

  sendToDevice<T>(deviceId: string, type: WebSocketEventType, payload: T): void {
    const message = this.createMessage(type, payload);
    const serialized = JSON.stringify(message);

    for (const client of this.clients.values()) {
      if (client.deviceId === deviceId && client.socket.readyState === WebSocket.OPEN) {
        client.socket.send(serialized);
      }
    }
  }

  private createMessage<T>(type: WebSocketEventType, payload: T): WebSocketMessage<T> {
    return {
      type,
      payload,
      timestamp: new Date().toISOString(),
    };
  }
}
