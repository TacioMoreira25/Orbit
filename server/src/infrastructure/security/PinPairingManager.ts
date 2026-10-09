import { PairingSession } from '../../core/entities/PairingSession.js';
import { ICryptographyService } from '../../core/interfaces/ICryptographyService.js';
import { IPairingManager } from '../../application/use-cases/AuthenticateDeviceUseCase.js';

export class PinPairingManager implements IPairingManager {
  private currentSession: PairingSession | null = null;
  private readonly authenticatedTokens = new Set<string>();

  constructor(
    private readonly cryptoService: ICryptographyService,
    private readonly expirationSeconds: number = 300
  ) {}

  generateNewSession(): PairingSession {
    const pin = this.cryptoService.generatePin();
    const token = this.cryptoService.generateToken();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + this.expirationSeconds * 1000);

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
    this.currentSession.isUsed = true;

    return { valid: true, token: authorizedToken };
  }

  isTokenValid(token: string): boolean {
    if (!token) return false;
    return this.authenticatedTokens.has(token);
  }

  registerPreauthorizedToken(token: string) {
    this.authenticatedTokens.add(token);
  }
}
