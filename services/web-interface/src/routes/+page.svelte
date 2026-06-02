<script lang="ts">
  import { onMount, onDestroy } from 'svelte';

  // --- Types ---
  interface Metrics {
    timestamp: number;
    cpu: { usage_percent: number; temp_celsius: number };
    memory: { total_kb: number; used_kb: number; usage_percent: number };
    disk: { total_kb: number; used_kb: number; usage_percent: number };
    network: { rx_bytes_per_sec: number; tx_bytes_per_sec: number };
    logs: { total_size_mb: number; max_allowed_mb: number };
  }

  interface ServiceStatus {
    name: string;
    healthy: boolean;
    has_api_key: boolean;
    usage: { requests_today: number; tokens_today: number };
  }

  // --- State ---
  let dt_metrics: Metrics | null = null;
  let dftr_srv: ServiceStatus[] = [];
  let dftr_smpn: any[] = [];
  let smbr_ev: EventSource | null = null;
  let wkt_akhir = '';
  let uptime = 0;

  const fmt_ukrn_byte = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B/s`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB/s`;
    return `${(bytes / 1024 / 1024).toFixed(1)} MB/s`;
  };

  const fmt_ukrn_kb = (kb: number) => {
    if (kb < 1024) return `${kb} KB`;
    if (kb < 1024 * 1024) return `${(kb / 1024).toFixed(1)} MB`;
    return `${(kb / 1024 / 1024).toFixed(1)} GB`;
  };

  const ambl_wrna_sts = (pct: number) => {
    if (pct > 90) return 'var(--accent-danger)';
    if (pct > 70) return 'var(--accent-warning)';
    return 'var(--accent-success)';
  };

  onMount(async () => {
    // Load AI providers status
    try {
      const res = await fetch('/api/ai/providers');
      const data = await res.json();
      dftr_srv = data.providers || [];
    } catch (e) {
      console.error('Failed to load providers', e);
    }

    // Load storage accounts
    try {
      const res = await fetch('/api/storage/accounts');
      const data = await res.json();
      dftr_smpn = data.accounts || [];
    } catch (e) {
      console.error('Failed to load storage', e);
    }

    // Real-time dt_metrics via SSE
    smbr_ev = new EventSource('/api/monitor/stream');
    smbr_ev.onmessage = (e) => {
      dt_metrics = JSON.parse(e.data);
      wkt_akhir = new Date().toLocaleTimeString('id-ID');
    };
    smbr_ev.onerror = () => {
      // Fallback: polling biasa
      mt_metrics();
    };
  });

  async function mt_metrics() {
    try {
      const res = await fetch('/api/monitor/dt_metrics');
      dt_metrics = await res.json();
    } catch {}
  }

  onDestroy(() => {
    smbr_ev?.close();
  });

  // Stat cards data dari dt_metrics
  $: dftr_stat = dt_metrics ? [
    {
      label: 'CPU',
      value: `${dt_metrics.cpu.usage_percent}%`,
      sub: `${dt_metrics.cpu.temp_celsius}°C`,
      pct: dt_metrics.cpu.usage_percent,
      icon: '⬡',
    },
    {
      label: 'RAM',
      value: fmt_ukrn_kb(dt_metrics.memory.used_kb),
      sub: `dari ${fmt_ukrn_kb(dt_metrics.memory.total_kb)}`,
      pct: dt_metrics.memory.usage_percent,
      icon: '◈',
    },
    {
      label: 'Storage',
      value: `${dt_metrics.disk.usage_percent}%`,
      sub: `${fmt_ukrn_kb(dt_metrics.disk.free_kb)} free`,
      pct: dt_metrics.disk.usage_percent,
      icon: '⬢',
    },
    {
      label: 'Network ↑',
      value: fmt_ukrn_byte(dt_metrics.network.tx_bytes_per_sec),
      sub: `↓ ${fmt_ukrn_byte(dt_metrics.network.rx_bytes_per_sec)}`,
      pct: 0,
      icon: '⇅',
    },
  ] : [];

  // Provider counts
  $: jml_aktif = dftr_srv.filter(s => s.enabled && s.healthy).length;
  $: jml_total = dftr_srv.length;
