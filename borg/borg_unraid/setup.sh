#!/bin/bash
# ============================================================
# Borgmatic Setup Script for Unraid
# ============================================================
# This script helps you set up borgmatic for automated
# backups on Unraid using Docker.
#
# Run on your Unraid server:
#   bash setup.sh
# ============================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directory
INSTALL_DIR="/mnt/user/appdata/borgmatic"

# ============================================================
# Functions
# ============================================================

print_header() {
    echo ""
    echo -e "${BLUE}============================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_unraid() {
    if [ ! -f /etc/unraid-version ]; then
        print_warning "This doesn't appear to be an Unraid system"
        read -rp "Continue anyway? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        print_success "Unraid system detected"
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    print_success "Docker is available"
}

create_directories() {
    print_info "Creating directory structure..."

    mkdir -p "$INSTALL_DIR/config"
    mkdir -p "$INSTALL_DIR/ssh"
    mkdir -p "$INSTALL_DIR/cache/borg"

    # Set permissions
    chmod 755 "$INSTALL_DIR"
    chmod 700 "$INSTALL_DIR/ssh"
    chmod 755 "$INSTALL_DIR/config"
    chmod 755 "$INSTALL_DIR/cache"

    print_success "Directories created at $INSTALL_DIR"
}

setup_env_file() {
    print_info "Setting up environment file..."

    if [ -f "$INSTALL_DIR/.env" ]; then
        print_warning ".env file already exists"
        read -rp "Overwrite? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Keeping existing .env file"
            return
        fi
    fi

    # Ask for passphrase
    echo ""
    echo "Enter a strong passphrase for repository encryption:"
    echo "(Mix of letters, numbers, symbols. 20+ characters recommended)"
    read -rsp "Passphrase: " passphrase
    echo ""
    read -rsp "Confirm passphrase: " passphrase_confirm
    echo ""

    if [ "$passphrase" != "$passphrase_confirm" ]; then
        print_error "Passphrases don't match"
        exit 1
    fi

    if [ ${#passphrase} -lt 12 ]; then
        print_warning "Passphrase is shorter than 12 characters (not recommended)"
        read -rp "Continue anyway? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Ask for timezone
    echo ""
    echo "Enter your timezone (e.g., America/New_York, Europe/London):"
    echo "See: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
    read -rp "Timezone [America/New_York]: " timezone
    timezone=${timezone:-America/New_York}

    # Create .env file
    cat > "$INSTALL_DIR/.env" << EOF
# Borgmatic Environment Variables
# CRITICAL: Keep this file secure and back up offline!

# Repository encryption passphrase
BORG_PASSPHRASE=$passphrase

# Timezone
TZ=$timezone

# Optional settings (uncomment if needed)
# BORG_RSH=ssh -i /root/.ssh/id_ed25519
# BORG_RELOCATED_REPO_ACCESS_IS_OK=no
# BORG_UNKNOWN_UNENCRYPTED_REPO_ACCESS_IS_OK=no
EOF

    chmod 600 "$INSTALL_DIR/.env"
    print_success ".env file created with secure permissions"

    print_warning "IMPORTANT: Back up your passphrase to a secure location!"
    print_warning "You will need it to recover backups."
}

setup_config_file() {
    print_info "Setting up borgmatic configuration..."

    if [ -f "$INSTALL_DIR/config/config.yaml" ]; then
        print_warning "config.yaml already exists"
        read -rp "Overwrite? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Keeping existing config.yaml"
            return
        fi
    fi

    # Check if config.yaml exists in current directory
    if [ -f "./config.yaml" ]; then
        cp ./config.yaml "$INSTALL_DIR/config/config.yaml"
        print_success "Copied config.yaml template"
    else
        print_warning "config.yaml not found in current directory"
        print_info "You'll need to create it manually or copy from the repository"
    fi
}

setup_docker_compose() {
    print_info "Setting up docker-compose.yml..."

    if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_warning "docker-compose.yml already exists"
        read -rp "Overwrite? [y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            print_info "Keeping existing docker-compose.yml"
            return
        fi
    fi

    # Check if docker-compose.yml exists in current directory
    if [ -f "./docker-compose.yml" ]; then
        cp ./docker-compose.yml "$INSTALL_DIR/docker-compose.yml"
        print_success "Copied docker-compose.yml"
    else
        print_warning "docker-compose.yml not found in current directory"
        print_info "You'll need to create it manually or copy from the repository"
    fi
}

setup_ssh_keys() {
    print_info "SSH key setup for remote backups..."

    echo ""
    read -rp "Do you need SSH keys for remote backups? [y/N] " setup_ssh

    if [[ "$setup_ssh" =~ ^[Yy]$ ]]; then
        if [ -f "$INSTALL_DIR/ssh/id_ed25519" ]; then
            print_warning "SSH key already exists at $INSTALL_DIR/ssh/id_ed25519"
            read -rp "Generate new key anyway? [y/N] " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                print_info "Keeping existing SSH key"
                return
            fi
        fi

        print_info "Generating SSH key..."
        ssh-keygen -t ed25519 -f "$INSTALL_DIR/ssh/id_ed25519" -N "" -C "borgmatic@unraid"

        chmod 600 "$INSTALL_DIR/ssh/id_ed25519"
        chmod 644 "$INSTALL_DIR/ssh/id_ed25519.pub"

        print_success "SSH key generated at $INSTALL_DIR/ssh/id_ed25519"

        echo ""
        print_info "Public key (copy this to your remote server):"
        echo ""
        cat "$INSTALL_DIR/ssh/id_ed25519.pub"
        echo ""

        print_info "To copy key to remote server, run:"
        echo "  ssh-copy-id -i $INSTALL_DIR/ssh/id_ed25519.pub user@backup-server.com"
        echo ""

        read -rp "Press Enter to continue..."
    else
        print_info "Skipping SSH key generation"
        print_info "You can generate one later if needed"
    fi
}

pull_docker_image() {
    print_info "Pulling borgmatic Docker image..."
    docker pull b3vis/borgmatic:latest
    print_success "Docker image pulled"
}

start_container() {
    print_info "Starting borgmatic container..."

    cd "$INSTALL_DIR"

    if docker ps -a --format '{{.Names}}' | grep -q '^borgmatic$'; then
        print_warning "Container 'borgmatic' already exists"
        read -rp "Remove and recreate? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            docker stop borgmatic 2>/dev/null || true
            docker rm borgmatic 2>/dev/null || true
        else
            print_info "Keeping existing container"
            return
        fi
    fi

    docker-compose up -d
    print_success "Container started"

    # Wait a few seconds for container to initialize
    sleep 3

    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q '^borgmatic$'; then
        print_success "Container is running"
    else
        print_error "Container failed to start"
        print_info "Check logs with: docker logs borgmatic"
        exit 1
    fi
}

initialize_repository() {
    print_info "Repository initialization..."

    echo ""
    read -rp "Initialize Borg repository now? [y/N] " init_repo

    if [[ "$init_repo" =~ ^[Yy]$ ]]; then
        print_info "Initializing repository with repokey encryption..."

        if docker exec borgmatic borgmatic init --encryption repokey; then
            print_success "Repository initialized"

            # Export repository key
            print_info "Exporting repository key..."
            docker exec borgmatic borg key export /mnt/borg-repository /tmp/repo.key 2>/dev/null || true
            docker cp borgmatic:/tmp/repo.key "$INSTALL_DIR/borg-local-repo.key" 2>/dev/null || true

            if [ -f "$INSTALL_DIR/borg-local-repo.key" ]; then
                chmod 600 "$INSTALL_DIR/borg-local-repo.key"
                print_success "Repository key exported to: $INSTALL_DIR/borg-local-repo.key"
                print_warning "CRITICAL: Back up this key file offline!"
            fi
        else
            print_error "Repository initialization failed"
            print_info "You can initialize manually later with:"
            echo "  docker exec borgmatic borgmatic init --encryption repokey"
        fi
    else
        print_info "Skipping repository initialization"
        print_info "Initialize later with: docker exec borgmatic borgmatic init --encryption repokey"
    fi
}

run_test_backup() {
    print_info "Test backup..."

    echo ""
    read -rp "Run a test backup now? [y/N] " test_backup

    if [[ "$test_backup" =~ ^[Yy]$ ]]; then
        print_info "Running test backup (this may take a while)..."

        if docker exec borgmatic borgmatic --verbosity 1 --stats; then
            print_success "Test backup completed successfully!"
        else
            print_error "Test backup failed"
            print_info "Check configuration and try again"
        fi
    else
        print_info "Skipping test backup"
        print_info "Run manually later with: docker exec borgmatic borgmatic --verbosity 1 --stats"
    fi
}

print_summary() {
    print_header "Setup Complete!"

    echo "Installation directory: $INSTALL_DIR"
    echo ""
    echo "Configuration files:"
    echo "  - $INSTALL_DIR/.env"
    echo "  - $INSTALL_DIR/config/config.yaml"
    echo "  - $INSTALL_DIR/docker-compose.yml"

    if [ -f "$INSTALL_DIR/borg-local-repo.key" ]; then
        echo ""
        echo "Repository key:"
        echo "  - $INSTALL_DIR/borg-local-repo.key"
    fi

    if [ -f "$INSTALL_DIR/ssh/id_ed25519" ]; then
        echo ""
        echo "SSH key:"
        echo "  - $INSTALL_DIR/ssh/id_ed25519"
    fi

    echo ""
    print_warning "CRITICAL NEXT STEPS:"
    echo ""
    echo "1. Back up these files to a secure, offline location:"
    echo "   - Your passphrase (from .env file)"
    echo "   - Repository key (borg-local-repo.key)"
    echo "   - SSH key (if using remote backups)"
    echo ""
    echo "2. Edit $INSTALL_DIR/config/config.yaml to customize:"
    echo "   - Backup sources (what to backup)"
    echo "   - Repositories (where to backup)"
    echo "   - Schedule (when to backup)"
    echo "   - Retention policy (how long to keep backups)"
    echo ""
    echo "3. Restart container after editing config:"
    echo "   docker restart borgmatic"
    echo ""

    print_info "Useful Commands:"
    echo ""
    echo "View logs:"
    echo "  docker logs -f borgmatic"
    echo ""
    echo "Run manual backup:"
    echo "  docker exec borgmatic borgmatic --verbosity 1 --stats"
    echo ""
    echo "List backups:"
    echo "  docker exec borgmatic borgmatic list"
    echo ""
    echo "Enter container:"
    echo "  docker exec -it borgmatic bash"
    echo ""
    echo "Stop container:"
    echo "  docker-compose -f $INSTALL_DIR/docker-compose.yml down"
    echo ""
    echo "Start container:"
    echo "  docker-compose -f $INSTALL_DIR/docker-compose.yml up -d"
    echo ""

    print_header "Happy Backing Up!"
}

# ============================================================
# Main Execution
# ============================================================

print_header "Borgmatic Setup for Unraid"

# Pre-flight checks
check_unraid
check_docker

# Setup steps
create_directories
setup_env_file
setup_config_file
setup_docker_compose
setup_ssh_keys
pull_docker_image
start_container
initialize_repository
run_test_backup

# Summary
print_summary

exit 0
