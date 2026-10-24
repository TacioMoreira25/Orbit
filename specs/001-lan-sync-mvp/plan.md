# Implementation Plan: Direct LAN File Streaming & Smart Clipboard Sync (Orbit MVP)

**Branch**: `001-lan-sync-mvp` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/001-lan-sync-mvp/spec.md`

## Summary

High-performance, zero-cloud peer-to-peer sync engine between Android and Linux on local Wi-Fi. Features ephemeral QR/PIN handshake, continuous Zero-Memory multipart file streaming directly to disk with SHA-256 validation, real-time WebSocket telemetry, smart lexical clipboard syncing, and Android Share Intent integration.

## Technical Context

**Language/Version**:
- Backend: Node.js 20+ / TypeScript 5.5 (ESM)
- Mobile: Dart 3.13+ / Flutter 3.47+

**Primary Dependencies**:
- Backend: `fastify` v4, `@fastify/multipart`, `@fastify/websocket`, `zod`, `bonjour-service`, `qrcode-terminal`
- Mobile: `flutter_riverpod`, `dio`, `mobile_scanner`, `receive_sharing_intent`, `shared_preferences`, `web_socket_channel`

**Storage**:
- Linux: Direct file stream writes to `~/Downloads`, persistent token registry at `~/.orbit_tokens.json`
- Mobile: `SharedPreferences` for device metadata and auth tokens

**Target Platform**:
- Linux Daemon (X11 / Wayland)
- Android App (API 24+)

**Architecture**:
- Backend: Clean Architecture (`core/`, `application/use-cases/`, `infrastructure/`)
- Mobile: MVVM (`models/`, `services/`, `viewmodels/`, `views/`, `widgets/`)

## Constitution Check

- [x] **Layer Separation**: Routes delegate to Use Cases; Views observe ViewModels.
- [x] **Result Pattern**: Business logic returns typed results, no unhandled throws for expected errors.
- [x] **Strict Typing**: Zod contracts on server endpoints; typed immutable models in Flutter.
- [x] **Zero-Trust Handshake**: Bearer token validation required for upload and clipboard.
- [x] **Zero-Memory Streaming**: Chunks written directly to disk via stream pipes; SHA-256 calculated on the fly.

## Project Structure & Architecture

```text
orbit/
├── .specify/                         # GitHub Spec Kit configuration & memory
│   ├── memory/constitution.md        # Project constitution
│   ├── scripts/bash/                 # Spec Kit automation scripts
│   └── templates/                    # Spec Kit artifact templates
├── specs/
│   └── 001-lan-sync-mvp/
│       ├── spec.md                   # Feature specification with prioritized stories
│       ├── plan.md                   # Implementation plan
│       └── tasks.md                  # Granular implementation tasks
├── server/
│   └── src/
│       ├── core/                     # Entities & Domain Interfaces
│       ├── application/              # Use Cases & DTOs
│       └── infrastructure/           # HTTP, WebSocket, System, Security & Storage
└── mobile/
    └── lib/
        ├── models/                   # Data Models
        ├── services/                 # Infrastructure adapters (HTTP, WS, Clipboard)
        ├── viewmodels/               # Riverpod StateNotifiers
        ├── views/                    # Screens (Pairing, Home, Transfer)
        └── widgets/                  # Reusable UI components
```
