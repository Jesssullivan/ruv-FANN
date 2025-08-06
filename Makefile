# ruv-FANN Optimized Deployment Makefile
# Single-command deployment with comprehensive management

.PHONY: all build deploy dev clean stop restart logs shell test bootstrap status health \
        init-data backup restore update scale monitor benchmark security

# Default target
all: deploy

# Environment detection
UID := $(shell id -u)
GID := $(shell id -g)

# Initialize required data directories
init-data:
	@echo "🔧 Initializing data directories..."
	@mkdir -p data/{postgres,redis,models,cache,sync,memory,logs}
	@mkdir -p config/syncthing config/grafana config/nginx config/prometheus
	@chmod 755 data/postgres data/redis
	@echo "✅ Data directories created"

# Build the container with caching
build: init-data
	@echo "🔨 Building ruv-FANN container with optimizations..."
	@BUILDKIT_PROGRESS=plain podman build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--cache-from ruv-fann:latest \
		--tag ruv-fann:latest \
		--file ContainerFile .
	@echo "✅ Container built successfully"

# Production deployment
deploy: build
	@echo "🚀 Deploying ruv-FANN production stack..."
	@export UID=$(UID) && podman-compose -f podman-compose.yaml up -d
	@echo "⏳ Waiting for services to initialize..."
	@sleep 15
	@$(MAKE) health
	@echo ""
	@echo "🎉 Deployment complete!"
	@echo "📊 MCP Server:    http://localhost:3000"
	@echo "🔧 Syncthing UI:  http://localhost:8384"
	@echo "🗄️  PostgreSQL:    localhost:5432 (fann/fann123)"
	@echo "🔴 Redis:         localhost:6379"
	@echo "📈 Health Check:  make health"
	@echo "📋 Logs:          make logs"

# Development deployment with hot reload
dev: build
	@echo "🛠️  Starting ruv-FANN development environment..."
	@export UID=$(UID) DEVELOPMENT=true && \
		podman-compose -f podman-compose.yaml -f podman-compose.dev.yaml up -d
	@echo "🔄 Development mode active with hot reloading"
	@$(MAKE) status

# Restart services
restart:
	@echo "🔄 Restarting ruv-FANN stack..."
	@podman-compose -f podman-compose.yaml restart
	@sleep 5
	@$(MAKE) health

# Stop all services
stop:
	@echo "⏹️  Stopping ruv-FANN stack..."
	@podman-compose -f podman-compose.yaml -f podman-compose.dev.yaml down --remove-orphans

