<script lang="ts">
  import { onMount } from 'svelte';

  // ── Types ──
  interface Message {
    role: 'user' | 'assistant' | 'system';
    content: string;
    provider?: string;
    model?: string;
    timestamp?: string;
    isLoading?: boolean;
  }

  // ── State ──
  let messages: Message[] = [];
  let input = '';
  let isLoading = false;
  let taskType = 'general';
  let forceProvider = '';
  let providers: any[] = [];
  let messagesEl: HTMLElement;

  // Mode analisis .env
  let envMode = false;
  let envContent = '';

  const taskTypes = [
    { value: 'general',   label: '💬 General'   },
    { value: 'coding',    label: '💻 Coding'     },
    { value: 'reasoning', label: '🧠 Reasoning'  },
    { value: 'fast',      label: '⚡ Fast'        },
    { value: 'sensitive', label: '🔒 Sensitif (.env)' },
  ];

  onMount(async () => {
    try {
      const res = await fetch('/api/ai/providers');
      const data = await res.json();
      providers = data.providers?.filter((p: any) => p.enabled) || [];
    } catch {}
  });

  async function sendMessage() {
    if (!input.trim() || isLoading) return;

    const userMsg: Message = {
      role: 'user',
      content: input,
      timestamp: new Date().toLocaleTimeString('id-ID'),
    };
    messages = [...messages, userMsg];
    const userInput = input;
    input = '';
    isLoading = true;

    // Placeholder loading
    const loadingMsg: Message = {
      role: 'assistant',
      content: '',
      isLoading: true,
    };
    messages = [...messages, loadingMsg];

    scrollToBottom();

    try {
      let response: Response;

      if (taskType === 'sensitive') {
        // Analisis .env via endpoint khusus
        response = await fetch('/api/ai/analyze-env', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            content: userInput,
            task: 'analyze',
          }),
        });
      } else {
        // Chat biasa
        const payload = {
          messages: [
            // System prompt berdasarkan task
            ...(taskType === 'coding' ? [{
              role: 'system',
              content: 'Kamu adalah expert programmer. Berikan jawaban teknis yang akurat dengan contoh kode.'
            }] : []),
            ...messages.filter(m => !m.isLoading).map(m => ({
              role: m.role,
              content: m.content,
            })),
          ],
          task_type: taskType,
          force_provider: forceProvider || undefined,
          max_tokens: 2048,
          temperature: taskType === 'coding' ? 0.2 : 0.7,
        };

        response = await fetch('/api/ai/v1/chat/completions', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
      }

      const data = await response.json();

      // Update loading placeholder dengan response
      const content = data.choices?.[0]?.message?.content || data.error || 'Error: Tidak ada response';
      const routing = data._routing || {};

      messages = messages.map(m =>
        m.isLoading ? {
          role: 'assistant',
          content,
          provider: routing.provider,
          model: routing.model,
          timestamp: new Date().toLocaleTimeString('id-ID'),
        } : m
      );
    } catch (e) {
      messages = messages.map(m =>
        m.isLoading ? {
          role: 'assistant',
          content: `Error: ${e instanceof Error ? e.message : 'Unknown error'}`,
          timestamp: new Date().toLocaleTimeString('id-ID'),
        } : m
      );
    } finally {
      isLoading = false;
      scrollToBottom();
    }
  }

  function scrollToBottom() {
    setTimeout(() => {
      if (messagesEl) {
        messagesEl.scrollTop = messagesEl.scrollHeight;
      }
    }, 50);
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  }

  function clearChat() {
    messages = [];
  }

  // Format kode dalam pesan
  function formatMessage(content: string): string {
    return content
      .replace(/```(\w+)?\n([\s\S]*?)```/g, (_, lang, code) =>
        `<pre><code class="lang-${lang || 'text'}">${escapeHtml(code.trim())}</code></pre>`
      )
      .replace(/`([^`]+)`/g, '<code>$1</code>')
      .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
      .replace(/\n/g, '<br>');
  }

  function escapeHtml(str: string): string {
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
</script>

<svelte:head>
  <title>AI Chat — MyServer</title>
</svelte:head>

<div class="ai-page animate-slide-up">
  <!-- Header -->
  <div class="page-header">
    <div>
      <h1>AI Chat</h1>
      <p style="color:var(--text-secondary); margin-top:4px;">
        TinyLLM Router · Auto-failover ke {providers.length} providers
      </p>
    </div>
    <button class="btn btn-ghost" on:click={clearChat}>🗑 Clear</button>
  </div>

  <!-- Controls -->
  <div class="controls card" style="margin-bottom:1rem; padding: 1rem 1.5rem;">
    <div class="controls-row">
      <div class="control-group">
        <label>Task Type</label>
        <div class="task-pills">
          {#each taskTypes as tt}
            <button
              class="pill"
              class:active={taskType === tt.value}
              on:click={() => taskType = tt.value}
            >
              {tt.label}
            </button>
          {/each}
        </div>
      </div>
      <div class="control-group">
        <label>Provider (opsional)</label>
        <select class="input" style="width:200px;" bind:value={forceProvider}>
          <option value="">Auto (terbaik)</option>
          {#each providers as p}
            <option value={p.name}>{p.name} {p.is_local ? '🔒' : ''}</option>
          {/each}
        </select>
      </div>
    </div>
    {#if taskType === 'sensitive'}
      <div class="sensitive-notice">
        🔒 Mode Sensitif: Request akan dikirim ke <strong>Qwen2.5 lokal</strong> saja.
        Tidak ada data yang keluar ke internet.
      </div>
    {/if}
  </div>

  <!-- Chat area -->
  <div class="chat-container">
    <div class="messages" bind:this={messagesEl}>
      {#if messages.length === 0}
        <div class="welcome-screen">
          <div class="welcome-icon gradient-text" style="font-size: 3rem;">✦</div>
          <h3>AI Router siap</h3>
          <p style="color:var(--text-muted);">
            Tanya apa saja. Router akan pilih provider terbaik secara otomatis.
          </p>
          <div class="suggestions">
            <button class="suggestion" on:click={() => { input = 'Buatkan fungsi Python untuk membaca file JSON'; }}>
              💻 Buat fungsi Python baca JSON
            </button>
            <button class="suggestion" on:click={() => { input = 'Jelaskan perbedaan goroutine vs thread'; }}>
              🧠 Goroutine vs Thread
            </button>
            <button class="suggestion" on:click={() => { taskType = 'sensitive'; input = 'DATABASE_URL=postgres://user:pass@localhost/db\nAPI_KEY=sk-abc123'; }}>
              🔒 Analisis .env (lokal)
            </button>
          </div>
        </div>
      {:else}
        {#each messages as msg}
          <div class="message" class:user={msg.role === 'user'} class:assistant={msg.role === 'assistant'}>
            {#if msg.isLoading}
              <div class="message-bubble loading-bubble">
                <span class="typing-dots">
                  <span></span><span></span><span></span>
                </span>
              </div>
            {:else}
              <div class="message-bubble">
                {@html formatMessage(msg.content)}
              </div>
              <div class="message-meta">
                {#if msg.provider}
                  <span class="badge badge-info" style="font-size:0.65rem;">{msg.provider}</span>
                  {#if msg.model}
                    <span class="mono" style="font-size:0.7rem; color:var(--text-muted);">{msg.model}</span>
                  {/if}
                {/if}
                {#if msg.timestamp}
                  <span style="font-size:0.7rem; color:var(--text-muted);">{msg.timestamp}</span>
                {/if}
              </div>
            {/if}
          </div>
        {/each}
      {/if}
    </div>

    <!-- Input -->
    <div class="input-area">
      <textarea
        class="input chat-input"
        placeholder={taskType === 'sensitive' ? 'Paste isi file .env di sini untuk dianalisis...' : 'Ketik pesan... (Enter kirim, Shift+Enter baris baru)'}
        bind:value={input}
        on:keydown={handleKeydown}
        rows="3"
        disabled={isLoading}
      ></textarea>
      <button class="btn btn-primary send-btn" on:click={sendMessage} disabled={isLoading || !input.trim()}>
        {isLoading ? '...' : '↑'}
      </button>
    </div>
  </div>
</div>

<style>
  .ai-page { display: flex; flex-direction: column; height: calc(100vh - 4rem); max-width: 1000px; }

  .page-header {
    display: flex; justify-content: space-between; align-items: flex-start;
    margin-bottom: 1rem;
  }

  .controls-row { display: flex; gap: 2rem; align-items: flex-start; flex-wrap: wrap; }
  .control-group { display: flex; flex-direction: column; gap: 6px; }
  .control-group label { font-size: 0.75rem; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }

  .task-pills { display: flex; gap: 6px; flex-wrap: wrap; }
  .pill {
    padding: 5px 12px;
    border-radius: 999px;
    border: 1px solid var(--border-subtle);
    background: transparent;
    color: var(--text-secondary);
    font-size: 0.8rem;
    cursor: pointer;
    transition: all var(--transition);
  }
  .pill:hover { border-color: var(--border-accent); color: var(--text-primary); }
  .pill.active { background: rgba(0,212,255,0.1); border-color: var(--accent-primary); color: var(--accent-primary); }

  .sensitive-notice {
    margin-top: 0.75rem;
    padding: 8px 14px;
    background: rgba(239,68,68,0.05);
    border: 1px solid rgba(239,68,68,0.15);
    border-radius: var(--radius-sm);
    font-size: 0.85rem;
    color: var(--text-secondary);
  }

  .chat-container {
    flex: 1;
    display: flex;
    flex-direction: column;
    background: var(--bg-card);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-lg);
    overflow: hidden;
  }

  .messages {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .message {
    display: flex;
    flex-direction: column;
    gap: 4px;
    max-width: 80%;
    animation: slide-up 0.2s ease;
  }
  .message.user { align-self: flex-end; align-items: flex-end; }
  .message.assistant { align-self: flex-start; align-items: flex-start; }

  .message-bubble {
    padding: 10px 16px;
    border-radius: var(--radius-md);
    line-height: 1.6;
    font-size: 0.9rem;
  }
  .message.user .message-bubble {
    background: linear-gradient(135deg, var(--accent-primary), var(--accent-secondary));
    color: white;
    border-radius: var(--radius-md) var(--radius-md) 4px var(--radius-md);
  }
  .message.assistant .message-bubble {
    background: var(--bg-elevated);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-md) var(--radius-md) var(--radius-md) 4px;
  }

  .message-bubble :global(pre) {
    background: var(--bg-base);
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    padding: 12px;
    overflow-x: auto;
    margin: 8px 0;
  }
  .message-bubble :global(code) {
    font-family: var(--font-mono);
    font-size: 0.85em;
    background: rgba(0,0,0,0.3);
    padding: 1px 5px;
    border-radius: 3px;
  }
  .message-bubble :global(pre code) { background: none; padding: 0; }

  .loading-bubble {
    display: flex;
    align-items: center;
    min-width: 60px;
    justify-content: center;
  }

  .typing-dots {
    display: flex;
    gap: 4px;
  }
  .typing-dots span {
    width: 6px;
    height: 6px;
    background: var(--text-muted);
    border-radius: 50%;
    animation: bounce 1.2s infinite;
  }
  .typing-dots span:nth-child(2) { animation-delay: 0.2s; }
  .typing-dots span:nth-child(3) { animation-delay: 0.4s; }
  @keyframes bounce {
    0%, 80%, 100% { transform: translateY(0); }
    40% { transform: translateY(-6px); }
  }

  .message-meta { display: flex; gap: 8px; align-items: center; padding: 0 4px; }

  .input-area {
    display: flex;
    gap: 8px;
    padding: 1rem 1.5rem;
    border-top: 1px solid var(--border-subtle);
    background: var(--bg-elevated);
  }
  .chat-input { resize: none; line-height: 1.5; flex: 1; }
  .send-btn {
    align-self: flex-end;
    width: 48px;
    height: 48px;
    border-radius: var(--radius-sm);
    justify-content: center;
    font-size: 1.2rem;
    flex-shrink: 0;
  }

  .welcome-screen {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    text-align: center;
    gap: 12px;
    padding: 2rem;
  }
  .suggestions {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-top: 1rem;
    width: 100%;
    max-width: 400px;
  }
  .suggestion {
    padding: 10px 16px;
    border: 1px solid var(--border-subtle);
    border-radius: var(--radius-sm);
    background: var(--bg-elevated);
    color: var(--text-secondary);
    cursor: pointer;
    font-size: 0.85rem;
    text-align: left;
    transition: all var(--transition);
  }
  .suggestion:hover {
    border-color: var(--border-accent);
    color: var(--text-primary);
    transform: translateX(4px);
  }
</style>
