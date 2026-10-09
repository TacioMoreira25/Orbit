export type ClipboardContentType = 'text' | 'url' | 'code' | 'json' | 'markdown';

export interface ClipboardItem {
  id: string;
  content: string;
  contentType: ClipboardContentType;
  detectedLanguage?: string;
  senderDeviceId: string;
  receivedAt: Date;
}
