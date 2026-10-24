# Feature Specification: Direct LAN File Streaming & Smart Clipboard Sync (Orbit MVP)

**Feature Branch**: `001-lan-sync-mvp`  
**Created**: 2026-10-12 | **Last Updated**: 2026-10-23  
**Status**: Implemented / In-Review  
**Input**: Direct high-speed LAN file transfer and clipboard sync between Android and Linux without cloud relays.

---

## User Scenarios & Testing

### User Story 1 - Zero-Trust Handshake & Pairing (Priority: P1)

As an Android user on the same Wi-Fi network as my Linux PC, I want to pair my phone using a 4-digit ephemeral PIN or camera QR Code, so that only authorized devices can exchange data with my computer.

**Why this priority**: Essential security gateway. No transfers or clipboard operations can occur without an authorized session token.

**Independent Test**:
- Can be tested by starting the Linux server (`npm run dev`), scanning the terminal QR Code or typing `10.0.2.2` + PIN on mobile, and asserting that the mobile client obtains a Bearer token and transitions to Connected status.
- Typing an invalid/expired PIN must show an immediate red error banner and keep the device unauthorized.

**Acceptance Scenarios**:
1. **Given** Orbit server running on Linux, **When** user scans terminal QR Code or submits valid 4-digit PIN, **Then** server returns HTTP 200 with Bearer token, persists authorized token in `~/.orbit_tokens.json`, and mobile establishes active session.
2. **Given** Orbit mobile on manual pairing screen, **When** user enters wrong or expired PIN, **Then** server returns HTTP 401 and mobile displays an explicit red error container above the submit button with keyboard closed.

---

### User Story 2 - Zero-Memory File Streaming (Priority: P1)

As an Android user, I want to send files (videos, photos, large documents) directly to my Linux `~/Downloads` folder with live progress feedback, without crashing phone or PC RAM.

**Why this priority**: Core value proposition of Orbit. High throughput local streaming without cloud intermediaries.

**Independent Test**:
- Can be tested by selecting or sharing a file from Android; checking real-time byte progress via WebSocket, verifying the file arrives intact in `~/Downloads`, and confirming SHA-256 integrity.

**Acceptance Scenarios**:
1. **Given** a paired Android device and an active WebSocket connection, **When** user uploads a file via `POST /api/upload`, **Then** server pipes chunks directly to disk (`~/Downloads`), broadcasts percentage updates over WebSocket, and returns HTTP 200 upon completion.
2. **Given** an ongoing file upload, **When** connection breaks or client aborts, **Then** server immediately removes partial/corrupted files from disk.

---

### User Story 3 - Smart Clipboard Synchronization (Priority: P2)

As a user, I want text copied on my phone to be quickly transferred to my Linux desktop clipboard with lexical classification (URL, code, plain text), so that I can seamlessly work across devices.

**Why this priority**: High-frequency convenience tool for productivity.

**Independent Test**:
- Can be tested by sending text from mobile via `POST /api/clipboard` and verifying Linux system clipboard (`wl-paste` or `xclip`) receives the exact string.

**Acceptance Scenarios**:
1. **Given** paired device and copied text on mobile, **When** user triggers clipboard sync, **Then** server classifies text (code snippet, URL, text), copies to Linux clipboard, shows desktop notification, and confirms sync.

---

### User Story 4 - Android Native Share Sheet Integration (Priority: P2)

As an Android user, I want to share media directly from Gallery or any app via the native Android Share menu to Orbit, so that I don't have to manually locate files inside Orbit.

**Why this priority**: Frictionless mobile UX.

**Independent Test**:
- Can be tested by clicking Share on a photo in Google Photos/Gallery, choosing Orbit, and confirming Orbit immediately connects and initiates the upload.

**Acceptance Scenarios**:
1. **Given** external app sharing one or more files, **When** Orbit receives the intent, **Then** if connected it starts uploading immediately; if disconnected, it prompts for connection and queues files.

---

### User Story 5 - Session Persistence & Auto-Reconnection (Priority: P3)

As a user, I want Orbit to remember paired computers, so that opening the app automatically reconnects without requiring QR/PIN re-entry every session.

**Why this priority**: Eliminates repetitive friction for frequent daily usage.

**Independent Test**:
- Close app, reopen app, verify GET /health check runs and device is marked online automatically.

---

## Functional Requirements Matrix

| ID | Requisito Funcional | Regra / Comportamento Esperado | Mapeamento |
|---|---|---|---|
| **RF-01** | Anúncio local mDNS | Publicar serviço `_orbit._tcp` com IP local e porta | US1 |
| **RF-02** | PIN efêmero & QR Code | PIN de 4 dígitos no terminal com QR Code legível, válido por 5 min | US1 |
| **RF-03** | Pareamento Zero-Trust | `POST /api/pair` valida PIN e emite Bearer token com persistência | US1 |
| **RF-04** | Upload por stream contínuo | `POST /api/upload` grava direto em `~/Downloads` sem buffer em RAM | US2 |
| **RF-05** | Checksum SHA-256 | Validar integridade via stream pipe com cabeçalho `x-file-hash` | US2 |
| **RF-06** | Telemetria WebSocket | `GET /ws` envia progresso (`TRANSFER_PROGRESS`, bytes, %) em tempo real | US2 |
| **RF-07** | Smart Clipboard | `POST /api/clipboard` classifica texto e injeta via `wl-copy`/`xclip` | US3 |
| **RF-08** | Auto-reconexão | Mobile persiste token no SharedPreferences e valida via `GET /health` | US5 |
| **RF-09** | Android Share Intent | Receber arquivos do menu Compartilhar nativo do Android | US4 |
| **RF-10** | Feedback de erro explícito | Banner vermelho no mobile para PIN incorreto e fechamento de teclado | US1 |
