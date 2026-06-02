<script lang="ts">
  import { onMount } from 'svelte';

  interface Service {
    name: string;
    state: string;
    status: string;
    image: string;
  }

  let services: Service[] = [];
  let loading = false;
  let logOutput = '';
  let selectedService = '';
  let actionLog: string[] = [];

  onMount(() => loadServices());

  async function loadServices() {
    loading = true;
    // Ini akan di-proxy ke API yang jalankan podman-compose ps
    // Untuk sekarang mock data
    services = [
      { name: 'ai-router',       state: 'running', status: 'Up 2h',  image: 'ai-router:latest' },
      { name: 'qwen-local',      state: 'running', status: 'Up 2h',  image: 'qwen-local:latest' },
      { name: 'storage-manager', state: 'running', status: 'Up 2h',  image: 'storage-manager:latest' },
      { name: 'web-interface',   state: 'running', status: 'Up 2h',  image: 'web-interface:latest' },
      { name: 'monitoring',      state: 'running', status: 'Up 2h',  image: 'monitoring:latest' },
      { name: 'nginx-proxy',     state: 'running', status: 'Up 2h',  image: 'nginx:alpine' },
    ];
    loading = false;
  }

  async function serviceAction(name: string, action: 'restart' | 'stop' | 'start' | 'logs') {
    if (action !== 'logs' && !confirm(`${action} service ${name}?`)) return;

    actionLog = [...actionLog, `[${new Date().toLocaleTimeString()}] ${action} ${name}...`];
    selectedService = name;

    // TODO: Implementasi via API endpoint yang jalankan podman-compose commands
    // Untuk sekarang, tampilkan instruksi
    if (action === 'logs') {
      logOutput = `# Untuk melihat log ${name}:\npodman-compose -f /root/myserver/core/docker-compose.yml logs -f ${name}\n\n# Log files:\n/opt/myserver/logs/${name}/`;
    } else {
      logOutput = `# Command yang dijalankan:\npodman-compose -f /root/myserver/core/docker-compose.yml ${action} ${name}`;
      actionLog = [...actionLog, `[${new Date().toLocaleTimeString()}] ✓ ${action} ${name} selesai`];
    }
  }

  const stateColor = (state: string) => {
    if (state === 'running') return 'var(--accent-success)';
    if (state === 'exited') return 'var(--accent-danger)';
    return 'var(--accent-warning)';
  };
</script>

<svelte:head>
  <title>Deploy — MyServer</title>
</svelte:head>

