#!/bin/bash

# Neoxa Daemon Deployment Script for Velocity Pool
# This script sets up a Neoxa daemon for mining pool operations

set -e

# Configuration
NEOXA_VERSION="2.3.0"
NEOXA_USER="neoxa"
NEOXA_HOME="/home/neoxa"
NEOXA_DATA_DIR="$NEOXA_HOME/.neoxa"
NEOXA_BIN_DIR="/usr/local/bin"
DOWNLOAD_URL="https://github.com/NeoxaChain/Neoxa/releases/download/v${NEOXA_VERSION}"
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
        warn "System has less than 2GB RAM. Neoxa daemon may experience performance issues."
    fi
    
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 10485760 ]; then  # 10GB in KB
        warn "Less than 10GB free space available. Blockchain sync requires storage."
    fi
    
    log "Prerequisites check completed"
}

create_user() {
    log "Creating Neoxa daemon user..."
    
    if ! id "$NEOXA_USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" $NEOXA_USER
        log "Created user: $NEOXA_USER"
    else
        log "User $NEOXA_USER already exists"
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

download_neoxa() {
    log "Downloading Neoxa daemon v${NEOXA_VERSION}..."
    
    cd /tmp
    
    # Download the binary
    FILENAME="neoxa-${NEOXA_VERSION}-${ARCH}.tar.gz"
    if [ ! -f "$FILENAME" ]; then
        # Try different possible filenames
        wget "${DOWNLOAD_URL}/${FILENAME}" || \
        wget "${DOWNLOAD_URL}/neoxa-${NEOXA_VERSION}-linux.tar.gz" -O "${FILENAME}" || \
        wget "${DOWNLOAD_URL}/neoxa-linux.tar.gz" -O "${FILENAME}" || \
        error "Failed to download Neoxa binary"
    fi
    
    log "Neoxa binary downloaded successfully"
}

install_neoxa() {
    log "Installing Neoxa daemon..."
    
    cd /tmp
    
    # Extract binary
    tar -xzf "neoxa-${NEOXA_VERSION}-${ARCH}.tar.gz" 2>/dev/null || \
    tar -xzf "neoxa-${NEOXA_VERSION}-linux.tar.gz" 2>/dev/null || \
    tar -xzf "neoxa-linux.tar.gz" 2>/dev/null || \
    error "Failed to extract Neoxa binary"
    
    # Find the extracted directory
    EXTRACT_DIR=$(find . -type d -name "*neoxa*" | head -1)
    if [ -z "$EXTRACT_DIR" ]; then
        error "Could not find extracted Neoxa directory"
    fi
    
    cd "$EXTRACT_DIR"
    
    # Install binaries
    if [ -f "bin/neoxad" ]; then
        sudo cp bin/neoxad $NEOXA_BIN_DIR/
        sudo cp bin/neoxa-cli $NEOXA_BIN_DIR/
    elif [ -f "neoxad" ]; then
        sudo cp neoxad $NEOXA_BIN_DIR/
        sudo cp neoxa-cli $NEOXA_BIN_DIR/
    else
        error "Could not find neoxad binary"
    fi
    
    sudo chmod +x $NEOXA_BIN_DIR/neoxad
    sudo chmod +x $NEOXA_BIN_DIR/neoxa-cli
    
    # Verify installation
    if ! $NEOXA_BIN_DIR/neoxad --version &>/dev/null; then
        error "Neoxa daemon installation verification failed"
    fi
    
    log "Neoxa daemon installed successfully"
}

configure_neoxa() {
    log "Configuring Neoxa daemon..."
    
    # Create data directory
    sudo -u $NEOXA_USER mkdir -p "$NEOXA_DATA_DIR"
    
    # Generate RPC credentials
    RPC_USER="neoxarpc$(openssl rand -hex 4)"
    RPC_PASS=$(openssl rand -base64 32)
    
    # Create configuration file
    sudo -u $NEOXA_USER cat > "$NEOXA_DATA_DIR/neoxa.conf" << EOF
# Neoxa daemon configuration for mining pool
# Generated on $(date)

# Network settings
listen=1
server=1
daemon=1

# RPC settings
rpcuser=$RPC_USER
rpcpassword=$RPC_PASS
rpcbind=127.0.0.1
rpcport=8766
rpcallowip=127.0.0.1
rpcthreads=8

# Connection settings
maxconnections=125
addnode=seed1.neoxa.org
addnode=seed2.neoxa.org
addnode=seed3.neoxa.org

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
    sudo chown $NEOXA_USER:$NEOXA_USER "$NEOXA_DATA_DIR/neoxa.conf"
    sudo chmod 600 "$NEOXA_DATA_DIR/neoxa.conf"
    
    # Save RPC credentials for pool configuration
    cat > /tmp/neoxa-rpc-credentials.txt << EOF
Neoxa RPC Credentials:
RPC Host: 127.0.0.1
RPC Port: 8766
RPC User: $RPC_USER
RPC Password: $RPC_PASS
Configuration saved to: $NEOXA_DATA_DIR/neoxa.conf
EOF
    
    log "Neoxa daemon configured. RPC credentials saved to /tmp/neoxa-rpc-credentials.txt"
}

create_systemd_service() {
    log "Creating systemd service..."
    
    sudo cat > /etc/systemd/system/neoxa-daemon.service << EOF
[Unit]
Description=Neoxa Daemon
Documentation=https://github.com/NeoxaChain/Neoxa
After=network.target

[Service]
Type=forking
User=$NEOXA_USER
Group=$NEOXA_USER
WorkingDirectory=$NEOXA_HOME
ExecStart=$NEOXA_BIN_DIR/neoxad -datadir=$NEOXA_DATA_DIR -daemon -pid=$NEOXA_DATA_DIR/neoxad.pid
ExecStop=$NEOXA_BIN_DIR/neoxa-cli -datadir=$NEOXA_DATA_DIR stop
ExecReload=/bin/kill -HUP \$MAINPID
PIDFile=$NEOXA_DATA_DIR/neoxad.pid
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
    sudo systemctl enable neoxa-daemon
    
    log "systemd service created and enabled"
}

setup_logrotate() {
    log "Setting up log rotation..."
    
    sudo cat > /etc/logrotate.d/neoxa << EOF
$NEOXA_DATA_DIR/debug.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    notifempty
    create 644 $NEOXA_USER $NEOXA_USER
}
EOF
    
    log "Log rotation configured"
}

