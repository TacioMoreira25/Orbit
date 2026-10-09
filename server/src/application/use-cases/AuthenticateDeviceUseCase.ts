import { AuthenticateDeviceInput, AuthenticateDeviceOutput } from '../dtos/PairingDto.js';

export interface IPairingManager {
  verifyPin(pin: string): { valid: boolean; token?: string; error?: string };
}

export class AuthenticateDeviceUseCase {
  constructor(
    private readonly pairingManager: IPairingManager,
    private readonly serverDeviceName: string
  ) {}

  async execute(input: AuthenticateDeviceInput): Promise<AuthenticateDeviceOutput> {
    const result = this.pairingManager.verifyPin(input.pin);

    if (!result.valid || !result.token) {
      return {
        success: false,
        serverDeviceName: this.serverDeviceName,
        message: result.error || 'PIN de pareamento inválido ou expirado.',
      };
    }

    return {
      success: true,
      token: result.token,
      serverDeviceName: this.serverDeviceName,
      message: 'Dispositivo pareado com sucesso!',
    };
  }
}
