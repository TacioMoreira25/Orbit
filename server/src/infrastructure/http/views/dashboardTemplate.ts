export interface DashboardViewProps {
  status: {
    serverName: string;
    activeConnections: number;
    downloadDirectory: string;
  };
  localIp: string;
}

export function renderDashboardHtml({ status, localIp }: DashboardViewProps): string {
  return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Orbit — Linux Dashboard</title>
  <style>
    :root {
      --bg: #0f1115;
      --card: #181b22;
      --border: rgba(0, 229, 255, 0.22);
      --cyan: #00e5ff;
      --text: #f3f4f6;
      --muted: #9ca3af;
      --green: #10b981;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }
    body { background: var(--bg); color: var(--text); min-height: 100vh; padding: 32px 20px; }
    .container { max-width: 860px; margin: 0 auto; }
    header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 28px; }
    .brand { display: flex; align-items: center; gap: 12px; }
    .logo-badge {
      width: 42px; height: 42px; border-radius: 12px;
      background: linear-gradient(135deg, #00e5ff22, #0e1f4a);
      border: 1.5px solid var(--cyan);
      display: flex; align-items: center; justify-content: center;
      font-weight: 800; color: var(--cyan); font-size: 18px;
      box-shadow: 0 0 16px rgba(0, 229, 255, 0.25);
    }
    h1 { font-size: 24px; letter-spacing: 0.5px; }
    .status-pill {
      display: inline-flex; align-items: center; gap: 8px;
      padding: 6px 14px; border-radius: 999px;
      background: rgba(16, 185, 129, 0.12); border: 1px solid rgba(16, 185, 129, 0.4);
      color: var(--green); font-size: 13px; font-weight: 600;
    }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 16px; margin-bottom: 24px; }
    .stat-card {
      background: var(--card); border: 1px solid rgba(255,255,255,0.07);
      border-radius: 16px; padding: 18px;
    }
    .stat-label { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.6px; }
    .stat-value { font-size: 18px; font-weight: 700; margin-top: 6px; color: var(--cyan); word-break: break-all; }
    .panel {
      background: var(--card); border: 1px solid var(--border);
      border-radius: 20px; padding: 24px; margin-bottom: 24px;
    }
    .panel h2 { font-size: 18px; margin-bottom: 6px; }
    .panel p { color: var(--muted); font-size: 14px; margin-bottom: 18px; }
    .dropzone {
      border: 2px dashed rgba(0, 229, 255, 0.4); border-radius: 16px;
      padding: 36px 20px; text-align: center; cursor: pointer;
      transition: all 0.2s ease; background: rgba(0, 229, 255, 0.03);
    }
    .dropzone:hover, .dropzone.dragover {
      background: rgba(0, 229, 255, 0.09); border-color: var(--cyan);
    }
    .btn {
      background: var(--cyan); color: #000; border: none; border-radius: 10px;
      padding: 10px 18px; font-weight: 700; cursor: pointer; font-size: 14px;
    }
    .btn:hover { opacity: 0.9; }
    textarea {
      width: 100%; min-height: 80px; background: #111318; color: var(--text);
      border: 1px solid rgba(255,255,255,0.12); border-radius: 12px; padding: 12px;
      margin-bottom: 12px; resize: vertical;
    }
    .progress-box { margin-top: 16px; display: none; }
    .bar-bg { width: 100%; height: 8px; background: #262932; border-radius: 4px; overflow: hidden; margin-top: 6px; }
    .bar-fill { height: 100%; width: 0%; background: var(--cyan); transition: width 0.1s; }
    .file-list { list-style: none; display: flex; flex-direction: column; gap: 10px; }
    .file-item {
      display: flex; align-items: center; justify-content: space-between;
      background: #12141a; padding: 12px 16px; border-radius: 12px;
      border: 1px solid rgba(255,255,255,0.06);
    }
    .file-item a { color: var(--cyan); text-decoration: none; font-weight: 600; font-size: 13px; }
  </style>
</head>
<body>
  <div class="container">
    <header>
      <div class="brand">
        <div class="logo-badge">O</div>
        <div>
          <h1>Orbit Linux Dashboard</h1>
          <span style="color: var(--muted); font-size: 13px;">Transferência Bidirecional LAN & Smart Clipboard</span>
        </div>
      </div>
      <div class="status-pill">● Servidor Ativo (<span id="connCount">${status.activeConnections}</span> dispositivo(s))</div>
    </header>

    <div class="grid">
      <div class="stat-card">
        <div class="stat-label">Endereço na Rede Local</div>
        <div class="stat-value">http://${localIp}:3000</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Servidor Linux</div>
        <div class="stat-value">${status.serverName}</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">Pasta de Destino</div>
        <div class="stat-value" style="font-size: 14px;">${status.downloadDirectory}</div>
      </div>
    </div>

    <div class="panel">
      <h2>Enviar Arquivo do Linux para o Celular</h2>
      <p>Arraste e solte qualquer arquivo abaixo para enviá-lo instantaneamente ao seu Android conectado.</p>
      <div class="dropzone" id="dropzone" onclick="document.getElementById('fileInput').click()">
        <input type="file" id="fileInput" style="display:none" onchange="handleFiles(this.files)" />
        <div style="font-weight: 600; margin-bottom: 4px;">Arraste um arquivo aqui ou clique para selecionar</div>
        <div style="font-size: 12px; color: var(--muted);">Streaming direto com validação SHA-256</div>
      </div>
      <div class="progress-box" id="progressBox">
        <div style="display:flex; justify-content:space-between; font-size:13px;">
          <span id="progressLabel">Enviando...</span>
          <span id="progressPct">0%</span>
        </div>
        <div class="bar-bg"><div class="bar-fill" id="progressBar"></div></div>
      </div>
    </div>

    <div class="panel">
      <h2>Enviar Texto / Link para o Clipboard do Celular</h2>
      <p>Cole um texto, código ou URL para copiar automaticamente na área de transferência do celular.</p>
      <textarea id="clipInput" placeholder="Digite ou cole aqui..."></textarea>
      <button class="btn" onclick="sendClipboard()">Sincronizar Clipboard</button>
      <span id="clipStatus" style="margin-left:12px; font-size:13px; color:var(--green);"></span>
    </div>

    <div class="panel">
      <h2>Arquivos Compartilhados na Sessão</h2>
      <p>Arquivos prontos para download direto via HTTP Range Stream.</p>
      <ul class="file-list" id="fileList">
        <li style="color: var(--muted); font-size: 13px;">Nenhum arquivo compartilhado ainda nesta sessão.</li>
      </ul>
    </div>
  </div>

  <script>
    const dz = document.getElementById('dropzone');
    dz.addEventListener('dragover', (e) => { e.preventDefault(); dz.classList.add('dragover'); });
    dz.addEventListener('dragleave', () => dz.classList.remove('dragover'));
    dz.addEventListener('drop', (e) => {
      e.preventDefault();
      dz.classList.remove('dragover');
      if (e.dataTransfer.files.length) handleFiles(e.dataTransfer.files);
    });

    function handleFiles(files) {
      const file = files[0];
      if (!file) return;
      const formData = new FormData();
      formData.append('file', file);

      const box = document.getElementById('progressBox');
      const bar = document.getElementById('progressBar');
      const label = document.getElementById('progressLabel');
      const pct = document.getElementById('progressPct');
      box.style.display = 'block';
      label.textContent = 'Enviando ' + file.name + '...';

      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/api/share-to-mobile', true);
      xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
          const p = Math.round((e.loaded / e.total) * 100);
          bar.style.width = p + '%';
          pct.textContent = p + '%';
        }
      };
      xhr.onload = () => {
        if (xhr.status === 201) {
          label.textContent = 'Enviado e anunciado para o celular: ' + file.name;
          loadSharedFiles();
        } else {
          label.textContent = 'Erro ao enviar arquivo.';
        }
      };
      xhr.send(formData);
    }

    async function sendClipboard() {
      const content = document.getElementById('clipInput').value;
      if (!content.trim()) return;
      const res = await fetch('/api/local/clipboard', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content })
      });
      if (res.ok) {
        document.getElementById('clipStatus').textContent = 'Enviado para os dispositivos conectados.';
        document.getElementById('clipInput').value = '';
        setTimeout(() => document.getElementById('clipStatus').textContent = '', 3000);
      }
    }

    async function loadSharedFiles() {
      const res = await fetch('/api/files');
      if (!res.ok) return;
      const data = await res.json();
      const ul = document.getElementById('fileList');
      if (!data.files || data.files.length === 0) return;
      ul.innerHTML = data.files.map(f => \`
        <li class="file-item">
          <div>
            <strong>\${f.filename}</strong>
            <div style="font-size:11px; color:var(--muted);">\${(f.sizeBytes / 1024 / 1024).toFixed(2)} MB • SHA-256: \${f.sha256.slice(0, 12)}...</div>
          </div>
          <a href="/api/download/\${f.fileId}" download>Baixar</a>
        </li>
      \`).join('');
    }
    async function refreshStatus() {
      try {
        const res = await fetch('/status');
        if (!res.ok) return;
        const data = await res.json();
        document.getElementById('connCount').textContent = data.activeConnections;
      } catch (_) {}
    }

    loadSharedFiles();
    setInterval(refreshStatus, 2500);
  </script>
</body>
</html>`;
}