setup_monitoring() {
    log "Setting up monitoring scripts..."
    
    # Create monitoring script
    sudo cat > $NEOXA_BIN_DIR/neoxa-monitor.sh << 'EOF'
#!/bin/bash
# Neoxa daemon monitoring script

NEOXA_CLI="/usr/local/bin/neoxa-cli"
DATA_DIR="/home/neoxa/.neoxa"

# Check if daemon is running
if ! pgrep -f "neoxad" > /dev/null; then
    echo "ERROR: Neoxa daemon is not running"
    exit 1
fi

# Get basic info
INFO=$($NEOXA_CLI -datadir=$DATA_DIR getblockchaininfo 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot connect to Neoxa daemon"
    exit 1
fi

# Extract key metrics
BLOCKS=$(echo "$INFO" | jq -r '.blocks // "unknown"')
HEADERS=$(echo "$INFO" | jq -r '.headers // "unknown"')
DIFFICULTY=$(echo "$INFO" | jq -r '.difficulty // "unknown"')
PROGRESS=$(echo "$INFO" | jq -r '.verificationprogress // "unknown"')

# Get network info
NET_INFO=$($NEOXA_CLI -datadir=$DATA_DIR getnetworkinfo 2>/dev/null)
if [ $? -eq 0 ]; then
    CONNECTIONS=$(echo "$NET_INFO" | jq -r '.connections // "unknown"')
else
    CONNECTIONS="unknown"
fi

# Get mining info (for hashrate estimation)
MINING_INFO=$($NEOXA_CLI -datadir=$DATA_DIR getmininginfo 2>/dev/null)
if [ $? -eq 0 ]; then
    NETHASH=$(echo "$MINING_INFO" | jq -r '.networkhashps // "unknown"')
else
    NETHASH="unknown"
fi

echo "Neoxa Daemon Status:"
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

    sudo chmod +x $NEOXA_BIN_DIR/neoxa-monitor.sh
    
    # Add monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $NEOXA_BIN_DIR/neoxa-monitor.sh") | crontab -
    
    log "Monitoring setup completed"
}

start_daemon() {
    log "Starting Neoxa daemon..."
    
    sudo systemctl start neoxa-daemon
    
    # Wait for daemon to start
    sleep 10
    
    # Check if it's running
    if sudo systemctl is-active --quiet neoxa-daemon; then
        log "Neoxa daemon started successfully"
    else
        error "Failed to start Neoxa daemon"
    fi
}

display_summary() {
    log "Neoxa daemon deployment completed!"
    echo ""
    echo "Summary:"
    echo "  Version: $NEOXA_VERSION"
    echo "  User: $NEOXA_USER"
    echo "  Data Directory: $NEOXA_DATA_DIR"
    echo "  Configuration: $NEOXA_DATA_DIR/neoxa.conf"
    echo "  Service: neoxa-daemon"
    echo ""
    echo "RPC Connection Details:"
    cat /tmp/neoxa-rpc-credentials.txt
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status neoxa-daemon       # Check service status"
    echo "  sudo systemctl restart neoxa-daemon      # Restart daemon"
    echo "  sudo journalctl -u neoxa-daemon -f       # View logs"
    echo "  $NEOXA_BIN_DIR/neoxa-monitor.sh           # Monitor daemon"
    echo "  $NEOXA_BIN_DIR/neoxa-cli getinfo          # Get daemon info"
    echo ""
    echo "Neoxa uses KawPoW algorithm - perfect for GPU mining!"
    echo "Growing network with gaming focus and solid community 🎮"
    echo ""
    echo "Configure your pool with the RPC credentials above."
}

# Main execution
main() {
    log "Starting Neoxa daemon deployment..."
    
    check_prerequisites
    create_user
    install_dependencies
    download_neoxa
    install_neoxa
    configure_neoxa
    create_systemd_service
    setup_logrotate
    setup_monitoring
    start_daemon
    display_summary
    
    log "Deployment completed successfully!"
}

# Execute main function
main "$@"
