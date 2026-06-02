FROM debian:bookworm-slim

WORKDIR /app

# Install llama.cpp dependencies
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        wget curl ca-certificates \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy llama-server binary (sudah diinstall saat setup-debian.sh)
# Atau download langsung saat build
ARG LLAMA_VERSION=b4631
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then CF_ARCH="arm64"; \
    elif [ "$ARCH" = "armv7l" ]; then CF_ARCH="arm"; \
    else CF_ARCH="x86-64"; fi && \
    wget -q "https://github.com/ggerganov/llama.cpp/releases/download/${LLAMA_VERSION}/llama-${LLAMA_VERSION}-bin-ubuntu-${CF_ARCH}.zip" \
        -O /tmp/llama.zip 2>/dev/null || \
    wget -q "https://github.com/ggerganov/llama.cpp/releases/latest/download/llama-server" \
        -O /usr/local/bin/llama-server || true

COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh && \
    apt-get update -y && apt-get install -y python3 python3-pip --no-install-recommends && \
    pip3 install --no-cache-dir fastapi uvicorn httpx && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /app/logs /models

EXPOSE 11434

CMD ["/app/start.sh"]
