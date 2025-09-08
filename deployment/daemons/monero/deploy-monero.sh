#!/bin/bash

# Monero Daemon Deployment Script for Velocity Pool
# This script sets up a Monero daemon for mining pool operations

set -e

# Configuration
MONERO_VERSION="0.18.3.1"
MONERO_USER="monero"
MONERO_HOME="/home/monero"
MONERO_DATA_DIR="$MONERO_HOME/.bitmonero"
MONERO_BIN_DIR="/usr/local/bin"
DOWNLOAD_URL="https://downloads.getmonero.org/cli"
ARCH="linux64"

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
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
    fi
    
    # Check system requirements
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 4096 ]; then
        warn "System has less than 4GB RAM. Monero daemon may experience performance issues."
    fi
    
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 209715200 ]; then  # 200GB in KB
        warn "Less than 200GB free space available. Monero blockchain requires significant storage."
    fi
    
    log "Prerequisites check completed"
}

create_user() {
    log "Creating Monero daemon user..."
    
    if ! id "$MONERO_USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" $MONERO_USER
        log "Created user: $MONERO_USER"
    else
        log "User $MONERO_USER already exists"
    fi
}

install_dependencies() {
    log "Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y \
        wget \
        curl \
        bzip2 \
        ca-certificates \
        systemd \
        bc \
        htop
    
    log "Dependencies installed successfully"
}

download_monero() {
    log "Downloading Monero daemon v${MONERO_VERSION}..."
    
    cd /tmp
    
    # Download the binary
    FILENAME="monero-${ARCH}-v${MONERO_VERSION}.tar.bz2"
    if [ ! -f "$FILENAME" ]; then
        wget "${DOWNLOAD_URL}/${FILENAME}" || error "Failed to download Monero binary"
        
        # Download and verify hashes (optional but recommended)
        wget "${DOWNLOAD_URL}/hashes.txt" || warn "Could not download hash verification file"
    fi
    
    # Basic verification if hashes available
    if [ -f "hashes.txt" ]; then
        log "Verifying download integrity..."
        if grep -q "$FILENAME" hashes.txt; then
            EXPECTED_HASH=$(grep "$FILENAME" hashes.txt | awk '{print $1}')
            ACTUAL_HASH=$(sha256sum "$FILENAME" | awk '{print $1}')
            if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
                error "Hash verification failed"
            fi
            log "Hash verification successful"
        fi
    fi
    
    log "Monero binary downloaded successfully"
}

install_monero() {
    log "Installing Monero daemon..."
    
    cd /tmp
    
    # Extract binary
    tar -xjf "monero-${ARCH}-v${MONERO_VERSION}.tar.bz2" || error "Failed to extract Monero binary"
    
    cd "monero-v${MONERO_VERSION}"
    
    # Install binaries
    sudo cp monerod $MONERO_BIN_DIR/
    sudo cp monero-wallet-cli $MONERO_BIN_DIR/
    sudo cp monero-wallet-rpc $MONERO_BIN_DIR/
    sudo chmod +x $MONERO_BIN_DIR/monerod
    sudo chmod +x $MONERO_BIN_DIR/monero-wallet-cli
    sudo chmod +x $MONERO_BIN_DIR/monero-wallet-rpc
    
    # Verify installation
    if ! $MONERO_BIN_DIR/monerod --version &>/dev/null; then
        error "Monero daemon installation verification failed"
    fi
    
    log "Monero daemon installed successfully"
}

configure_monero() {
    log "Configuring Monero daemon..."
    
    # Create data directory
    sudo -u $MONERO_USER mkdir -p "$MONERO_DATA_DIR"
    
    # Generate RPC credentials
    RPC_USER="monerorpc$(openssl rand -hex 4)"
    RPC_PASS=$(openssl rand -base64 32)
    
    # Create configuration file
    sudo -u $MONERO_USER cat > "$MONERO_DATA_DIR/monerod.conf" << EOF
# Monero daemon configuration for mining pool
# Generated on $(date)

# Data directory
data-dir=$MONERO_DATA_DIR

# Network settings
p2p-bind-ip=0.0.0.0
p2p-bind-port=18080

# RPC settings
rpc-bind-ip=127.0.0.1
rpc-bind-port=18081
rpc-login=$RPC_USER:$RPC_PASS
rpc-access-control-origins=*

# Connection settings
out-peers=64
in-peers=32
limit-rate-up=2048
limit-rate-down=8192

# Performance settings
db-sync-mode=safe
max-concurrency=4

# Mining settings
start-mining=0
mining-threads=0

# Logging
log-level=1
log-file=$MONERO_DATA_DIR/monero.log

# Security
restricted-rpc=1
no-igd=1
no-zmq=0

# Disable wallet functionality (pool mode)
disable-dns-checkpoints=0
EOF

    # Set proper permissions
    sudo chown $MONERO_USER:$MONERO_USER "$MONERO_DATA_DIR/monerod.conf"
    sudo chmod 600 "$MONERO_DATA_DIR/monerod.conf"
    
    # Save RPC credentials for pool configuration
    cat > /tmp/monero-rpc-credentials.txt << EOF
Monero RPC Credentials:
RPC Host: 127.0.0.1
RPC Port: 18081
RPC User: $RPC_USER
RPC Password: $RPC_PASS
Configuration saved to: $MONERO_DATA_DIR/monerod.conf
EOF
    
    log "Monero daemon configured. RPC credentials saved to /tmp/monero-rpc-credentials.txt"
}

