# ruv-FANN Deployment Quick Start Guide

## 🚀 One-Command Deployment

The ruv-FANN stack has been optimized for single-command deployment with comprehensive automation:

```bash
# Complete deployment and setup
make quickstart
```

This command will:
- ✅ Build the optimized container
- ✅ Deploy all services (PostgreSQL, Redis, Syncthing, MCP Server)
- ✅ Initialize the Claude Flow integration
- ✅ Run health checks and validation
- ✅ Display service URLs and credentials

## 📋 Prerequisites

### Required Tools
- **Podman** (or Docker) - Container runtime
- **podman-compose** - Multi-container orchestration
- **curl** - HTTP client for health checks
- **jq** - JSON processing
- **nc** (netcat) - Network connectivity testing

### System Requirements
- **RAM**: Minimum 4GB, Recommended 8GB+
- **CPU**: 2+ cores, 4+ cores recommended
- **Storage**: Minimum 5GB free space
- **Ports**: 3000, 5432, 6379, 8384, 22000, 21027

### Installation Commands

#### macOS (Homebrew)
```bash
brew install podman podman-compose curl jq netcat
```

#### Ubuntu/Debian
```bash
sudo apt update
sudo apt install podman podman-compose curl jq netcat-openbsd
```

#### RHEL/CentOS/Fedora
```bash
sudo dnf install podman podman-compose curl jq nmap-ncat
```

## 🏗️ Deployment Options

### 1. Production Deployment (Default)
```bash
make deploy
```
- Optimized for performance and stability
- All services embedded in single container
- Persistent data volumes
- Health monitoring enabled

### 2. Development Deployment
```bash
make dev
```
- Hot reloading enabled
- Debug logging
- Development ports exposed
- Source code mounted for live editing

### 3. Custom Configuration
```bash
# Copy environment template
cp .env.example .env
# Edit configuration
nano .env
# Deploy with custom settings
make deploy
```

## 📊 Service Overview

| Service | Port | Description | Health Check |
|---------|------|-------------|--------------|
| **MCP Server** | 3000 | Claude Flow API & Tools | `curl http://localhost:3000/health` |
| **PostgreSQL** | 5432 | Neural models & session data | `pg_isready -h localhost -p 5432` |
| **Redis** | 6379 | Cache & real-time coordination | `redis-cli ping` |
| **Syncthing UI** | 8384 | P2P mesh synchronization | `curl http://localhost:8384` |
| **Syncthing Protocol** | 22000 | File synchronization | Network discovery |

### Default Credentials
- **PostgreSQL**: `fann` / `fann123` / `fanndb`
- **Redis**: No password (localhost only)
- **Syncthing**: Auto-generated API key

## 🔧 Management Commands

### Essential Commands
```bash
# Deploy and bootstrap
make quickstart           # Complete setup

# Service management
make deploy              # Production deployment
make dev                 # Development deployment
make stop                # Stop all services
make restart             # Restart services
make clean               # Full cleanup

# Monitoring
make status              # Service status
make health              # Comprehensive health check
make logs                # View real-time logs
make monitor             # Resource monitoring

# Maintenance
make backup              # Create data backup
make test                # Run validation tests
make shell               # Container shell access
```

### Advanced Commands
```bash
# Performance and analysis
make benchmark           # Run performance tests
make security            # Security scanning
make update              # Update to latest version

# Scaling and optimization
make scale               # Scale services
make bootstrap           # Re-initialize Claude Flow
```

## 🔗 Claude Flow Integration

### Automatic Integration
The `make quickstart` command automatically:
1. Initializes hierarchical swarm topology
2. Spawns essential agents (coordinator, researcher, coder, tester, reviewer, optimizer)
3. Loads neural models (claude-code-optimizer, lstm-coding-optimizer, etc.)
4. Configures memory persistence and caching
5. Sets up Syncthing mesh for FANN network synchronization
6. Enables WASM SIMD acceleration

### Manual Integration
If you need to re-bootstrap or customize:

