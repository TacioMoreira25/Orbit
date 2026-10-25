import { randomUUID } from 'node:crypto';
import { IClipboardService } from '../../core/interfaces/IClipboardService.js';
import { ISmartClassifier } from '../../core/interfaces/ISmartClassifier.js';
import { INotificationService } from '../../core/interfaces/INotificationService.js';
import { IWebSocketBroadcaster } from '../../core/interfaces/IWebSocketBroadcaster.js';
import { SyncClipboardInput, SyncClipboardOutput } from '../dtos/ClipboardDto.js';

export class SyncClipboardUseCase {
  constructor(
    private readonly clipboardService: IClipboardService,
    private readonly classifier: ISmartClassifier,
    private readonly notificationService: INotificationService,
    private readonly wsBroadcaster: IWebSocketBroadcaster
  ) {}

  async execute(input: SyncClipboardInput): Promise<SyncClipboardOutput> {
    const { content, senderDeviceId } = input;
    const isFromLinuxSelf = senderDeviceId === 'linux-server';
    const classification = await this.classifier.classify(content);
    const textToApply = classification.formattedText;

    const applied = await this.clipboardService.writeText(textToApply);

    const receivedAt = new Date();
    const id = randomUUID();

    const preview = content.length > 60 ? content.substring(0, 57) + '...' : content;
    const tag = classification.type !== 'text' ? ` [${classification.type.toUpperCase()}]` : '';

    // Só exibe notificação no desktop Linux quando o clipboard veio de outro dispositivo (ex: Celular)
    if (!isFromLinuxSelf) {
      await this.notificationService.notify(
        `Orbit: Clipboard Sincronizado${tag}`,
        `Conteúdo pronto para colar: "${preview}"`,
        'low'
      );
    }

    // Notifica dispositivos conectados via WebSocket
    this.wsBroadcaster.broadcast('CLIPBOARD_RECEIVED', {
      id,
      content: textToApply,
      type: classification.type,
      detectedLanguage: classification.detectedLanguage,
      senderDeviceId,
      preview,
      receivedAt: receivedAt.toISOString(),
    });

    return {
      id,
      content: textToApply,
      contentType: classification.type,
      detectedLanguage: classification.detectedLanguage,
      appliedToSystemClipboard: applied,
      receivedAt,
    };
  }
}
