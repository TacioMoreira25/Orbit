import { Readable } from 'node:stream';

export interface ProcessUploadInput {
  transferId: string;
  filename: string;
  mimeType: string;
  fileStream: Readable;
  totalSizeBytes?: number;
  expectedSha256?: string;
  senderDeviceId: string;
}

export interface ProcessUploadOutput {
  transferId: string;
  filename: string;
  savedPath: string;
  bytesWritten: number;
  calculatedSha256: string;
  isHashValid: boolean;
  completedAt: Date;
}
