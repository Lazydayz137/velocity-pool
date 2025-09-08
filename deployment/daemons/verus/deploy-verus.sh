#!/bin/bash

# Verus Daemon Deployment Script for Velocity Pool
# This script sets up a Verus daemon for mining pool operations

set -e

# Configuration
VERUS_VERSION="0.9.8-2"
VERUS_USER="verus"
VERUS_HOME="/home/verus"
VERUS_DATA_DIR="$VERUS_HOME/.komodo/VRSC"
VERUS_BIN_DIR="/usr/local/bin"
DOWNLOAD_URL="https://github.com/VerusCoin/VerusCoin/releases/download/v${VERUS_VERSION}"
ARCH="linux-x86_64"

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
        warn "System has less than 4GB RAM. Verus daemon may experience performance issues."
    fi
    
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 52428800 ]; then  # 50GB in KB
        warn "Less than 50GB free space available. Blockchain sync requires significant storage."
    fi
    
    log "Prerequisites check completed"
}

create_user() {
    log "Creating Verus daemon user..."
    
    if ! id "$VERUS_USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" $VERUS_USER
        sudo usermod -aG sudo $VERUS_USER
        log "Created user: $VERUS_USER"
    else
        log "User $VERUS_USER already exists"
    fi
}

install_dependencies() {
    log "Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y \
        wget \
        curl \
        unzip \
        libgomp1 \
        libz-dev \
        libc6-dev \
        libc6 \
        build-essential \
        libtool \
        autotools-dev \
        automake \
        pkg-config \
        libssl-dev \
        libevent-dev \
        bsdmainutils \
        python3 \
        libboost-all-dev \
        libminiupnpc-dev \
        libzmq3-dev \
        systemd
    
    log "Dependencies installed successfully"
}

download_verus() {
    log "Downloading Verus daemon v${VERUS_VERSION}..."
    
    cd /tmp
    
    # Download the binary
    FILENAME="Verus-CLI-${ARCH}-v${VERUS_VERSION}.tar.gz"
    if [ ! -f "$FILENAME" ]; then
        wget "${DOWNLOAD_URL}/${FILENAME}" || error "Failed to download Verus binary"
    fi
    
    # Verify download (basic check)
    if [ ! -f "$FILENAME" ]; then
        error "Downloaded file not found: $FILENAME"
    fi
    
    # Extract binary
    tar -xzf "$FILENAME" || error "Failed to extract Verus binary"
    
    log "Verus binary downloaded and extracted"
}

install_verus() {
    log "Installing Verus daemon..."
    
    cd /tmp
    
    # Find the extracted directory (varies by release)
    EXTRACT_DIR=$(ls -d */ | grep -i verus | head -1)
    if [ -z "$EXTRACT_DIR" ]; then
        error "Could not find extracted Verus directory"
    fi
    
    cd "$EXTRACT_DIR"
    
    # Install binaries
    sudo cp verusd $VERUS_BIN_DIR/
    sudo cp verus $VERUS_BIN_DIR/
    sudo chmod +x $VERUS_BIN_DIR/verusd
    sudo chmod +x $VERUS_BIN_DIR/verus
    
    # Verify installation
    if ! $VERUS_BIN_DIR/verusd --version &>/dev/null; then
        error "Verus daemon installation verification failed"
    fi
    
    log "Verus daemon installed successfully"
}

configure_verus() {
    log "Configuring Verus daemon..."
    
    # Create data directory
    sudo -u $VERUS_USER mkdir -p "$VERUS_DATA_DIR"
    
    # Generate RPC credentials
    RPC_USER="verusrpc$(openssl rand -hex 4)"
    RPC_PASS=$(openssl rand -base64 32)
    
    # Create configuration file
    sudo -u $VERUS_USER cat > "$VERUS_DATA_DIR/VRSC.conf" << EOF
# Verus daemon configuration for mining pool
# Generated on $(date)

# Network settings
listen=1
server=1
daemon=1
rest=1

# RPC settings
rpcuser=$RPC_USER
rpcpassword=$RPC_PASS
rpcbind=127.0.0.1
rpcport=27486
rpcallowip=127.0.0.1

# Connection settings
maxconnections=200
addnode=185.25.48.236:27485
addnode=185.64.105.111:27485
addnode=node1.verus.io:27485
addnode=node2.verus.io:27485

# Mining settings
gen=0
genproclimit=0

# Performance settings
dbcache=4096
maxmempool=512

# Logging
shrinkdebugfile=1
logips=0

# Security
disablewallet=1
EOF

    # Set proper permissions
    sudo chown $VERUS_USER:$VERUS_USER "$VERUS_DATA_DIR/VRSC.conf"
    sudo chmod 600 "$VERUS_DATA_DIR/VRSC.conf"
    
    # Save RPC credentials for pool configuration
    cat > /tmp/verus-rpc-credentials.txt << EOF
Verus RPC Credentials:
RPC Host: 127.0.0.1
RPC Port: 27486
RPC User: $RPC_USER
RPC Password: $RPC_PASS
Configuration saved to: $VERUS_DATA_DIR/VRSC.conf
EOF
    
    log "Verus daemon configured. RPC credentials saved to /tmp/verus-rpc-credentials.txt"
}

