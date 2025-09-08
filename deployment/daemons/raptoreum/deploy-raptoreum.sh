#!/bin/bash

# Raptoreum Daemon Deployment Script for Velocity Pool
# This script sets up a Raptoreum daemon for mining pool operations

set -e

# Configuration
RAPTOREUM_VERSION="2.0.3.01-mainnet"
RAPTOREUM_USER="raptoreum"
RAPTOREUM_HOME="/home/raptoreum"
RAPTOREUM_DATA_DIR="$RAPTOREUM_HOME/.raptoreumcore"
RAPTOREUM_BIN_DIR="/usr/local/bin"
DOWNLOAD_URL="https://github.com/Raptor3um/raptoreum/releases/download/${RAPTOREUM_VERSION}"
ARCH="ubuntu22"

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
    if [ "$total_ram" -lt 4096 ]; then
        warn "System has less than 4GB RAM. Raptoreum daemon requires significant memory for GhostRider algorithm."
    fi
    
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 20971520 ]; then  # 20GB in KB
        warn "Less than 20GB free space available. Blockchain sync requires storage."
    fi
    
    log "Prerequisites check completed"
}

create_user() {
    log "Creating Raptoreum daemon user..."
    
    if ! id "$RAPTOREUM_USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" $RAPTOREUM_USER
        log "Created user: $RAPTOREUM_USER"
    else
        log "User $RAPTOREUM_USER already exists"
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
        jq \
        unzip
    
    log "Dependencies installed successfully"
}

download_raptoreum() {
    log "Downloading Raptoreum daemon v${RAPTOREUM_VERSION}..."
    
    cd /tmp
    
    # Download the binary (correct filename)
    FILENAME="raptoreum-${ARCH}-${RAPTOREUM_VERSION}-.tar.gz"
    if [ ! -f "$FILENAME" ]; then
        wget "${DOWNLOAD_URL}/${FILENAME}" || error "Failed to download Raptoreum binary"
    fi
    
    log "Raptoreum binary downloaded successfully"
}

install_raptoreum() {
    log "Installing Raptoreum daemon..."
    
    cd /tmp
    
    # Extract binary
    tar -xzf "raptoreum-${RAPTOREUM_VERSION}-${ARCH}.tar.gz" 2>/dev/null || \
    tar -xzf "raptoreum-${RAPTOREUM_VERSION}-linux.tar.gz" 2>/dev/null || \
    tar -xzf "raptoreum-${RAPTOREUM_VERSION}.tar.gz" 2>/dev/null || \
    error "Failed to extract Raptoreum binary"
    
    # Find the extracted directory
    EXTRACT_DIR=$(find . -type d -name "*raptoreum*" | head -1)
    if [ -z "$EXTRACT_DIR" ]; then
        error "Could not find extracted Raptoreum directory"
    fi
    
    cd "$EXTRACT_DIR"
    
    # Install binaries
    if [ -f "bin/raptoreumd" ]; then
        sudo cp bin/raptoreumd $RAPTOREUM_BIN_DIR/
        sudo cp bin/raptoreum-cli $RAPTOREUM_BIN_DIR/
    elif [ -f "raptoreumd" ]; then
        sudo cp raptoreumd $RAPTOREUM_BIN_DIR/
        sudo cp raptoreum-cli $RAPTOREUM_BIN_DIR/
    else
        error "Could not find raptoreumd binary"
    fi
    
    sudo chmod +x $RAPTOREUM_BIN_DIR/raptoreumd
    sudo chmod +x $RAPTOREUM_BIN_DIR/raptoreum-cli
    
    # Verify installation
    if ! $RAPTOREUM_BIN_DIR/raptoreumd --version &>/dev/null; then
        error "Raptoreum daemon installation verification failed"
    fi
    
    log "Raptoreum daemon installed successfully"
}

