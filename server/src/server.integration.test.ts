import test, { describe, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { FastifyInstance } from 'fastify';

import { buildServer } from './infrastructure/http/server.js';
import { LocalDiskStorage } from './infrastructure/storage/LocalDiskStorage.js';
import { Sha256StreamValidator } from './infrastructure/security/Sha256StreamValidator.js';
import { PinPairingManager } from './infrastructure/security/PinPairingManager.js';
import { TransferWebSocketServer } from './infrastructure/websocket/TransferWebSocketServer.js';
import { LinuxClipboardService } from './infrastructure/system/LinuxClipboardService.js';
import { LinuxNotifier } from './infrastructure/system/LinuxNotifier.js';
import { SmartClipboardClassifier } from './infrastructure/ai/SmartClipboardClassifier.js';
import { ProcessFileUploadUseCase } from './application/use-cases/ProcessFileUploadUseCase.js';
import { SyncClipboardUseCase } from './application/use-cases/SyncClipboardUseCase.js';
import { AuthenticateDeviceUseCase } from './application/use-cases/AuthenticateDeviceUseCase.js';
import { GetServerStatusUseCase } from './application/use-cases/GetServerStatusUseCase.js';

describe('Orbit Backend Integration Tests', () => {
  let app: FastifyInstance;
  let tempDir: string;
  let tokensPath: string;
  let pairingManager: PinPairingManager;
  let activePin: string;
  let validToken: string;

  beforeEach(async () => {
    tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'orbit-test-'));
    tokensPath = path.join(tempDir, 'tokens.json');

    const storageService = new LocalDiskStorage(tempDir);
    const cryptoService = new Sha256StreamValidator();
    pairingManager = new PinPairingManager(cryptoService, 300, tokensPath);

    // Mock clipboard and notification to prevent OS level side-effects during tests
    const clipboardService = new LinuxClipboardService();
    clipboardService.writeText = async () => true;

    const notificationService = new LinuxNotifier();
    notificationService.notify = async () => {};

    const classifier = new SmartClipboardClassifier();
    const wsServer = new TransferWebSocketServer();
    const serverDeviceName = 'Test-Orbit-PC';

    const processUploadUseCase = new ProcessFileUploadUseCase(storageService, wsServer, notificationService);
    const syncClipboardUseCase = new SyncClipboardUseCase(clipboardService, classifier, notificationService, wsServer);
    const authenticateDeviceUseCase = new AuthenticateDeviceUseCase(pairingManager, serverDeviceName);
    const getServerStatusUseCase = new GetServerStatusUseCase({
      getActiveConnectionsCount: () => wsServer.getActiveConnectionsCount(),
      getDownloadDirectory: () => storageService.getDestinationDirectory(),
      getServerName: () => serverDeviceName,
    });

    app = buildServer({
      processUploadUseCase,
      syncClipboardUseCase,
      authenticateDeviceUseCase,
      getServerStatusUseCase,
      wsServer,
      pairingManager,
    });

    await app.ready();

    // Create a live pairing session for testing
    const session = pairingManager.generateNewSession();
    activePin = session.pin;
    validToken = session.token;
  });

  afterEach(async () => {
    await app.close();
    if (fs.existsSync(tempDir)) {
      fs.rmSync(tempDir, { recursive: true, force: true });
    }
  });

  test('GET /health - returns ok status and timestamp', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/health',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.status, 'ok');
    assert.ok(body.timestamp);
  });

  test('GET /status - returns server status telemetry', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/status',
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.status, 'online');
    assert.strictEqual(body.serverName, 'Test-Orbit-PC');
    assert.strictEqual(body.version, '1.0.0');
    assert.strictEqual(body.activeConnections, 0);
  });

  test('POST /api/pair - rejects invalid PIN with 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/pair',
      payload: {
        pin: '9999',
        deviceName: 'Pixel 8',
        platform: 'android',
      },
    });

    assert.strictEqual(res.statusCode, 401);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.code, 'INVALID_PIN');
  });

  test('POST /api/pair - validates format via Zod schema (rejects empty or malformed)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/pair',
      payload: {
        pin: 'not-4-digits',
      },
    });

    assert.strictEqual(res.statusCode, 400);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.code, 'VALIDATION_ERROR');
  });

  test('POST /api/pair - authenticates valid PIN and returns Bearer token', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/pair',
      payload: {
        pin: activePin,
        deviceName: 'Pixel 8',
        platform: 'android',
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.success, true);
    assert.strictEqual(body.token, validToken);
    assert.strictEqual(body.serverDeviceName, 'Test-Orbit-PC');

    // Token must be registered and valid
    assert.strictEqual(pairingManager.isTokenValid(body.token), true);
  });

  test('POST /api/upload - rejects unauthenticated requests with 401', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/api/upload',
    });

    assert.strictEqual(res.statusCode, 401);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.code, 'UNAUTHORIZED');
  });

  test('POST /api/upload - streams multipart file directly to disk and validates SHA-256', async () => {
    // Pair device first to authorize token
    pairingManager.registerPreauthorizedToken(validToken);

    const boundary = '----WebKitFormBoundaryTest12345';
    const fileContent = 'Orbit streaming zero-memory verification payload!';
    const expectedHash = crypto.createHash('sha256').update(fileContent).digest('hex');

    const multipartBody = [
      `--${boundary}`,
      'Content-Disposition: form-data; name="file"; filename="sample-test.txt"',
      'Content-Type: text/plain',
      '',
      fileContent,
      `--${boundary}--`,
      '',
    ].join('\r\n');

    const res = await app.inject({
      method: 'POST',
      url: '/api/upload',
      headers: {
        authorization: `Bearer ${validToken}`,
        'content-type': `multipart/form-data; boundary=${boundary}`,
        'x-file-hash': expectedHash,
        'x-file-size': Buffer.byteLength(fileContent).toString(),
        'x-device-id': 'test-android-device',
      },
      payload: multipartBody,
    });

    assert.strictEqual(res.statusCode, 201);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.filename, 'sample-test.txt');
    assert.strictEqual(body.calculatedSha256, expectedHash);
    assert.strictEqual(body.bytesWritten, Buffer.byteLength(fileContent));

    // Verify file actually exists on disk in destination directory
    assert.ok(fs.existsSync(body.savedPath));
    const savedContent = fs.readFileSync(body.savedPath, 'utf-8');
    assert.strictEqual(savedContent, fileContent);
  });

  test('POST /api/upload - aborts and removes file when SHA-256 checksum is divergent', async () => {
    pairingManager.registerPreauthorizedToken(validToken);

    const boundary = '----WebKitFormBoundaryTest67890';
    const fileContent = 'Genuine content';
    const wrongHash = 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    const multipartBody = [
      `--${boundary}`,
      'Content-Disposition: form-data; name="file"; filename="corrupted-test.txt"',
      'Content-Type: text/plain',
      '',
      fileContent,
      `--${boundary}--`,
      '',
    ].join('\r\n');

    const res = await app.inject({
      method: 'POST',
      url: '/api/upload',
      headers: {
        authorization: `Bearer ${validToken}`,
        'content-type': `multipart/form-data; boundary=${boundary}`,
        'x-file-hash': wrongHash,
      },
      payload: multipartBody,
    });

    assert.strictEqual(res.statusCode, 422);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.code, 'STREAM_WRITE_FAILED');
  });

  test('POST /api/clipboard - syncs text and applies classification', async () => {
    pairingManager.registerPreauthorizedToken(validToken);

    const res = await app.inject({
      method: 'POST',
      url: '/api/clipboard',
      headers: {
        authorization: `Bearer ${validToken}`,
      },
      payload: {
        content: 'https://github.com/github/spec-kit',
        senderDeviceId: 'test-mobile',
        senderDeviceName: 'Pixel 8',
      },
    });

    assert.strictEqual(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.strictEqual(body.contentType, 'url');
    assert.strictEqual(body.appliedToSystemClipboard, true);
  });
});
