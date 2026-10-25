import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import assert from 'node:assert';

import { buildServer } from '../src/infrastructure/http/server.js';
import { LocalDiskStorage } from '../src/infrastructure/storage/LocalDiskStorage.js';
import { Sha256StreamValidator } from '../src/infrastructure/security/Sha256StreamValidator.js';
import { PinPairingManager } from '../src/infrastructure/security/PinPairingManager.js';
import { TransferWebSocketServer } from '../src/infrastructure/websocket/TransferWebSocketServer.js';
import { LinuxClipboardService } from '../src/infrastructure/system/LinuxClipboardService.js';
import { LinuxNotifier } from '../src/infrastructure/system/LinuxNotifier.js';
import { SmartClipboardClassifier } from '../src/infrastructure/ai/SmartClipboardClassifier.js';
import { ProcessFileUploadUseCase } from '../src/application/use-cases/ProcessFileUploadUseCase.js';
import { SyncClipboardUseCase } from '../src/application/use-cases/SyncClipboardUseCase.js';
import { AuthenticateDeviceUseCase } from '../src/application/use-cases/AuthenticateDeviceUseCase.js';
import { GetServerStatusUseCase } from '../src/application/use-cases/GetServerStatusUseCase.js';

const ONE_GIGABYTE = 1024 * 1024 * 1024; // 1.073.741.824 bytes
const CHUNK_SIZE = 64 * 1024; // 64 KB por chunk

