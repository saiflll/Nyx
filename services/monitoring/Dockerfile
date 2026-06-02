FROM debian:bookworm-slim

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        bash curl wget jq bc procps \
        python3 python3-pip \
    && pip3 install --no-cache-dir fastapi uvicorn aiofiles \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY collector.sh .
COPY server.py .

RUN chmod +x collector.sh && \
    mkdir -p /app/logs /data

EXPOSE 8099

CMD ["python3", "server.py"]
