#!/bin/bash

# MeowCoin Daemon Deployment Script for Velocity Pool
# This script sets up a MeowCoin daemon for mining pool operations

set -e

# Configuration
MEOWCOIN_VERSION="1.5.0"
MEOWCOIN_USER="meowcoin"
MEOWCOIN_HOME="/home/meowcoin"
MEOWCOIN_DATA_DIR="$MEOWCOIN_HOME/.meowcoin"
MEOWCOIN_BIN_DIR="/usr/local/bin"
DOWNLOAD_URL="https://github.com/MeowcoinDev/MeowCoin/releases/download/v${MEOWCOIN_VERSION}"
ARCH="x86_64-linux-gnu"

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
        warn "System has less than 2GB RAM. MeowCoin daemon may experience performance issues."
    fi
    
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 10485760 ]; then  # 10GB in KB
        warn "Less than 10GB free space available. Blockchain sync requires storage."
    fi
    
    log "Prerequisites check completed"
}

create_user() {
    log "Creating MeowCoin daemon user..."
    
    if ! id "$MEOWCOIN_USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" $MEOWCOIN_USER
        log "Created user: $MEOWCOIN_USER"
    else
        log "User $MEOWCOIN_USER already exists"
    fi
}

install_dependencies() {
    log "Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y \
        wget \
        curl \
        tar \
        ca-certificates \
        systemd \
        bc \
        jq
    
    log "Dependencies installed successfully"
}

download_meowcoin() {
    log "Downloading MeowCoin daemon v${MEOWCOIN_VERSION}..."
    
    cd /tmp
    
    # Download the binary
    FILENAME="meowcoin-${MEOWCOIN_VERSION}-${ARCH}.tar.gz"
    if [ ! -f "$FILENAME" ]; then
        # Try different possible filenames
        wget "${DOWNLOAD_URL}/${FILENAME}" || \
        wget "${DOWNLOAD_URL}/meowcoin-${MEOWCOIN_VERSION}-linux.tar.gz" -O "${FILENAME}" || \
        error "Failed to download MeowCoin binary"
    fi
    
    log "MeowCoin binary downloaded successfully"
}

install_meowcoin() {
    log "Installing MeowCoin daemon..."
    
    cd /tmp
    
    # Extract binary
    tar -xzf "meowcoin-${MEOWCOIN_VERSION}-${ARCH}.tar.gz" 2>/dev/null || \
    tar -xzf "meowcoin-${MEOWCOIN_VERSION}-linux.tar.gz" 2>/dev/null || \
    error "Failed to extract MeowCoin binary"
    
    # Find the extracted directory
    EXTRACT_DIR=$(find . -type d -name "*meowcoin*" | head -1)
    if [ -z "$EXTRACT_DIR" ]; then
        error "Could not find extracted MeowCoin directory"
    fi
    
    cd "$EXTRACT_DIR"
    
    # Install binaries
    if [ -f "bin/meowcoind" ]; then
        sudo cp bin/meowcoind $MEOWCOIN_BIN_DIR/
        sudo cp bin/meowcoin-cli $MEOWCOIN_BIN_DIR/
    elif [ -f "meowcoind" ]; then
        sudo cp meowcoind $MEOWCOIN_BIN_DIR/
        sudo cp meowcoin-cli $MEOWCOIN_BIN_DIR/
    else
        error "Could not find meowcoind binary"
    fi
    
    sudo chmod +x $MEOWCOIN_BIN_DIR/meowcoind
    sudo chmod +x $MEOWCOIN_BIN_DIR/meowcoin-cli
    
    # Verify installation
    if ! $MEOWCOIN_BIN_DIR/meowcoind --version &>/dev/null; then
        error "MeowCoin daemon installation verification failed"
    fi
    
    log "MeowCoin daemon installed successfully"
}

