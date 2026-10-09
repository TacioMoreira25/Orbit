export interface PairingSession {
  pin: string;
  token: string;
  createdAt: Date;
  expiresAt: Date;
  isUsed: boolean;
  pairedDeviceId?: string;
}