create_systemd_service() {
    log "Creating systemd service..."
    
    sudo cat > /etc/systemd/system/monero-daemon.service << EOF
[Unit]
Description=Monero Daemon
Documentation=https://github.com/monero-project/monero
After=network.target

[Service]
Type=forking
User=$MONERO_USER
Group=$MONERO_USER
WorkingDirectory=$MONERO_HOME
ExecStart=$MONERO_BIN_DIR/monerod --config-file=$MONERO_DATA_DIR/monerod.conf --detach --pidfile=$MONERO_DATA_DIR/monerod.pid
ExecStop=/bin/kill -TERM \$MAINPID
PIDFile=$MONERO_DATA_DIR/monerod.pid
KillMode=mixed
Restart=always
RestartSec=10
TimeoutStartSec=120
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

    sudo systemctl daemon-reload
    sudo systemctl enable monero-daemon
    
    log "systemd service created and enabled"
}

setup_logrotate() {
    log "Setting up log rotation..."
    
    sudo cat > /etc/logrotate.d/monero << EOF
$MONERO_DATA_DIR/monero.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    notifempty
    create 644 $MONERO_USER $MONERO_USER
}
EOF
    
    log "Log rotation configured"
}

setup_monitoring() {
    log "Setting up monitoring scripts..."
    
    # Create monitoring script
    sudo cat > $MONERO_BIN_DIR/monero-monitor.sh << 'EOF'
#!/bin/bash
# Monero daemon monitoring script

MONERO_RPC_HOST="127.0.0.1"
MONERO_RPC_PORT="18081"

# Check if daemon is running
if ! pgrep -f "monerod" > /dev/null; then
    echo "ERROR: Monero daemon is not running"
    exit 1
fi

# Get daemon info via RPC
RPC_RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":"0","method":"get_info"}' \
    http://${MONERO_RPC_HOST}:${MONERO_RPC_PORT}/json_rpc 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$RPC_RESPONSE" ]; then
    echo "ERROR: Cannot connect to Monero daemon RPC"
    exit 1
fi

# Parse response
HEIGHT=$(echo "$RPC_RESPONSE" | grep -o '"height":[0-9]*' | cut -d':' -f2)
TARGET_HEIGHT=$(echo "$RPC_RESPONSE" | grep -o '"target_height":[0-9]*' | cut -d':' -f2)
CONNECTIONS=$(echo "$RPC_RESPONSE" | grep -o '"incoming_connections_count":[0-9]*' | cut -d':' -f2)
OUTGOING=$(echo "$RPC_RESPONSE" | grep -o '"outgoing_connections_count":[0-9]*' | cut -d':' -f2)
DIFFICULTY=$(echo "$RPC_RESPONSE" | grep -o '"difficulty":[0-9]*' | cut -d':' -f2)

echo "Monero Daemon Status:"
echo "  Height: $HEIGHT"
echo "  Target Height: $TARGET_HEIGHT"
echo "  Incoming Connections: $CONNECTIONS"
echo "  Outgoing Connections: $OUTGOING"
echo "  Difficulty: $DIFFICULTY"

# Check sync status
if [ -n "$HEIGHT" ] && [ -n "$TARGET_HEIGHT" ]; then
    if [ "$HEIGHT" -lt "$TARGET_HEIGHT" ]; then
        SYNC_PERCENT=$(echo "scale=2; $HEIGHT * 100 / $TARGET_HEIGHT" | bc -l)
        echo "  Status: Syncing (${SYNC_PERCENT}%)"
    else
        echo "  Status: Fully synced"
    fi
else
    echo "  Status: Unknown"
fi

exit 0
EOF

    sudo chmod +x $MONERO_BIN_DIR/monero-monitor.sh
    
    # Add monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $MONERO_BIN_DIR/monero-monitor.sh") | crontab -
    
    log "Monitoring setup completed"
}

start_daemon() {
    log "Starting Monero daemon..."
    
    sudo systemctl start monero-daemon
    
    # Wait for daemon to start
    sleep 15
    
    # Check if it's running
    if sudo systemctl is-active --quiet monero-daemon; then
        log "Monero daemon started successfully"
    else
        error "Failed to start Monero daemon"
    fi
}

display_summary() {
    log "Monero daemon deployment completed!"
    echo ""
    echo "Summary:"
    echo "  Version: $MONERO_VERSION"
    echo "  User: $MONERO_USER"
    echo "  Data Directory: $MONERO_DATA_DIR"
    echo "  Configuration: $MONERO_DATA_DIR/monerod.conf"
    echo "  Service: monero-daemon"
    echo ""
    echo "RPC Connection Details:"
    cat /tmp/monero-rpc-credentials.txt
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status monero-daemon     # Check service status"
    echo "  sudo systemctl restart monero-daemon    # Restart daemon"
    echo "  sudo journalctl -u monero-daemon -f     # View logs"
    echo "  $MONERO_BIN_DIR/monero-monitor.sh        # Monitor daemon"
    echo "  curl -X POST -H 'Content-Type: application/json' \\"
    echo "       -d '{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"get_info\"}' \\"
    echo "       http://127.0.0.1:18081/json_rpc     # Get daemon info via RPC"
    echo ""
    echo "IMPORTANT: Monero initial sync will take 12-24 hours and requires 200GB+ storage."
    echo "The daemon is now synchronizing with the network."
    echo ""
    echo "Monero is CPU-only mining (RandomX algorithm) - perfect for pool operations!"
    echo "Configure your pool with the RPC credentials above."
}

# Main execution
main() {
    log "Starting Monero daemon deployment..."
    
    check_prerequisites
    create_user
    install_dependencies
    download_monero
    install_monero
    configure_monero
    create_systemd_service
    setup_logrotate
    setup_monitoring
    start_daemon
    display_summary
    
    log "Deployment completed successfully!"
}

# Execute main function
main "$@"
