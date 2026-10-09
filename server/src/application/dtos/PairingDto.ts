import { DevicePlatform } from '../../core/entities/Device.js';

export interface AuthenticateDeviceInput {
  pin: string;
  deviceName: string;
  platform: DevicePlatform;
  ipAddress: string;
}

export interface AuthenticateDeviceOutput {
  success: boolean;
  token?: string;
  serverDeviceName: string;
  message?: string;
}
