<script lang="ts">
  import { onMount } from 'svelte';

  let accounts: any[] = [];
  let files: any[] = [];
  let currentRemote = 'all';
  let currentPath = '/';
  let loading = false;
  let breadcrumbs: string[] = [];
  let sortBy = 'name';
  let filterCategory = '';

  const categories = ['all','documents','images','videos','audio','code','archives','configs','others'];

  onMount(() => {
    loadAccounts();
    loadFiles();
  });

  async function loadAccounts() {
    try {
      const res = await fetch('/api/storage/accounts');
      const data = await res.json();
      accounts = data.accounts || [];
    } catch {}
  }

  async function loadFiles() {
    loading = true;
    try {
      const params = new URLSearchParams({
        remote: currentRemote,
        path: currentPath,
      });
      const res = await fetch(`/api/storage/files?${params}`);
      const data = await res.json();
      files = data.files || [];
    } catch {} finally {
      loading = false;
    }
  }

  function navigate(path: string) {
    currentPath = path;
    loadFiles();

    // Update breadcrumbs
    if (path === '/') {
      breadcrumbs = [];
    } else {
      breadcrumbs = path.split('/').filter(Boolean);
    }
  }

  function navigateTo(idx: number) {
    if (idx === -1) {
      navigate('/');
    } else {
      const path = '/' + breadcrumbs.slice(0, idx + 1).join('/');
      navigate(path);
    }
  }

  function selectRemote(remote: string) {
    currentRemote = remote;
    navigate('/');
  }

  async function deleteFile(path: string, remote: string) {
    if (!confirm(`Hapus ${path}?`)) return;
    const fullPath = `${remote}:${path}`;
    await fetch(`/api/storage/file?path=${encodeURIComponent(fullPath)}`, { method: 'DELETE' });
    loadFiles();
  }

  const fileIcon = (file: any) => {
    if (file.is_dir) return '📁';
    const cat = file.category;
    const icons: Record<string, string> = {
      images: '🖼', videos: '🎬', audio: '🎵',
      documents: '📄', code: '💻', archives: '📦',
      configs: '⚙', databases: '🗃', others: '📎',
    };
    return icons[cat] || '📎';
  };

  // Filter & sort
  $: displayFiles = files
    .filter(f => !filterCategory || filterCategory === 'all' || f.category === filterCategory)
    .sort((a, b) => {
      if (a.is_dir !== b.is_dir) return a.is_dir ? -1 : 1;
      if (sortBy === 'name') return a.name.localeCompare(b.name);
      if (sortBy === 'size') return b.size - a.size;
      if (sortBy === 'date') return new Date(b.mod_time).getTime() - new Date(a.mod_time).getTime();
      return 0;
    });

  $: totalSize = accounts.reduce((acc, a) => acc + (a.used || 0), 0);
  $: totalFree = accounts.reduce((acc, a) => acc + (a.free || 0), 0);
</script>

<svelte:head>
  <title>Storage — MyServer</title>
</svelte:head>