async function runBenchmark() {
  console.log('\n============================================================');
  console.log('   🚀 ORBIT - BENCHMARK DE STREAMING 1 GB & MEMÓRIA RAM');
  console.log('============================================================\n');

  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'orbit-bench-1gb-'));
  const tokensPath = path.join(tempDir, 'tokens.json');

  const storageService = new LocalDiskStorage(tempDir);
  const cryptoService = new Sha256StreamValidator();
  const pairingManager = new PinPairingManager(cryptoService, 300, tokensPath);
  const clipboardService = new LinuxClipboardService();
  const notificationService = new LinuxNotifier();
  notificationService.notify = async () => {}; // Silencia notificações desktop durante o benchmark

  const classifier = new SmartClipboardClassifier();
  const wsServer = new TransferWebSocketServer();

  const processUploadUseCase = new ProcessFileUploadUseCase(storageService, wsServer, notificationService);
  const syncClipboardUseCase = new SyncClipboardUseCase(clipboardService, classifier, notificationService, wsServer);
  const authenticateDeviceUseCase = new AuthenticateDeviceUseCase(pairingManager, 'Orbit-Benchmark');
  const getServerStatusUseCase = new GetServerStatusUseCase({
    getActiveConnectionsCount: () => wsServer.getActiveConnectionsCount(),
    getDownloadDirectory: () => storageService.getDestinationDirectory(),
    getServerName: () => 'Orbit-Benchmark',
  });

  const app = buildServer({
    processUploadUseCase,
    syncClipboardUseCase,
    authenticateDeviceUseCase,
    getServerStatusUseCase,
    wsServer,
    pairingManager,
  });

  const token = 'bench-valid-token-1gb';
  pairingManager.registerPreauthorizedToken(token);

  await app.listen({ port: 0, host: '127.0.0.1' });
  const address = app.server.address();
  const port = typeof address === 'object' && address ? address.port : 0;

  // Pré-calcula o SHA-256 de 1 GB de bytes determinísticos (64KB de 'A')
  const staticChunk = Buffer.alloc(CHUNK_SIZE, 0x41);
  const expectedHash = crypto.createHash('sha256');
  const totalChunks = ONE_GIGABYTE / CHUNK_SIZE;
  for (let i = 0; i < totalChunks; i++) {
    expectedHash.update(staticChunk);
  }
  const expectedSha256 = expectedHash.digest('hex');

  if (global.gc) global.gc();
  const baselineMem = process.memoryUsage();
  let peakHeapUsed = baselineMem.heapUsed;
  let peakRss = baselineMem.rss;
  let samplesCount = 0;

  const sampler = setInterval(() => {
    const mem = process.memoryUsage();
    samplesCount++;
    if (mem.heapUsed > peakHeapUsed) peakHeapUsed = mem.heapUsed;
    if (mem.rss > peakRss) peakRss = mem.rss;
  }, 100);

  const boundary = '----OrbitBenchmarkBoundary1GB';
  const headerPart = Buffer.from(
    [
      `--${boundary}`,
      'Content-Disposition: form-data; name="file"; filename="payload-1gb.bin"',
      'Content-Type: application/octet-stream',
      '',
      '',
    ].join('\r\n')
  );
  const footerPart = Buffer.from(`\r\n--${boundary}--\r\n`);

  console.log(`📦 Iniciando envio via HTTP Stream de 1.00 GB (${ONE_GIGABYTE.toLocaleString()} bytes)...`);
  const startTime = performance.now();

  try {
    const responseBody: any = await new Promise((resolve, reject) => {
      const req = http.request(
        {
          hostname: '127.0.0.1',
          port,
          path: '/api/upload',
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': `multipart/form-data; boundary=${boundary}`,
            'x-file-hash': expectedSha256,
            'x-file-size': ONE_GIGABYTE.toString(),
            'x-device-id': 'benchmark-client',
          },
        },
        (res) => {
          let data = '';
          res.on('data', (chunk) => (data += chunk));
          res.on('end', () => {
            if (res.statusCode === 201) {
              resolve(JSON.parse(data));
            } else {
              reject(new Error(`Status inesperado ${res.statusCode}: ${data}`));
            }
          });
        }
      );

      req.on('error', reject);
      req.write(headerPart);

      let chunksSent = 0;
      function writeNext() {
        let canContinue = true;
        while (chunksSent < totalChunks && canContinue) {
          chunksSent++;
          canContinue = req.write(staticChunk);
        }
        if (chunksSent < totalChunks) {
          req.once('drain', writeNext);
        } else {
          req.end(footerPart);
        }
      }

      writeNext();
    });

    clearInterval(sampler);
    const durationSec = (performance.now() - startTime) / 1000;
    const throughputMbps = 1024 / durationSec;
    const heapDeltaMb = Math.max(0, (peakHeapUsed - baselineMem.heapUsed) / (1024 * 1024));
    const rssDeltaMb = Math.max(0, (peakRss - baselineMem.rss) / (1024 * 1024));

    assert.strictEqual(responseBody.bytesWritten, ONE_GIGABYTE);
    assert.strictEqual(responseBody.calculatedSha256, expectedSha256);
    assert.strictEqual(responseBody.isHashValid, true);

    console.log('\n✅ TRANSFERÊNCIA DE 1 GB CONCLUÍDA E VALIDADA COM SUCESSO!\n');
    console.table({
      'Tamanho do Arquivo': '1.00 GB (1,073,741,824 bytes)',
      'Tempo Total': `${durationSec.toFixed(2)} s`,
      'Throughput Médio': `${throughputMbps.toFixed(1)} MB/s`,
      'Amostras (100ms)': samplesCount,
      'Heap Inicial': `${(baselineMem.heapUsed / 1024 / 1024).toFixed(2)} MB`,
      'Pico de Heap': `${(peakHeapUsed / 1024 / 1024).toFixed(2)} MB`,
      'Delta de Buffer (RAM)': `${heapDeltaMb.toFixed(2)} MB (< 50 MB ✅)`,
      'Delta RSS': `${rssDeltaMb.toFixed(2)} MB`,
      'SHA-256 Verificado': `${expectedSha256.slice(0, 16)}... (100% Íntegro)`,
    });

    assert.ok(heapDeltaMb < 50, `O delta de Heap (${heapDeltaMb.toFixed(2)} MB) excedeu o limite de 50 MB!`);
  } finally {
    clearInterval(sampler);
    await app.close();
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
  }
}

runBenchmark().catch((err) => {
  console.error('❌ Falha no benchmark:', err);
  process.exit(1);
});
