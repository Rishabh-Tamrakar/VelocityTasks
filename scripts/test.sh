#!/bin/bash

# VelocityTasks Test Suite
# Comprehensive testing for all components

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="velocitytasks"
TEST_PORT="8081"
TEST_URL="http://localhost:${TEST_PORT}"

echo -e "${BLUE}🧪 VelocityTasks Test Suite${NC}"
echo -e "${BLUE}===========================${NC}"

# Function to cleanup test server
cleanup() {
    if [ ! -z "${SERVER_PID}" ]; then
        echo -e "${YELLOW}🛑 Stopping test server...${NC}"
        kill ${SERVER_PID} 2>/dev/null || true
        wait ${SERVER_PID} 2>/dev/null || true
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Function to check dependencies
check_dependencies() {
    echo -e "${YELLOW}🔍 Checking dependencies...${NC}"
    
    local missing_deps=()
    
    if ! command -v go > /dev/null; then
        missing_deps+=("go")
    fi
    
    if ! command -v curl > /dev/null; then
        missing_deps+=("curl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}❌ Missing dependencies: ${missing_deps[*]}${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All dependencies found${NC}"
}

# Function to run Go tests
run_go_tests() {
    echo -e "${YELLOW}🧪 Running Go unit tests...${NC}"
    
    if [ -d "tests" ]; then
        go test ./tests/... -v -cover
        echo -e "${GREEN}✅ Go unit tests passed${NC}"
    else
        echo -e "${YELLOW}⚠️ No Go tests found${NC}"
    fi
}

# Function to build test binary
build_test_binary() {
    echo -e "${YELLOW}🔨 Building test binary...${NC}"
    
    go build -o ${APP_NAME}-test main.go
    
    if [ ! -f "${APP_NAME}-test" ]; then
        echo -e "${RED}❌ Failed to build test binary${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Test binary built successfully${NC}"
}

# Function to start test server
start_test_server() {
    echo -e "${YELLOW}🚀 Starting test server on port ${TEST_PORT}...${NC}"
    
    export PORT=${TEST_PORT}
    export HOST="localhost"
    export STATIC_DIR="web"
    export LOG_LEVEL="debug"
    
    ./${APP_NAME}-test &
    SERVER_PID=$!
    
    # Wait for server to start
    local attempts=0
    local max_attempts=30
    
    while [ ${attempts} -lt ${max_attempts} ]; do
        if curl -s "${TEST_URL}/health" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Test server started successfully${NC}"
            return 0
        fi
        
        attempts=$((attempts + 1))
        sleep 1
    done
    
    echo -e "${RED}❌ Failed to start test server${NC}"
    exit 1
}

# Function to test health endpoint
test_health_endpoint() {
    echo -e "${YELLOW}🏥 Testing health endpoint...${NC}"
    
    local response=$(curl -s -w "%{http_code}" "${TEST_URL}/health")
    local http_code=${response: -3}
    local body=${response%???}
    
    if [ "${http_code}" = "200" ]; then
        echo -e "${GREEN}✅ Health endpoint working${NC}"
        echo -e "${GREEN}   Response: ${body}${NC}"
    else
        echo -e "${RED}❌ Health endpoint failed (HTTP ${http_code})${NC}"
        exit 1
    fi
}

# Function to test static files
test_static_files() {
    echo -e "${YELLOW}📁 Testing static file serving...${NC}"
    
    # Test index.html
    local response=$(curl -s -w "%{http_code}" "${TEST_URL}/")
    local http_code=${response: -3}
    
    if [ "${http_code}" = "200" ]; then
        echo -e "${GREEN}✅ Index page served successfully${NC}"
    else
        echo -e "${RED}❌ Index page failed (HTTP ${http_code})${NC}"
        exit 1
    fi
    
    # Test CSS
    response=$(curl -s -w "%{http_code}" "${TEST_URL}/css/styles.css")
    http_code=${response: -3}
    
    if [ "${http_code}" = "200" ]; then
        echo -e "${GREEN}✅ CSS served successfully${NC}"
    else
        echo -e "${RED}❌ CSS failed (HTTP ${http_code})${NC}"
        exit 1
    fi
    
    # Test JavaScript
    response=$(curl -s -w "%{http_code}" "${TEST_URL}/js/app.js")
    http_code=${response: -3}
    
    if [ "${http_code}" = "200" ]; then
        echo -e "${GREEN}✅ JavaScript served successfully${NC}"
    else
        echo -e "${RED}❌ JavaScript failed (HTTP ${http_code})${NC}"
        exit 1
    fi
}

# Function to test API endpoints
test_api_endpoints() {
    echo -e "${YELLOW}🔌 Testing API endpoints...${NC}"
    
    # Test GET /api/tasks (empty)
    local response=$(curl -s -w "%{http_code}" "${TEST_URL}/api/tasks")
    local http_code=${response: -3}
    local body=${response%???}
    
    if [ "${http_code}" = "200" ]; then
        echo -e "${GREEN}✅ GET /api/tasks working${NC}"
        if [ "${body}" = "[]" ]; then
            echo -e "${GREEN}✅ Empty tasks list returned${NC}"
        else
            echo -e "${YELLOW}⚠️ Non-empty tasks list: ${body}${NC}"
        fi
    else
        echo -e "${RED}❌ GET /api/tasks failed (HTTP ${http_code})${NC}"
        exit 1
    fi
    
    # Test POST /api/tasks
    local task_data='{"title":"Test Task","description":"This is a test task","priority":"medium","status":"pending"}'
    response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "${task_data}" "${TEST_URL}/api/tasks")
    http_code=${response: -3}
    body=${response%???}
    
    if [ "${http_code}" = "201" ]; then
        echo -e "${GREEN}✅ POST /api/tasks working${NC}"
        
        # Extract task ID for further tests
        TASK_ID=$(echo "${body}" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        if [ ! -z "${TASK_ID}" ]; then
            echo -e "${GREEN}✅ Task created with ID: ${TASK_ID}${NC}"
        else
            echo -e "${RED}❌ No task ID returned${NC}"
            exit 1
        fi
    else
        echo -e "${RED}❌ POST /api/tasks failed (HTTP ${http_code})${NC}"
        echo -e "${RED}   Response: ${body}${NC}"
        exit 1
    fi
    
    # Test GET /api/tasks/{id}
    response=$(curl -s -w "%{http_code}" "${TEST_URL}/api/tasks/${TASK_ID}")
    http_code=${response: -3}
    body=${response%???}
    
    if [ "${http_code}" = "200" ]; then
        echo -e "${GREEN}✅ GET /api/tasks/{id} working${NC}"
    else
        echo -e "${RED}❌ GET /api/tasks/{id} failed (HTTP ${http_code})${NC}"
        exit 1
    fi
    
    # Test PUT /api/tasks/{id}
    local updated_task='{"title":"Updated Test Task","description":"Updated description","priority":"high","status":"completed"}'
    response=$(curl -s -w "%{http_code}" -X PUT -H "Content-Type: application/json" -d "${updated_task}" "${TEST_URL}/api/tasks/${TASK_ID}")
    http_code=${response: -3}
    
    if [ "${http_code}" = "200" ]; then
        echo -e "${GREEN}✅ PUT /api/tasks/{id} working${NC}"
    else
        echo -e "${RED}❌ PUT /api/tasks/{id} failed (HTTP ${http_code})${NC}"
        exit 1
    fi
    
    # Test DELETE /api/tasks/{id}
    response=$(curl -s -w "%{http_code}" -X DELETE "${TEST_URL}/api/tasks/${TASK_ID}")
    http_code=${response: -3}
    
    if [ "${http_code}" = "200" ]; then
        echo -e "${GREEN}✅ DELETE /api/tasks/{id} working${NC}"
    else
        echo -e "${RED}❌ DELETE /api/tasks/{id} failed (HTTP ${http_code})${NC}"
        exit 1
    fi
    
    # Verify task is deleted
    response=$(curl -s -w "%{http_code}" "${TEST_URL}/api/tasks/${TASK_ID}")
    http_code=${response: -3}
    
    if [ "${http_code}" = "404" ]; then
        echo -e "${GREEN}✅ Task deletion verified${NC}"
    else
        echo -e "${RED}❌ Task not properly deleted (HTTP ${http_code})${NC}"
        exit 1
    fi
}

# Function to test CORS headers
test_cors() {
    echo -e "${YELLOW}🌐 Testing CORS headers...${NC}"
    
    local response=$(curl -s -H "Origin: http://localhost:3000" -H "Access-Control-Request-Method: GET" -H "Access-Control-Request-Headers: Content-Type" -X OPTIONS -I "${TEST_URL}/api/tasks")
    
    if echo "${response}" | grep -i "access-control-allow-origin" > /dev/null; then
        echo -e "${GREEN}✅ CORS headers present${NC}"
    else
        echo -e "${RED}❌ CORS headers missing${NC}"
        exit 1
    fi
}

# Function to test error handling
test_error_handling() {
    echo -e "${YELLOW}❌ Testing error handling...${NC}"
    
    # Test 404 for non-existent endpoint
    local response=$(curl -s -w "%{http_code}" "${TEST_URL}/api/nonexistent")
    local http_code=${response: -3}
    
    if [ "${http_code}" = "404" ]; then
        echo -e "${GREEN}✅ 404 handling working${NC}"
    else
        echo -e "${RED}❌ 404 handling failed (HTTP ${http_code})${NC}"
        exit 1
    fi
    
    # Test 404 for non-existent task
    response=$(curl -s -w "%{http_code}" "${TEST_URL}/api/tasks/nonexistent-id")
    http_code=${response: -3}
    
    if [ "${http_code}" = "404" ]; then
        echo -e "${GREEN}✅ Task 404 handling working${NC}"
    else
        echo -e "${RED}❌ Task 404 handling failed (HTTP ${http_code})${NC}"
        exit 1
    fi
    
    # Test invalid JSON
    response=$(curl -s -w "%{http_code}" -X POST -H "Content-Type: application/json" -d "invalid json" "${TEST_URL}/api/tasks")
    http_code=${response: -3}
    
    if [ "${http_code}" = "400" ]; then
        echo -e "${GREEN}✅ Invalid JSON handling working${NC}"
    else
        echo -e "${RED}❌ Invalid JSON handling failed (HTTP ${http_code})${NC}"
        exit 1
    fi
}

# Function to test performance
test_performance() {
    echo -e "${YELLOW}⚡ Testing basic performance...${NC}"
    
    # Create multiple tasks quickly
    local start_time=$(date +%s%N)
    
    for i in {1..10}; do
        local task_data="{\"title\":\"Task ${i}\",\"description\":\"Description ${i}\",\"priority\":\"medium\",\"status\":\"pending\"}"
        curl -s -X POST -H "Content-Type: application/json" -d "${task_data}" "${TEST_URL}/api/tasks" > /dev/null
    done
    
    local end_time=$(date +%s%N)
    local duration=$((($end_time - $start_time) / 1000000)) # Convert to milliseconds
    
    echo -e "${GREEN}✅ Created 10 tasks in ${duration}ms${NC}"
    
    # Test bulk retrieval
    start_time=$(date +%s%N)
    local response=$(curl -s "${TEST_URL}/api/tasks")
    end_time=$(date +%s%N)
    duration=$((($end_time - $start_time) / 1000000))
    
    local task_count=$(echo "${response}" | grep -o '"id"' | wc -l)
    echo -e "${GREEN}✅ Retrieved ${task_count} tasks in ${duration}ms${NC}"
}

# Function to generate test report
generate_report() {
    echo -e "${BLUE}📊 Test Report${NC}"
    echo -e "${BLUE}=============${NC}"
    echo ""
    echo -e "${GREEN}✅ All tests passed successfully!${NC}"
    echo ""
    echo "Test Coverage:"
    echo "  • Health endpoint"
    echo "  • Static file serving"
    echo "  • CRUD API operations"
    echo "  • CORS headers"
    echo "  • Error handling"
    echo "  • Basic performance"
    echo ""
    echo "VelocityTasks is ready for deployment!"
}

# Main test execution
main() {
    check_dependencies
    run_go_tests
    build_test_binary
    start_test_server
    
    echo ""
    test_health_endpoint
    test_static_files
    test_api_endpoints
    test_cors
    test_error_handling
    test_performance
    
    echo ""
    generate_report
    
    # Cleanup test binary
    rm -f ${APP_NAME}-test
}

# Run main function
main

echo -e "${GREEN}🎉 Test suite completed successfully!${NC}"
