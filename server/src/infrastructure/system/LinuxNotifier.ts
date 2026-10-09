import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import { INotificationService } from '../../core/interfaces/INotificationService.js';

const execAsync = promisify(exec);

export class LinuxNotifier implements INotificationService {
  async notify(title: string, message: string, urgency: 'low' | 'normal' | 'critical' = 'normal'): Promise<void> {
    try {
      const sanitizedTitle = title.replace(/"/g, '\\"');
      const sanitizedMessage = message.replace(/"/g, '\\"');
      const icon = 'emblem-shared';

      await execAsync(`notify-send -u ${urgency} -i "${icon}" "${sanitizedTitle}" "${sanitizedMessage}"`);
    } catch {
      // Ignora falha silenciosa se notify-send não estiver disponível no ambiente
      console.log(`[Orbit Notification] ${title}: ${message}`);
    }
  }
}
