#!/bin/bash
# RUV-FANN + HuskyCats Integrated Stack Bootstrap Script
# Creates a production-ready deployment with all services

set -euo pipefail

# Script metadata
SCRIPT_NAME="RUV-FANN + HuskyCats Bootstrap"
SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $*${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARN: $*${NC}" >&2
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*${NC}" >&2
}

success() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $*${NC}" >&2
}

# Configuration
COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-ruv-fann-integrated}"
DEPLOY_ENV="${DEPLOY_ENV:-production}"
DATA_ROOT="${DATA_ROOT:-$PROJECT_ROOT/data}"
CONFIG_ROOT="${CONFIG_ROOT:-$PROJECT_ROOT/config}"
LOGS_ROOT="${LOGS_ROOT:-$PROJECT_ROOT/logs}"

# Port configuration
FANN_CORE_PORT="${FANN_CORE_PORT:-8080}"
FANN_TRAINING_PORT="${FANN_TRAINING_PORT:-8082}"
FANN_INFERENCE_PORT="${FANN_INFERENCE_PORT:-8083}"
MCP_SERVER_PORT="${MCP_SERVER_PORT:-8084}"
SYNCTHING_GUI_PORT="${SYNCTHING_GUI_PORT:-8385}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
REDIS_PORT="${REDIS_PORT:-6379}"
PROMETHEUS_PORT="${PROMETHEUS_PORT:-9090}"
GRAFANA_PORT="${GRAFANA_PORT:-3000}"

# Generate secure secrets
generate_secret() {
    openssl rand -hex 32
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    for tool in podman podman-compose curl openssl jq; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check for claude-flow
    if ! command -v claude-flow >/dev/null 2>&1; then
        warn "claude-flow not found. MCP integration will be limited."
    fi
    
    # Check available resources
    local total_memory
    total_memory=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $total_memory -lt 16 ]]; then
        warn "System has less than 16GB RAM. Consider adjusting resource limits."
    fi
    
    # Check disk space
    local available_space
    available_space=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 10485760 ]]; then  # 10GB in KB
        warn "Less than 10GB disk space available. Consider freeing up space."
    fi
    
    success "Prerequisites check completed"
}

# Setup directory structure
setup_directories() {
    log "Setting up directory structure..."
    
    # Data directories
    mkdir -p "$DATA_ROOT"/{fann/{models,datasets,checkpoints,cache},huskycat/workspace,syncthing/{config,fann,repositories},postgres/{data,backups},redis/data,prometheus,grafana/{data,logs},validation/reports,shared}
    
    # Config directories
    mkdir -p "$CONFIG_ROOT"/{fann,huskycat,syncthing,postgres,prometheus/{rules},grafana/{provisioning/{datasources,dashboards,notifiers},dashboards}}
    
    # Logs directory
    mkdir -p "$LOGS_ROOT"/{fann,huskycat,syncthing,postgres,redis,prometheus,grafana}
    
    # Scripts directory
    mkdir -p "$PROJECT_ROOT/scripts"/{fann,huskycat,syncthing,monitoring,backup}
    
    success "Directory structure created"
}

