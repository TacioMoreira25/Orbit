import { Readable } from 'node:stream';

export interface FileSaveResult {
  savedPath: string;
  bytesWritten: number;
  calculatedHashSha256: string;
}

export interface ProgressCallback {
  (bytesWritten: number, totalBytes?: number): void;
}

export interface IStorageService {
  saveStream(
    filename: string,
    stream: Readable,
    options?: {
      totalBytes?: number;
      expectedHash?: string;
      onProgress?: ProgressCallback;
    }
  ): Promise<FileSaveResult>;

  ensureDestinationDirectory(): Promise<string>;
  getDestinationDirectory(): string;
}
