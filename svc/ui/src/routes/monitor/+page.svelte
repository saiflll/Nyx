<script lang="ts">
  import { onMount, onDestroy } from 'svelte';

  interface MetricsPoint {
    timestamp: number;
    cpu: { usage_percent: number; temp_celsius: number };
    memory: { usage_percent: number; used_kb: number; total_kb: number };
    disk: { usage_percent: number; free_kb: number };
    network: { rx_bytes_per_sec: number; tx_bytes_per_sec: number };
    logs: { total_size_mb: number; max_allowed_mb: number };
  }

  let current: MetricsPoint | null = null;
  let history: MetricsPoint[] = [];
  let eventSource: EventSource | null = null;
  let providers: any[] = [];
  let usage: any = {};

  const KB = 1024;
  const MB = 1024 * KB;
  const GB = 1024 * MB;

  const fmt = (kb: number) => {
    if (kb > GB / KB) return `${(kb / GB * KB).toFixed(1)} GB`;
    if (kb > MB / KB) return `${(kb / MB * KB).toFixed(1)} MB`;
    return `${kb} KB`;
  };

  const fmtSpeed = (bps: number) => {
    if (bps > MB) return `${(bps / MB).toFixed(1)} MB/s`;
    if (bps > KB) return `${(bps / KB).toFixed(1)} KB/s`;
    return `${bps} B/s`;
  };

  onMount(async () => {
    // Load history
    try {
      const res = await fetch('/api/monitor/history?limit=60');
      const data = await res.json();
      history = data.history || [];
      if (history.length > 0) current = history[history.length - 1];
    } catch {}

    // SSE real-time
    eventSource = new EventSource('/api/monitor/stream');
    eventSource.onmessage = (e) => {
      const m = JSON.parse(e.data);
      current = m;
      history = [...history.slice(-119), m];
    };

    // Load providers usage
    try {
      const r1 = await fetch('/api/ai/providers');
      providers = (await r1.json()).providers || [];
      const r2 = await fetch('/api/ai/usage');
      usage = (await r2.json()).usage || {};
    } catch {}
  });

  onDestroy(() => eventSource?.close());

  // Sparkline helper (simple SVG)
  function sparkline(data: number[], color: string, height = 40): string {
    if (!data.length) return '';
    const max = Math.max(...data, 1);
    const w = 200;
    const pts = data.map((v, i) => {
      const x = (i / (data.length - 1)) * w;
      const y = height - (v / max) * height;
      return `${x},${y}`;
    }).join(' ');
    return `<svg viewBox="0 0 ${w} ${height}" xmlns="http://www.w3.org/2000/svg" style="width:100%;height:${height}px">
      <polyline points="${pts}" fill="none" stroke="${color}" stroke-width="2" stroke-linecap="round"/>
    </svg>`;
  }

  $: cpuHistory = history.map(h => h.cpu?.usage_percent || 0);
  $: ramHistory = history.map(h => h.memory?.usage_percent || 0);
  $: rxHistory  = history.map(h => h.network?.rx_bytes_per_sec || 0);
</script>

<svelte:head>
  <title>Monitor — MyServer</title>
</svelte:head>