# Generate environment configuration
generate_env_config() {
    log "Generating environment configuration..."
    
    local env_file="$PROJECT_ROOT/.env.production"
    
    # Generate secrets if not already present
    if [[ ! -f "$env_file" ]]; then
        cat > "$env_file" <<EOF
# RUV-FANN + HuskyCats Integrated Stack Configuration
# Generated on $(date -Iseconds)

# =============================================================================
# DEPLOYMENT CONFIGURATION
# =============================================================================
COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME
DEPLOY_ENV=$DEPLOY_ENV
DATA_ROOT=$DATA_ROOT
CONFIG_ROOT=$CONFIG_ROOT
LOGS_ROOT=$LOGS_ROOT

# =============================================================================
# PORT CONFIGURATION
# =============================================================================
FANN_CORE_PORT=$FANN_CORE_PORT
FANN_TRAINING_PORT=$FANN_TRAINING_PORT
FANN_INFERENCE_PORT=$FANN_INFERENCE_PORT
MCP_SERVER_PORT=$MCP_SERVER_PORT
SYNCTHING_GUI_PORT=$SYNCTHING_GUI_PORT
POSTGRES_PORT=$POSTGRES_PORT
REDIS_PORT=$REDIS_PORT
PROMETHEUS_PORT=$PROMETHEUS_PORT
GRAFANA_PORT=$GRAFANA_PORT

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================
SYNCTHING_API_KEY=$(generate_secret)
BEARER_TOKEN=$(generate_secret)
DB_PASSWORD=$(generate_password)
GRAFANA_ADMIN_PASSWORD=$(generate_password)

# =============================================================================
# DATABASE CONFIGURATION
# =============================================================================
DB_NAME=ruvfann
DB_USER=ruvfann

# =============================================================================
# FANN CONFIGURATION
# =============================================================================
RUST_LOG=info
FANN_GPU_ENABLED=true
FANN_WASM_THREADS=8
FANN_MODEL_CACHE_SIZE=1000
FANN_TRAINING_PARALLEL=true
TRAINING_QUEUE_SIZE=100
GPU_MEMORY_FRACTION=0.8
DISTRIBUTED_TRAINING=true
INFERENCE_BATCH_SIZE=32
INFERENCE_MAX_QUEUE=1000
INFERENCE_TIMEOUT=30
MODEL_CACHE_SIZE=1000
ENABLE_A_B_TESTING=true

# =============================================================================
# VALIDATION CONFIGURATION
# =============================================================================
VALIDATION_PARALLEL=true
SECURITY_SCANNING=true
AUTO_FIX_ENABLED=true
RATE_LIMIT_REQUESTS=1000
RATE_LIMIT_WINDOW=60
CORS_ORIGINS=*

# =============================================================================
# SYNCTHING CONFIGURATION
# =============================================================================
MESH_MODE=coordinator
FANN_SYNC_ENABLED=true
AUTO_ACCEPT_FOLDERS=true
ENABLE_RELAYS=true
ENABLE_NAT_TRAVERSAL=true
SYNC_INTERVAL=300
CLEANUP_INTERVAL=3600
CONFLICT_RESOLUTION=latest
MAX_SEND_KBPS=0
MAX_RECV_KBPS=0
RESCAN_INTERVAL=3600
FS_WATCHER_ENABLED=true
FS_WATCHER_DELAY=10

# =============================================================================
# MONITORING CONFIGURATION
# =============================================================================
LOG_LEVEL=info
PROMETHEUS_RETENTION_TIME=15d
PROMETHEUS_RETENTION_SIZE=10GB
GRAFANA_ADMIN_USER=admin

# =============================================================================
# CACHE CONFIGURATION
# =============================================================================
REDIS_MAX_MEMORY=4gb
VALIDATION_CACHE_TTL=3600
CHECKPOINT_INTERVAL=3600
DATASET_CACHE_SIZE=10000

# =============================================================================
# SECURITY AND TLS
# =============================================================================
TLS_ENABLED=false
ENABLE_CORS=true
AUTH_TOKEN_EXPIRY=86400

# =============================================================================
# RESOURCE LIMITS
# =============================================================================
MAX_VALIDATION_TIME=300
MAX_MEMORY_USAGE=4G
MAX_CPU_USAGE=4
WORKER_PROCESSES=4

# =============================================================================
# PODMAN/DOCKER CONFIGURATION
# =============================================================================
PODMAN_SOCKET=/run/podman/podman.sock

# =============================================================================
# CLAUDE-FLOW INTEGRATION
# =============================================================================
CLAUDE_FLOW_INTEGRATION=true
ENABLE_CLAUDE_INTEGRATION=true
MCP_AUTH_TOKEN=\${BEARER_TOKEN}

# =============================================================================
# OPTIONAL SERVICES
# =============================================================================
# Uncomment to enable optional services
# ENABLE_TRAEFIK=true
# ENABLE_FAIL2BAN=true
# TRAEFIK_HTTP_PORT=80
# TRAEFIK_HTTPS_PORT=443
# TRAEFIK_DASHBOARD_PORT=8080
# ACME_EMAIL=admin@ruv-fann.local
# TRAEFIK_LOG_LEVEL=INFO
EOF
        
        success "Environment configuration generated: $env_file"
        warn "IMPORTANT: Save the generated passwords and API keys securely!"
        
        # Display important credentials
        echo -e "\n${PURPLE}=== IMPORTANT CREDENTIALS ===${NC}"
        echo "Syncthing API Key: $(grep SYNCTHING_API_KEY "$env_file" | cut -d'=' -f2)"
        echo "Bearer Token: $(grep BEARER_TOKEN "$env_file" | grep -v MCP | cut -d'=' -f2)"
        echo "Database Password: $(grep DB_PASSWORD "$env_file" | cut -d'=' -f2)"
        echo "Grafana Admin Password: $(grep GRAFANA_ADMIN_PASSWORD "$env_file" | cut -d'=' -f2)"
        echo -e "${PURPLE}===============================${NC}\n"
        
    else
        log "Using existing environment configuration: $env_file"
    fi
    
    # Source the environment file
    set -a
    source "$env_file"
    set +a
}

