<script lang="ts">
  import '../app.css';
  import { page } from '$app/stores';

  const navItems = [
    { href: '/',          icon: '⬡',  label: 'Dashboard' },
    { href: '/ai',        icon: '✦',  label: 'AI Chat'   },
    { href: '/storage',   icon: '☁',  label: 'Storage'   },
    { href: '/monitor',   icon: '◈',  label: 'Monitor'   },
    { href: '/deploy',    icon: '⚙',  label: 'Deploy'    },
  ];
</script>

<div class="layout">
  <!-- Sidebar -->
  <nav class="sidebar glass">
    <!-- Logo -->
    <div class="logo">
      <div class="logo-icon">
        <span>⬡</span>
      </div>
      <div class="logo-text">
        <span class="gradient-text">MyServer</span>
        <span class="logo-sub">Note 10S</span>
      </div>
    </div>

    <div class="divider" style="margin: 1.25rem 0;"></div>

    <!-- Nav links -->
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

    <!-- Server status -->
    <div class="server-status">
      <div class="status-dot online"></div>
      <span style="font-size: 0.8rem; color: var(--text-secondary);">Server Online</span>
    </div>
  </nav>

  <!-- Main content -->
  <main class="main-content">
    <slot />
  </main>
</div>

<style>
  .layout {
    display: flex;
    height: 100vh;
    overflow: hidden;
  }

  .sidebar {
    width: 240px;
    min-width: 240px;
    padding: 1.5rem 1rem;
    display: flex;
    flex-direction: column;
    border-right: 1px solid var(--border-subtle);
    overflow-y: auto;
  }

  .logo {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 0 0.5rem;
  }

  .logo-icon {
    width: 40px;
    height: 40px;
    background: linear-gradient(135deg, var(--accent-primary), var(--accent-secondary));
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.25rem;
    color: white;
    box-shadow: 0 4px 12px rgba(0, 212, 255, 0.3);
  }

  .logo-text {
    display: flex;
    flex-direction: column;
    line-height: 1.2;
  }

  .logo-text .gradient-text {
    font-size: 1.1rem;
    font-weight: 700;
  }

  .logo-sub {
    font-size: 0.7rem;
    color: var(--text-muted);
    letter-spacing: 0.05em;
  }

  .nav-list {
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .nav-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 12px;
    border-radius: var(--radius-sm);
    text-decoration: none;
    color: var(--text-secondary);
    font-size: 0.9rem;
    font-weight: 500;
    transition: all var(--transition);
  }

  .nav-item:hover {
    background: var(--bg-elevated);
    color: var(--text-primary);
  }

  .nav-item.active {
    background: rgba(0, 212, 255, 0.1);
    color: var(--accent-primary);
    border: 1px solid rgba(0, 212, 255, 0.15);
  }

  .nav-icon {
    font-size: 1.1rem;
    width: 24px;
    text-align: center;
  }

  .server-status {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 12px;
    background: rgba(16, 185, 129, 0.05);
    border: 1px solid rgba(16, 185, 129, 0.1);
    border-radius: var(--radius-sm);
  }

  .main-content {
    flex: 1;
    overflow-y: auto;
    padding: 2rem;
  }

  @media (max-width: 768px) {
    .sidebar {
      display: none;
    }
  }
</style>
