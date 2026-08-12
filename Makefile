# Variables
COMPOSE_FILE := $(shell test -f docker-compose.yaml && echo docker-compose.yaml || echo docker-compose.yml)
BITCOIN_CONF_COMPOSE_FILE := docker-compose.bitcoin-conf.yaml
BITCOIN_VOL := personal-node_bitcoin_data_dir
ELECTRS_VOL := personal-node_electrs_index_dir
TOR_VOL := personal-node_tor_data_dir

# Ports to check before spinning up infrastructure
P2P_PORT := 8333
RPC_PORT := 8332
ELECTRUM_PORT := 50001
TOR_SOCKS_PORT := 9050

.PHONY: help up up-bootstrap-onion down restart logs status ps verify-ports fix-permissions sync-cookie-perms tor-hostname

help:
	@echo "Personal Node Makefile"
	@echo "----------------------------"
	@echo "make up              - Run the steady-state node stack with node-local bitcoin.conf"
	@echo "make up-bootstrap-onion - First-run stack without bitcoin.conf to generate a Tor onion hostname"
	@echo "make down    - Safely stop and remove containers (keeps volumes intact)"
	@echo "make restart - Gracefully restart all node services"
	@echo "make logs    - Stream live container orchestration logs"
	@echo "make status       - View operational health and port bindings"
	@echo "make tor-hostname - Print the Bitcoin P2P onion hostname after Tor initializes"

verify-ports:
	@echo "Running preflight network checks..."
	@for port in $(P2P_PORT) $(RPC_PORT) $(ELECTRUM_PORT) $(TOR_SOCKS_PORT); do \
		if lsof -Pi :$$port -sTCP:LISTEN -t >/dev/null 2>&1; then \
			echo "ERROR: Port $$port is already occupied on the host system."; \
			echo "Please stop the conflicting service before running the node."; \
			exit 1; \
		fi; \
	done
	@echo "All target network ports are clear."

fix-permissions:
	@echo "Checking and setting volume directory ownership for non-root containers..."
	@docker volume create $(BITCOIN_VOL) >/dev/null 2>&1 || true
	@docker volume create $(ELECTRS_VOL) >/dev/null 2>&1 || true
	@docker volume create $(TOR_VOL) >/dev/null 2>&1 || true
	@docker run --rm -v $(BITCOIN_VOL):/data alpine sh -c "chown -R 10001:10001 /data && chmod 755 /data" >/dev/null 2>&1 || true
	@docker run --rm -v $(ELECTRS_VOL):/data alpine sh -c "chown -R 10002:10002 /data && chmod 755 /data" >/dev/null 2>&1 || true
	@docker run --rm -v $(TOR_VOL):/data alpine sh -c "chown -R 10003:10003 /data && chmod 700 /data" >/dev/null 2>&1 || true

sync-cookie-perms:
	@echo "Waiting for Bitcoin Core to initialize auth cookie..."
	@for i in $$(seq 1 30); do \
		if docker run --rm -v $(BITCOIN_VOL):/data alpine test -f /data/.cookie 2>/dev/null; then \
			docker run --rm -v $(BITCOIN_VOL):/data alpine chmod 644 /data/.cookie >/dev/null 2>&1; \
			echo "Auth cookie readable by electrs."; \
			break; \
		fi; \
		sleep 1; \
	done

up: fix-permissions
	@test -f bitcoin.conf || (echo "ERROR: bitcoin.conf is missing. For first-time onion generation, run 'make up-bootstrap-onion'. Then copy bitcoin.conf.example to bitcoin.conf and set externalip."; exit 1)
	@echo "Running steady-state node stack with node-local bitcoin.conf..."
	docker compose -f $(COMPOSE_FILE) -f $(BITCOIN_CONF_COMPOSE_FILE) up -d --remove-orphans
	@$(MAKE) sync-cookie-perms
	@echo "Stack is running with the node-local bitcoin.conf override. Run 'make status' to verify health."

up-bootstrap-onion: verify-ports fix-permissions
	@echo "Starting first-run stack without bitcoin.conf to generate a Tor onion hostname..."
	docker compose -f $(COMPOSE_FILE) up -d --remove-orphans
	@$(MAKE) sync-cookie-perms
	@echo "Bootstrap stack is running. Run 'make tor-hostname' after Tor initializes."

down:
	@echo "Safely bringing down containers..."
	docker compose -f $(COMPOSE_FILE) down

restart:
	@echo "Gracefully restarting node stack..."
	docker compose -f $(COMPOSE_FILE) restart
	@$(MAKE) sync-cookie-perms

logs:
	docker compose -f $(COMPOSE_FILE) logs -f --tail=100

status ps:
	docker compose -f $(COMPOSE_FILE) ps

tor-hostname:
	@docker run --rm -v $(TOR_VOL):/data alpine sh -c 'cat /data/knots-p2p/hostname 2>/dev/null || echo "Tor hostname is not available yet. Start the stack and wait for Tor to initialize."'
