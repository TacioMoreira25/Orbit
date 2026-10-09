export type TransferStatus = 'pending' | 'in_progress' | 'completed' | 'failed' | 'cancelled';

export interface FileTransfer {
  id: string;
  filename: string;
  sizeBytes: number;
  mimeType: string;
  expectedHashSha256?: string;
  calculatedHashSha256?: string;
  status: TransferStatus;
  bytesReceived: number;
  progressPercentage: number;
  destinationPath: string;
  senderDeviceId: string;
  startedAt: Date;
  completedAt?: Date;
  errorMessage?: string;
}
