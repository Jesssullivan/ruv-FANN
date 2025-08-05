# Deployment Guide

## Quick Deployment

### 1. Single Command Deployment

```bash
make deploy
```

This single command will:
1. Build the consolidated container with all services
2. Start PostgreSQL, Redis, Syncthing, and MCP Server
3. Initialize database schemas
4. Set up persistent volumes
5. Configure networking

### 2. Claude Flow Integration

```bash
# Install Claude Flow alpha
npm install -g claude-flow@alpha

# Bootstrap integration
make bootstrap

# Or use the full script
./scripts/claude-flow-integrated-bootstrap.sh
```

### 🏗️ Service Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FANN Core     │    │   FANN Training │    │ FANN Inference  │
│   Port: 8080    │    │   Port: 8082    │    │   Port: 8083    │
│   Neural Engine │    │   Model Training│    │  Real-time AI   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  HuskyCat MCP   │    │ HuskyCat Valid. │    │ Syncthing Mesh  │
│   Port: 8084    │    │   Validation    │    │   Port: 8385    │
│   Claude Bridge │    │   Code Quality  │    │ Network Sync    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │     Redis       │    │    Grafana      │
│   Port: 5432    │    │   Port: 6379    │    │   Port: 3000    │
│    Database     │    │     Cache       │    │   Monitoring    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🛠️ Deployment Options

### Option 1: Local Development (Podman-Compose)

**Requirements:**
- 16GB+ RAM
- 50GB+ disk space
- Podman 4.0+
- podman-compose

**Deploy:**
```bash
# Quick deployment
./scripts/bootstrap-integrated-stack.sh

# Manual deployment
podman-compose up -d
```

### Option 2: Kubernetes Production

**Requirements:**
- Kubernetes 1.25+
- Istio Service Mesh
- Prometheus + Grafana
- 100GB+ persistent storage

**Deploy:**
```bash
# Create namespace and secrets
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secrets.yaml

# Deploy services with HPA
kubectl apply -f k8s/deployments/
kubectl apply -f k8s/services/
kubectl apply -f k8s/hpa-configurations.yaml

# Configure service mesh
kubectl apply -f k8s/service-mesh.yaml
```

## 🔧 Configuration

### Environment Variables

Create `.env.production` with:

```bash
# === CORE CONFIGURATION ===
COMPOSE_PROJECT_NAME=ruv-fann-integrated
DEPLOY_ENV=production

# === SERVICE PORTS ===
FANN_CORE_PORT=8080
FANN_TRAINING_PORT=8082
FANN_INFERENCE_PORT=8083
MCP_SERVER_PORT=8084
SYNCTHING_GUI_PORT=8385

# === SECURITY (Generate with bootstrap script) ===
SYNCTHING_API_KEY=<generated-32-char-hex>
BEARER_TOKEN=<generated-32-char-hex>
DB_PASSWORD=<generated-password>
GRAFANA_ADMIN_PASSWORD=<generated-password>

# === FANN CONFIGURATION ===
FANN_GPU_ENABLED=true
FANN_WASM_THREADS=8
DISTRIBUTED_TRAINING=true
INFERENCE_BATCH_SIZE=32

# === VALIDATION CONFIGURATION ===
VALIDATION_PARALLEL=true
SECURITY_SCANNING=true
AUTO_FIX_ENABLED=true

# === SYNCTHING CONFIGURATION ===
MESH_MODE=coordinator
FANN_SYNC_ENABLED=true
SYNC_INTERVAL=300
```

### Resource Requirements

| Service | CPU | Memory | Storage | Scaling |
|---------|-----|---------|---------|---------|
| FANN Core | 2-8 cores | 4-16GB | 50GB | HPA 2-10 |
| FANN Training | 4-16 cores | 8-64GB | 500GB | HPA 1-5 |
| FANN Inference | 1-4 cores | 2-8GB | 20GB | HPA 3-50 |
| HuskyCat MCP | 2-4 cores | 2-4GB | 10GB | HPA 2-15 |
| HuskyCat Validator | 2-8 cores | 4-8GB | 20GB | HPA 2-20 |
| Syncthing Mesh | 1-2 cores | 1-2GB | 1TB | Fixed 1 |

## 📊 Monitoring & Observability

### Grafana Dashboards

Access: `http://localhost:3000`
- Username: `admin`
- Password: `<from environment file>`

**Available Dashboards:**
- FANN Neural Network Metrics
- Training Job Progress
- Inference Performance
- Code Validation Statistics
- Syncthing Network Status
- System Resource Usage

### Prometheus Metrics

Access: `http://localhost:9090`

**Key Metrics:**
- `neural_network_queue_size` - Core processing queue
- `inference_requests_per_second` - Inference throughput
- `training_job_duration_seconds` - Training progress
- `validation_request_queue_size` - Validation backlog
- `syncthing_folder_sync_completion_percentage` - Sync status

### Health Endpoints

| Service | Health Check |
|---------|--------------|
| FANN Core | `GET /health` |
| FANN Training | `GET /health` |
| FANN Inference | `GET /health` |
| HuskyCat MCP | `GET /health` |
| Syncthing | `GET /rest/system/ping` |

## 🔄 Syncthing Network Synchronization