configure_meowcoin() {
    log "Configuring MeowCoin daemon..."
    
    # Create data directory
    sudo -u $MEOWCOIN_USER mkdir -p "$MEOWCOIN_DATA_DIR"
    
    # Generate RPC credentials
    RPC_USER="meowcoinrpc$(openssl rand -hex 4)"
    RPC_PASS=$(openssl rand -base64 32)
    
    # Create configuration file
    sudo -u $MEOWCOIN_USER cat > "$MEOWCOIN_DATA_DIR/meowcoin.conf" << EOF
# MeowCoin daemon configuration for mining pool
# Generated on $(date)

# Network settings
listen=1
server=1
daemon=1

# RPC settings
rpcuser=$RPC_USER
rpcpassword=$RPC_PASS
rpcbind=127.0.0.1
rpcport=9766
rpcallowip=127.0.0.1
rpcthreads=8

# Connection settings
maxconnections=125
addnode=seed1.meowcoin.org
addnode=seed2.meowcoin.org
addnode=seed3.meowcoin.org

# Performance settings
dbcache=2048
maxmempool=512

# Mining settings (pool mode)
gen=0

# Logging
shrinkdebugfile=1
logips=0

# Security
disablewallet=1
EOF

    # Set proper permissions
    sudo chown $MEOWCOIN_USER:$MEOWCOIN_USER "$MEOWCOIN_DATA_DIR/meowcoin.conf"
    sudo chmod 600 "$MEOWCOIN_DATA_DIR/meowcoin.conf"
    
    # Save RPC credentials for pool configuration
    cat > /tmp/meowcoin-rpc-credentials.txt << EOF
MeowCoin RPC Credentials:
RPC Host: 127.0.0.1
RPC Port: 9766
RPC User: $RPC_USER
RPC Password: $RPC_PASS
Configuration saved to: $MEOWCOIN_DATA_DIR/meowcoin.conf
EOF
    
    log "MeowCoin daemon configured. RPC credentials saved to /tmp/meowcoin-rpc-credentials.txt"
}

create_systemd_service() {
    log "Creating systemd service..."
    
    sudo cat > /etc/systemd/system/meowcoin-daemon.service << EOF
[Unit]
Description=MeowCoin Daemon
Documentation=https://github.com/MeowcoinDev/MeowCoin
After=network.target

[Service]
Type=forking
User=$MEOWCOIN_USER
Group=$MEOWCOIN_USER
WorkingDirectory=$MEOWCOIN_HOME
ExecStart=$MEOWCOIN_BIN_DIR/meowcoind -datadir=$MEOWCOIN_DATA_DIR -daemon -pid=$MEOWCOIN_DATA_DIR/meowcoind.pid
ExecStop=$MEOWCOIN_BIN_DIR/meowcoin-cli -datadir=$MEOWCOIN_DATA_DIR stop
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=$MEOWCOIN_DATA_DIR/meowcoind.pid
KillMode=mixed
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

    sudo systemctl daemon-reload
    sudo systemctl enable meowcoin-daemon
    
    log "systemd service created and enabled"
}

setup_logrotate() {
    log "Setting up log rotation..."
    
    sudo cat > /etc/logrotate.d/meowcoin << EOF
$MEOWCOIN_DATA_DIR/debug.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    notifempty
    create 644 $MEOWCOIN_USER $MEOWCOIN_USER
}
EOF
    
    log "Log rotation configured"
}

