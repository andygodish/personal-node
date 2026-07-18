# Variables
COMPOSE_FILE := $(shell test -f docker-compose.yaml && echo docker-compose.yaml || echo docker-compose.yml)

# Ports to check before spinning up infrastructure
P2P_PORT := 8333
RPC_PORT := 8332
ELECTRUM_PORT := 50001

.PHONY: help up down restart logs status ps verify-ports

help:
	@echo "Personal Node Makefile"
	@echo "----------------------------"
	@echo "make up      - Idempotently spin up or update the node stack (includes preflight checks)"
	@echo "make down    - Safely stop and remove containers (keeps volumes intact)"
	@echo "make restart - Gracefully restart all node services"
	@echo "make logs    - Stream live container orchestration logs"
	@echo "make status  - View operational health and port bindings"

verify-ports:
	@echo "Running preflight network checks..."
	@for port in $(P2P_PORT) $(RPC_PORT) $(ELECTRUM_PORT); do \
		if lsof -Pi :$$port -sTCP:LISTEN -t >/dev/null 2>&1; then \
			echo "ERROR: Port $$port is already occupied on the host system."; \
			echo "Please stop the conflicting service before running the node."; \
			exit 1; \
		fi; \
	done
	@echo "All target network ports are clear."

up: verify-ports
	@echo "Checking infrastructure state and applying configuration..."
	docker compose -f $(COMPOSE_FILE) up -d --remove-orphans
	@echo "Stack is running. Run 'make status' to verify health."

down:
	@echo "Safely bringing down containers..."
	docker compose -f $(COMPOSE_FILE) down

restart:
	@echo "Gracefully restarting node stack..."
	docker compose -f $(COMPOSE_FILE) restart

logs:
	docker compose -f $(COMPOSE_FILE) logs -f --tail=100

status ps:
	docker compose -f $(COMPOSE_FILE) ps