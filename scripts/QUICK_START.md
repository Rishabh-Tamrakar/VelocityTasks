# VelocityTasks Quick Start Scripts

## Linux/macOS

### Build the application
```bash
chmod +x scripts/*.sh
./scripts/build.sh
```

### Test the application
```bash
./scripts/test.sh
```

### Deploy locally
```bash
./scripts/deploy.sh local
```

### Deploy with Docker
```bash
./scripts/deploy.sh docker
```

### Deploy with Docker Compose
```bash
./scripts/deploy.sh compose
```

### Deploy with Nginx
```bash
./scripts/deploy.sh nginx
```

### Deploy as systemd service
```bash
./scripts/deploy.sh systemd
```

### Deploy to Kubernetes
```bash
./scripts/deploy.sh kubernetes
```

## Windows (PowerShell)

### Build the application
```powershell
.\scripts\scripts.ps1 build
```

### Test the application
```powershell
.\scripts\scripts.ps1 test
```

### Start the application
```powershell
.\scripts\scripts.ps1 start
```

### Deploy locally
```powershell
.\scripts\scripts.ps1 deploy
```

## Quick Development Start

### Option 1: Direct Go Run
```bash
go run main.go
```

### Option 2: Build and Run
```bash
go build -o velocitytasks main.go
./velocitytasks
```

### Option 3: Using Scripts
```bash
# Linux/macOS
./scripts/build.sh
./scripts/deploy.sh local

# Windows
.\scripts\scripts.ps1 build
.\scripts\scripts.ps1 deploy
```

## Configuration

### Environment Variables
- `PORT`: Server port (default: 8080)
- `HOST`: Server host (default: 0.0.0.0)
- `STATIC_DIR`: Static files directory (default: web)
- `CONFIG_FILE`: Configuration file path (default: config.yaml)
- `ENABLE_PERSISTENCE`: Enable task persistence (default: false)
- `PERSISTENCE_FILE`: Persistence file path (default: tasks.json)
- `LOG_LEVEL`: Log level (default: info)

### Example with Custom Settings
```bash
export PORT=3000
export ENABLE_PERSISTENCE=true
export PERSISTENCE_FILE=/tmp/my-tasks.json
go run main.go
```

## Accessing the Application

Once started, access VelocityTasks at:
- **Local**: http://localhost:8080
- **Custom Port**: http://localhost:YOUR_PORT

## Stopping the Application

- **Development**: Press `Ctrl+C`
- **Docker**: `docker stop velocitytasks`
- **Systemd**: `sudo systemctl stop velocitytasks`
- **Docker Compose**: `docker-compose down`

## Health Check

Check if the application is running:
```bash
curl http://localhost:8080/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "version": "1.0.0"
}
```
