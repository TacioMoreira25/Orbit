# Orbit Constitution

## Core Principles

### I. Layer Separation (Clean Architecture & MVVM)
- Fastify routes and controllers MUST NOT contain business rules, direct storage access, or validation logic. They delegate to Use Cases and return typed Results.
- Flutter Views MUST NOT perform HTTP/WebSocket network calls, direct persistence, or state orchestration. Views only observe ViewModels and dispatch user actions.

### II. Result Pattern Over Exceptions
- Expected business scenarios (e.g., invalid/expired PIN, file oversized, device offline) MUST return a typed `Result<T, E>`.
- Throwing exceptions (`throw`) for anticipated domain logic is forbidden. Native external exceptions (e.g., `DioException`, filesystem errors) must be caught and mapped to `Failure` at the infrastructure boundary.

### III. Strict Typing & Schema Validation
- Payloads on the Fastify backend MUST be strictly validated using Zod schemas before reaching Use Cases. Usage of `any` in TypeScript is prohibited.
- Flutter models MUST be immutable. Leaking untyped `Map<String, dynamic>` beyond serialization adapters is prohibited.

### IV. Local Zero-Trust Handshake
- Transfer endpoints (`POST /api/upload`) and clipboard endpoints (`POST /api/clipboard`) require an authorized session Bearer token issued during ephemeral PIN/QR pairing.
- The server MUST NOT stream chunks to disk from unauthenticated clients. Corrupted or aborted streams must be purged immediately.

### V. Zero-Memory Streaming
- File transfer operations MUST use continuous streams (`@fastify/multipart` streaming to disk, progressive chunk reading in Flutter).
- Loading entire files or large chunks into RAM buffer is strictly forbidden. Checksum (SHA-256) computation must be calculated on-the-fly through stream pipes.

## Technology & Platform Standards

- **Backend**: Node.js 20+, Fastify v4, TypeScript (ESM), Zod, bonjour-service, WebSocket.
- **Mobile**: Flutter 3.47+, Riverpod (MVVM), Dio, mobile_scanner, receive_sharing_intent, shared_preferences.
- **Target Platforms**: Android (Mobile) and Linux X11/Wayland (Daemon).

## Governance

- All pull requests, code refactors, and AI-driven tasks must comply with these principles.
- Features are defined under `specs/` following GitHub Spec Kit conventions (`spec.md`, `plan.md`, `tasks.md`).

**Version**: 1.0.0 | **Ratified**: 2026-10-12 | **Last Amended**: 2026-10-23
