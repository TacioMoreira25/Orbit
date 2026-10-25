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

    const startTime = Date.now();
    let lastProgressReportTime = 0;

    let saveResult;
    try {
      saveResult = await this.storageService.saveStream(filename, fileStream, {
        totalBytes: totalSizeBytes,
        expectedHash: expectedSha256,
        onProgress: (bytesWritten, total) => {
          const now = Date.now();
          // Emite no máximo a cada 100ms para evitar flood no WebSocket
          if (now - lastProgressReportTime > 100 || (total && bytesWritten >= total)) {
            lastProgressReportTime = now;
            const elapsedSec = Math.max(0.001, (now - startTime) / 1000);
            const speedBytesPerSec = bytesWritten / elapsedSec;
            const speedMbps = Number((speedBytesPerSec / (1024 * 1024)).toFixed(2));
            const etaSeconds =
              total && total > bytesWritten && speedBytesPerSec > 0
                ? Math.ceil((total - bytesWritten) / speedBytesPerSec)
                : 0;
            const percentage =
              total && total > 0 ? Math.min(100, Math.round((bytesWritten / total) * 100)) : 0;

            this.wsBroadcaster.sendToDevice(senderDeviceId, 'TRANSFER_PROGRESS', {
              transferId,
              filename,
              bytesWritten,
              totalBytes: total,
              percentage,
              speedBytesPerSec,
              speedMbps,
              etaSeconds,
            });
          }
        },
      });
    } catch (err: any) {
      this.wsBroadcaster.sendToDevice(senderDeviceId, 'TRANSFER_ERROR', {
        transferId,
        filename,
        error: err.message || 'Conexão interrompida durante a transferência.',
      });
      throw err;
    }

    const isHashValid = expectedSha256
      ? saveResult.calculatedHashSha256.toLowerCase() === expectedSha256.toLowerCase()
      : true;

    if (!isHashValid) {
      await this.storageService.deleteFile?.(saveResult.savedPath);
      this.wsBroadcaster.sendToDevice(senderDeviceId, 'TRANSFER_ERROR', {
        transferId,
        filename,
        error: `Integridade violada! Hash esperado: ${expectedSha256}, calculado: ${saveResult.calculatedHashSha256}`,
      });
      throw new Error(`Falha de integridade: Hash SHA-256 divergente para o arquivo ${filename}`);
    }

    const completedAt = new Date();
    const totalElapsedSec = Math.max(0.001, (completedAt.getTime() - startTime) / 1000);
    const avgSpeedMbps = (saveResult.bytesWritten / (1024 * 1024) / totalElapsedSec).toFixed(1);

    // Notifica via WebSocket
    this.wsBroadcaster.sendToDevice(senderDeviceId, 'TRANSFER_COMPLETED', {
      transferId,
      filename,
      bytesWritten: saveResult.bytesWritten,
      savedPath: saveResult.savedPath,
      sha256: saveResult.calculatedHashSha256,
      avgSpeedMbps: Number(avgSpeedMbps),
      completedAt: completedAt.toISOString(),
    });

    // Notificação desktop nativa no Linux com ação "Abrir Pasta"
    const sizeMb = (saveResult.bytesWritten / (1024 * 1024)).toFixed(1);
    await this.notificationService.notify(
      'Orbit: Arquivo Recebido!',
      `"${filename}" (${sizeMb} MB a ${avgSpeedMbps} MB/s) salvo em ${saveResult.savedPath}`,
      'normal',
      this.storageService.getDestinationDirectory()
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
