# 🪐 Orbit

> **Transferência direta de arquivos e sincronização em tempo real entre Celular e Linux via Wi-Fi local, sem nuvem e sem cabos.**

![TypeScript](https://img.shields.io/badge/TypeScript-007ACC?style=for-the-badge&logo=typescript&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Fastify](https://img.shields.io/badge/Fastify-000000?style=for-the-badge&logo=fastify&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)

---

## Destaques Técnicos & Decisões Arquiteturais

- **Zero-Memory Streaming:** Uploads de arquivos de múltiplos gigabytes via `@fastify/multipart` com pipeline de Streams contínuo direto para o disco rígido, mantendo o consumo de memória do servidor abaixo de 50MB.
- **Validação Criptográfica de Integridade (SHA-256):** O hash SHA-256 do arquivo é calculado de forma concorrente em tempo de streaming (`crypto.createHash`) e comparado com o hash calculado na origem antes de confirmar o salvamento.
- **Sincronização Duplex em Tempo Real (WebSockets):** Notificação instantânea de progresso chunk-a-chunk com base no padrão **Observer**, refletindo a porcentagem transferida no celular.
- **Pareamento Seguro Local (Zero-Trust):** Handshake inicial via **PIN efêmero de 4 dígitos** exibido via **QR Code no terminal**, prevenindo acessos não autorizados na mesma rede Wi-Fi.
- **Smart Clipboard com IA:** Classificação automática do texto copiado (código fonte, URLs, markdown ou texto plano) e integração com a área de transferência do Linux (suporte nativo Wayland e X11).
- **Descoberta na Rede Local:** Broadcast via mDNS (`orbit.local`) dispensando a necessidade de descobrir manualmente o IP do PC.

---

## Estrutura do Projeto

```text
Orbit/
├── server/                         # Daemon / API Linux (Clean Architecture)
│   ├── src/
│   │   ├── core/                   # Entidades de Domínio e Contratos
│   │   ├── application/            # Casos de Uso (Upload, Clipboard, Auth)
│   │   └── infrastructure/         # Fastify, WebSocket, Streams, Criptografia, Linux IO
│   └── main.ts                     # Ponto de entrada (QR Code, mDNS, Fastify)
│
├── mobile/                         # App Mobile Flutter (MVVM + Riverpod)
│   └── lib/
│       ├── models/                 # Modelos de Dados
│       ├── services/               # Clientes HTTP, WebSocket e Criptografia
│       ├── viewmodels/             # StateNotifier / Riverpod
│       └── views/                  # Telas Minimalistas (Home, Transfer, Pairing)
│
└── systemd/                        # Configuração do Daemon para Linux
```

---

## Como Rodar o Servidor (Linux)

### Pré-requisitos
- Node.js (v18+)
- Ferramenta de clipboard: `wl-clipboard` (Wayland) ou `xclip` (X11)
- `libnotify-bin` para notificações de desktop

### Execução

```bash
cd server
npm install
npm run dev
```

Ao iniciar, o terminal exibirá o endereço IP local, o PIN efêmero de pareamento e o QR Code para leitura no celular.

---

## 📱 Como Rodar o App (Flutter)

```bash
cd mobile
flutter pub get
flutter run
```
