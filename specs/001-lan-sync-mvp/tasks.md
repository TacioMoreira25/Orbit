# Tasks: Direct LAN File Streaming & Smart Clipboard Sync (Orbit MVP)

**Input**: Design documents from `specs/001-lan-sync-mvp/`  
**Prerequisites**: `plan.md`, `spec.md`  

---

## Task Backlog & Execution Status

| ID | Tarefa | Origem | Depende de | Concluída quando | Status |
|---|---|---|---|---|---|
| **T-01** | Criar estrutura do projeto e integrar Spec Kit | Constituição | - | Pastas `server/`, `mobile/` e `.specify/` existem e compilam | [x] Concluído |
| **T-02** | Anúncio mDNS do serviço na rede local | RF-01, US1 | T-01 | Serviço `_orbit._tcp` publicado via `bonjour-service` | [x] Concluído |
| **T-03** | Gerador de PIN efêmero de 4 dígitos e QR Code | RF-02, US1 | T-01 | Terminal renderiza QR Code e PIN válido por 5 min | [x] Concluído |
| **T-04** | Endpoint `POST /api/pair` com validação Zod | RF-03, US1 | T-03 | PIN correto retorna 200 com token; incorreto retorna 401 | [x] Concluído |
| **T-05** | Persistência de tokens autorizados no disco | RF-03, US1 | T-04 | Tokens salvos e lidos de `~/.orbit_tokens.json` | [x] Concluído |
| **T-06** | Middleware `requireAuth` para rotas protegidas | RF-03, US1 | T-05 | Requisições sem Bearer token retornam HTTP 401 | [x] Concluído |
| **T-07** | Streaming contínuo de upload direto para disco | RF-04, US2 | T-06 | `POST /api/upload` grava em `~/Downloads/` sem buffer em RAM | [x] Concluído |
| **T-08** | Validação de checksum SHA-256 no stream | RF-05, US2 | T-07 | Stream calcula hash e descarta arquivo se divergente | [x] Concluído |
| **T-09** | WebSocket Observer para telemetria de progresso | RF-06, US2 | T-07 | Eventos em `/ws` enviam bytes e porcentagem em tempo real | [x] Concluído |
| **T-10** | Smart Clipboard com injeção no Linux | RF-07, US3 | T-06 | `POST /api/clipboard` classifica e injeta no X11/Wayland | [x] Concluído |
| **T-11** | App Flutter base com Riverpod e Dark Theme | Constituição | T-01 | App renderiza tela inicial limpa com tema escuro | [x] Concluído |
| **T-12** | Scanner de QR Code com câmera no celular | RF-02, US1 | T-11 | Câmera decodifica JSON e preenche IP/porta/PIN automaticamente | [x] Concluído |
| **T-13** | Formulário manual de conexão com IP e PIN | RF-03, US1 | T-11 | Campos com atalho para emulador (`10.0.2.2`) e PIN | [x] Concluído |
| **T-14** | Banner explícito de erro para PIN incorreto | RF-10, US1 | T-13 | PIN errado exibe card vermelho e fecha teclado virtual | [x] Concluído |
| **T-15** | Botão padrão de logout/sair com diálogo | Constituição | T-11 | Ícone padrão de porta com diálogo de encerramento do app | [x] Concluído |
| **T-16** | Persistência local e auto-reconexão no Mobile | RF-08, US5 | T-13 | App reabre e restaura sessão ativa via `GET /health` | [x] Concluído |
| **T-17** | Integração com Share Sheet nativo do Android | RF-09, US4 | T-11 | Compartilhar arquivo de outros apps envia para o Orbit | [x] Concluído |
| **T-18** | Barra de progresso visual e botão de tentar novamente | RF-04, US2 | T-17 | Card exibe barra fluida e botão Retry em falha | [x] Concluído |
| **T-19** | Result Pattern canônico no core do Backend e Mobile | Constituição | T-04 | Use Cases e ViewModels usam tipo Result sem throws | [x] Concluído |
| **T-20** | Testes automatizados de integração do Backend | Constituição | T-04, T-07 | Testes cobrem `/health`, `/api/pair` e stream de upload | [ ] Pendente |
| **T-21** | Testes unitários com `flutter_test` para ViewModels | Constituição | T-14, T-16 | Testes cobrem `PairingViewModel` e `HomeViewModel` | [ ] Pendente |
