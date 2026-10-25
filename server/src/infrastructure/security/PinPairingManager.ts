import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { PairingSession } from '../../core/entities/PairingSession.js';
import { ICryptographyService } from '../../core/interfaces/ICryptographyService.js';
import { IPairingManager } from '../../application/use-cases/AuthenticateDeviceUseCase.js';

export class PinPairingManager implements IPairingManager {
  private currentSession: PairingSession | null = null;
  private readonly authenticatedTokens = new Set<string>();
  private readonly tokenStoragePath: string;

  constructor(
    private readonly cryptoService: ICryptographyService,
    private readonly expirationSeconds: number = 300,
    storagePath?: string
  ) {
    this.tokenStoragePath = storagePath || path.join(os.homedir(), '.orbit_tokens.json');
    this.loadPersistedTokens();
  }

  private loadPersistedTokens(): void {
    try {
      if (fs.existsSync(this.tokenStoragePath)) {
        const raw = fs.readFileSync(this.tokenStoragePath, 'utf-8');
        const tokens: string[] = JSON.parse(raw);
        for (const t of tokens) {
          this.authenticatedTokens.add(t);
        }
      }
    } catch {}
  }

  private saveTokens(): void {
    try {
      fs.writeFileSync(
        this.tokenStoragePath,
        JSON.stringify(Array.from(this.authenticatedTokens), null, 2),
        'utf-8'
      );
    } catch {}
  }

  generateNewSession(): PairingSession {
    const pin = this.cryptoService.generatePin();
    const token = this.cryptoService.generateToken();
    const now = new Date();
    // Se expirationSeconds <= 0 (modo daemon), define expiração longa (1 ano)
    const ttlMs = this.expirationSeconds > 0 ? this.expirationSeconds * 1000 : 365 * 24 * 60 * 60 * 1000;
    const expiresAt = new Date(now.getTime() + ttlMs);

    this.currentSession = {
      pin,
      token,
      createdAt: now,
      expiresAt,
      isUsed: false,
    };

    return this.currentSession;
  }

  getCurrentSession(): PairingSession | null {
    if (!this.currentSession) return null;
    if (new Date() > this.currentSession.expiresAt) {
      this.currentSession = null;
      return null;
    }
    return this.currentSession;
  }

  verifyPin(pin: string): { valid: boolean; token?: string; error?: string } {
    if (!this.currentSession) {
      return { valid: false, error: 'Nenhuma sessão de pareamento ativa. Gere um novo PIN.' };
    }

    if (new Date() > this.currentSession.expiresAt) {
      this.currentSession = null;
      return { valid: false, error: 'O PIN expirou. Gere um novo no terminal do servidor.' };
    }

    if (this.currentSession.pin !== pin.trim()) {
      return { valid: false, error: 'PIN incorreto.' };
    }

    const authorizedToken = this.currentSession.token;
    this.authenticatedTokens.add(authorizedToken);
    this.saveTokens();
    this.currentSession.isUsed = true;

    return { valid: true, token: authorizedToken };
  }

  isTokenValid(token: string): boolean {
    if (!token) return false;
    const cleanToken = token.startsWith('Bearer ') ? token.slice(7).trim() : token.trim();
    return this.authenticatedTokens.has(cleanToken);
  }

  registerPreauthorizedToken(token: string) {
    this.authenticatedTokens.add(token);
  }
}
