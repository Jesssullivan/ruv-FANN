# ruv-FANN Simplified Makefile
# Turnkey deployment commands

.PHONY: all build deploy clean stop logs shell test

# Default target
all: deploy

# Build the container
build:
	@echo "Building ruv-FANN container..."
	podman build -t ruv-fann:latest -f ContainerFile .

# Deploy the stack
deploy: build
	@echo "Deploying ruv-FANN stack..."
	podman-compose -f podman-compose.yaml up -d
	@echo "Waiting for services to start..."
	@sleep 10
	@echo "Checking health status..."
	@curl -f http://localhost:3000/health || echo "Services starting up..."
	@echo ""
	@echo "Deployment complete!"
	@echo "MCP Server: http://localhost:3000"
	@echo "Syncthing UI: http://localhost:8384"
	@echo "PostgreSQL: localhost:5432"
	@echo "Redis: localhost:6379"

# Stop all services
stop:
	@echo "Stopping ruv-FANN stack..."
	podman-compose -f podman-compose.yaml down

# Clean up everything
clean: stop
	@echo "Cleaning up volumes and images..."
	podman-compose -f podman-compose.yaml down -v
	podman rmi ruv-fann:latest || true
	rm -rf data/postgres data/redis data/sync data/models data/cache

# View logs
logs:
	podman-compose -f podman-compose.yaml logs -f

# Shell into container
shell:
	podman exec -it ruv-fann /bin/sh

# Run tests
test:
	@echo "Running validation tests..."
	npm test
	@echo "Testing MCP endpoints..."
	curl http://localhost:3000/api/tools
	curl http://localhost:3000/health

# Bootstrap Claude Flow integration
bootstrap:
	@echo "Bootstrapping Claude Flow integration..."
	curl -X POST http://localhost:3000/api/claude-flow/bootstrap \
		-H "Content-Type: application/json" \
		-d '{"config":{"topology":"hierarchical","maxAgents":8}}'

# Quick start (one command deployment)
quickstart: deploy bootstrap
	@echo "ruv-FANN is ready for Claude Flow!"

.DEFAULT_GOAL := deploy