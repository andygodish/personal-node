#!/usr/bin/env bash
#
# Idempotent, works on macOS (M-series, Intel) and Linux.
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Starting Automatic Docker Setup ===${NC}"

OS_TYPE="$(uname -s)"

if [ "$OS_TYPE" = "Darwin" ]; then
    echo -e "${YELLOW}Detected macOS system. Setting up Homebrew & Colima...${NC}"

    # 1. Force PATH detection for Homebrew (Apple Silicon & Intel)
    if [ -x "/opt/homebrew/bin/brew" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x "/usr/local/bin/brew" ]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    # 2. Install Homebrew if totally missing
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Homebrew not found. Installing Homebrew automatically...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        if [ -x "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x "/usr/local/bin/brew" ]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    # 3. Ensure Homebrew PATH is permanently in ~/.zshrc (without duplicating lines)
    SHELL_RC="$HOME/.zshrc"
    touch "$SHELL_RC"
    if ! grep -q "brew shellenv" "$SHELL_RC"; then
        echo -e "${YELLOW}Saving Homebrew PATH to $SHELL_RC...${NC}"
        if [ -d "/opt/homebrew" ]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$SHELL_RC"
        else
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$SHELL_RC"
        fi
    fi

    # 4. Install Formulae
    echo -e "${YELLOW}Installing Docker CLI, Docker Compose, and Colima...${NC}"
    brew install docker docker-compose colima || true

    # 5. Force-link formulas to fix "installed but not linked" errors
    echo -e "${YELLOW}Linking executables to PATH...${NC}"
    brew link --overwrite docker docker-compose colima 2>/dev/null || true

    # 6. Set up the Docker Compose CLI Plugin symlink
    mkdir -p "$HOME/.docker/cli-plugins"
    if [ -f "$(brew --prefix 2>/dev/null)/opt/docker-compose/bin/docker-compose" ]; then
        ln -sfn "$(brew --prefix)/opt/docker-compose/bin/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"
    fi

    # 7. Start Colima Daemon if not running
    if ! colima status &> /dev/null; then
        echo -e "${YELLOW}Starting Colima VM (Allocating 2 CPUs, 4 GB RAM)...${NC}"
        colima start --cpu 2 --memory 4
    else
        echo -e "${GREEN}✓ Colima container engine is already running.${NC}"
    fi

elif [ "$OS_TYPE" = "Linux" ]; then
    echo -e "${YELLOW}Detected Linux system. Installing native Docker Engine...${NC}"

    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        rm get-docker.sh
        sudo usermod -aG docker "$USER" || true
    fi

else
    echo -e "${RED}Error: Unsupported Operating System ($OS_TYPE).${NC}"
    exit 1
fi

# 8. Force the active shell session to recognize the new commands
if [ -x "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# 9. Print Success Verification
echo ""
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}           DOCKER READY FOR USE!                    ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "Docker Client Version: $(docker --version)"
echo -e "Compose Plugin Version: $(docker compose version)"
echo ""
echo -e "${BLUE}Testing connection to background container daemon...${NC}"
docker info > /dev/null
echo -e "${GREEN}✓ SUCCESS: Docker daemon is responding and operational!${NC}"
echo -e "${GREEN}====================================================${NC}"
