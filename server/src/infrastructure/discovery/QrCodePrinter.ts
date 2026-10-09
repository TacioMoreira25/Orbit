import qrcode from 'qrcode-terminal';

export interface PairingPayload {
  ip: string;
  port: number;
  pin: string;
  token: string;
  deviceName: string;
  url: string;
}

export class QrCodePrinter {
  static print(payload: PairingPayload): void {
    const rawJson = JSON.stringify(payload);

    console.log('\n' + '='.repeat(60));
    console.log('   🪐 ORBIT - SERVIDOR LOCAL ATIVO');
    console.log('='.repeat(60));
    console.log(`📡 Endereço IP: http://${payload.ip}:${payload.port}`);
    console.log(`🔐 PIN Efêmero: \x1b[32m\x1b[1m${payload.pin}\x1b[0m (Válido por 5 minutos)`);
    console.log(`💻 Dispositivo: ${payload.deviceName}`);
    console.log('='.repeat(60));
    console.log('📱 Aponte a câmera do App Orbit no celular para o QR Code abaixo:');
    console.log('='.repeat(60) + '\n');

    qrcode.generate(rawJson, { small: true });

    console.log('='.repeat(60) + '\n');
  }
}
