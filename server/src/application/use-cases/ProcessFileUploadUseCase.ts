import { IStorageService } from '../../core/interfaces/IStorageService.js';
import { IWebSocketBroadcaster } from '../../core/interfaces/IWebSocketBroadcaster.js';
import { INotificationService } from '../../core/interfaces/INotificationService.js';
import { ProcessUploadInput, ProcessUploadOutput } from '../dtos/UploadDto.js';

export class ProcessFileUploadUseCase {
  constructor(
    private readonly storageService: IStorageService,
    private readonly wsBroadcaster: IWebSocketBroadcaster,
    private readonly notificationService: INotificationService
  ) {}

  async execute(input: ProcessUploadInput): Promise<ProcessUploadOutput> {
    const { transferId, filename, fileStream, totalSizeBytes, expectedSha256, senderDeviceId } = input;

    let lastProgressReportTime = 0;

    const saveResult = await this.storageService.saveStream(filename, fileStream, {
      totalBytes: totalSizeBytes,
      expectedHash: expectedSha256,
      onProgress: (bytesWritten, total) => {
        const now = Date.now();
        // Emite no máximo a cada 100ms para evitar flood no WebSocket
        if (now - lastProgressReportTime > 100 || (total && bytesWritten >= total)) {
          lastProgressReportTime = now;
          const percentage = total && total > 0 ? Math.min(100, Math.round((bytesWritten / total) * 100)) : 0;
          this.wsBroadcaster.sendToDevice(senderDeviceId, 'TRANSFER_PROGRESS', {
            transferId,
            filename,
            bytesWritten,
            totalBytes: total,
            percentage,
          });
        }
      },
    });

    const isHashValid = expectedSha256
      ? saveResult.calculatedHashSha256.toLowerCase() === expectedSha256.toLowerCase()
      : true;

    if (!isHashValid) {
      this.wsBroadcaster.sendToDevice(senderDeviceId, 'TRANSFER_ERROR', {
        transferId,
        filename,
        error: `Integridade violada! Hash esperado: ${expectedSha256}, calculado: ${saveResult.calculatedHashSha256}`,
      });
      throw new Error(`Falha de integridade: Hash SHA-256 divergente para o arquivo ${filename}`);
    }

    const completedAt = new Date();

    // Notifica via WebSocket
    this.wsBroadcaster.sendToDevice(senderDeviceId, 'TRANSFER_COMPLETED', {
      transferId,
      filename,
      bytesWritten: saveResult.bytesWritten,
      savedPath: saveResult.savedPath,
      sha256: saveResult.calculatedHashSha256,
      completedAt: completedAt.toISOString(),
    });

    // Notificação desktop nativa no Linux
    const sizeMb = (saveResult.bytesWritten / (1024 * 1024)).toFixed(1);
    await this.notificationService.notify(
      'Orbit: Arquivo Recebido!',
      `"${filename}" (${sizeMb} MB) salvo em ${saveResult.savedPath}`,
      'normal'
    );

    return {
      transferId,
      filename,
      savedPath: saveResult.savedPath,
      bytesWritten: saveResult.bytesWritten,
      calculatedSha256: saveResult.calculatedHashSha256,
      isHashValid,
      completedAt,
    };
  }
}