<div class="monitor-page animate-slide-up">
  <h1 style="margin-bottom: 1.5rem;">System Monitor</h1>

  {#if !current}
    <div style="display:flex;align-items:center;gap:12px;color:var(--text-muted);padding:3rem;">
      <div class="spin"></div>
      Menunggu data metrics...
    </div>
  {:else}
    <!-- Metric Cards Row -->
    <div class="grid-4" style="margin-bottom:1.5rem;">
      <!-- CPU -->
      <div class="card metric-card">
        <div class="metric-header">
          <span class="metric-label">CPU Usage</span>
          <span class="metric-value" style="color:{current.cpu.usage_percent > 80 ? 'var(--accent-danger)' : 'var(--accent-primary)'}">
            {current.cpu.usage_percent}%
          </span>
        </div>
        <div style="margin: 8px 0 4px;">
          {@html sparkline(cpuHistory, 'var(--accent-primary)')}
        </div>
        <div class="metric-sub">
          🌡️ Temp: <strong>{current.cpu.temp_celsius}°C</strong>
          {#if current.cpu.temp_celsius > 80}
            <span class="badge badge-danger" style="font-size:0.65rem;">HOT!</span>
          {/if}
        </div>
      </div>

      <!-- RAM -->
      <div class="card metric-card">
        <div class="metric-header">
          <span class="metric-label">RAM Usage</span>
          <span class="metric-value" style="color:{current.memory.usage_percent > 85 ? 'var(--accent-danger)' : 'var(--accent-primary)'}">
            {current.memory.usage_percent}%
          </span>
        </div>
        <div style="margin: 8px 0 4px;">
          {@html sparkline(ramHistory, 'var(--accent-secondary)')}
        </div>
        <div class="metric-sub">
          {fmt(current.memory.used_kb)} / {fmt(current.memory.total_kb)}
        </div>
      </div>

      <!-- Disk -->
      <div class="card metric-card">
        <div class="metric-header">
          <span class="metric-label">Storage</span>
          <span class="metric-value" style="color:{current.disk.usage_percent > 85 ? 'var(--accent-danger)' : 'var(--accent-primary)'}">
            {current.disk.usage_percent}%
          </span>
        </div>
        <div class="progress-bar" style="margin: 16px 0 8px;">
          <div class="progress-fill"
            class:warning={current.disk.usage_percent > 70}
            class:danger={current.disk.usage_percent > 85}
            style="width:{current.disk.usage_percent}%"
          ></div>
        </div>
        <div class="metric-sub">{fmt(current.disk.free_kb)} free</div>
      </div>

      <!-- Network -->
      <div class="card metric-card">
        <div class="metric-header">
          <span class="metric-label">Network</span>
          <span class="metric-value">↑↓</span>
        </div>
        <div style="margin: 8px 0 4px;">
          {@html sparkline(rxHistory, 'var(--accent-success)')}
        </div>
        <div class="metric-sub">
          ↓ {fmtSpeed(current.network.rx_bytes_per_sec)} &nbsp;
          ↑ {fmtSpeed(current.network.tx_bytes_per_sec)}
        </div>
      </div>
    </div>

    <!-- Log + AI Usage Row -->
    <div class="grid-2" style="margin-bottom:1.5rem;">
      <!-- Log Storage -->
      <div class="card">
        <h3 style="margin-bottom:1rem;">Log Storage</h3>
        {@const logPct = Math.min((current.logs.total_size_mb / current.logs.max_allowed_mb) * 100, 100)}
        <div style="display:flex;justify-content:space-between;margin-bottom:8px;">
          <span style="color:var(--text-secondary);">
            {(current.logs.total_size_mb/1024).toFixed(1)} GB
          </span>
          <span class="mono" style="color:var(--text-muted);">
            / {(current.logs.max_allowed_mb/1024).toFixed(0)} GB
          </span>
        </div>
        <div class="progress-bar" style="height:10px;margin-bottom:8px;">
          <div class="progress-fill"
            class:warning={logPct > 70}
            class:danger={logPct > 90}
            style="width:{logPct}%"
          ></div>
        </div>
        <div style="font-size:0.8rem;color:var(--text-muted);">
          Auto-cleanup: 80% threshold · Hapus log > 7 hari tidak diakses
        </div>
      </div>

      <!-- AI Provider Usage -->
      <div class="card">
        <h3 style="margin-bottom:1rem;">AI Provider Usage (Hari Ini)</h3>
        <div class="provider-usage-list">
          {#each providers.filter(p => usage[p.name]?.requests_today > 0) as p}
            <div class="usage-row">
              <div style="display:flex;align-items:center;gap:8px;">
                <span class="status-dot" class:online={p.healthy} class:offline={!p.healthy}></span>
                <span style="font-size:0.875rem;font-weight:500;">{p.name}</span>
              </div>
              <div style="display:flex;gap:12px;align-items:center;">
                <span class="mono" style="font-size:0.8rem;color:var(--text-muted);">
                  {usage[p.name]?.requests_today || 0} req
                </span>
                <span class="mono" style="font-size:0.8rem;color:var(--text-muted);">
                  {((usage[p.name]?.tokens_used_today || 0) / 1000).toFixed(1)}k tok
                </span>
              </div>
            </div>
          {:else}
            <p style="color:var(--text-muted);font-size:0.875rem;">Belum ada request hari ini.</p>
          {/each}
        </div>
      </div>
    </div>
  {/if}
</div>

<style>
  .monitor-page { max-width: 1400px; }
  .metric-card { padding: 1.25rem; }
  .metric-header { display: flex; justify-content: space-between; align-items: baseline; }
  .metric-label { font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }
  .metric-value { font-size: 1.5rem; font-weight: 700; }
  .metric-sub { font-size: 0.8rem; color: var(--text-secondary); }

  .provider-usage-list { display: flex; flex-direction: column; gap: 8px; }
  .usage-row {
    display: flex; justify-content: space-between; align-items: center;
    padding: 8px 10px; background: var(--bg-elevated); border-radius: var(--radius-sm);
  }

  .spin {
    width: 20px; height: 20px;
    border: 2px solid var(--border-subtle); border-top-color: var(--accent-primary);
    border-radius: 50%; animation: rot 1s linear infinite;
  }
  @keyframes rot { to { transform: rotate(360deg); } }
</style>
