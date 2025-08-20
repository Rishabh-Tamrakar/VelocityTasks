#!/bin/bash

# VelocityTasks Build and Deploy Script
# Usage: ./build-and-deploy.sh [featherjet-path]

set -e

echo "🚀 VelocityTasks - Build and Deploy Script"
echo "=========================================="

# Configuration
FEATHERJET_PATH=${1:-"/opt/featherjet"}
APP_NAME="velocity-tasks"
BUILD_DIR="target"
WAR_FILE="$BUILD_DIR/$APP_NAME.war"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    print_error "Maven is not installed. Please install Maven first."
    exit 1
fi

# Check if Java is installed
if ! command -v java &> /dev/null; then
    print_error "Java is not installed. Please install Java 17+ first."
    exit 1
fi

# Check Java version
JAVA_VERSION=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
if [ "$JAVA_VERSION" -lt 17 ]; then
    print_error "Java 17 or higher is required. Current version: $JAVA_VERSION"
    exit 1
fi

print_status "Java version check passed: $JAVA_VERSION"

# Clean and build the project
print_status "Cleaning previous build..."
mvn clean

print_status "Building VelocityTasks..."
mvn package -DskipTests=false

# Check if build was successful
if [ ! -f "$WAR_FILE" ]; then
    print_error "Build failed! WAR file not found: $WAR_FILE"
    exit 1
fi

print_success "Build completed successfully!"

# Check if FeatherJet path exists
if [ ! -d "$FEATHERJET_PATH" ]; then
    print_warning "FeatherJet directory not found: $FEATHERJET_PATH"
    print_status "Creating FeatherJet directory structure..."
    mkdir -p "$FEATHERJET_PATH/webapps"
fi

# Deploy to FeatherJet
WEBAPP_DIR="$FEATHERJET_PATH/webapps"
if [ ! -d "$WEBAPP_DIR" ]; then
    print_status "Creating webapps directory: $WEBAPP_DIR"
    mkdir -p "$WEBAPP_DIR"
fi

print_status "Deploying to FeatherJet: $WEBAPP_DIR"

# Option 1: Deploy as WAR file
cp "$WAR_FILE" "$WEBAPP_DIR/"
print_success "WAR file deployed: $WEBAPP_DIR/$APP_NAME.war"

# Option 2: Deploy as exploded directory (uncomment if preferred)
# EXPLODED_DIR="$WEBAPP_DIR/$APP_NAME"
# if [ -d "$EXPLODED_DIR" ]; then
#     print_status "Removing existing deployment: $EXPLODED_DIR"
#     rm -rf "$EXPLODED_DIR"
# fi
# 
# print_status "Extracting WAR to: $EXPLODED_DIR"
# mkdir -p "$EXPLODED_DIR"
# cd "$EXPLODED_DIR"
# unzip -q "../$APP_NAME.war"
# cd - > /dev/null
# print_success "Application deployed as exploded directory"

# Create startup script if it doesn't exist
STARTUP_SCRIPT="$FEATHERJET_PATH/start-velocity-tasks.sh"
if [ ! -f "$STARTUP_SCRIPT" ]; then
    print_status "Creating startup script: $STARTUP_SCRIPT"
    cat > "$STARTUP_SCRIPT" << 'EOF'
#!/bin/bash

# VelocityTasks Startup Script
FEATHERJET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$FEATHERJET_DIR"

echo "Starting VelocityTasks on FeatherJet..."
echo "Access the application at: http://localhost:8080/velocity-tasks/"

# Start FeatherJet with optimized settings for VelocityTasks
java -Xms256m -Xmx512m \
     -XX:+UseG1GC \
     -XX:MaxGCPauseMillis=200 \
     -Dfile.encoding=UTF-8 \
     -jar featherjet-server.jar
EOF
    chmod +x "$STARTUP_SCRIPT"
    print_success "Startup script created and made executable"
fi

# Check if FeatherJet server JAR exists
FEATHERJET_JAR="$FEATHERJET_PATH/featherjet-server.jar"
if [ ! -f "$FEATHERJET_JAR" ]; then
    print_warning "FeatherJet server JAR not found: $FEATHERJET_JAR"
    print_status "Please ensure FeatherJet is properly installed in: $FEATHERJET_PATH"
fi

# Print deployment summary
echo ""
print_success "🎉 VelocityTasks deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "   Application: VelocityTasks v1.0.0"
echo "   Build file:  $WAR_FILE"
echo "   Deploy path: $WEBAPP_DIR/$APP_NAME.war"
echo "   Startup:     $STARTUP_SCRIPT"
echo ""
echo "🚀 To start the application:"
echo "   cd $FEATHERJET_PATH"
echo "   ./start-velocity-tasks.sh"
echo ""
echo "🌐 Access URLs:"
echo "   Application: http://localhost:8080/velocity-tasks/"
echo "   API:         http://localhost:8080/velocity-tasks/api/tasks"
echo "   Statistics:  http://localhost:8080/velocity-tasks/api/stats"
echo ""
print_status "Happy task managing! ⚡"
