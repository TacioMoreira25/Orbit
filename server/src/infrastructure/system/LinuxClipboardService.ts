import { exec, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { IClipboardService } from '../../core/interfaces/IClipboardService.js';

const execAsync = promisify(exec);

export class LinuxClipboardService implements IClipboardService {
  private isWaylandSession: boolean;

  constructor() {
    const sessionType = process.env.XDG_SESSION_TYPE || '';
    const waylandDisplay = process.env.WAYLAND_DISPLAY || '';
    this.isWaylandSession = sessionType.toLowerCase() === 'wayland' || waylandDisplay.length > 0;
  }

  async writeText(text: string): Promise<boolean> {
    try {
      if (this.isWaylandSession) {
        // Tenta wl-copy no Wayland
        await this.pipeToCommand('wl-copy', text);
        return true;
      } else {
        // Tenta xclip no X11
        await this.pipeToCommand('xclip', text, ['-selection', 'clipboard']);
        return true;
      }
    } catch {
      // Fallback cruzado caso a variável de ambiente não corresponda ao binário instalado
      try {
        const fallbackCmd = this.isWaylandSession ? 'xclip' : 'wl-copy';
        const fallbackArgs = this.isWaylandSession ? ['-selection', 'clipboard'] : [];
        await this.pipeToCommand(fallbackCmd, text, fallbackArgs);
        return true;
      } catch (err) {
        console.error('[Orbit Clipboard] Não foi possível copiar para a área de transferência. Certifique-se de que wl-copy ou xclip estão instalados.', err);
        return false;
      }
    }
  }

  async readText(): Promise<string> {
    try {
      if (this.isWaylandSession) {
        const { stdout } = await execAsync('wl-paste --no-newline');
        return stdout;
      } else {
        const { stdout } = await execAsync('xclip -selection clipboard -o');
        return stdout;
      }
    } catch {
      return '';
    }
  }

  private pipeToCommand(command: string, input: string, args: string[] = []): Promise<void> {
    return new Promise((resolve, reject) => {
      const proc = spawn(command, args, { stdio: ['pipe', 'ignore', 'ignore'] });

      proc.on('error', (err) => reject(err));
      proc.on('close', (code) => {
        if (code === 0) resolve();
        else reject(new Error(`${command} saiu com código ${code}`));
      });

      proc.stdin.write(input);
      proc.stdin.end();
    });
  }
}