configure_raptoreum() {
    log "Configuring Raptoreum daemon..."
    
    # Create data directory
    sudo -u $RAPTOREUM_USER mkdir -p "$RAPTOREUM_DATA_DIR"
    
    # Generate RPC credentials
    RPC_USER="raptoreumrpc$(openssl rand -hex 4)"
    RPC_PASS=$(openssl rand -base64 32)
    
    # Create configuration file
    sudo -u $RAPTOREUM_USER cat > "$RAPTOREUM_DATA_DIR/raptoreum.conf" << EOF
# Raptoreum daemon configuration for mining pool
# Generated on $(date)

# Network settings
listen=1
server=1
daemon=1

# RPC settings
rpcuser=$RPC_USER
rpcpassword=$RPC_PASS
rpcbind=127.0.0.1
rpcport=10226
rpcallowip=127.0.0.1
rpcthreads=16

# Connection settings
maxconnections=125
addnode=seed1.raptoreum.com
addnode=seed2.raptoreum.com
addnode=seed3.raptoreum.com
addnode=seed4.raptoreum.com

# Performance settings
dbcache=4096
maxmempool=1024

# Mining settings (pool mode)
gen=0

# Logging
shrinkdebugfile=1
logips=0

# Security
disablewallet=1

# GhostRider specific optimizations
par=0
EOF

    # Set proper permissions
    sudo chown $RAPTOREUM_USER:$RAPTOREUM_USER "$RAPTOREUM_DATA_DIR/raptoreum.conf"
    sudo chmod 600 "$RAPTOREUM_DATA_DIR/raptoreum.conf"
    
    # Save RPC credentials for pool configuration
    cat > /tmp/raptoreum-rpc-credentials.txt << EOF
Raptoreum RPC Credentials:
RPC Host: 127.0.0.1
RPC Port: 10226
RPC User: $RPC_USER
RPC Password: $RPC_PASS
Configuration saved to: $RAPTOREUM_DATA_DIR/raptoreum.conf
EOF
    
    log "Raptoreum daemon configured. RPC credentials saved to /tmp/raptoreum-rpc-credentials.txt"
}

create_systemd_service() {
    log "Creating systemd service..."
    
    sudo cat > /etc/systemd/system/raptoreum-daemon.service << EOF
[Unit]
Description=Raptoreum Core Daemon
Documentation=https://github.com/Raptor3um/raptoreum
After=network.target

[Service]
Type=forking
User=$RAPTOREUM_USER
Group=$RAPTOREUM_USER
WorkingDirectory=$RAPTOREUM_HOME
ExecStart=$RAPTOREUM_BIN_DIR/raptoreumd -datadir=$RAPTOREUM_DATA_DIR -daemon -pid=$RAPTOREUM_DATA_DIR/raptoreumd.pid
ExecStop=$RAPTOREUM_BIN_DIR/raptoreum-cli -datadir=$RAPTOREUM_DATA_DIR stop
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=$RAPTOREUM_DATA_DIR/raptoreumd.pid
KillMode=mixed
Restart=always
RestartSec=15
TimeoutStartSec=120
TimeoutStopSec=120

# Resource limits (GhostRider requires more resources)
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
    sudo systemctl enable raptoreum-daemon
    
    log "systemd service created and enabled"
}

setup_logrotate() {
    log "Setting up log rotation..."
    
    sudo cat > /etc/logrotate.d/raptoreum << EOF
$RAPTOREUM_DATA_DIR/debug.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    notifempty
    create 644 $RAPTOREUM_USER $RAPTOREUM_USER
}
EOF
    
    log "Log rotation configured"
}