```bash
# Run bootstrap script directly
./scripts/claude-flow-bootstrap.sh

# Or use API directly
curl -X POST http://localhost:3000/api/claude-flow/bootstrap \
  -H "Content-Type: application/json" \
  -d '{"topology":"hierarchical","maxAgents":12,"enableDAA":true}'
```

### Adding to Claude Desktop
```bash
# Add MCP server to Claude Desktop configuration
claude mcp add ruv-fann http://localhost:3000
```

## 🧪 Validation & Testing

### Health Check
```bash
make health
```
Performs comprehensive validation:
- ✅ Container status
- ✅ Database connectivity
- ✅ API endpoint responsiveness
- ✅ WASM SIMD acceleration
- ✅ Neural model readiness
- ✅ Memory persistence
- ✅ Integration tests

### API Testing
```bash
# Test core APIs
curl http://localhost:3000/api/tools
curl http://localhost:3000/api/agents
curl http://localhost:3000/api/neural/status

# Test WASM features
curl -X POST http://localhost:3000/api/wasm/test
```

## 🐛 Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check container status
podman ps -a

# View service logs
make logs

# Check resource usage
make status
```

#### Port Conflicts
If ports 3000, 5432, 6379, or 8384 are in use:
1. Edit `podman-compose.yaml`
2. Update port mappings
3. Redeploy: `make deploy`

#### Insufficient Resources
```bash
# Check disk space
df -h

# Check memory usage
free -h

# Monitor resource usage
make monitor
```

#### Database Connection Issues
```bash
# Reset database
make clean
make deploy

# Check database logs
podman logs ruv-fann-stack | grep postgres
```

### Performance Issues

#### Enable WASM SIMD
Ensure your CPU supports SIMD instructions:
```bash
# Check SIMD status
curl http://localhost:3000/api/wasm/status

# Enable SIMD if supported
curl -X POST http://localhost:3000/api/wasm/enable-simd
```

#### Optimize Memory Usage
```bash
# Configure memory limits in .env
REDIS_MAXMEMORY=512mb
NODE_OPTIONS=--max-old-space-size=2048
```

### Recovery Procedures

#### Complete Reset
```bash
make clean    # Stop and remove everything
make deploy   # Fresh deployment
```

#### Data Recovery
```bash
# Restore from backup
make restore

# Or rebuild with existing data
make build
make deploy
```

## 📈 Performance Metrics

### Expected Performance
- **Agent Spawn Time**: < 500ms
- **API Response Time**: < 100ms
- **WASM Execution**: 2.8-4.4x speedup with SIMD
- **Memory Usage**: ~4GB total
- **Boot Time**: ~45 seconds complete stack

### Monitoring
```bash
# Real-time metrics
make monitor

# Resource analysis
make status

# Performance benchmarks
make benchmark
```

## 🔒 Security Considerations

### Default Security
- Non-root container execution
- Network isolation
- Read-only filesystems where possible
- Secret management via environment variables

### Hardening
```bash
# Run security scan
make security

# Update to latest versions
make update

# Review logs for anomalies
make logs | grep -i error
```

## 🆘 Support

### Documentation
- **Architecture**: [DEPLOYMENT.md](DEPLOYMENT.md)
- **API Reference**: [ruv-swarm/docs/API_REFERENCE.md](../ruv-swarm/docs/API_REFERENCE.md)
- **Claude Integration**: [CLAUDE.md](../CLAUDE.md)

### Logs and Diagnostics
```bash
# Complete diagnostic
make health > health-report.txt

# Export logs
make logs > deployment.log

# System information
make status > system-status.txt
```

### Getting Help
1. Check this documentation
2. Review service logs: `make logs`
3. Run health check: `make health`
4. Check GitHub issues: [ruv-FANN Issues](https://github.com/ruvnet/ruv-FANN/issues)

---

## 🎯 Quick Reference

```bash
# Deploy everything
make quickstart

# Check if working
make health

# View running services  
make status

# Access logs
make logs

# Stop everything
make stop
```

**🎉 You're ready to use ruv-FANN with Claude Flow!**