create_systemd_service() {
    log "Creating systemd service..."
    
    sudo cat > /etc/systemd/system/verus-daemon.service << EOF
[Unit]
Description=Verus Daemon
Documentation=https://github.com/VerusCoin/VerusCoin
After=network.target

[Service]
Type=forking
User=$VERUS_USER
Group=$VERUS_USER
WorkingDirectory=$VERUS_HOME
ExecStart=$VERUS_BIN_DIR/verusd -datadir=$VERUS_DATA_DIR -daemon
ExecStop=$VERUS_BIN_DIR/verus -datadir=$VERUS_DATA_DIR stop
ExecReload=/bin/kill -HUP \$MAINPID
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
    sudo systemctl enable verus-daemon
    
    log "systemd service created and enabled"
}

setup_logrotate() {
    log "Setting up log rotation..."
    
    sudo cat > /etc/logrotate.d/verus << EOF
$VERUS_DATA_DIR/debug.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    copytruncate
    notifempty
    create 644 $VERUS_USER $VERUS_USER
}
EOF
    
    log "Log rotation configured"
}

setup_monitoring() {
    log "Setting up monitoring scripts..."
    
    # Create monitoring script
    sudo cat > $VERUS_BIN_DIR/verus-monitor.sh << 'EOF'
#!/bin/bash
# Verus daemon monitoring script

VERUS_CLI="/usr/local/bin/verus"
DATA_DIR="/home/verus/.komodo/VRSC"

# Check if daemon is running
if ! pgrep -f "verusd" > /dev/null; then
    echo "ERROR: Verus daemon is not running"
    exit 1
fi

# Get basic info
INFO=$($VERUS_CLI getinfo 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "ERROR: Cannot connect to Verus daemon"
    exit 1
fi

# Extract key metrics
BLOCKS=$(echo "$INFO" | grep '"blocks"' | awk -F: '{print $2}' | tr -d ' ,')
CONNECTIONS=$(echo "$INFO" | grep '"connections"' | awk -F: '{print $2}' | tr -d ' ,')
DIFFICULTY=$(echo "$INFO" | grep '"difficulty"' | awk -F: '{print $2}' | tr -d ' ,')

echo "Verus Daemon Status:"
echo "  Blocks: $BLOCKS"
echo "  Connections: $CONNECTIONS"  
echo "  Difficulty: $DIFFICULTY"

# Check sync status
BLOCKCHAIN_INFO=$($VERUS_CLI getblockchaininfo 2>/dev/null)
if [ $? -eq 0 ]; then
    PROGRESS=$(echo "$BLOCKCHAIN_INFO" | grep '"verificationprogress"' | awk -F: '{print $2}' | tr -d ' ,')
    if (( $(echo "$PROGRESS < 0.99" | bc -l) )); then
        echo "  Status: Syncing ($(echo "$PROGRESS * 100" | bc -l | cut -d. -f1)%)"
    else
        echo "  Status: Fully synced"
    fi
fi

exit 0
EOF

    sudo chmod +x $VERUS_BIN_DIR/verus-monitor.sh
    
    # Add monitoring cron job
    (crontab -l 2>/dev/null; echo "*/5 * * * * $VERUS_BIN_DIR/verus-monitor.sh") | crontab -
    
    log "Monitoring setup completed"
}

start_daemon() {
    log "Starting Verus daemon..."
    
    sudo systemctl start verus-daemon
    
    # Wait for daemon to start
    sleep 10
    
    # Check if it's running
    if sudo systemctl is-active --quiet verus-daemon; then
        log "Verus daemon started successfully"
    else
        error "Failed to start Verus daemon"
    fi
}

display_summary() {
    log "Verus daemon deployment completed!"
    echo ""
    echo "Summary:"
    echo "  Version: $VERUS_VERSION"
    echo "  User: $VERUS_USER"
    echo "  Data Directory: $VERUS_DATA_DIR"
    echo "  Configuration: $VERUS_DATA_DIR/VRSC.conf"
    echo "  Service: verus-daemon"
    echo ""
    echo "RPC Connection Details:"
    cat /tmp/verus-rpc-credentials.txt
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status verus-daemon    # Check service status"
    echo "  sudo systemctl restart verus-daemon   # Restart daemon"
    echo "  sudo journalctl -u verus-daemon -f    # View logs"
    echo "  $VERUS_BIN_DIR/verus-monitor.sh        # Monitor daemon"
    echo "  $VERUS_BIN_DIR/verus getinfo           # Get daemon info"
    echo ""
    echo "The daemon is now synchronizing with the network."
    echo "Initial sync may take several hours depending on your connection."
    echo ""
    echo "Configure your pool with the RPC credentials above."
}

# Main execution
main() {
    log "Starting Verus daemon deployment..."
    
    check_prerequisites
    create_user
    install_dependencies
    download_verus
    install_verus
    configure_verus
    create_systemd_service
    setup_logrotate
    setup_monitoring
    start_daemon
    display_summary
    
    log "Deployment completed successfully!"
}

# Execute main function
main "$@"
