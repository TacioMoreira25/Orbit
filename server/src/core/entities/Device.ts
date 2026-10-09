export type DevicePlatform = 'android' | 'linux' | 'ios' | 'windows' | 'macos';

export interface Device {
  id: string;
  name: string;
  ipAddress: string;
  platform: DevicePlatform;
  pairedAt?: Date;
  lastSeen: Date;
}