</script>

<svelte:head>
  <title>Dashboard — MyServer</title>
</svelte:head>

<div class="dashboard animate-slide-up">
  <!-- Header -->
  <div class="page-header">
    <div>
      <h1>Dashboard</h1>
      <p class="text-secondary">Redmi Note 10S · AI Agent Server</p>
    </div>
    <div class="header-right">
      {#if wkt_akhir}
        <span class="mono text-muted" style="font-size:0.75rem;">Update: {wkt_akhir}</span>
      {/if}
      <div class="badge badge-success">
        <span class="status-dot online"></span>
        Online
      </div>
    </div>
  </div>

  <!-- Stat Cards -->
  {#if dt_metrics}
    <div class="grid-4" style="margin-bottom: 2rem;">
      {#each dftr_stat as card}
        <div class="card stat-card">
          <div class="stat-top">
            <span class="stat-icon gradient-text">{card.icon}</span>
            <span class="stat-label">{card.label}</span>
          </div>
          <div class="stat-value">{card.value}</div>
          <div class="stat-sub text-muted">{card.sub}</div>
          {#if card.pct > 0}
            <div class="progress-bar" style="margin-top: 0.75rem;">
              <div
                class="progress-fill"
                class:warning={card.pct > 70}
                class:danger={card.pct > 90}
                style="width: {Math.min(card.pct, 100)}%"
              ></div>
            </div>
          {/if}
        </div>
      {/each}
    </div>
  {:else}
    <div class="loading-placeholder">
      <div class="spinner"></div>
      <span>Memuat dt_metrics...</span>
    </div>
  {/if}

  <!-- Main Grid -->
  <div class="main-grid">
    <!-- AI Providers -->
    <div class="card">
      <div class="flex justify-between items-center" style="margin-bottom: 1rem;">
        <h3>AI Providers</h3>
        <div class="badge badge-info">{jml_aktif}/{jml_total} aktif</div>
      </div>
      <div class="providers-list">
        {#each dftr_srv.slice(0, 8) as svc}
          <div class="provider-row">
            <div class="flex items-center gap-2">
              <span class="status-dot" class:online={svc.enabled && svc.healthy} class:offline={!svc.enabled || !svc.healthy}></span>
              <span class="provider-name">{svc.name}</span>
              {#if svc.is_local}
                <span class="badge badge-info" style="font-size:0.65rem;">lokal</span>
              {/if}
            </div>
            <div class="flex items-center gap-2">
              {#if svc.usage.requests_today > 0}
                <span class="mono text-muted" style="font-size:0.75rem;">{svc.usage.requests_today} req</span>
              {/if}
              {#if !svc.has_api_key}
                <span class="badge badge-warning" style="font-size:0.65rem;">no key</span>
              {/if}
            </div>
          </div>
        {/each}
      </div>
      <a href="/ai" class="btn btn-ghost" style="width:100%; justify-content:center; margin-top:1rem;">
        Buka AI Chat →
      </a>
    </div>

    <!-- Cloud Storage -->
    <div class="card">
      <div class="flex justify-between items-center" style="margin-bottom: 1rem;">
        <h3>Cloud Storage</h3>
        <a href="/storage" class="btn btn-ghost" style="padding: 4px 12px; font-size: 0.8rem;">Lihat →</a>
      </div>
      {#if dftr_smpn.length > 0}
        <div class="storage-list">
          {#each dftr_smpn as acc}
            <div class="storage-item">
              <div class="flex justify-between items-center" style="margin-bottom: 4px;">
                <span class="font-medium">{acc.name}</span>
                <span class="text-muted mono" style="font-size:0.75rem;">{acc.free_human} free</span>
              </div>
              {#if acc.total > 0}
                <div class="progress-bar">
                  <div
                    class="progress-fill"
                    style="width: {Math.min((acc.used / acc.total) * 100, 100)}%"
                  ></div>
                </div>
                <div style="font-size:0.75rem; color:var(--text-muted); margin-top:2px;">
                  {acc.used_human} / {acc.total_human}
                </div>
              {:else if acc.error}
                <span class="badge badge-warning" style="font-size:0.7rem;">{acc.error}</span>
              {:else}
                <span class="text-muted" style="font-size:0.75rem;">Klik lihat untuk detail</span>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <div class="empty-state">
          <p class="text-muted">Belum ada cloud storage yang ditautkan.</p>
          <p class="text-muted" style="font-size: 0.8rem;">Jalankan <code class="mono">rclone config</code></p>
        </div>
      {/if}
    </div>

    <!-- Log Usage -->
    {#if dt_metrics}
      <div class="card">
        <h3 style="margin-bottom: 1rem;">Log Storage</h3>
        {@const logPct = Math.min((dt_metrics.logs.total_size_mb / dt_metrics.logs.max_allowed_mb) * 100, 100)}
        <div class="stat-value" style="font-size: 1.5rem;">
          {(dt_metrics.logs.total_size_mb / 1024).toFixed(1)} GB
        </div>
        <div class="text-muted" style="margin: 4px 0 12px;">dari {dt_metrics.logs.max_allowed_mb / 1024} GB alokasi</div>
        <div class="progress-bar" style="height: 10px;">
          <div class="progress-fill"
            class:warning={logPct > 70}
            class:danger={logPct > 90}
            style="width: {logPct}%"
          ></div>
        </div>
        <div style="font-size:0.8rem; color:var(--text-muted); margin-top:8px;">
          Auto-cleanup aktif · Threshold 80%
        </div>
      </div>
    {/if}

    <!-- Quick Links -->
    <div class="card">
      <h3 style="margin-bottom: 1rem;">Quick Actions</h3>
      <div style="display: flex; flex-direction: column; gap: 8px;">
        <a href="/ai" class="btn btn-ghost" style="justify-content: flex-start;">
          ✦ Chat dengan AI
        </a>
        <a href="/storage" class="btn btn-ghost" style="justify-content: flex-start;">
          ☁ Manage Storage
        </a>
        <a href="/monitor" class="btn btn-ghost" style="justify-content: flex-start;">
          ◈ System Monitor
        </a>
        <a href="/deploy" class="btn btn-ghost" style="justify-content: flex-start;">
          ⚙ Deploy Service
        </a>
      </div>
    </div>
  </div>
</div>

<style>
  .dashboard { max-width: 1400px; }

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 2rem;
  }
  .header-right {
    display: flex;
    align-items: center;
    gap: 12px;
  }
  .text-secondary { color: var(--text-secondary); margin-top: 4px; }
  .text-muted { color: var(--text-muted); }
  .font-medium { font-weight: 500; }

  .stat-card { position: relative; overflow: hidden; }
  .stat-card::before {
    content: '';
    position: absolute;
    top: -50%;
    right: -50%;
    width: 100%;
    height: 100%;
    background: radial-gradient(circle, rgba(0,212,255,0.05) 0%, transparent 70%);
    pointer-events: none;
  }
  .stat-top {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 0.5rem;
  }
  .stat-icon { font-size: 1.2rem; }
  .stat-label { font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.08em; }
  .stat-value { font-size: 1.75rem; font-weight: 700; line-height: 1; margin-bottom: 4px; }
  .stat-sub { font-size: 0.8rem; }

  .loading-placeholder {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 2rem;
    color: var(--text-muted);
  }

  .spinner {
    width: 20px;
    height: 20px;
    border: 2px solid var(--border-subtle);
    border-top-color: var(--accent-primary);
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .main-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 1.5rem;
  }
  @media (max-width: 1024px) {
    .main-grid { grid-template-columns: 1fr; }
  }

  .providers-list { display: flex; flex-direction: column; gap: 8px; }
  .provider-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 10px;
    border-radius: var(--radius-sm);
    background: var(--bg-elevated);
  }
  .provider-name { font-size: 0.875rem; font-weight: 500; }

  .storage-list { display: flex; flex-direction: column; gap: 12px; }
  .storage-item {
    padding: 12px;
    background: var(--bg-elevated);
    border-radius: var(--radius-sm);
  }

  .empty-state {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 1rem 0;
  }

  code { font-family: var(--font-mono); font-size: 0.85rem; background: var(--bg-elevated); padding: 2px 6px; border-radius: 4px; }
</style>
