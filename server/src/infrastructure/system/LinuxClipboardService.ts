import { exec, execFile, spawn } from 'node:child_process';
import { promisify } from 'node:util';
import { IClipboardService } from '../../core/interfaces/IClipboardService.js';

const execAsync = promisify(exec);
const execFileAsync = promisify(execFile);

export class LinuxClipboardService implements IClipboardService {
  async writeText(text: string): Promise<boolean> {
    // 1. Tenta KDE Plasma Klipper via DBus (qdbus-qt6 / qdbus / gdbus) — funciona em background e systemd sem perder seleção
    for (const qdbusBin of ['qdbus-qt6', 'qdbus6', 'qdbus']) {
      try {
        await execFileAsync(qdbusBin, [
          'org.kde.klipper',
          '/klipper',
          'org.kde.klipper.klipper.setClipboardContents',
          text,
        ]);
        return true;
      } catch {
        // Continua para o próximo método
      }
    }

    // 2. Tenta gdbus para org.kde.klipper
    try {
      await execFileAsync('gdbus', [
        'call',
        '--session',
        '--dest',
        'org.kde.klipper',
        '--object-path',
        '/klipper',
        '--method',
        'org.kde.klipper.klipper.setClipboardContents',
        text,
      ]);
      return true;
    } catch {
      // Continua para wl-copy / xclip
    }

    // 3. Tenta wl-copy (Wayland)
    try {
      await this.pipeToCommand('wl-copy', text);
      return true;
    } catch {
      // Continua para xclip / xsel
    }

    // 4. Tenta xclip / xsel (X11 / XWayland)
    try {
      await this.pipeToCommand('xclip', text, ['-selection', 'clipboard']);
      return true;
    } catch {
      try {
        await this.pipeToCommand('xsel', text, ['--clipboard', '--input']);
        return true;
      } catch (err) {
        console.error(
          '[Orbit Clipboard] Não foi possível copiar para a área de transferência.',
          err
        );
        return false;
      }
    }
  }

  async readText(): Promise<string> {
    for (const qdbusBin of ['qdbus-qt6', 'qdbus6', 'qdbus']) {
      try {
        const { stdout } = await execFileAsync(qdbusBin, [
          'org.kde.klipper',
          '/klipper',
          'org.kde.klipper.klipper.getClipboardContents',
        ]);
        return stdout.replace(/\n$/, '');
      } catch {
        // Continua
      }
    }

    try {
      const { stdout } = await execAsync('wl-paste --no-newline');
      return stdout;
    } catch {
      try {
        const { stdout } = await execAsync('xclip -selection clipboard -o');
        return stdout;
      } catch {
        return '';
      }
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
