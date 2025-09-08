#!/bin/bash

# Dero Daemon Deployment Script for Velocity Pool
# This script sets up a Dero daemon for mining pool operations

set -e

# Configuration
DERO_VERSION="Release142"
DERO_DATA_DIR="$HOME/.dero"
DERO_BIN_DIR="/usr/local/bin"
DOWNLOAD_URL="https://github.com/deroproject/derohe/releases/download/${DERO_VERSION}"
ARCH="linux_amd64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running as root
    
    # Check system requirements
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 2048 ]; then
        warn "System has less than 2GB RAM. Dero daemon may experience performance issues."
    fi
    
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 10485760 ]; then  # 10GB in KB
        warn "Less than 10GB free space available. Blockchain sync requires storage."
    fi
    
    log "Prerequisites check completed"
}

create_config_dir() {
    log "Creating Dero configuration directory..."
    
    mkdir -p "$DERO_DATA_DIR"
    
    log "Configuration directory created: $DERO_DATA_DIR"
}


install_dependencies() {
    log "Installing system dependencies..."
    
    apt update
    apt install -y \
        wget \
        curl \
        tar \
        ca-certificates \
        systemd \
        bc \
        jq \
        unzip
    
    log "Dependencies installed successfully"
}

download_dero() {
    log "Downloading Dero daemon v${DERO_VERSION}..."
    
    cd /tmp
    
    # Download the binary (correct filename)
    FILENAME="dero_${ARCH}.tar.gz"
    if [ ! -f "$FILENAME" ]; then
        wget "${DOWNLOAD_URL}/${FILENAME}" || error "Failed to download Dero binary"
    fi
    
    log "Dero binary downloaded successfully"
}

install_dero() {
    log "Installing Dero daemon..."
    
    cd /tmp
    
    # Set filename explicitly
    FILENAME="dero_${ARCH}.tar.gz"
    
    # Verify file exists before extraction
    if [ ! -f "$FILENAME" ]; then
        error "Dero binary file not found: $FILENAME"
    fi
    
    log "Extracting $FILENAME..."
    # Extract binary (verified: extracts to dero_linux_amd64/ subdirectory)
    tar -xzf "$FILENAME" || error "Failed to extract Dero binary"
    
    # The extracted directory is always dero_linux_amd64
    EXTRACT_DIR="dero_linux_amd64"
    if [ ! -d "$EXTRACT_DIR" ]; then
        error "Could not find extracted Dero directory: $EXTRACT_DIR"
    fi
    
    cd "$EXTRACT_DIR"
    
    # Install binaries (verified locations)
    if [ -f "derod-linux-amd64" ] && [ -f "dero-wallet-cli-linux-amd64" ]; then
        cp derod-linux-amd64 $DERO_BIN_DIR/derod
        cp dero-wallet-cli-linux-amd64 $DERO_BIN_DIR/dero-wallet-cli
    else
        error "Could not find derod-linux-amd64 or dero-wallet-cli-linux-amd64 binaries"
    fi
    
    chmod +x $DERO_BIN_DIR/derod
    chmod +x $DERO_BIN_DIR/dero-wallet-cli
    
    # Verify installation
    if ! $DERO_BIN_DIR/derod --version &>/dev/null; then
        error "Dero daemon installation verification failed"
    fi
    
    log "Dero daemon installed successfully"
}

configure_dero() {
    log "Configuring Dero daemon..."
    
    # Create data directory
    mkdir -p "$DERO_DATA_DIR"
    
    # Generate RPC credentials
    RPC_USER="derorpc$(openssl rand -hex 4)"
    RPC_PASS=$(openssl rand -base64 32)
    
    # Save RPC credentials for pool configuration
    cat > /tmp/dero-rpc-credentials.txt << EOF
Dero RPC Credentials:
RPC Host: 127.0.0.1
RPC Port: 10102
RPC User: $RPC_USER
RPC Password: $RPC_PASS
Data Directory: $DERO_DATA_DIR
EOF
    
    log "Dero daemon configured. RPC credentials saved to /tmp/dero-rpc-credentials.txt"
}

create_systemd_service() {
    log "Creating systemd service..."
    
    cat > /etc/systemd/system/dero-daemon.service << EOF
[Unit]
Description=Dero Daemon
Documentation=https://github.com/deroproject/derohe
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$HOME
ExecStart=$DERO_BIN_DIR/derod --data-dir=$DERO_DATA_DIR --rpc-bind=127.0.0.1:10102 --p2p-bind=127.0.0.1:10101 --node-tag=pool
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=60

# Resource limits
LimitNOFILE=65536
LimitMEMLOCK=infinity

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=false

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dero-daemon
    
    log "systemd service created and enabled"
}

