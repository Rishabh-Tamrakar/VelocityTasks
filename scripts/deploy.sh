#!/bin/bash

# VelocityTasks Deployment Script
# Automates deployment to various platforms

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="velocitytasks"
VERSION="1.0.0"
BUILD_DIR="build"

echo -e "${BLUE}🚀 VelocityTasks Deployment Script${NC}"
echo -e "${BLUE}===================================${NC}"

# Check if build directory exists
if [ ! -d "${BUILD_DIR}" ]; then
    echo -e "${RED}❌ Build directory not found. Run build.sh first.${NC}"
    exit 1
fi

# Function to show usage
show_usage() {
    echo -e "${YELLOW}Usage: $0 [deployment-type]${NC}"
    echo ""
    echo "Deployment types:"
    echo "  local       - Deploy locally for development"
    echo "  docker      - Deploy using Docker"
    echo "  compose     - Deploy using Docker Compose"
    echo "  nginx       - Deploy with Nginx reverse proxy"
    echo "  systemd     - Deploy as systemd service"
    echo "  kubernetes  - Deploy to Kubernetes cluster"
    echo "  heroku      - Deploy to Heroku"
    echo "  aws         - Deploy to AWS"
    echo "  all         - Show all deployment options"
    echo ""
}

# Function to deploy locally
deploy_local() {
    echo -e "${YELLOW}📦 Deploying locally...${NC}"
    
    # Detect platform
    PLATFORM=""
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux-amd64"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(uname -m) == "arm64" ]]; then
            PLATFORM="darwin-arm64"
        else
            PLATFORM="darwin-amd64"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        PLATFORM="windows-amd64"
    else
        echo -e "${RED}❌ Unsupported platform: $OSTYPE${NC}"
        exit 1
    fi
    
    # Copy binary
    BINARY_NAME="${APP_NAME}-${PLATFORM}"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
        BINARY_NAME+=".exe"
    fi
    
    if [ ! -f "${BUILD_DIR}/${BINARY_NAME}" ]; then
        echo -e "${RED}❌ Binary not found: ${BUILD_DIR}/${BINARY_NAME}${NC}"
        exit 1
    fi
    
    # Create deployment directory
    DEPLOY_DIR="deploy"
    mkdir -p ${DEPLOY_DIR}
    
    # Copy files
    cp ${BUILD_DIR}/${BINARY_NAME} ${DEPLOY_DIR}/${APP_NAME}
    cp -r web ${DEPLOY_DIR}/
    cp config.yaml ${DEPLOY_DIR}/
    
    # Make binary executable
    chmod +x ${DEPLOY_DIR}/${APP_NAME}
    
    echo -e "${GREEN}✅ Local deployment ready in ${DEPLOY_DIR}/${NC}"
    echo -e "${GREEN}Run: cd ${DEPLOY_DIR} && ./${APP_NAME}${NC}"
}

# Function to deploy with Docker
deploy_docker() {
    echo -e "${YELLOW}🐳 Deploying with Docker...${NC}"
    
    if ! command -v docker > /dev/null; then
        echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
        exit 1
    fi
    
    # Build if image doesn't exist
    if ! docker image inspect velocitytasks:${VERSION} > /dev/null 2>&1; then
        echo -e "${YELLOW}Building Docker image...${NC}"
        docker build -t velocitytasks:${VERSION} -f deployment/docker/Dockerfile .
    fi
    
    # Stop existing container
    docker stop velocitytasks 2>/dev/null || true
    docker rm velocitytasks 2>/dev/null || true
    
    # Run container
    docker run -d \
        --name velocitytasks \
        -p 8080:8080 \
        -v velocitytasks_data:/data \
        -e ENABLE_PERSISTENCE=true \
        -e PERSISTENCE_FILE=/data/tasks.json \
        --restart unless-stopped \
        velocitytasks:${VERSION}
    
    echo -e "${GREEN}✅ Docker deployment successful${NC}"
    echo -e "${GREEN}Access at: http://localhost:8080${NC}"
    echo -e "${GREEN}View logs: docker logs -f velocitytasks${NC}"
}

# Function to deploy with Docker Compose
deploy_compose() {
    echo -e "${YELLOW}🐳 Deploying with Docker Compose...${NC}"
    
    if ! command -v docker-compose > /dev/null; then
        echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose.${NC}"
        exit 1
    fi
    
    cd deployment/docker
    
    # Stop existing services
    docker-compose down 2>/dev/null || true
    
    # Start services
    docker-compose up -d
    
    echo -e "${GREEN}✅ Docker Compose deployment successful${NC}"
    echo -e "${GREEN}Access at: http://localhost:8080${NC}"
    echo -e "${GREEN}View logs: docker-compose logs -f${NC}"
    
    cd ../..
}

