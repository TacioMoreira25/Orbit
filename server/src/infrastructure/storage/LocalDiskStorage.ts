import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { Readable, Transform } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { FileSaveResult, IStorageService, ProgressCallback } from '../../core/interfaces/IStorageService.js';

export class LocalDiskStorage implements IStorageService {
  private readonly targetDirectory: string;

  constructor(rawDirectoryPath: string = '~/Downloads') {
    this.targetDirectory = this.resolveHomeDir(rawDirectoryPath);
  }

  private resolveHomeDir(dirPath: string): string {
    if (dirPath.startsWith('~/') || dirPath === '~') {
      return path.join(os.homedir(), dirPath.slice(1));
    }
    return path.resolve(dirPath);
  }

  getDestinationDirectory(): string {
    return this.targetDirectory;
  }

  async ensureDestinationDirectory(): Promise<string> {
    if (!fs.existsSync(this.targetDirectory)) {
      await fs.promises.mkdir(this.targetDirectory, { recursive: true });
    }
    return this.targetDirectory;
  }

  private getUniqueFilePath(filename: string): string {
    const ext = path.extname(filename);
    const basename = path.basename(filename, ext);
    let candidatePath = path.join(this.targetDirectory, filename);
    let counter = 1;

    while (fs.existsSync(candidatePath)) {
      candidatePath = path.join(this.targetDirectory, `${basename} (${counter})${ext}`);
      counter++;
    }

    return candidatePath;
  }

  async saveStream(
    filename: string,
    stream: Readable,
    options?: {
      totalBytes?: number;
      expectedHash?: string;
      onProgress?: ProgressCallback;
    }
  ): Promise<FileSaveResult> {
    await this.ensureDestinationDirectory();
    const targetFilePath = this.getUniqueFilePath(filename);
    const writeStream = fs.createWriteStream(targetFilePath);

    const hashStream = crypto.createHash('sha256');
    let bytesWritten = 0;

    // Stream intermediário para contar bytes e computar hash em tempo real sem alocar memória extra
    const spyTransform = new Transform({
      transform(chunk: Buffer, _encoding, callback) {
        bytesWritten += chunk.length;
        hashStream.update(chunk);
        if (options?.onProgress) {
          options.onProgress(bytesWritten, options.totalBytes);
        }
        callback(null, chunk);
      },
    });

    try {
      await pipeline(stream, spyTransform, writeStream);
      const calculatedHashSha256 = hashStream.digest('hex');

      return {
        savedPath: targetFilePath,
        bytesWritten,
        calculatedHashSha256,
      };
    } catch (error) {
      // Se falhou no meio da transferência, limpa o arquivo corrompido do disco
      if (fs.existsSync(targetFilePath)) {
        try {
          await fs.promises.unlink(targetFilePath);
        } catch {}
      }
      throw error;
    }
  }
}