<div class="storage-page animate-slide-up">
  <div class="page-header">
    <div>
      <h1>Cloud Storage</h1>
      <p style="color:var(--text-secondary); margin-top:4px;">
        {accounts.length} akun · Upload langsung dari browser ke cloud
      </p>
    </div>
  </div>

  <!-- Account Cards -->
  <div class="accounts-row">
    <div
      class="account-card"
      class:active={currentRemote === 'all'}
      on:click={() => selectRemote('all')}
      role="button"
      tabindex="0"
      on:keydown={(e) => e.key === 'Enter' && selectRemote('all')}
    >
      <div class="account-icon">☁</div>
      <div class="account-info">
        <div class="account-name">Semua Storage</div>
        <div class="account-stats">
          <span style="color:var(--accent-success);">{(totalFree / 1e9).toFixed(1)}GB free</span>
        </div>
      </div>
    </div>

    {#each accounts as acc}
      <div
        class="account-card"
        class:active={currentRemote === acc.name}
        on:click={() => selectRemote(acc.name)}
        role="button"
        tabindex="0"
        on:keydown={(e) => e.key === 'Enter' && selectRemote(acc.name)}
      >
        <div class="account-icon">
          {acc.provider === 'Google Drive' ? '🔵' :
           acc.provider === 'MEGA' ? '🔴' :
           acc.provider === 'Dropbox' ? '🔷' :
           acc.provider === 'Terabox' ? '🟣' : '☁'}
        </div>
        <div class="account-info">
          <div class="account-name">{acc.name}</div>
          <div class="account-stats">
            {#if acc.total > 0}
              <span style="color:var(--text-muted); font-size:0.75rem;">{acc.free_human} free</span>
              <div class="mini-progress">
                <div class="mini-fill" style="width: {Math.min((acc.used / acc.total) * 100, 100)}%"></div>
              </div>
            {:else if acc.error}
              <span style="color:var(--accent-warning); font-size:0.75rem;">Error</span>
            {/if}
          </div>
        </div>
      </div>
    {/each}
  </div>

  <!-- File Browser -->
  <div class="card browser">
    <!-- Toolbar -->
    <div class="browser-toolbar">
      <!-- Breadcrumbs -->
      <div class="breadcrumbs">
        <button class="crumb" on:click={() => navigateTo(-1)}>☁ Root</button>
        {#each breadcrumbs as crumb, i}
          <span class="crumb-sep">›</span>
          <button class="crumb" on:click={() => navigateTo(i)}>{crumb}</button>
        {/each}
      </div>

      <!-- Controls -->
      <div class="toolbar-controls">
        <select class="input" style="width:140px; padding: 6px 10px;" bind:value={filterCategory}>
          {#each categories as cat}
            <option value={cat}>{cat === 'all' ? 'Semua kategori' : cat}</option>
          {/each}
        </select>
        <select class="input" style="width:120px; padding: 6px 10px;" bind:value={sortBy}>
          <option value="name">Sort: Nama</option>
          <option value="size">Sort: Ukuran</option>
          <option value="date">Sort: Tanggal</option>
        </select>
      </div>
    </div>

    <!-- File list -->
    {#if loading}
      <div class="file-loading">
        <div class="spinner-lg"></div>
        <span>Memuat file...</span>
      </div>
    {:else if displayFiles.length === 0}
      <div class="empty-dir">
        <span style="font-size:3rem;">📂</span>
        <p style="color:var(--text-muted);">Folder kosong atau tidak ada file</p>
      </div>
    {:else}
      <div class="file-list">
        <!-- Header -->
        <div class="file-header">
          <span>Nama</span>
          <span>Kategori</span>
          <span>Ukuran</span>
          <span>Aksi</span>
        </div>
        {#each displayFiles as file}
          <div class="file-row">
            <div class="file-name">
              <span class="file-icon">{fileIcon(file)}</span>
              {#if file.is_dir}
                <button class="file-link" on:click={() => navigate('/' + [...breadcrumbs, file.name].join('/'))}>
                  {file.name}
                </button>
              {:else}
                <span>{file.name}</span>
              {/if}
            </div>
            <div>
              <span class="badge badge-info" style="font-size:0.7rem;">{file.category}</span>
            </div>
            <div class="mono" style="font-size:0.8rem; color:var(--text-muted);">
              {file.is_dir ? '—' : file.size_human}
            </div>
            <div class="file-actions">
              {#if !file.is_dir}
                <button class="btn btn-ghost" style="padding:4px 8px; font-size:0.75rem;"
                  on:click={() => deleteFile(file.path, currentRemote)}
                >🗑</button>
              {/if}
            </div>
          </div>
        {/each}
      </div>
    {/if}
  </div>
</div>

<style>
  .storage-page { max-width: 1400px; }
  .page-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 1.5rem; }

  .accounts-row {
    display: flex;
    gap: 12px;
    overflow-x: auto;
    padding-bottom: 8px;
    margin-bottom: 1.5rem;
  }
  .account-card {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    background: var(--bg-card);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-md);
    cursor: pointer;
    transition: all var(--transition);
    min-width: 160px;
    flex-shrink: 0;
  }
  .account-card:hover, .account-card.active {
    border-color: var(--border-accent);
    box-shadow: var(--glow-primary);
    background: var(--bg-hover);
  }
  .account-icon { font-size: 1.5rem; }
  .account-name { font-size: 0.875rem; font-weight: 600; }
  .account-stats { display: flex; flex-direction: column; gap: 3px; margin-top: 2px; }
  .mini-progress { height: 3px; background: var(--bg-elevated); border-radius: 999px; width: 80px; overflow: hidden; }
  .mini-fill { height: 100%; background: var(--accent-primary); border-radius: 999px; }

  .browser { padding: 0; overflow: hidden; }

  .browser-toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border-subtle);
    gap: 16px;
    flex-wrap: wrap;
  }
  .breadcrumbs { display: flex; align-items: center; gap: 6px; flex-wrap: wrap; }
  .crumb {
    background: none;
    border: none;
    color: var(--text-secondary);
    cursor: pointer;
    font-size: 0.875rem;
    padding: 2px 6px;
    border-radius: 4px;
    transition: color var(--transition);
  }
  .crumb:hover { color: var(--accent-primary); }
  .crumb-sep { color: var(--text-muted); }
  .toolbar-controls { display: flex; gap: 8px; }

  .file-loading, .empty-dir {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 4rem;
    gap: 12px;
    color: var(--text-muted);
  }

  .spinner-lg {
    width: 32px; height: 32px;
    border: 3px solid var(--border-subtle);
    border-top-color: var(--accent-primary);
    border-radius: 50%;
    animation: spin 1s linear infinite;
  }
  @keyframes spin { to { transform: rotate(360deg); } }

  .file-list { display: flex; flex-direction: column; }
  .file-header {
    display: grid;
    grid-template-columns: 1fr 120px 100px 80px;
    padding: 8px 16px;
    font-size: 0.75rem;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    border-bottom: 1px solid var(--border-subtle);
    background: var(--bg-elevated);
  }
  .file-row {
    display: grid;
    grid-template-columns: 1fr 120px 100px 80px;
    padding: 10px 16px;
    border-bottom: 1px solid var(--border-subtle);
    transition: background var(--transition);
    align-items: center;
  }
  .file-row:hover { background: var(--bg-elevated); }
  .file-row:last-child { border-bottom: none; }

  .file-name { display: flex; align-items: center; gap: 8px; overflow: hidden; }
  .file-icon { font-size: 1.1rem; flex-shrink: 0; }
  .file-link {
    background: none; border: none; color: var(--accent-primary);
    cursor: pointer; font-size: 0.875rem; text-align: left;
    white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  }
  .file-link:hover { text-decoration: underline; }
  .file-actions { display: flex; gap: 4px; }
</style>
