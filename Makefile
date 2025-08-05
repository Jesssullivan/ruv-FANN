# ruv-FANN Makefile
# Simplified deployment and management

.PHONY: help build up down test clean deploy k8s

help:
	@echo "ruv-FANN MCP Server Commands:"
	@echo "  make build   - Build containers"
	@echo "  make up      - Start services"
	@echo "  make down    - Stop services"
	@echo "  make test    - Run tests"
	@echo "  make deploy  - Full deployment"
	@echo "  make k8s     - Deploy to Kubernetes"
	@echo "  make clean   - Clean everything"

build:
	podman-compose -f podman-compose.production.yaml build

up:
	podman-compose -f podman-compose.production.yaml up -d
	@echo "Waiting for services..."
	@sleep 5
	@curl -s http://localhost:3000/health | jq .

down:
	podman-compose -f podman-compose.production.yaml down

test:
	@echo "Testing MCP tools..."
	@curl -s http://localhost:3000/tools | jq '.total'
	@echo "Testing models..."
	@curl -s http://localhost:3000/models | jq '.total'
	@echo "Health check..."
	@curl -s http://localhost:3000/health | jq .

deploy: build up
	./scripts/claude-flow-init.sh

k8s:
	kubectl apply -f k8s/
	kubectl wait --for=condition=ready pod -l app=ruv-fann -n ruv-fann --timeout=60s

clean:
	podman-compose -f podman-compose.production.yaml down -v
	rm -rf data/cache data/sync/.syncthing
	find . -name "*.tmp" -o -name "*.backup" -o -name "*.old" | xargs rm -f

logs:
	podman-compose -f podman-compose.production.yaml logs -f ruv-fann

shell:
	podman exec -it ruv-fann /bin/sh