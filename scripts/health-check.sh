#!/bin/bash
# ruv-FANN Comprehensive Health Check Script
# Validates all services and components

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MCP_SERVER_URL="http://localhost:3000"
POSTGRES_HOST="localhost"
POSTGRES_PORT="5432"
POSTGRES_USER="fann"
REDIS_HOST="localhost"
REDIS_PORT="6379"
SYNCTHING_URL="http://localhost:8384"

# Health check counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Function to perform health check
check_service() {
    local service_name=$1
    local check_command=$2
    local expected_result=${3:-"0"}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -n "  ⏳ Checking $service_name... "
    
    if eval "$check_command" >/dev/null 2>&1; then
        if [ "$expected_result" = "0" ]; then
            echo -e "${GREEN}✅ PASS${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            return 0
        else
            echo -e "${RED}❌ FAIL${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            return 1
        fi
    else
        echo -e "${RED}❌ FAIL${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to check HTTP endpoint
check_http() {
    local service_name=$1
    local url=$2
    local expected_status=${3:-"200"}
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -n "  🌐 Checking $service_name HTTP... "
    
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS ($status_code)${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL ($status_code)${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

# Function to check JSON API response
check_json_api() {
    local service_name=$1
    local url=$2
    local expected_key=$3
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -n "  📊 Checking $service_name API... "
    
    local response=$(curl -s "$url" 2>/dev/null | jq -r ".$expected_key // \"error\"" 2>/dev/null || echo "error")
    
    if [ "$response" != "error" ] && [ "$response" != "null" ]; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        return 1
    fi
}

echo -e "${BLUE}🏥 ruv-FANN Comprehensive Health Check${NC}"
echo -e "${BLUE}=====================================:${NC}"
echo ""

# Container health
echo -e "${YELLOW}🐳 Container Status${NC}"
if command -v podman >/dev/null 2>&1; then
    container_status=$(podman ps --filter "name=ruv-fann" --format "{{.Status}}" 2>/dev/null | head -1)
    if [[ "$container_status" == *"Up"* ]]; then
        echo -e "  ${GREEN}✅ ruv-fann-stack container is running${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  ${RED}❌ ruv-fann-stack container is not running${NC}"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
else
    echo -e "  ${YELLOW}⚠️  Podman not available for container status check${NC}"
fi

echo ""

# Database services
echo -e "${YELLOW}🗄️  Database Services${NC}"
check_service "PostgreSQL port" "nc -z $POSTGRES_HOST $POSTGRES_PORT"
if command -v pg_isready >/dev/null 2>&1; then
    check_service "PostgreSQL ready" "pg_isready -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER"
fi

check_service "Redis port" "nc -z $REDIS_HOST $REDIS_PORT"
if command -v redis-cli >/dev/null 2>&1; then
    check_service "Redis ping" "redis-cli -p $REDIS_PORT ping | grep -q PONG"
fi

echo ""

# Core services
echo -e "${YELLOW}🚀 Core Services${NC}"
check_service "MCP Server port" "nc -z localhost 3000"
check_http "MCP Health" "$MCP_SERVER_URL/health"
check_service "Syncthing port" "nc -z localhost 8384"
check_http "Syncthing UI" "$SYNCTHING_URL"

echo ""

# API endpoints
echo -e "${YELLOW}🔌 API Endpoints${NC}"
check_json_api "MCP Tools" "$MCP_SERVER_URL/api/tools" "length"
check_json_api "MCP Agents" "$MCP_SERVER_URL/api/agents" "length"
check_json_api "Neural Status" "$MCP_SERVER_URL/api/neural/status" "status"
check_json_api "WASM Status" "$MCP_SERVER_URL/api/wasm/status" "simd_enabled"

echo ""

# Performance checks
echo -e "${YELLOW}⚡ Performance Features${NC}"

# WASM SIMD check
wasm_simd=$(curl -s "$MCP_SERVER_URL/api/wasm/status" 2>/dev/null | jq -r '.simd_enabled // false' 2>/dev/null || echo "false")
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ "$wasm_simd" = "true" ]; then
    echo -e "  ${GREEN}✅ WASM SIMD acceleration enabled${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${YELLOW}⚠️  WASM SIMD not detected${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Neural models check
neural_status=$(curl -s "$MCP_SERVER_URL/api/neural/status" 2>/dev/null | jq -r '.status // "error"' 2>/dev/null || echo "error")
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ "$neural_status" = "ready" ]; then
    echo -e "  ${GREEN}✅ Neural models initialized${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${YELLOW}⚠️  Neural models not ready${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Memory persistence check
memory_status=$(curl -s "$MCP_SERVER_URL/api/memory/status" 2>/dev/null | jq -r '.persistence // false' 2>/dev/null || echo "false")
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ "$memory_status" = "true" ]; then
    echo -e "  ${GREEN}✅ Memory persistence active${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${YELLOW}⚠️  Memory persistence not configured${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""

# File system checks
echo -e "${YELLOW}📁 File System${NC}"
check_service "Data directory" "test -d /Users/jsullivan2/git/ruv-FANN/data"
check_service "Models directory" "test -d /Users/jsullivan2/git/ruv-FANN/data/models"
check_service "Logs directory" "test -d /Users/jsullivan2/git/ruv-FANN/data/logs"

# Check disk space (warn if less than 1GB)
available_kb=$(df /Users/jsullivan2/git/ruv-FANN/data 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
available_gb=$((available_kb / 1024 / 1024))
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ "$available_gb" -gt 1 ]; then
    echo -e "  ${GREEN}✅ Sufficient disk space (${available_gb}GB)${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${RED}❌ Low disk space (${available_gb}GB)${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""

# Integration tests
echo -e "${YELLOW}🧪 Integration Tests${NC}"

# Test swarm initialization
swarm_test=$(curl -s -X POST "$MCP_SERVER_URL/api/swarm/status" 2>/dev/null | jq -r '.status // "error"' 2>/dev/null || echo "error")
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ "$swarm_test" != "error" ]; then
    echo -e "  ${GREEN}✅ Swarm integration working${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${RED}❌ Swarm integration failed${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

# Test memory operations
memory_test=$(curl -s -X POST "$MCP_SERVER_URL/api/memory/test" \
    -H "Content-Type: application/json" \
    -d '{"key":"health-check","value":"test","ttl":60}' 2>/dev/null | jq -r '.status // "error"' 2>/dev/null || echo "error")
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ "$memory_test" = "stored" ] || [ "$memory_test" = "success" ]; then
    echo -e "  ${GREEN}✅ Memory operations working${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  ${RED}❌ Memory operations failed${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi

echo ""

# Summary
echo -e "${BLUE}📋 Health Check Summary${NC}"
echo -e "${BLUE}======================:${NC}"
echo -e "Total Checks: ${BLUE}$TOTAL_CHECKS${NC}"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Failed: ${RED}$FAILED_CHECKS${NC}"

if [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "\n${GREEN}🎉 All health checks passed! ruv-FANN is fully operational.${NC}"
    exit 0
elif [ $FAILED_CHECKS -lt 3 ]; then
    echo -e "\n${YELLOW}⚠️  Minor issues detected. ruv-FANN is mostly operational.${NC}"
    exit 1
else
    echo -e "\n${RED}❌ Multiple failures detected. ruv-FANN needs attention.${NC}"
    echo -e "\nTroubleshooting steps:"
    echo -e "1. Check service logs: make logs"
    echo -e "2. Restart services: make restart"
    echo -e "3. Check system resources: make status"
    exit 2
fi