# Generate configuration files
generate_configs() {
    log "Generating configuration files..."
    
    # Prometheus configuration
    cat > "$CONFIG_ROOT/prometheus/prometheus.yml" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'ruv-fann-monitor'
    environment: '$DEPLOY_ENV'

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'ruv-fann-core'
    static_configs:
      - targets: ['ruv-fann-core:8081']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'ruv-fann-training'
    static_configs:
      - targets: ['ruv-fann-training:8081']
    metrics_path: '/metrics'
    scrape_interval: 60s

  - job_name: 'ruv-fann-inference'
    static_configs:
      - targets: ['ruv-fann-inference:8081']
    metrics_path: '/metrics'
    scrape_interval: 10s

  - job_name: 'huskycat-mcp'
    static_configs:
      - targets: ['huskycat-mcp:8080']
    metrics_path: '/metrics'
    scrape_interval: 30s

  - job_name: 'syncthing-mesh'
    static_configs:
      - targets: ['syncthing-mesh:8384']
    metrics_path: '/rest/stats/device'
    scrape_interval: 60s
    params:
      format: ['prometheus']
      device: ['']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-db:5432']
    scrape_interval: 30s

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-cache:6379']
    scrape_interval: 30s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
    scrape_interval: 30s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []
EOF

    # PostgreSQL initialization script
    cat > "$CONFIG_ROOT/postgres/init-db.sql" <<EOF
-- RUV-FANN + HuskyCats Database Initialization

-- Create databases
CREATE DATABASE ruvfann_test;
CREATE DATABASE ruvfann_dev;

-- Create users
CREATE USER grafana WITH PASSWORD '$GRAFANA_ADMIN_PASSWORD';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE ruvfann TO ruvfann;
GRANT ALL PRIVILEGES ON DATABASE ruvfann TO grafana;
GRANT ALL PRIVILEGES ON DATABASE ruvfann_test TO ruvfann;
GRANT ALL PRIVILEGES ON DATABASE ruvfann_dev TO ruvfann;

-- Connect to main database
\c ruvfann;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS fann;
CREATE SCHEMA IF NOT EXISTS validation;
CREATE SCHEMA IF NOT EXISTS monitoring;
CREATE SCHEMA IF NOT EXISTS syncthing;

-- FANN tables
CREATE TABLE IF NOT EXISTS fann.models (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    version VARCHAR(50) NOT NULL,
    architecture JSONB NOT NULL,
    parameters BIGINT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    file_path TEXT,
    checksum VARCHAR(64),
    metadata JSONB,
    UNIQUE(name, version)
);

CREATE TABLE IF NOT EXISTS fann.training_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_id UUID REFERENCES fann.models(id),
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    config JSONB NOT NULL,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    metrics JSONB,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fann.inference_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    model_id UUID REFERENCES fann.models(id),
    input_data JSONB NOT NULL,
    output_data JSONB,
    processing_time_ms INTEGER,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Validation tables
CREATE TABLE IF NOT EXISTS validation.jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    repository_path TEXT NOT NULL,
    tools_used TEXT[] NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    results JSONB,
    started_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS validation.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id UUID REFERENCES validation.jobs(id),
    tool VARCHAR(100) NOT NULL,
    file_path TEXT NOT NULL,
    issues JSONB,
    severity VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Syncthing tables
CREATE TABLE IF NOT EXISTS syncthing.devices (
    id VARCHAR(64) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    addresses TEXT[],
    last_seen TIMESTAMP WITH TIME ZONE,
    sync_status VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS syncthing.folders (
    id VARCHAR(255) PRIMARY KEY,
    label VARCHAR(255) NOT NULL,
    path TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    devices TEXT[],
    sync_status VARCHAR(50),
    last_sync TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Monitoring tables
CREATE TABLE IF NOT EXISTS monitoring.metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service VARCHAR(100) NOT NULL,
    metric_name VARCHAR(255) NOT NULL,
    metric_value NUMERIC NOT NULL,
    labels JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_models_name_version ON fann.models(name, version);
CREATE INDEX IF NOT EXISTS idx_training_jobs_status ON fann.training_jobs(status);
CREATE INDEX IF NOT EXISTS idx_training_jobs_created_at ON fann.training_jobs(created_at);
CREATE INDEX IF NOT EXISTS idx_inference_requests_model_id ON fann.inference_requests(model_id);
CREATE INDEX IF NOT EXISTS idx_inference_requests_created_at ON fann.inference_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_validation_jobs_status ON validation.jobs(status);
CREATE INDEX IF NOT EXISTS idx_validation_reports_job_id ON validation.reports(job_id);
CREATE INDEX IF NOT EXISTS idx_syncthing_devices_last_seen ON syncthing.devices(last_seen);
CREATE INDEX IF NOT EXISTS idx_syncthing_folders_last_sync ON syncthing.folders(last_sync);
CREATE INDEX IF NOT EXISTS idx_monitoring_metrics_service_timestamp ON monitoring.metrics(service, timestamp);

-- Grant schema permissions
GRANT USAGE ON SCHEMA fann TO ruvfann;
GRANT ALL ON ALL TABLES IN SCHEMA fann TO ruvfann;
GRANT ALL ON ALL SEQUENCES IN SCHEMA fann TO ruvfann;

GRANT USAGE ON SCHEMA validation TO ruvfann;
GRANT ALL ON ALL TABLES IN SCHEMA validation TO ruvfann;
GRANT ALL ON ALL SEQUENCES IN SCHEMA validation TO ruvfann;

GRANT USAGE ON SCHEMA monitoring TO ruvfann;
GRANT ALL ON ALL TABLES IN SCHEMA monitoring TO ruvfann;
GRANT ALL ON ALL SEQUENCES IN SCHEMA monitoring TO ruvfann;

GRANT USAGE ON SCHEMA syncthing TO ruvfann;
GRANT ALL ON ALL TABLES IN SCHEMA syncthing TO ruvfann;
GRANT ALL ON ALL SEQUENCES IN SCHEMA syncthing TO ruvfann;

-- Grant permissions to grafana user
GRANT USAGE ON SCHEMA monitoring TO grafana;
GRANT SELECT ON ALL TABLES IN SCHEMA monitoring TO grafana;
GRANT SELECT ON ALL TABLES IN SCHEMA fann TO grafana;
GRANT SELECT ON ALL TABLES IN SCHEMA validation TO grafana;
GRANT SELECT ON ALL TABLES IN SCHEMA syncthing TO grafana;
EOF

    # PostgreSQL extensions
    cat > "$CONFIG_ROOT/postgres/extensions.sql" <<EOF
-- Install useful extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";
EOF

    # Grafana datasource provisioning
    mkdir -p "$CONFIG_ROOT/grafana/provisioning/datasources"
    cat > "$CONFIG_ROOT/grafana/provisioning/datasources/prometheus.yml" <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: "15s"
      queryTimeout: "60s"
      httpMethod: "POST"

  - name: PostgreSQL
    type: postgres
    access: proxy
    url: postgres-db:5432
    database: $DB_NAME
    user: grafana
    jsonData:
      sslmode: "disable"
      postgresVersion: 1500
      timescaledb: false
    secureJsonData:
      password: '$GRAFANA_ADMIN_PASSWORD'
    editable: false
EOF

    # Grafana dashboard provisioning
    mkdir -p "$CONFIG_ROOT/grafana/provisioning/dashboards"
    cat > "$CONFIG_ROOT/grafana/provisioning/dashboards/dashboards.yml" <<EOF
apiVersion: 1

providers:
  - name: 'RUV-FANN Dashboards'
    orgId: 1
    folder: 'RUV-FANN'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

    success "Configuration files generated"
}

# Setup file permissions
setup_permissions() {
    log "Setting up file permissions..."
    
    # Set ownership for data directories
    sudo chown -R 1000:1000 "$DATA_ROOT"/{syncthing,fann,huskycat}
    sudo chown -R 999:999 "$DATA_ROOT"/postgres
    sudo chown -R 472:472 "$DATA_ROOT"/grafana
    
    # Set proper permissions
    chmod -R 755 "$DATA_ROOT"
    chmod -R 755 "$CONFIG_ROOT"
    chmod -R 755 "$LOGS_ROOT"
    
    # Make scripts executable
    find "$PROJECT_ROOT/scripts" -name "*.sh" -exec chmod +x {} \;
    
    success "File permissions configured"
}

# Start the stack
start_stack() {
    log "Starting the integrated stack..."
    
    cd "$PROJECT_ROOT"
    
    # Pull images first
    log "Pulling container images..."
    podman-compose pull
    
    # Build custom images
    log "Building custom container images..."
    podman-compose build --parallel
    
    # Start core services first
    log "Starting database and cache services..."
    podman-compose up -d postgres-db redis-cache
    
    # Wait for database to be ready
    log "Waiting for database to be ready..."
    timeout 60 bash -c 'until podman exec ruv-fann-postgres pg_isready -U $DB_USER -d $DB_NAME; do sleep 2; done'
    
    # Start syncthing
    log "Starting Syncthing mesh coordinator..."
    podman-compose up -d syncthing-mesh
    
    # Wait for syncthing to be ready
    log "Waiting for Syncthing to be ready..."
    timeout 60 bash -c 'until curl -f -H "X-API-Key: $SYNCTHING_API_KEY" http://localhost:$SYNCTHING_GUI_PORT/rest/system/ping; do sleep 2; done'
    
    # Start FANN services
    log "Starting FANN neural network services..."
    podman-compose up -d ruv-fann-core ruv-fann-training ruv-fann-inference
    
    # Start validation services
    log "Starting HuskyCat validation services..."
    podman-compose up -d huskycat-mcp huskycat-validator
    
    # Start monitoring
    log "Starting monitoring services..."
    podman-compose up -d prometheus grafana
    
    success "Integrated stack started successfully!"
}

# Setup Claude-Flow integration
setup_claude_flow() {
    if ! command -v claude-flow >/dev/null 2>&1; then
        warn "claude-flow not found. Skipping MCP integration setup."
        return
    fi
    
    log "Setting up Claude-Flow MCP integration..."
    
    # Create MCP configuration
    local mcp_config="$CONFIG_ROOT/claude-mcp-config.json"
    cat > "$mcp_config" <<EOF
{
  "mcpServers": {
    "ruv-fann-integrated": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer $BEARER_TOKEN",
        "http://localhost:$MCP_SERVER_PORT/mcp"
      ],
      "env": {
        "FANN_CORE_URL": "http://localhost:$FANN_CORE_PORT",
        "FANN_TRAINING_URL": "http://localhost:$FANN_TRAINING_PORT",
        "FANN_INFERENCE_URL": "http://localhost:$FANN_INFERENCE_PORT",
        "SYNCTHING_URL": "http://localhost:$SYNCTHING_GUI_PORT",
        "SYNCTHING_API_KEY": "$SYNCTHING_API_KEY"
      }
    }
  },
  "features": {
    "fannIntegration": true,
    "validationIntegration": true,
    "syncthingIntegration": true,
    "distributedTraining": true,
    "realtimeInference": true,
    "codeValidation": true,
    "repositorySync": true
  },
  "tools": [
    {
      "name": "fann_create_model",
      "description": "Create a new FANN neural network model",
      "endpoint": "/api/v1/models",
      "method": "POST"
    },
    {
      "name": "fann_train_model",
      "description": "Start training a FANN model",
      "endpoint": "/api/v1/training/start",
      "method": "POST"
    },
    {
      "name": "fann_inference",
      "description": "Run inference on a FANN model",
      "endpoint": "/api/v1/inference",
      "method": "POST"
    },
    {
      "name": "validate_code",
      "description": "Validate code using HuskyCat tools",
      "endpoint": "/api/v1/validate",
      "method": "POST"
    },
    {
      "name": "sync_repository",
      "description": "Synchronize repository using Syncthing",
      "endpoint": "/api/v1/sync",
      "method": "POST"
    }
  ]
}
EOF
    
    # Add to Claude-Flow
    if claude-flow mcp add ruv-fann-integrated "$mcp_config"; then
        success "Claude-Flow MCP integration configured"
    else
        warn "Failed to configure Claude-Flow MCP integration"
    fi
}

