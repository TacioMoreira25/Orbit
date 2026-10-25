import { execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { INotificationService } from '../../core/interfaces/INotificationService.js';

const execFileAsync = promisify(execFile);

export class LinuxNotifier implements INotificationService {
  async notify(
    title: string,
    message: string,
    urgency: 'low' | 'normal' | 'critical' = 'normal',
    actionOpenPath?: string
  ): Promise<void> {
    const icon = 'emblem-shared';

    if (actionOpenPath) {
      this.notifyWithOpenAction(title, message, urgency, icon, actionOpenPath);
      return;
    }

    try {
      await execFileAsync('notify-send', ['-u', urgency, '-i', icon, title, message]);
    } catch {
      console.log(`[Orbit Notification] ${title}: ${message}`);
    }
  }

  private notifyWithOpenAction(
    title: string,
    message: string,
    urgency: string,
    icon: string,
    openPath: string
  ): void {
    try {
      // Executa em background pois --action aguarda a interação do usuário na notificação
      const proc = spawn(
        'notify-send',
        ['-u', urgency, '-i', icon, '--action=open=Abrir Pasta', title, message],
        { stdio: ['ignore', 'pipe', 'ignore'] }
      );

      let output = '';
      proc.stdout.on('data', (chunk) => {
        output += chunk.toString();
      });

      proc.on('close', (code) => {
        if (code === 0 && output.trim() === 'open') {
          const opener = spawn('xdg-open', [openPath], {
            detached: true,
            stdio: 'ignore',
          });
          opener.unref();
        }
      });

      proc.on('error', () => {
        // Fallback caso notify-send não esteja disponível
        console.log(`[Orbit Notification] ${title}: ${message}`);
      });
    } catch {
      console.log(`[Orbit Notification] ${title}: ${message}`);
    }
  }
}
