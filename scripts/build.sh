#!/bin/bash

# VelocityTasks Build Script
# Builds the application for multiple platforms

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
LDFLAGS="-w -s -X main.version=${VERSION} -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Platforms to build for
PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "darwin/amd64"
    "darwin/arm64"
    "windows/amd64"
    "windows/arm64"
)

echo -e "${BLUE}🚀 VelocityTasks Build Script${NC}"
echo -e "${BLUE}================================${NC}"

# Clean previous builds
echo -e "${YELLOW}📦 Cleaning previous builds...${NC}"
rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}

# Build for each platform
echo -e "${YELLOW}🔨 Building for multiple platforms...${NC}"

for platform in "${PLATFORMS[@]}"; do
    platform_split=(${platform//\// })
    GOOS=${platform_split[0]}
    GOARCH=${platform_split[1]}
    
    output_name=${APP_NAME}-${GOOS}-${GOARCH}
    if [ $GOOS = "windows" ]; then
        output_name+='.exe'
    fi
    
    echo -e "${BLUE}Building for ${GOOS}/${GOARCH}...${NC}"
    
    env GOOS=$GOOS GOARCH=$GOARCH go build \
        -ldflags="${LDFLAGS}" \
        -o ${BUILD_DIR}/${output_name} \
        ./main.go
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to build for ${GOOS}/${GOARCH}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Built ${output_name}${NC}"
done

# Build CLI version
echo -e "${YELLOW}🔨 Building CLI version...${NC}"
for platform in "${PLATFORMS[@]}"; do
    platform_split=(${platform//\// })
    GOOS=${platform_split[0]}
    GOARCH=${platform_split[1]}
    
    output_name=${APP_NAME}-cli-${GOOS}-${GOARCH}
    if [ $GOOS = "windows" ]; then
        output_name+='.exe'
    fi
    
    echo -e "${BLUE}Building CLI for ${GOOS}/${GOARCH}...${NC}"
    
    env GOOS=$GOOS GOARCH=$GOARCH go build \
        -ldflags="${LDFLAGS}" \
        -o ${BUILD_DIR}/${output_name} \
        ./cmd/velocitytasks/main.go
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to build CLI for ${GOOS}/${GOARCH}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Built ${output_name}${NC}"
done

# Create distribution packages
echo -e "${YELLOW}📦 Creating distribution packages...${NC}"

for platform in "${PLATFORMS[@]}"; do
    platform_split=(${platform//\// })
    GOOS=${platform_split[0]}
    GOARCH=${platform_split[1]}
    
    package_name=${APP_NAME}-${VERSION}-${GOOS}-${GOARCH}
    package_dir=${BUILD_DIR}/${package_name}
    
    mkdir -p ${package_dir}
    
    # Copy binaries
    if [ $GOOS = "windows" ]; then
        cp ${BUILD_DIR}/${APP_NAME}-${GOOS}-${GOARCH}.exe ${package_dir}/
        cp ${BUILD_DIR}/${APP_NAME}-cli-${GOOS}-${GOARCH}.exe ${package_dir}/
    else
        cp ${BUILD_DIR}/${APP_NAME}-${GOOS}-${GOARCH} ${package_dir}/
        cp ${BUILD_DIR}/${APP_NAME}-cli-${GOOS}-${GOARCH} ${package_dir}/
    fi
    
    # Copy web assets
    cp -r web ${package_dir}/
    
    # Copy configuration
    cp config.yaml ${package_dir}/
    
    # Copy documentation
    cp README.md ${package_dir}/
    cp LICENSE ${package_dir}/
    
    # Copy deployment configs
    cp -r deployment ${package_dir}/
    
    # Create archive
    cd ${BUILD_DIR}
    if command -v zip > /dev/null; then
        zip -r ${package_name}.zip ${package_name}/
        echo -e "${GREEN}✅ Created ${package_name}.zip${NC}"
    fi
    
    if command -v tar > /dev/null; then
        tar -czf ${package_name}.tar.gz ${package_name}/
        echo -e "${GREEN}✅ Created ${package_name}.tar.gz${NC}"
    fi
    
    cd ..
done

# Build Docker image
echo -e "${YELLOW}🐳 Building Docker image...${NC}"
if command -v docker > /dev/null; then
    docker build -t velocitytasks:${VERSION} -f deployment/docker/Dockerfile .
    docker tag velocitytasks:${VERSION} velocitytasks:latest
    echo -e "${GREEN}✅ Built Docker image velocitytasks:${VERSION}${NC}"
else
    echo -e "${YELLOW}⚠️ Docker not found, skipping Docker build${NC}"
fi

# Generate checksums
echo -e "${YELLOW}🔐 Generating checksums...${NC}"
cd ${BUILD_DIR}
if command -v sha256sum > /dev/null; then
    find . -name "*.zip" -o -name "*.tar.gz" | xargs sha256sum > checksums.txt
    echo -e "${GREEN}✅ Generated checksums.txt${NC}"
elif command -v shasum > /dev/null; then
    find . -name "*.zip" -o -name "*.tar.gz" | xargs shasum -a 256 > checksums.txt
    echo -e "${GREEN}✅ Generated checksums.txt${NC}"
fi
cd ..

# Display build summary
echo -e "${GREEN}🎉 Build completed successfully!${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Built binaries:${NC}"
ls -la ${BUILD_DIR}/${APP_NAME}-* | grep -v "\.zip\|\.tar\.gz"

echo -e "${GREEN}Distribution packages:${NC}"
ls -la ${BUILD_DIR}/*.zip ${BUILD_DIR}/*.tar.gz 2>/dev/null || echo "No archives created"

echo -e "${GREEN}Total build size:${NC}"
du -sh ${BUILD_DIR}

echo -e "${BLUE}📚 Next steps:${NC}"
echo -e "1. Test the binaries: ./${BUILD_DIR}/${APP_NAME}-linux-amd64"
echo -e "2. Deploy with Docker: docker run -p 8080:8080 velocitytasks:${VERSION}"
echo -e "3. Upload packages to GitHub releases"
echo -e "4. Update documentation with new version"