# Function to deploy with Nginx
deploy_nginx() {
    echo -e "${YELLOW}🌐 Deploying with Nginx...${NC}"
    
    if ! command -v nginx > /dev/null; then
        echo -e "${RED}❌ Nginx not found. Please install Nginx.${NC}"
        exit 1
    fi
    
    # Deploy static files
    STATIC_DIR="/var/www/velocitytasks"
    sudo mkdir -p ${STATIC_DIR}
    sudo cp -r web/* ${STATIC_DIR}/
    sudo chown -R www-data:www-data ${STATIC_DIR}
    
    # Copy Nginx config
    sudo cp deployment/nginx/nginx.conf /etc/nginx/sites-available/velocitytasks
    sudo ln -sf /etc/nginx/sites-available/velocitytasks /etc/nginx/sites-enabled/
    
    # Test Nginx config
    sudo nginx -t
    
    # Reload Nginx
    sudo systemctl reload nginx
    
    # Start VelocityTasks backend
    deploy_systemd
    
    echo -e "${GREEN}✅ Nginx deployment successful${NC}"
    echo -e "${GREEN}Configure domain in /etc/nginx/sites-available/velocitytasks${NC}"
}

# Function to deploy as systemd service
deploy_systemd() {
    echo -e "${YELLOW}⚙️ Deploying as systemd service...${NC}"
    
    if ! command -v systemctl > /dev/null; then
        echo -e "${RED}❌ systemd not found.${NC}"
        exit 1
    fi
    
    # Create user
    sudo useradd -r -s /bin/false velocitytasks || true
    
    # Create directories
    sudo mkdir -p /opt/velocitytasks
    sudo mkdir -p /var/lib/velocitytasks
    sudo mkdir -p /var/log/velocitytasks
    
    # Copy files
    sudo cp ${BUILD_DIR}/${APP_NAME}-linux-amd64 /opt/velocitytasks/${APP_NAME}
    sudo cp -r web /opt/velocitytasks/
    sudo cp config.yaml /opt/velocitytasks/
    
    # Set permissions
    sudo chown -R velocitytasks:velocitytasks /opt/velocitytasks
    sudo chown -R velocitytasks:velocitytasks /var/lib/velocitytasks
    sudo chown -R velocitytasks:velocitytasks /var/log/velocitytasks
    sudo chmod +x /opt/velocitytasks/${APP_NAME}
    
    # Create systemd service file
    sudo tee /etc/systemd/system/velocitytasks.service > /dev/null << EOF
[Unit]
Description=VelocityTasks - Ultra-Lightweight Task Management
After=network.target

[Service]
Type=simple
User=velocitytasks
Group=velocitytasks
WorkingDirectory=/opt/velocitytasks
ExecStart=/opt/velocitytasks/${APP_NAME}
Restart=always
RestartSec=10

Environment=PORT=8080
Environment=HOST=0.0.0.0
Environment=STATIC_DIR=web
Environment=ENABLE_PERSISTENCE=true
Environment=PERSISTENCE_FILE=/var/lib/velocitytasks/tasks.json

StandardOutput=journal
StandardError=journal
SyslogIdentifier=velocitytasks

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd and start service
    sudo systemctl daemon-reload
    sudo systemctl enable velocitytasks
    sudo systemctl start velocitytasks
    
    echo -e "${GREEN}✅ Systemd deployment successful${NC}"
    echo -e "${GREEN}Service status: sudo systemctl status velocitytasks${NC}"
    echo -e "${GREEN}View logs: sudo journalctl -u velocitytasks -f${NC}"
}

# Function to deploy to Kubernetes
deploy_kubernetes() {
    echo -e "${YELLOW}☸️ Deploying to Kubernetes...${NC}"
    
    if ! command -v kubectl > /dev/null; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
        exit 1
    fi
    
    # Create Kubernetes manifests
    mkdir -p k8s
    
    # Deployment manifest
    cat > k8s/deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: velocitytasks
  labels:
    app: velocitytasks
spec:
  replicas: 3
  selector:
    matchLabels:
      app: velocitytasks
  template:
    metadata:
      labels:
        app: velocitytasks
    spec:
      containers:
      - name: velocitytasks
        image: velocitytasks:${VERSION}
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: "8080"
        - name: HOST
          value: "0.0.0.0"
        - name: STATIC_DIR
          value: "web"
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: velocitytasks-service
spec:
  selector:
    app: velocitytasks
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
EOF
    
    # Apply manifests
    kubectl apply -f k8s/
    
    echo -e "${GREEN}✅ Kubernetes deployment successful${NC}"
    echo -e "${GREEN}Check status: kubectl get pods -l app=velocitytasks${NC}"
    echo -e "${GREEN}Get service: kubectl get service velocitytasks-service${NC}"
}

# Function to show all deployment options
show_all_options() {
    echo -e "${BLUE}Available deployment options:${NC}"
    echo ""
    echo -e "${GREEN}1. Local Development:${NC}"
    echo -e "   ./deploy.sh local"
    echo -e "   Quick setup for development and testing"
    echo ""
    echo -e "${GREEN}2. Docker:${NC}"
    echo -e "   ./deploy.sh docker"
    echo -e "   Containerized deployment with data persistence"
    echo ""
    echo -e "${GREEN}3. Docker Compose:${NC}"
    echo -e "   ./deploy.sh compose"
    echo -e "   Multi-service setup with Nginx, Redis, monitoring"
    echo ""
    echo -e "${GREEN}4. Nginx Reverse Proxy:${NC}"
    echo -e "   ./deploy.sh nginx"
    echo -e "   Production setup with Nginx for static files"
    echo ""
    echo -e "${GREEN}5. Systemd Service:${NC}"
    echo -e "   ./deploy.sh systemd"
    echo -e "   Native Linux service with auto-restart"
    echo ""
    echo -e "${GREEN}6. Kubernetes:${NC}"
    echo -e "   ./deploy.sh kubernetes"
    echo -e "   Scalable container orchestration"
    echo ""
}

# Main deployment logic
case "${1:-}" in
    "local")
        deploy_local
        ;;
    "docker")
        deploy_docker
        ;;
    "compose")
        deploy_compose
        ;;
    "nginx")
        deploy_nginx
        ;;
    "systemd")
        deploy_systemd
        ;;
    "kubernetes")
        deploy_kubernetes
        ;;
    "all")
        show_all_options
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