setup_monitoring() {
    log "Setting up monitoring scripts..."
    
    # Create monitoring script
    sudo cat > $RAPTOREUM_BIN_DIR/raptoreum-monitor.sh << 'EOF'
#!/bin/bash
# Raptoreum daemon monitoring script

RAPTOREUM_CLI="/usr/local/bin/raptoreum-cli"
DATA_DIR="/home/raptoreum/.raptoreumcore"

# Check if daemon is running
if ! pgrep -f "raptoreumd" > /dev/null; then
    echo "ERROR: Raptoreum daemon is not running"
    exit 1
fi

# Get basic info
INFO=$($RAPTOREUM_CLI -datadir=$DATA_DIR getblockchaininfo 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot connect to Raptoreum daemon"
    exit 1
fi

# Extract key metrics
BLOCKS=$(echo "$INFO" | jq -r '.blocks // "unknown"')
HEADERS=$(echo "$INFO" | jq -r '.headers // "unknown"')
DIFFICULTY=$(echo "$INFO" | jq -r '.difficulty // "unknown"')
PROGRESS=$(echo "$INFO" | jq -r '.verificationprogress // "unknown"')

# Get network info
NET_INFO=$($RAPTOREUM_CLI -datadir=$DATA_DIR getnetworkinfo 2>/dev/null)
if [ $? -eq 0 ]; then
    CONNECTIONS=$(echo "$NET_INFO" | jq -r '.connections // "unknown"')
else
    CONNECTIONS="unknown"
fi

# Get mining info (for hashrate estimation)
MINING_INFO=$($RAPTOREUM_CLI -datadir=$DATA_DIR getmininginfo 2>/dev/null)
if [ $? -eq 0 ]; then
    NETHASH=$(echo "$MINING_INFO" | jq -r '.networkhashps // "unknown"')
else
    NETHASH="unknown"
fi

echo "Raptoreum Daemon Status:"
echo "  Blocks: $BLOCKS"
echo "  Headers: $HEADERS"
echo "  Connections: $CONNECTIONS"
echo "  Difficulty: $DIFFICULTY"
echo "  Network Hashrate: $NETHASH H/s"

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

    sudo chmod +x $RAPTOREUM_BIN_DIR/raptoreum-monitor.sh
    
    # Add monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $RAPTOREUM_BIN_DIR/raptoreum-monitor.sh") | crontab -
    
    log "Monitoring setup completed"
}

start_daemon() {
    log "Starting Raptoreum daemon..."
    
    sudo systemctl start raptoreum-daemon
    
    # Wait for daemon to start (GhostRider takes longer to initialize)
    sleep 20
    
    # Check if it's running
    if sudo systemctl is-active --quiet raptoreum-daemon; then
        log "Raptoreum daemon started successfully"
    else
        error "Failed to start Raptoreum daemon"
    fi
}

display_summary() {
    log "Raptoreum daemon deployment completed!"
    echo ""
    echo "Summary:"
    echo "  Version: $RAPTOREUM_VERSION"
    echo "  User: $RAPTOREUM_USER"
    echo "  Data Directory: $RAPTOREUM_DATA_DIR"
    echo "  Configuration: $RAPTOREUM_DATA_DIR/raptoreum.conf"
    echo "  Service: raptoreum-daemon"
    echo ""
    echo "RPC Connection Details:"
    cat /tmp/raptoreum-rpc-credentials.txt
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status raptoreum-daemon     # Check service status"
    echo "  sudo systemctl restart raptoreum-daemon    # Restart daemon"
    echo "  sudo journalctl -u raptoreum-daemon -f     # View logs"
    echo "  $RAPTOREUM_BIN_DIR/raptoreum-monitor.sh     # Monitor daemon"
    echo "  $RAPTOREUM_BIN_DIR/raptoreum-cli getinfo    # Get daemon info"
    echo ""
    echo "Raptoreum uses GhostRider algorithm - optimized for CPU mining!"
    echo "Small but growing network with strong fundamentals 🦖"
    echo ""
    echo "Configure your pool with the RPC credentials above."
}

# Main execution
main() {
    log "Starting Raptoreum daemon deployment..."
    
    check_prerequisites
    create_user
    install_dependencies
    download_raptoreum
    install_raptoreum
    configure_raptoreum
    create_systemd_service
    setup_logrotate
    setup_monitoring
    start_daemon
    display_summary
    
    log "Deployment completed successfully!"
}

# Execute main function
main "$@"
