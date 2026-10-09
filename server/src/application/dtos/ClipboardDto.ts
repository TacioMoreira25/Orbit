import { ClipboardContentType } from '../../core/entities/ClipboardItem.js';

export interface SyncClipboardInput {
  content: string;
  senderDeviceId: string;
}

export interface SyncClipboardOutput {
  id: string;
  content: string;
  contentType: ClipboardContentType;
  detectedLanguage?: string;
  appliedToSystemClipboard: boolean;
  receivedAt: Date;
}