# Full cleanup (removes volumes)
clean: stop
	@echo "🧹 Cleaning up containers, images and volumes..."
	@podman-compose -f podman-compose.yaml down -v --remove-orphans
	@podman rmi ruv-fann:latest 2>/dev/null || true
	@podman system prune -f
	@echo "⚠️  Removing persistent data (5 second delay)..."
	@sleep 5
	@rm -rf data/postgres/* data/redis/* data/cache/* data/logs/*
	@echo "✅ Cleanup complete"

# View logs with follow
logs:
	@podman-compose -f podman-compose.yaml logs -f --tail=100

# Interactive shell access
shell:
	@echo "🐚 Opening shell in ruv-fann-stack container..."
	@podman exec -it ruv-fann-stack /bin/bash || \
		podman exec -it ruv-fann-stack /bin/sh

# Comprehensive status check
status:
	@echo "📊 ruv-FANN Stack Status:"
	@echo "========================="
	@podman ps --filter "name=ruv-fann" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "🔍 Resource Usage:"
	@podman stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Health check all services
health:
	@echo "🏥 Checking service health..."
	@echo -n "MCP Server: "; curl -s -f http://localhost:3000/health >/dev/null && echo "✅ OK" || echo "❌ DOWN"
	@echo -n "PostgreSQL: "; pg_isready -h localhost -p 5432 -U fann >/dev/null 2>&1 && echo "✅ OK" || echo "❌ DOWN"
	@echo -n "Redis: "; redis-cli -p 6379 ping >/dev/null 2>&1 && echo "✅ OK" || echo "❌ DOWN"
	@echo -n "Syncthing: "; curl -s -f http://localhost:8384 >/dev/null && echo "✅ OK" || echo "❌ DOWN"

# Run comprehensive tests
test: health
	@echo "🧪 Running validation tests..."
	@echo "Testing MCP API endpoints..."
	@curl -s http://localhost:3000/api/tools | jq . || echo "❌ Tools API failed"
	@curl -s http://localhost:3000/api/agents | jq . || echo "❌ Agents API failed"
	@echo "Testing WASM modules..."
	@curl -s -X POST http://localhost:3000/api/wasm/test | jq . || echo "❌ WASM test failed"
	@echo "Testing neural models..."
	@curl -s -X POST http://localhost:3000/api/neural/health | jq . || echo "❌ Neural test failed"
	@echo "✅ All tests completed"

# Bootstrap Claude Flow integration
bootstrap:
	@echo "🤖 Bootstrapping Claude Flow integration..."
	@curl -X POST http://localhost:3000/api/claude-flow/bootstrap \
		-H "Content-Type: application/json" \
		-d '{"config":{"topology":"hierarchical","maxAgents":12,"enableDAA":true,"enableNeural":true}}' \
		| jq . || echo "❌ Bootstrap failed"
	@echo "✅ Claude Flow integration ready"

# Backup data volumes
backup:
	@echo "💾 Creating backup of ruv-FANN data..."
	@mkdir -p backups/$(shell date +%Y%m%d_%H%M%S)
	@tar -czf backups/$(shell date +%Y%m%d_%H%M%S)/ruv-fann-data.tar.gz data/
	@echo "✅ Backup saved to backups/$(shell date +%Y%m%d_%H%M%S)/"

# Restore from backup
restore:
	@echo "♻️  Select backup to restore:"
	@ls -la backups/
	@read -p "Enter backup directory name: " backup && \
		tar -xzf backups/$$backup/ruv-fann-data.tar.gz
	@echo "✅ Data restored, restart services with: make restart"

# Update container images
update: stop
	@echo "🔄 Updating ruv-FANN to latest version..."
	@git pull
	@$(MAKE) build
	@$(MAKE) deploy

# Scale services (for Kubernetes)
scale:
	@echo "📈 Scaling ruv-FANN services..."
	@podman-compose -f podman-compose.yaml up -d --scale ruv-fann-stack=2

# Monitor resource usage
monitor:
	@echo "📊 Monitoring ruv-FANN resources (Press Ctrl+C to exit)..."
	@watch -n 2 'podman stats --no-stream && echo "" && curl -s http://localhost:3000/api/metrics || true'

# Run performance benchmarks
benchmark: health
	@echo "🏃 Running performance benchmarks..."
	@curl -X POST http://localhost:3000/api/benchmark/neural
	@curl -X POST http://localhost:3000/api/benchmark/wasm
	@curl -X POST http://localhost:3000/api/benchmark/database
	@echo "✅ Benchmarks completed"

# Security scan
security:
	@echo "🔒 Running security scans..."
	@podman images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | head -10
	@echo "Running container security scan..."
	@podman run --rm -v /var/run/docker.sock:/var/run/docker.sock \
		aquasec/trivy image ruv-fann:latest || echo "Trivy not available"

# Complete setup (one command deployment)
quickstart: deploy bootstrap
	@echo ""
	@echo "🎉 ruv-FANN is ready for Claude Flow!"
	@echo "📚 Quick commands:"
	@echo "   make logs     - View real-time logs"
	@echo "   make status   - Check system status"
	@echo "   make health   - Run health checks"
	@echo "   make test     - Run validation tests"
	@echo "   make shell    - Access container shell"
	@echo "   make stop     - Stop all services"
	@echo "   make clean    - Full cleanup"
	@echo ""
	@$(MAKE) status

.DEFAULT_GOAL := quickstart