<div class="deploy-page animate-slide-up">
  <div class="page-header" style="margin-bottom:1.5rem;">
    <div>
      <h1>Service Manager</h1>
      <p style="color:var(--text-secondary);margin-top:4px;">Podman Compose — Kelola semua Docker service</p>
    </div>
    <button class="btn btn-primary" on:click={loadServices}>↻ Refresh</button>
  </div>

  <div class="deploy-grid">
    <!-- Service List -->
    <div class="card" style="padding:0;overflow:hidden;">
      <div style="padding:1rem 1.5rem;border-bottom:1px solid var(--border-subtle);">
        <h3>Services</h3>
      </div>
      {#if loading}
        <div style="padding:2rem;text-align:center;color:var(--text-muted);">Loading...</div>
      {:else}
        {#each services as svc}
          <div class="service-row" class:selected={selectedService === svc.name}>
            <div class="svc-info">
              <div style="display:flex;align-items:center;gap:8px;">
                <div class="status-dot" style="background:{stateColor(svc.state)};box-shadow:0 0 6px {stateColor(svc.state)};"></div>
                <span class="svc-name">{svc.name}</span>
              </div>
              <div class="svc-meta">
                <span class="mono" style="font-size:0.75rem;color:var(--text-muted);">{svc.image}</span>
                <span style="font-size:0.75rem;color:var(--text-secondary);">{svc.status}</span>
              </div>
            </div>
            <div class="svc-actions">
              <button class="btn btn-ghost" style="padding:4px 8px;font-size:0.75rem;"
                on:click={() => serviceAction(svc.name, 'logs')}>📋 Log</button>
              <button class="btn btn-ghost" style="padding:4px 8px;font-size:0.75rem;"
                on:click={() => serviceAction(svc.name, 'restart')}>↻</button>
              {#if svc.state === 'running'}
                <button class="btn btn-danger" style="padding:4px 8px;font-size:0.75rem;"
                  on:click={() => serviceAction(svc.name, 'stop')}>■</button>
              {:else}
                <button class="btn btn-primary" style="padding:4px 8px;font-size:0.75rem;"
                  on:click={() => serviceAction(svc.name, 'start')}>▶</button>
              {/if}
            </div>
          </div>
        {/each}
      {/if}
    </div>

    <!-- Log / Output -->
    <div class="card" style="padding:0;overflow:hidden;display:flex;flex-direction:column;">
      <div style="padding:1rem 1.5rem;border-bottom:1px solid var(--border-subtle);display:flex;justify-content:space-between;align-items:center;">
        <h3>Output {selectedService ? `— ${selectedService}` : ''}</h3>
        <button class="btn btn-ghost" style="padding:4px 10px;font-size:0.75rem;" on:click={() => logOutput = ''}>Clear</button>
      </div>
      <pre class="log-output">{logOutput || '# Pilih service dan klik Log untuk melihat output\n# Atau klik action untuk menjalankan perintah'}</pre>
      {#if actionLog.length > 0}
        <div style="padding:0.75rem 1rem;border-top:1px solid var(--border-subtle);">
          {#each actionLog.slice(-5) as entry}
            <div class="mono" style="font-size:0.75rem;color:var(--text-muted);">{entry}</div>
          {/each}
        </div>
      {/if}
    </div>
  </div>

  <!-- Resource Summary -->
  <div class="card" style="margin-top:1.5rem;">
    <h3 style="margin-bottom:1rem;">Resource Limits per Service</h3>
    <div class="resource-table">
      <div class="rt-header">
        <span>Service</span><span>RAM Limit</span><span>CPU</span><span>Fungsi</span>
      </div>
      <div class="rt-row"><span>ai-router</span><span>256 MB</span><span>0.5 core</span><span>TinyLLM Router — 12+ providers</span></div>
      <div class="rt-row"><span>qwen-local</span><span>2 GB</span><span>2.0 core</span><span>Qwen2.5-1.5B lokal — file sensitif</span></div>
      <div class="rt-row"><span>storage-manager</span><span>128 MB</span><span>0.5 core</span><span>Multi-cloud storage + rclone</span></div>
      <div class="rt-row"><span>web-interface</span><span>128 MB</span><span>0.3 core</span><span>Svelte dashboard</span></div>
      <div class="rt-row"><span>monitoring</span><span>128 MB</span><span>0.2 core</span><span>Metrics collector</span></div>
      <div class="rt-row"><span>nginx-proxy</span><span>64 MB</span><span>0.2 core</span><span>Reverse proxy</span></div>
      <div class="rt-row rt-total"><span><strong>Total</strong></span><span><strong>~2.7 GB</strong></span><span><strong>~3.7 core</strong></span><span style="color:var(--accent-success);">Aman untuk 8GB RAM</span></div>
    </div>
  </div>
</div>

<style>
  .deploy-page { max-width: 1400px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; }

  .deploy-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.5rem;
    min-height: 400px;
  }
  @media (max-width: 1024px) { .deploy-grid { grid-template-columns: 1fr; } }

  .service-row {
    display: flex; justify-content: space-between; align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-subtle);
    transition: background var(--transition);
    cursor: pointer;
  }
  .service-row:hover { background: var(--bg-elevated); }
  .service-row.selected { background: rgba(0,212,255,0.05); border-left: 2px solid var(--accent-primary); }
  .service-row:last-child { border-bottom: none; }

  .svc-info { display: flex; flex-direction: column; gap: 4px; }
  .svc-name { font-size: 0.9rem; font-weight: 600; }
  .svc-meta { display: flex; gap: 12px; align-items: center; }
  .svc-actions { display: flex; gap: 6px; align-items: center; }

  .log-output {
    flex: 1;
    padding: 1rem 1.5rem;
    font-family: var(--font-mono);
    font-size: 0.8rem;
    line-height: 1.6;
    color: var(--accent-success);
    background: var(--bg-base);
    overflow: auto;
    white-space: pre-wrap;
    min-height: 200px;
  }

  .resource-table { display: flex; flex-direction: column; }
  .rt-header, .rt-row {
    display: grid; grid-template-columns: 180px 100px 100px 1fr;
    padding: 8px 12px; gap: 16px; align-items: center;
  }
  .rt-header {
    font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase;
    letter-spacing: 0.05em; border-bottom: 1px solid var(--border-subtle);
    margin-bottom: 4px;
  }
  .rt-row { font-size: 0.875rem; border-radius: var(--radius-sm); }
  .rt-row:hover { background: var(--bg-elevated); }
  .rt-total {
    margin-top: 8px; border-top: 1px solid var(--border-subtle);
    padding-top: 12px;
  }
</style>