# Health checks
run_health_checks() {
    log "Running health checks..."
    
    local failed_services=()
    
    # Check FANN Core
    if ! curl -f "http://localhost:$FANN_CORE_PORT/health" >/dev/null 2>&1; then
        failed_services+=("FANN Core")
    fi
    
    # Check MCP Server
    if ! curl -f "http://localhost:$MCP_SERVER_PORT/health" >/dev/null 2>&1; then
        failed_services+=("MCP Server")
    fi
    
    # Check Syncthing
    if ! curl -f -H "X-API-Key: $SYNCTHING_API_KEY" "http://localhost:$SYNCTHING_GUI_PORT/rest/system/ping" >/dev/null 2>&1; then
        failed_services+=("Syncthing")
    fi
    
    # Check Database
    if ! podman exec ruv-fann-postgres pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
        failed_services+=("PostgreSQL")
    fi
    
    # Check Redis
    if ! podman exec ruv-fann-redis redis-cli ping >/dev/null 2>&1; then
        failed_services+=("Redis")
    fi
    
    # Check Prometheus
    if ! curl -f "http://localhost:$PROMETHEUS_PORT/-/healthy" >/dev/null 2>&1; then
        failed_services+=("Prometheus")
    fi
    
    # Check Grafana
    if ! curl -f "http://localhost:$GRAFANA_PORT/api/health" >/dev/null 2>&1; then
        failed_services+=("Grafana")
    fi
    
    if [[ ${#failed_services[@]} -eq 0 ]]; then
        success "All services are healthy!"
    else
        error "Failed health checks for: ${failed_services[*]}"
        warn "Check logs with: podman-compose logs <service-name>"
    fi
}

# Display service information
display_service_info() {
    echo -e "\n${PURPLE}=== RUV-FANN + HuskyCats Integrated Stack ===${NC}"
    echo -e "${BLUE}Stack Status:${NC} $(podman-compose ps --format table)"
    echo ""
    echo -e "${BLUE}Service URLs:${NC}"
    echo "🧠 FANN Core API:        http://localhost:$FANN_CORE_PORT"
    echo "🏋️  FANN Training:        http://localhost:$FANN_TRAINING_PORT"
    echo "⚡ FANN Inference:       http://localhost:$FANN_INFERENCE_PORT"
    echo "🐱 HuskyCat MCP:         http://localhost:$MCP_SERVER_PORT"
    echo "🔄 Syncthing GUI:        http://localhost:$SYNCTHING_GUI_PORT"
    echo "🐘 PostgreSQL:           localhost:$POSTGRES_PORT"
    echo "🔴 Redis:                localhost:$REDIS_PORT"
    echo "📊 Prometheus:           http://localhost:$PROMETHEUS_PORT"
    echo "📈 Grafana:              http://localhost:$GRAFANA_PORT"
    echo ""
    echo -e "${BLUE}Grafana Login:${NC}"
    echo "Username: $GRAFANA_ADMIN_USER"
    echo "Password: $GRAFANA_ADMIN_PASSWORD"
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    echo "📋 View logs:            podman-compose logs -f <service>"
    echo "🔄 Restart service:      podman-compose restart <service>"
    echo "📊 Service status:       podman-compose ps"
    echo "🛑 Stop stack:           podman-compose down"
    echo "🗑️  Remove everything:    podman-compose down -v"
    echo ""
    echo -e "${BLUE}Claude-Flow Integration:${NC}"
    if command -v claude-flow >/dev/null 2>&1; then
        echo "✅ MCP server configured: ruv-fann-integrated"
        echo "🔧 Configuration file: $CONFIG_ROOT/claude-mcp-config.json"
    else
        echo "⚠️  Claude-Flow not installed - MCP integration unavailable"
    fi
    echo -e "${PURPLE}============================================${NC}\n"
}

# Cleanup function
cleanup() {
    if [[ -n "${1:-}" ]]; then
        error "Script interrupted. Cleaning up..."
        podman-compose down >/dev/null 2>&1 || true
    fi
}

# Main execution
main() {
    echo -e "${CYAN}$SCRIPT_NAME v$SCRIPT_VERSION${NC}"
    echo -e "${CYAN}Deploying integrated RUV-FANN + HuskyCats stack${NC}\n"
    
    # Set up signal handling
    trap 'cleanup 1' INT TERM
    
    # Execute setup steps
    check_prerequisites
    setup_directories
    generate_env_config
    generate_configs
    setup_permissions
    start_stack
    setup_claude_flow
    
    # Wait for services to stabilize
    log "Waiting for services to stabilize..."
    sleep 30
    
    run_health_checks
    display_service_info
    
    success "Bootstrap completed successfully!"
    success "Your integrated RUV-FANN + HuskyCats stack is ready!"
}

# Execute main function
main "$@"