### Folder Structure

```
/var/syncthing/
├── fann/
│   ├── models/          # Neural network models
│   └── datasets/        # Training datasets
├── repositories/        # Code repositories
└── shared/             # Shared workspace
```

### Sync Configuration

- **Models**: Automatic sync every 1 hour
- **Datasets**: Automatic sync every 2 hours  
- **Repositories**: Real-time sync (5 second delay)
- **Conflict Resolution**: Latest timestamp wins
- **Versioning**: Keep last 10 versions

### Adding New Devices

```bash
# Get device ID
curl -H "X-API-Key: $SYNCTHING_API_KEY" \
     http://localhost:8385/rest/system/status | jq -r '.myID'

# Add device via API or Web UI
open http://localhost:8385
```

## 🤖 Claude-Flow MCP Integration

### Setup

```bash
# 1. Install Claude-Flow (if not already installed)
npm install -g @anthropic/claude-flow@alpha

# 2. Bootstrap MCP integration
./scripts/claude-flow-mcp-bootstrap.sh

# 3. Restart Claude Desktop
```

### Available Tools

| Tool | Description | Usage |
|------|-------------|-------|
| `fann_create_neural_network` | Create new neural network | Architecture design |
| `fann_train_network` | Start training job | Model training |
| `fann_inference` | Run inference | Real-time predictions |
| `huskycat_validate_code` | Validate code quality | Code review |
| `syncthing_sync_repository` | Sync repositories | Version control |
| `system_health_check` | Check system status | Monitoring |

### Example Usage

```javascript
// In Claude Desktop
@ruv-fann-integrated fann_create_neural_network {
  "name": "image_classifier",
  "layers": [784, 128, 64, 10],
  "activation": "relu",
  "learning_rate": 0.001
}
```

## 🚢 Production Deployment

### Kubernetes with Helm

```bash
# 1. Add Helm repository
helm repo add ruv-fann https://charts.ruv-fann.io
helm repo update

# 2. Install with production values
helm install ruv-fann-prod ruv-fann/integrated-stack \
  --namespace ruv-fann \
  --create-namespace \
  --values values-production.yaml

# 3. Configure Istio service mesh
kubectl apply -f k8s/service-mesh.yaml
```

### Horizontal Pod Autoscaling

- **FANN Core**: Scales 2-10 pods based on queue size
- **FANN Inference**: Scales 3-50 pods based on RPS
- **HuskyCat Services**: Scales 2-20 pods based on CPU/memory
- **Custom Metrics**: Neural network specific metrics

### Security Considerations

- **mTLS**: All service-to-service communication encrypted
- **RBAC**: Role-based access control for all components
- **Network Policies**: Restrict inter-pod communication
- **Secrets Management**: Kubernetes secrets + external vault
- **Container Security**: Non-root containers, read-only filesystems

## 🔍 Troubleshooting

### Common Issues

**Service won't start:**
```bash
# Check logs
podman-compose logs <service-name>

# Check resources
docker stats

# Restart specific service
podman-compose restart <service-name>
```

**Database connection issues:**
```bash
# Test database connection
podman exec ruv-fann-postgres pg_isready -U ruvfann

# Reset database
podman-compose down postgres-db
podman volume rm ruv-fann-integrated_postgres-data
podman-compose up -d postgres-db
```

**Syncthing sync problems:**
```bash
# Check sync status
curl -H "X-API-Key: $SYNCTHING_API_KEY" \
     http://localhost:8385/rest/db/status

# Force rescan
curl -X POST -H "X-API-Key: $SYNCTHING_API_KEY" \
     "http://localhost:8385/rest/db/scan?folder=fann-models"
```

**Claude MCP not working:**
```bash
# Test MCP server
cd scripts && node mcp-server-integrated.js

# Check Claude Desktop logs
tail -f ~/.config/Claude\ Desktop/logs/main.log
```

### Performance Tuning

**FANN Training Optimization:**
- Increase `FANN_WASM_THREADS` for more parallelism
- Enable `DISTRIBUTED_TRAINING` for multi-node setups
- Adjust `GPU_MEMORY_FRACTION` based on available GPU memory

**Inference Performance:**
- Increase `INFERENCE_BATCH_SIZE` for higher throughput
- Deploy multiple inference replicas
- Use model caching with Redis

**Validation Performance:**
- Enable `VALIDATION_PARALLEL` for concurrent validation
- Increase `WORKER_PROCESSES` for CPU-intensive validation
- Use SSD storage for validation workspace

## 📚 Additional Resources

- [Architecture Design Document](docs/k8s-architecture-design.md)
- [API Documentation](docs/api-reference.md)
- [Development Guide](docs/development.md)
- [Security Best Practices](docs/security.md)
- [Performance Tuning Guide](docs/performance.md)

## 🎯 Next Steps

1. **Scale Up**: Add more worker nodes for distributed training
2. **Optimize**: Fine-tune neural network architectures
3. **Integrate**: Connect with CI/CD pipelines
4. **Monitor**: Set up advanced alerting and monitoring
5. **Extend**: Add custom neural network layers and operations

---

**🎉 Your integrated RUV-FANN + HuskyCats stack is ready for production neural network operations with comprehensive code validation and seamless Claude integration!**