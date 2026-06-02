<script lang="ts">
  import '../app.scss';
  import { page } from '$app/stores';

  const navItems = [
    { href: '/',        icon: '▣',  label: 'Dashboard' },
    { href: '/ai',      icon: '⌬',  label: 'AI Chat'   },
    { href: '/storage', icon: '⊞',  label: 'Storage'   },
    { href: '/monitor', icon: '◉',  label: 'Monitor'   },
    { href: '/deploy',  icon: '⚙',  label: 'Deploy'    },
    { href: '/about',   icon: '◎',  label: 'About'     },
  ];
</script>

<div class="layout">
  <nav class="sidebar glass">
    <div class="logo">
      <div class="logo-icon">
        <img src="/favicon.png" alt="Nyx" width="28" height="28" />
      </div>
      <div class="logo-text">
        <span class="gradient-text logo-name">Nyx</span>
        <span class="logo-sub">nyxCore</span>
      </div>
    </div>

    <div class="divider" style="margin: 1.25rem 0;"></div>

    <ul class="nav-list">
      {#each navItems as item}
        <li>
          <a
            href={item.href}
            class="nav-item"
            class:active={$page.url.pathname === item.href}
          >
            <span class="nav-icon">{item.icon}</span>
            <span class="nav-label">{item.label}</span>
          </a>
        </li>
      {/each}
    </ul>

    <div style="flex: 1;" />

    <div class="server-status">
      <div class="status-dot online"></div>
      <span style="font-size: 0.8rem; color: #4b5563;">nyxAgent online</span>
    </div>
  </nav>

  <main class="main-content">
    <slot />
  </main>
</div>

<style>
  .layout {
    display: flex;
    height: 100vh;
    overflow: hidden;
    background: #0d1117;
  }

  .sidebar {
    width: 220px;
    min-width: 220px;
    padding: 1.5rem 0.875rem;
    display: flex;
    flex-direction: column;
    border-right: 1px solid rgba(255,255,255,0.06);
    overflow-y: auto;
  }

  .logo {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 0 0.375rem;
  }

  .logo-icon {
    width: 36px;
    height: 36px;
    background: #111827;
    border: 1px solid rgba(220,38,38,0.3);
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    overflow: hidden;
    flex-shrink: 0;
  }

  .logo-text {
    display: flex;
    flex-direction: column;
    line-height: 1.2;
  }

  .logo-name {
    font-size: 1.15rem;
    font-weight: 700;
    letter-spacing: 0.04em;
  }

  .logo-sub {
    font-size: 0.68rem;
    color: #4b5563;
    letter-spacing: 0.06em;
    font-family: 'JetBrains Mono', monospace;
  }

  .nav-list {
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 9px 10px;
    border-radius: 6px;
    text-decoration: none;
    color: #4b5563;
    font-size: 0.875rem;
    font-weight: 500;
    transition: all 0.18s ease;
    border: 1px solid transparent;
  }

  .nav-item:hover {
    background: #111827;
    color: #94a3b8;
  }

  .nav-item.active {
    background: rgba(220, 38, 38, 0.1);
    color: #ef4444;
    border-color: rgba(220, 38, 38, 0.18);
  }

  .nav-icon {
    font-size: 1rem;
    width: 20px;
    text-align: center;
    flex-shrink: 0;
  }

  .server-status {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 9px 10px;
    background: rgba(22, 163, 74, 0.04);
    border: 1px solid rgba(22, 163, 74, 0.1);
    border-radius: 6px;
  }

  .main-content {
    flex: 1;
    overflow-y: auto;
    padding: 2rem;
    background: #0d1117;
  }

  @media (max-width: 768px) {
    .sidebar { display: none; }
  }
</style>