setup_monitoring() {
    log "Setting up monitoring scripts..."
    
    # Create monitoring script
    sudo cat > $MEOWCOIN_BIN_DIR/meowcoin-monitor.sh << 'EOF'
#!/bin/bash
# MeowCoin daemon monitoring script

MEOWCOIN_CLI="/usr/local/bin/meowcoin-cli"
DATA_DIR="/home/meowcoin/.meowcoin"

# Check if daemon is running
if ! pgrep -f "meowcoind" > /dev/null; then
    echo "ERROR: MeowCoin daemon is not running"
    exit 1
fi

# Get basic info
INFO=$($MEOWCOIN_CLI -datadir=$DATA_DIR getblockchaininfo 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot connect to MeowCoin daemon"
    exit 1
fi

# Extract key metrics
BLOCKS=$(echo "$INFO" | jq -r '.blocks // "unknown"')
HEADERS=$(echo "$INFO" | jq -r '.headers // "unknown"')
DIFFICULTY=$(echo "$INFO" | jq -r '.difficulty // "unknown"')
PROGRESS=$(echo "$INFO" | jq -r '.verificationprogress // "unknown"')

# Get network info
NET_INFO=$($MEOWCOIN_CLI -datadir=$DATA_DIR getnetworkinfo 2>/dev/null)
if [ $? -eq 0 ]; then
    CONNECTIONS=$(echo "$NET_INFO" | jq -r '.connections // "unknown"')
else
    CONNECTIONS="unknown"
fi

echo "MeowCoin Daemon Status:"
echo "  Blocks: $BLOCKS"
echo "  Headers: $HEADERS"
echo "  Connections: $CONNECTIONS"
echo "  Difficulty: $DIFFICULTY"

# Check sync status
if [ "$PROGRESS" != "unknown" ] && [ "$PROGRESS" != "null" ]; then
    if (( $(echo "$PROGRESS < 0.99" | bc -l 2>/dev/null || echo 0) )); then
        PERCENT=$(echo "$PROGRESS * 100" | bc -l 2>/dev/null | cut -d. -f1)
        echo "  Status: Syncing (${PERCENT}%)"
    else
        echo "  Status: Fully synced"
    fi
else
    if [ "$BLOCKS" = "$HEADERS" ] && [ "$BLOCKS" != "unknown" ]; then
        echo "  Status: Fully synced"
    else
        echo "  Status: Syncing"
    fi
fi

exit 0
EOF

    sudo chmod +x $MEOWCOIN_BIN_DIR/meowcoin-monitor.sh
    
    # Add monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $MEOWCOIN_BIN_DIR/meowcoin-monitor.sh") | crontab -
    
    log "Monitoring setup completed"
}

start_daemon() {
    log "Starting MeowCoin daemon..."
    
    sudo systemctl start meowcoin-daemon
    
    # Wait for daemon to start
    sleep 10
    
    # Check if it's running
    if sudo systemctl is-active --quiet meowcoin-daemon; then
        log "MeowCoin daemon started successfully"
    else
        error "Failed to start MeowCoin daemon"
    fi
}

display_summary() {
    log "MeowCoin daemon deployment completed!"
    echo ""
    echo "Summary:"
    echo "  Version: $MEOWCOIN_VERSION"
    echo "  User: $MEOWCOIN_USER"
    echo "  Data Directory: $MEOWCOIN_DATA_DIR"
    echo "  Configuration: $MEOWCOIN_DATA_DIR/meowcoin.conf"
    echo "  Service: meowcoin-daemon"
    echo ""
    echo "RPC Connection Details:"
    cat /tmp/meowcoin-rpc-credentials.txt
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status meowcoin-daemon     # Check service status"
    echo "  sudo systemctl restart meowcoin-daemon    # Restart daemon"
    echo "  sudo journalctl -u meowcoin-daemon -f     # View logs"
    echo "  $MEOWCOIN_BIN_DIR/meowcoin-monitor.sh      # Monitor daemon"
    echo "  $MEOWCOIN_BIN_DIR/meowcoin-cli getinfo     # Get daemon info"
    echo ""
    echo "MeowCoin uses KawPoW algorithm - perfect for GPU mining!"
    echo "Small network = high chance of finding blocks! 🐱"
    echo ""
    echo "Configure your pool with the RPC credentials above."
}

# Main execution
main() {
    log "Starting MeowCoin daemon deployment..."
    
    check_prerequisites
    create_user
    install_dependencies
    download_meowcoin
    install_meowcoin
    configure_meowcoin
    create_systemd_service
    setup_logrotate
    setup_monitoring
    start_daemon
    display_summary
    
    log "Deployment completed successfully!"
}

# Execute main function
main "$@"
