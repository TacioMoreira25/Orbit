export type WebSocketEventType =
  | 'TRANSFER_PROGRESS'
  | 'TRANSFER_COMPLETED'
  | 'TRANSFER_ERROR'
  | 'CLIPBOARD_RECEIVED'
  | 'DEVICE_CONNECTED'
  | 'DEVICE_DISCONNECTED';

export interface WebSocketMessage<T = unknown> {
  type: WebSocketEventType;
  payload: T;
  timestamp: string;
}

export interface IWebSocketBroadcaster {
  broadcast<T>(type: WebSocketEventType, payload: T): void;
  sendToDevice<T>(deviceId: string, type: WebSocketEventType, payload: T): void;
}
