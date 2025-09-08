# VelocityTasks Dockerfile
# Multi-stage build for minimal production image

# Build stage
FROM golang:1.21-alpine AS builder

# Install git and ca-certificates
RUN apk update && apk add --no-cache git ca-certificates tzdata

# Create appuser for security
RUN adduser -D -g '' appuser

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download
RUN go mod verify

# Copy source code
COPY . .

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o velocitytasks \
    ./main.go

# Production stage
FROM scratch

# Import from builder
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy binary and static files
COPY --from=builder /build/velocitytasks /app/
COPY --from=builder /build/web /app/web/
COPY --from=builder /build/config.yaml /app/

# Use non-root user
USER appuser

# Set working directory
WORKDIR /app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/app/velocitytasks", "--help"] || exit 1

# Set environment variables
ENV PORT=8080
ENV HOST=0.0.0.0
ENV STATIC_DIR=web
ENV LOG_LEVEL=info

# Run the binary
ENTRYPOINT ["/app/velocitytasks"]