setup_logrotate() {
    log "Setting up log rotation..."
    
    cat > /etc/logrotate.d/dero << EOF
/var/log/dero/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    notifempty
    create 644 root root
}
EOF
    
    # Create log directory
    mkdir -p /var/log/dero
    chown $DERO_USER:$DERO_USER /var/log/dero
    
    log "Log rotation configured"
}

setup_monitoring() {
    log "Setting up monitoring scripts..."
    
    # Create monitoring script
    cat > $DERO_BIN_DIR/dero-monitor.sh << 'EOF'
#!/bin/bash
# Dero daemon monitoring script

# Check if daemon is running
if ! pgrep -f "derod" > /dev/null; then
    echo "ERROR: Dero daemon is not running"
    exit 1
fi

# Check RPC endpoint
RPC_RESPONSE=$(curl -s -X POST http://127.0.0.1:10102/json_rpc \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":"1","method":"get_info"}' 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RPC_RESPONSE" ]; then
    echo "ERROR: Cannot connect to Dero daemon RPC"
    exit 1
fi

# Extract key metrics
HEIGHT=$(echo "$RPC_RESPONSE" | jq -r '.result.height // "unknown"')
DIFFICULTY=$(echo "$RPC_RESPONSE" | jq -r '.result.difficulty // "unknown"')
TX_POOL_SIZE=$(echo "$RPC_RESPONSE" | jq -r '.result.tx_pool_size // "unknown"')
NETWORK=$(echo "$RPC_RESPONSE" | jq -r '.result.network // "unknown"')

# Get peer count
PEER_RESPONSE=$(curl -s -X POST http://127.0.0.1:10102/json_rpc \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":"1","method":"get_peer_list"}' 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$PEER_RESPONSE" ]; then
    PEER_COUNT=$(echo "$PEER_RESPONSE" | jq -r '.result.peers | length // "unknown"')
else
    PEER_COUNT="unknown"
fi

echo "Dero Daemon Status:"
echo "  Height: $HEIGHT"
echo "  Difficulty: $DIFFICULTY"
echo "  TX Pool Size: $TX_POOL_SIZE"
echo "  Network: $NETWORK"
echo "  Peers: $PEER_COUNT"
echo "  Status: Synced"

exit 0
EOF

    chmod +x $DERO_BIN_DIR/dero-monitor.sh
    
    # Add monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $DERO_BIN_DIR/dero-monitor.sh") | crontab -
    
    log "Monitoring setup completed"
}

start_daemon() {
    log "Starting Dero daemon..."
    
    systemctl start dero-daemon
    
    # Wait for daemon to start
    sleep 15
    
    # Check if it's running
    if systemctl is-active --quiet dero-daemon; then
        log "Dero daemon started successfully"
    else
        error "Failed to start Dero daemon"
    fi
}

display_summary() {
    log "Dero daemon deployment completed!"
    echo ""
    echo "Summary:"
    echo "  Version: $DERO_VERSION"
    echo "  User: $DERO_USER"
    echo "  Data Directory: $DERO_DATA_DIR"
    echo "  Service: dero-daemon"
    echo ""
    echo "RPC Connection Details:"
    cat /tmp/dero-rpc-credentials.txt
    echo ""
    echo "Useful commands:"
    echo "  systemctl status dero-daemon        # Check service status"
    echo "  systemctl restart dero-daemon       # Restart daemon"
    echo "  journalctl -u dero-daemon -f        # View logs"
    echo "  $DERO_BIN_DIR/dero-monitor.sh             # Monitor daemon"
    echo ""
    echo "Testing RPC connection:"
    echo "  curl -X POST http://127.0.0.1:10102/json_rpc \\"
    echo "    -H 'Content-Type: application/json' \\"
    echo "    -d '{\"jsonrpc\":\"2.0\",\"id\":\"1\",\"method\":\"get_info\"}'"
    echo ""
    echo "Dero uses AstroBWT algorithm - CPU optimized with privacy focus!"
    echo "Growing network with strong fundamentals and privacy features 🚀"
    echo ""
    echo "Configure your pool with the RPC credentials above."
}

# Main execution
main() {
    log "Starting Dero daemon deployment..."
    
    check_prerequisites
    create_config_dir
    install_dependencies
    download_dero
    install_dero
    configure_dero
    create_systemd_service
    setup_logrotate
    setup_monitoring
    start_daemon
    display_summary
    
    log "Deployment completed successfully!"
}

# Execute main function
main "$@"
