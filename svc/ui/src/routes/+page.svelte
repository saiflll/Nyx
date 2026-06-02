<script lang="ts">
  import { onMount, onDestroy } from 'svelte';

  interface Metrics {
    timestamp: number;
    cpu: { usage_percent: number; temp_celsius: number };
    memory: { total_kb: number; used_kb: number; usage_percent: number };
    disk: { total_kb: number; used_kb: number; free_kb: number; usage_percent: number };
    network: { rx_bytes_per_sec: number; tx_bytes_per_sec: number };
    logs: { total_size_mb: number; max_allowed_mb: number };
  }

  interface ServiceStatus {
    name: string;
    healthy: boolean;
    enabled: boolean;
    has_api_key: boolean;
    is_local?: boolean;
    usage: { requests_today: number; tokens_today: number };
  }

  let dt_metrics: Metrics | null = null;
  let dftr_srv: ServiceStatus[] = [];
  let dftr_smpn: any[] = [];
  let agentic_skills: string[] = [];
  let smbr_ev: EventSource | null = null;
  let wkt_akhir = '';

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
    if (pct > 90) return 'var(--crimson-400, #dc2626)';
    if (pct > 70) return '#f59e0b';
    return '#22c55e';
  };

  onMount(async () => {
    try {
      const res = await fetch('/api/ai/providers');
      const data = await res.json();
      dftr_srv = data.providers || [];
    } catch (e) {}

    try {
      const res = await fetch('/api/storage/accounts');
      const data = await res.json();
      dftr_smpn = data.accounts || [];
    } catch (e) {}

    try {
      const res = await fetch('/api/skills');
      const data = await res.json();
      agentic_skills = (data.skills || []).map((s: any) => s.name);
    } catch (e) {}

    smbr_ev = new EventSource('/api/monitor/stream');
    smbr_ev.onmessage = (e) => {
      dt_metrics = JSON.parse(e.data);
      wkt_akhir = new Date().toLocaleTimeString('id-ID');
    };
    smbr_ev.onerror = () => {
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

  $: dftr_stat = dt_metrics ? [
    {
      label: 'CPU',
      value: `${dt_metrics.cpu.usage_percent}%`,
      sub: `${dt_metrics.cpu.temp_celsius}°C`,
      pct: dt_metrics.cpu.usage_percent,
      icon: '▣',
    },
    {
      label: 'RAM',
      value: fmt_ukrn_kb(dt_metrics.memory.used_kb),
      sub: `/ ${fmt_ukrn_kb(dt_metrics.memory.total_kb)}`,
      pct: dt_metrics.memory.usage_percent,
      icon: '◈',
    },
    {
      label: 'Disk',
      value: `${dt_metrics.disk.usage_percent}%`,
      sub: `${fmt_ukrn_kb(dt_metrics.disk.free_kb)} free`,
      pct: dt_metrics.disk.usage_percent,
      icon: '⊞',
    },
    {
      label: 'Network ↑',
      value: fmt_ukrn_byte(dt_metrics.network.tx_bytes_per_sec),
      sub: `↓ ${fmt_ukrn_byte(dt_metrics.network.rx_bytes_per_sec)}`,
      pct: 0,
      icon: '⇅',
    },
  ] : [];

  $: jml_aktif = dftr_srv.filter(s => s.enabled && s.healthy).length;
  $: jml_total = dftr_srv.length;
</script>

<svelte:head>
  <title>Dashboard — Nyx</title>
</svelte:head>

<div class="dashboard animate-slide-up">
  <div class="page-header">
    <div>
      <h1>Dashboard</h1>
      <p class="sub-label">nyxCore · System Overview</p>
    </div>
    <div class="header-right">
      {#if wkt_akhir}
        <span class="mono" style="font-size:0.72rem; color:#4b5563;">Updated {wkt_akhir}</span>
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
            <span class="stat-icon">{card.icon}</span>
            <span class="stat-label">{card.label}</span>
          </div>
          <div class="stat-value">{card.value}</div>
          <div class="stat-sub">{card.sub}</div>
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
    <div class="loading-state">
      <div class="spinner"></div>
      <span style="color:#4b5563; font-size:0.875rem;">Connecting to nyxAgent...</span>
    </div>
  {/if}

  <!-- Main Grid -->
  <div class="main-grid">
    <!-- Providers -->
    <div class="card">
      <div class="flex justify-between items-center" style="margin-bottom: 1rem;">
        <h3>Providers</h3>
        <div class="badge badge-navy">{jml_aktif}/{jml_total} active</div>
      </div>
      <div class="providers-list">
        {#each dftr_srv.slice(0, 8) as svc}
          <div class="provider-row">
            <div class="flex items-center gap-2">
              <span class="status-dot" class:online={svc.enabled && svc.healthy} class:offline={!svc.enabled || !svc.healthy}></span>
              <span class="provider-name">{svc.name}</span>
              {#if svc.is_local}
                <span class="badge badge-navy" style="font-size:0.62rem;">local</span>
              {/if}
            </div>
            <div class="flex items-center gap-2">
              {#if svc.usage.requests_today > 0}
                <span class="mono" style="font-size:0.72rem; color:#4b5563;">{svc.usage.requests_today} req</span>
              {/if}
              {#if !svc.has_api_key}
                <span class="badge badge-warning" style="font-size:0.62rem;">no key</span>
              {/if}
            </div>
          </div>
        {/each}
      </div>

      <div style="margin-top: 1.5rem; padding-top: 1rem; border-top: 1px solid rgba(255,255,255,0.05);">
        <div class="flex justify-between items-center" style="margin-bottom: 0.75rem;">
          <h3>Skills</h3>
          <div class="badge badge-navy">{agentic_skills.length} loaded</div>
        </div>
        <div class="skills-wrap">
          {#each agentic_skills as skill}
            <span class="badge badge-navy skill-tag">{skill}</span>
          {/each}
          {#if agentic_skills.length === 0}
            <span style="font-size:0.8rem; color:#4b5563;">No skills in /skills</span>
          {/if}
        </div>
      </div>

      <a href="/ai" class="btn btn-ghost" style="width:100%; justify-content:center; margin-top:1.25rem;">
        Open Chat →
      </a>
    </div>

    <!-- Storage -->
    <div class="card">
      <div class="flex justify-between items-center" style="margin-bottom: 1rem;">
        <h3>Cloud Storage</h3>
        <a href="/storage" class="btn btn-ghost" style="padding: 4px 10px; font-size: 0.8rem;">View →</a>
      </div>
      {#if dftr_smpn.length > 0}
        <div class="storage-list">
          {#each dftr_smpn as acc}
            <div class="storage-item">
              <div class="flex justify-between items-center" style="margin-bottom: 4px;">
                <span style="font-weight:500; font-size:0.875rem;">{acc.name}</span>
                <span class="mono" style="font-size:0.72rem; color:#4b5563;">{acc.free_human} free</span>
              </div>
              {#if acc.total > 0}
                <div class="progress-bar">
                  <div
                    class="progress-fill"
                    style="width: {Math.min((acc.used / acc.total) * 100, 100)}%"
                  ></div>
                </div>
                <div style="font-size:0.72rem; color:#4b5563; margin-top:3px;">
                  {acc.used_human} / {acc.total_human}
                </div>
              {:else if acc.error}
                <span class="badge badge-warning" style="font-size:0.68rem;">{acc.error}</span>
              {:else}
                <span style="font-size:0.75rem; color:#4b5563;">Click view for details</span>
              {/if}
            </div>
          {/each}
        </div>
      {:else}
        <div class="empty-state">
          <p style="color:#4b5563; font-size:0.875rem;">No storage accounts linked.</p>
          <p style="color:#4b5563; font-size:0.8rem; margin-top:4px;">Run <code class="mono">rclone config</code></p>
        </div>
      {/if}
    </div>

    <!-- Log Storage -->
    {#if dt_metrics}
      <div class="card">
        <h3 style="margin-bottom: 1rem;">Log Storage</h3>
        {@const logPct = Math.min((dt_metrics.logs.total_size_mb / dt_metrics.logs.max_allowed_mb) * 100, 100)}
        <div class="stat-value" style="font-size: 1.6rem;">
          {(dt_metrics.logs.total_size_mb / 1024).toFixed(1)} GB
        </div>
        <div style="font-size:0.8rem; color:#4b5563; margin: 4px 0 12px;">
          of {dt_metrics.logs.max_allowed_mb / 1024} GB allocated
        </div>
        <div class="progress-bar" style="height: 8px;">
          <div class="progress-fill"
            class:warning={logPct > 70}
            class:danger={logPct > 90}
            style="width: {logPct}%"
          ></div>
        </div>
        <div style="font-size:0.75rem; color:#4b5563; margin-top:8px;">
          Auto-cleanup · threshold 80%
        </div>
      </div>
    {/if}

    <!-- Quick Links -->
    <div class="card">
      <h3 style="margin-bottom: 1rem;">Quick Actions</h3>
      <div style="display: flex; flex-direction: column; gap: 6px;">
        <a href="/ai"      class="btn btn-ghost" style="justify-content: flex-start;">⌬ Chat</a>
        <a href="/storage" class="btn btn-ghost" style="justify-content: flex-start;">⊞ Storage</a>
        <a href="/monitor" class="btn btn-ghost" style="justify-content: flex-start;">◉ Monitor</a>
        <a href="/deploy"  class="btn btn-ghost" style="justify-content: flex-start;">⚙ Deploy</a>
      </div>
    </div>
  </div>
</div>

<style lang="scss">
  .dashboard { max-width: 1400px; }

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 2rem;
  }

  .sub-label { color: #4b5563; font-size: 0.875rem; margin-top: 3px; }

  .header-right {
    display: flex;
    align-items: center;
    gap: 10px;
  }

  .stat-card { position: relative; overflow: hidden; }
  .stat-top  { display: flex; align-items: center; gap: 8px; margin-bottom: 0.5rem; }
  .stat-icon { font-size: 1rem; color: #dc2626; }
  .stat-label { font-size: 0.72rem; color: #4b5563; text-transform: uppercase; letter-spacing: 0.08em; }
  .stat-value { font-size: 1.7rem; font-weight: 700; line-height: 1; margin-bottom: 3px; }
  .stat-sub   { font-size: 0.78rem; color: #4b5563; }

  .loading-state {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 2rem 0;
  }

  .spinner {
    width: 18px;
    height: 18px;
    border: 2px solid rgba(255,255,255,0.08);
    border-top-color: #dc2626;
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }

  @keyframes spin { to { transform: rotate(360deg); } }

  .main-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: 1.25rem;
  }

  @media (max-width: 1024px) {
    .main-grid { grid-template-columns: 1fr; }
  }

  .providers-list { display: flex; flex-direction: column; gap: 4px; }
  .provider-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 10px;
    border-radius: 6px;
    background: #111827;
  }
  .provider-name { font-size: 0.85rem; font-weight: 500; }

  .skills-wrap { display: flex; gap: 6px; flex-wrap: wrap; }
  .skill-tag { font-size: 0.68rem !important; }

  .storage-list { display: flex; flex-direction: column; gap: 10px; }
  .storage-item { padding: 10px; background: #111827; border-radius: 6px; }

  .empty-state { padding: 0.5rem 0; }

  code { font-family: 'JetBrains Mono', monospace; font-size: 0.82rem; background: #111827; padding: 2px 5px; border-radius: 4px; }
</style>
