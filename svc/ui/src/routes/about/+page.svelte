<svelte:head>
  <title>About — Nyx</title>
</svelte:head>

<div class="about-page animate-slide-up">
  <div class="page-header">
    <h1>About</h1>
    <p class="sub-label">Project & Author</p>
  </div>

  <div class="about-grid">
    <!-- Project info -->
    <div class="card">
      <div class="card-logo">
        <img src="/favicon.png" alt="Nyx" class="about-icon" />
        <div>
          <div class="project-name gradient-text">Nyx</div>
          <div class="project-ver mono">v 1.0.0 beta</div>
        </div>
      </div>

      <p class="project-desc">
        A self-hosted server stack built to run on constrained hardware.
        Handles API routing, cloud storage, system monitoring, and local inference — all containerized.
      </p>

      <div class="divider" style="margin: 1.25rem 0;"></div>

      <div class="stack-list">
        <div class="stack-row">
          <span class="stack-key mono">nyxCore</span>
          <span class="stack-val">Orchestration — docker-compose, secrets, infra</span>
        </div>
        <div class="stack-row">
          <span class="stack-key mono">nyxAgent</span>
          <span class="stack-val">API gateway — provider routing & local inference</span>
        </div>
        <div class="stack-row">
          <span class="stack-key mono">nyxUi</span>
          <span class="stack-val">Dashboard — SvelteKit web interface</span>
        </div>
      </div>
    </div>

    <!-- Author -->
    <div class="card author-card">
      <div class="author-header">
        <div class="author-avatar">MS</div>
        <div>
          <div class="author-name">Muhammad Saifulloh</div>
          <div class="author-handle mono">aka renagge39</div>
        </div>
      </div>

      <blockquote class="author-quote">
        "Build it small, run it everywhere, own everything."
      </blockquote>

      <a
        href="https://github.com/renagge39"
        target="_blank"
        rel="noopener"
        class="btn btn-ghost github-btn"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0 0 24 12c0-6.63-5.37-12-12-12z"/>
        </svg>
        github.com/renagge39
      </a>

      <div class="divider" style="margin: 1.25rem 0;"></div>

      <div class="inspirations">
        <p class="inspir-label">Inspired by</p>
        <div class="inspir-links">
          <a
            href="https://github.com/renagge39/nanobot"
            target="_blank"
            rel="noopener"
            class="inspir-item"
          >
            <span class="inspir-icon">⚙</span>
            <div>
              <span class="inspir-name">nanobot</span>
              <span class="inspir-sub mono">github.com/renagge39/nanobot</span>
            </div>
          </a>
          <a
            href="https://www.casaos.io"
            target="_blank"
            rel="noopener"
            class="inspir-item"
          >
            <span class="inspir-icon">⊞</span>
            <div>
              <span class="inspir-name">CasaOS</span>
              <span class="inspir-sub mono">casaos.io</span>
            </div>
          </a>
        </div>
      </div>
    </div>
  </div>

  <footer class="page-footer">
    <span class="mono">v 1.0.0 beta</span>
    <span class="sep">·</span>
    <span>renagge39</span>
    <span class="sep">·</span>
    <span>2026</span>
  </footer>
</div>

<style lang="scss">
  .about-page { max-width: 860px; }

  .page-header { margin-bottom: 2rem; }
  .sub-label { color: #4b5563; font-size: 0.875rem; margin-top: 3px; }

  .about-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1.25rem;

    @media (max-width: 768px) {
      grid-template-columns: 1fr;
    }
  }

  .card-logo {
    display: flex;
    align-items: center;
    gap: 14px;
    margin-bottom: 1.25rem;
  }

  .about-icon {
    width: 52px;
    height: 52px;
    border-radius: 10px;
    border: 1px solid rgba(220,38,38,0.2);
    background: #111827;
  }

  .project-name {
    font-size: 1.6rem;
    font-weight: 800;
    letter-spacing: 0.04em;
    line-height: 1;
  }

  .project-ver {
    font-size: 0.72rem;
    color: #4b5563;
    margin-top: 3px;
  }

  .project-desc {
    font-size: 0.875rem;
    color: #6b7280;
    line-height: 1.65;
  }

  .stack-list { display: flex; flex-direction: column; gap: 10px; }
  .stack-row  { display: flex; flex-direction: column; gap: 2px; }
  .stack-key  { font-size: 0.8rem; color: #ef4444; }
  .stack-val  { font-size: 0.82rem; color: #4b5563; }

  .author-header {
    display: flex;
    align-items: center;
    gap: 14px;
    margin-bottom: 1.25rem;
  }

  .author-avatar {
    width: 48px;
    height: 48px;
    background: rgba(220,38,38,0.12);
    border: 1px solid rgba(220,38,38,0.25);
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    font-weight: 700;
    font-size: 0.9rem;
    color: #ef4444;
    flex-shrink: 0;
    letter-spacing: 0.04em;
  }

  .author-name {
    font-size: 1rem;
    font-weight: 600;
  }

  .author-handle {
    font-size: 0.75rem;
    color: #4b5563;
    margin-top: 2px;
  }

  .author-quote {
    border-left: 2px solid #dc2626;
    padding: 0.5rem 0 0.5rem 1rem;
    font-size: 0.9rem;
    color: #6b7280;
    font-style: italic;
    margin-bottom: 1.25rem;
    line-height: 1.5;
  }

  .github-btn {
    width: 100%;
    justify-content: center;
    gap: 8px;
  }

  .inspirations { }

  .inspir-label {
    font-size: 0.72rem;
    color: #4b5563;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    margin-bottom: 0.75rem;
  }

  .inspir-links { display: flex; flex-direction: column; gap: 8px; }

  .inspir-item {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 12px;
    background: #111827;
    border-radius: 6px;
    border: 1px solid rgba(255,255,255,0.05);
    text-decoration: none;
    transition: border-color 0.18s ease;

    &:hover { border-color: rgba(220,38,38,0.2); }
  }

  .inspir-icon {
    font-size: 1rem;
    color: #4b5563;
    flex-shrink: 0;
  }

  .inspir-name {
    display: block;
    font-size: 0.875rem;
    font-weight: 500;
    color: #94a3b8;
  }

  .inspir-sub {
    display: block;
    font-size: 0.68rem;
    color: #4b5563;
    margin-top: 1px;
  }

  .page-footer {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 2.5rem;
    padding-top: 1.5rem;
    border-top: 1px solid rgba(255,255,255,0.05);
    font-size: 0.78rem;
    color: #4b5563;
  }

  .sep { color: rgba(255,255,255,0.1); }
</style>
