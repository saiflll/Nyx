FROM golang:1.22-bookworm AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o storage-manager .

# ---
FROM debian:bookworm-slim
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        rclone ca-certificates wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/storage-manager .
COPY categories.yml .

RUN mkdir -p /app/logs /data /root/.config/rclone

EXPOSE 8090
CMD ["./storage-manager"]
