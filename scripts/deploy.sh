#!/bin/bash
# ruv-FANN Production Deployment Script
# One-command deployment with health checks and validation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOY_MODE="${1:-production}"
TIMEOUT_SECONDS=300
HEALTH_CHECK_INTERVAL=5

echo -e "${CYAN}🚀 ruv-FANN Deployment Script${NC}"
echo -e "${CYAN}================================${NC}"
echo -e "Mode: ${YELLOW}$DEPLOY_MODE${NC}"
echo -e "Project Root: ${YELLOW}$PROJECT_ROOT${NC}"
echo ""

cd "$PROJECT_ROOT"

# Function to wait for service with timeout
wait_for_service() {
    local host=$1
    local port=$2
    local service=$3
    local timeout=${4:-60}
    
    echo -e "${YELLOW}⏳ Waiting for $service at $host:$port (timeout: ${timeout}s)...${NC}"
    
    local elapsed=0
    while ! nc -z "$host" "$port" 2>/dev/null; do
        if [ $elapsed -ge $timeout ]; then
            echo -e "${RED}❌ Timeout waiting for $service${NC}"
            return 1
        fi
        sleep 1
        elapsed=$((elapsed + 1))
        if [ $((elapsed % 10)) -eq 0 ]; then
            echo -e "${YELLOW}   Still waiting... (${elapsed}s elapsed)${NC}"
        fi
    done
    
    echo -e "${GREEN}✅ $service is ready!${NC}"
}

# Function to check HTTP endpoint
check_http_endpoint() {
    local url=$1
    local service=$2
    local timeout=${3:-30}
    
    echo -e "${YELLOW}🌐 Checking $service endpoint: $url${NC}"
    
    local elapsed=0
    while ! curl -s -f "$url" >/dev/null 2>&1; do
        if [ $elapsed -ge $timeout ]; then
            echo -e "${RED}❌ $service endpoint not responding${NC}"
            return 1
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    echo -e "${GREEN}✅ $service endpoint is healthy!${NC}"
}

# Pre-deployment checks
echo -e "${BLUE}📋 Pre-deployment checks${NC}"
echo "========================="

# Check required tools
for tool in podman podman-compose curl jq nc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo -e "${RED}❌ Required tool not found: $tool${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✅ All required tools available${NC}"

# Check disk space (minimum 5GB)
available_space=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
required_space=5242880  # 5GB in KB
if [ "$available_space" -lt "$required_space" ]; then
    echo -e "${RED}❌ Insufficient disk space. Required: 5GB, Available: $((available_space/1024/1024))GB${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Sufficient disk space available${NC}"

# Initialize data directories
echo -e "${BLUE}📁 Initializing data directories${NC}"
make init-data

# Build and deploy
echo ""
echo -e "${BLUE}🏗️  Building and deploying${NC}"
echo "=========================="

if [ "$DEPLOY_MODE" = "development" ] || [ "$DEPLOY_MODE" = "dev" ]; then
    echo -e "${YELLOW}🛠️  Starting development deployment...${NC}"
    make dev
else
    echo -e "${YELLOW}🚀 Starting production deployment...${NC}"
    make deploy
fi

# Wait for services to start
echo ""
echo -e "${BLUE}⏳ Waiting for services to initialize${NC}"
echo "===================================="

# Wait for database services first
wait_for_service localhost 5432 "PostgreSQL" 90
wait_for_service localhost 6379 "Redis" 60

# Wait for application services
wait_for_service localhost 3000 "MCP Server" 120
wait_for_service localhost 8384 "Syncthing UI" 60

# Health checks
echo ""
echo -e "${BLUE}🏥 Running health checks${NC}"
echo "======================="

# Check MCP Server API
check_http_endpoint "http://localhost:3000/health" "MCP Server Health"
check_http_endpoint "http://localhost:3000/api/tools" "MCP Tools API"

# Check Syncthing
check_http_endpoint "http://localhost:8384" "Syncthing Web UI"

# Database connectivity checks
echo -e "${YELLOW}🗃️  Testing database connectivity...${NC}"
if pg_isready -h localhost -p 5432 -U fann >/dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL connection successful${NC}"
else
    echo -e "${RED}❌ PostgreSQL connection failed${NC}"
fi

if redis-cli -p 6379 ping >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Redis connection successful${NC}"
else
    echo -e "${RED}❌ Redis connection failed${NC}"
fi

# Claude Flow bootstrap
echo ""
echo -e "${BLUE}🤖 Bootstrapping Claude Flow integration${NC}"
echo "========================================"

# Wait a bit more for MCP server to fully initialize
sleep 10

bootstrap_response=$(curl -s -X POST http://localhost:3000/api/claude-flow/bootstrap \
    -H "Content-Type: application/json" \
    -d '{
        "config": {
            "topology": "hierarchical",
            "maxAgents": 12,
            "enableDAA": true,
            "enableNeural": true,
            "enableSIMD": true,
            "persistence": true
        }
    }' | jq -r '.status // "error"' 2>/dev/null || echo "error")

if [ "$bootstrap_response" = "success" ] || [ "$bootstrap_response" = "ready" ]; then
    echo -e "${GREEN}✅ Claude Flow integration successful${NC}"
else
    echo -e "${YELLOW}⚠️  Claude Flow bootstrap may need manual intervention${NC}"
fi

# Performance validation
echo ""
echo -e "${BLUE}⚡ Performance validation${NC}"
echo "======================="

# Test WASM SIMD acceleration
wasm_test=$(curl -s -X POST http://localhost:3000/api/wasm/test | jq -r '.simd_enabled // false' 2>/dev/null || echo "false")
if [ "$wasm_test" = "true" ]; then
    echo -e "${GREEN}✅ WASM SIMD acceleration enabled${NC}"
else
    echo -e "${YELLOW}⚠️  WASM SIMD not detected (performance may be reduced)${NC}"
fi

# Test neural models
neural_test=$(curl -s -X POST http://localhost:3000/api/neural/health | jq -r '.status // "error"' 2>/dev/null || echo "error")
if [ "$neural_test" = "ready" ]; then
    echo -e "${GREEN}✅ Neural models initialized${NC}"
else
    echo -e "${YELLOW}⚠️  Neural models may still be loading${NC}"
fi

# Final status report
echo ""
echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${PURPLE}📊 Service URLs:${NC}"
echo -e "   ${CYAN}MCP Server:${NC}    http://localhost:3000"
echo -e "   ${CYAN}Health Check:${NC}  http://localhost:3000/health"
echo -e "   ${CYAN}API Tools:${NC}     http://localhost:3000/api/tools"
echo -e "   ${CYAN}Syncthing UI:${NC}  http://localhost:8384"
echo ""
echo -e "${PURPLE}🗄️  Database Connections:${NC}"
echo -e "   ${CYAN}PostgreSQL:${NC}    localhost:5432 (fann/fann123)"
echo -e "   ${CYAN}Redis:${NC}         localhost:6379"
echo ""
echo -e "${PURPLE}🛠️  Management Commands:${NC}"
echo -e "   ${CYAN}View Logs:${NC}     make logs"
echo -e "   ${CYAN}Check Status:${NC}  make status"
echo -e "   ${CYAN}Run Tests:${NC}     make test"
echo -e "   ${CYAN}Shell Access:${NC}  make shell"
echo -e "   ${CYAN}Stop Services:${NC} make stop"
echo ""
echo -e "${GREEN}ruv-FANN is ready for Claude Flow integration!${NC}"

# Optional: Show system status
echo ""
read -p "Show system status? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    make status
fi