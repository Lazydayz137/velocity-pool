#!/bin/bash

# Velocity Pool VPS Deployment Script (Root Compatible)
# This script sets up a complete mining pool on a VPS running as root

set -e

# Configuration
POOL_USER="velocity"
POOL_HOME="/opt/velocity-pool"
DB_NAME="velocity_pool"
DB_USER="velocity_pool"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

display_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔══════════════════════════════════════╗
║        Velocity Pool Deployment      ║
║     High-Performance Mining Pool     ║
╚══════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

check_prerequisites() {
    log "Checking system prerequisites..."
    
    # Check if running as root (required for this version)
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Check system requirements
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 4096 ]; then
        warn "System has less than 4GB RAM. Pool may experience performance issues."
    fi
    
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 20971520 ]; then  # 20GB in KB
        warn "Less than 20GB free space available."
    fi
    
    # Check Ubuntu/Debian
    if ! command -v apt &> /dev/null; then
        error "This script requires a Debian/Ubuntu-based system with apt package manager"
    fi
    
    log "Prerequisites check completed"
}

update_system() {
    log "Updating system packages..."
    apt update
    DEBIAN_FRONTEND=noninteractive apt upgrade -y
    log "System updated successfully"
}

install_dependencies() {
    log "Installing system dependencies..."
    
    # Install basic packages
    DEBIAN_FRONTEND=noninteractive apt install -y \
        curl \
        wget \
        git \
        build-essential \
        pkg-config \
        libssl-dev \
        libboost-all-dev \
        libsodium-dev \
        cmake \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        jq \
        bc
    
    log "Basic dependencies installed"
}

install_dotnet() {
    log "Installing .NET 6 SDK..."
    
    # Get Ubuntu version
    UBUNTU_VERSION=$(lsb_release -rs)
    
    # Add Microsoft repository
    wget https://packages.microsoft.com/config/ubuntu/${UBUNTU_VERSION}/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    
    # Update package list and install .NET
    apt update
    DEBIAN_FRONTEND=noninteractive apt install -y dotnet-sdk-6.0
    
    # Verify installation
    if ! dotnet --version &>/dev/null; then
        error ".NET 6 SDK installation failed"
    fi
    
    log ".NET 6 SDK installed successfully"
}

install_postgresql() {
    log "Installing PostgreSQL..."
    
    DEBIAN_FRONTEND=noninteractive apt install -y postgresql postgresql-contrib
    
    # Start and enable PostgreSQL
    systemctl start postgresql
    systemctl enable postgresql
    
    log "PostgreSQL installed and started"
}

install_nginx() {
    log "Installing Nginx..."
    
    DEBIAN_FRONTEND=noninteractive apt install -y nginx
    
    # Start and enable Nginx
    systemctl start nginx
    systemctl enable nginx
    
    log "Nginx installed and started"
}

setup_firewall() {
    log "Configuring firewall..."
    
    # Install and configure UFW
    DEBIAN_FRONTEND=noninteractive apt install -y ufw fail2ban
    
    # Configure UFW
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow ssh
    ufw allow 80/tcp   # HTTP
    ufw allow 443/tcp  # HTTPS
    ufw allow 4000/tcp # Pool API
    ufw allow 3333/tcp # Stratum (Verus)
    ufw allow 3334/tcp # Stratum (Raptoreum) 
    ufw allow 3335/tcp # Stratum (Dero)
    ufw allow 3336/tcp # Stratum (MeowCoin)
    ufw allow 3337/tcp # Stratum (Neoxa)
    
    # Enable firewall
    ufw --force enable
    
    # Configure fail2ban
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF
    
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "Firewall configured successfully"
}

create_pool_user() {
    log "Creating pool user..."
    
    if ! id "$POOL_USER" &>/dev/null; then
        useradd -r -s /bin/false -d $POOL_HOME -c "Velocity Pool Service" $POOL_USER
        log "Created user: $POOL_USER"
    else
        log "User $POOL_USER already exists"
    fi
}

setup_database() {
    log "Setting up PostgreSQL database..."
    
    # Generate database password
    DB_PASS=$(openssl rand -base64 32)
    
    # Create database and user
    sudo -u postgres psql << EOF
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';
CREATE DATABASE $DB_NAME OWNER $DB_USER;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF
    
    # Save credentials
    cat > /root/db-credentials.txt << EOF
Database Configuration:
Database: $DB_NAME
User: $DB_USER  
Password: $DB_PASS
Host: localhost
Port: 5432
EOF
    
    log "Database created. Credentials saved to /root/db-credentials.txt"
}

clone_and_build() {
    log "Cloning repository and building pool..."
    
    # Create pool directory
    mkdir -p $POOL_HOME
    cd /opt
    
    # Clone repository
    if [ -d "velocity-pool" ]; then
        rm -rf velocity-pool
    fi
    
    git clone https://github.com/Lazydayz137/velocity-pool.git
    mv velocity-pool/* $POOL_HOME/
    rmdir velocity-pool
    
    # Build native libraries
    cd $POOL_HOME/src/Miningcore
    if [ -f "build-libs-linux.sh" ]; then
        chmod +x build-libs-linux.sh
        ./build-libs-linux.sh $POOL_HOME/build
    fi
    
    # Build .NET project
    dotnet publish -c Release --framework net6.0 -o $POOL_HOME/build
    
    # Set permissions
    chown -R $POOL_USER:$POOL_USER $POOL_HOME
    chmod +x $POOL_HOME/build/Miningcore
    
    log "Repository cloned and built successfully"
}

initialize_database_schema() {
    log "Initializing database schema..."
    
    # Read database password
    DB_PASS=$(grep "Password:" /root/db-credentials.txt | cut -d' ' -f2)
    
    # Initialize schema
    if [ -f "$POOL_HOME/src/Miningcore/Persistence/Postgres/Scripts/createdb.sql" ]; then
        PGPASSWORD=$DB_PASS psql -h localhost -U $DB_USER -d $DB_NAME -f $POOL_HOME/src/Miningcore/Persistence/Postgres/Scripts/createdb.sql
        log "Database schema initialized"
    else
        warn "Database schema file not found - you may need to initialize manually"
    fi
}

create_pool_config() {
    log "Creating pool configuration..."
    
    # Read database password
    DB_PASS=$(grep "Password:" /root/db-credentials.txt | cut -d' ' -f2)
    
    cat > $POOL_HOME/config.json << EOF
{
  "logging": {
    "level": "info",
    "enableConsoleLog": true,
    "enableConsoleColors": true,
    "logFile": "/var/log/velocity-pool/velocity-pool.log",
    "rotateLogFileSize": 50000000
  },
  "clusterName": "Velocity Pool",
  "persistence": {
    "postgres": {
      "host": "localhost",
      "port": 5432,
      "user": "$DB_USER",
      "password": "$DB_PASS",
      "database": "$DB_NAME"
    }
  },
  "paymentProcessing": {
    "enabled": true,
    "interval": 600
  },
  "notifications": {
    "enabled": true,
    "admin": {
      "enabled": false
    }
  },
  "api": {
    "enabled": true,
    "listenAddress": "127.0.0.1",
    "port": 4000,
    "rateLimiting": {
      "disabled": false,
      "rules": [
        {
          "endpoint": "*",
          "period": "1s",
          "limit": 5
        }
      ]
    }
  },
  "pools": [
    {
      "id": "verus",
      "enabled": false,
      "coin": "verus",
      "address": "CHANGE_THIS_TO_YOUR_VERUS_ADDRESS",
      "addressInfoLink": "https://explorer.verus.io/address/{0}",
      "rewardRecipients": [],
      "blockRefreshInterval": 300,
      "jobRebroadcastTimeout": 10,
      "clientConnectionTimeout": 600,
      "banning": {
        "enabled": true,
        "time": 600,
        "invalidPercent": 50,
        "checkThreshold": 50
      },
      "ports": {
        "3333": {
          "difficulty": 0.01,
          "varDiff": {
            "minDiff": 0.001,
            "maxDiff": 1000000000,
            "targetTime": 15,
            "retargetTime": 90,
            "variancePercent": 30
          }
        }
      },
      "daemons": [
        {
          "host": "127.0.0.1",
          "port": 27486,
          "user": "CHANGE_THIS",
          "password": "CHANGE_THIS"
        }
      ],
      "paymentProcessing": {
        "enabled": true,
        "minimumPayment": 0.01,
        "payoutScheme": "PPLNS",
        "payoutSchemeConfig": {
          "factor": 2.0
        }
      }
    }
  ]
}
EOF
    
    chown $POOL_USER:$POOL_USER $POOL_HOME/config.json
    chmod 600 $POOL_HOME/config.json
    
    log "Pool configuration created"
}

create_systemd_service() {
    log "Creating systemd service..."
    
    cat > /etc/systemd/system/velocity-pool.service << EOF
[Unit]
Description=Velocity Pool Mining Software
Documentation=https://github.com/Lazydayz137/velocity-pool
After=network.target postgresql.service

[Service]
Type=simple
User=$POOL_USER
Group=$POOL_USER
WorkingDirectory=$POOL_HOME/build
ExecStart=$POOL_HOME/build/Miningcore -c $POOL_HOME/config.json
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=30

# Resource limits
LimitNOFILE=65536
LimitMEMLOCK=infinity

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=$POOL_HOME /var/log/velocity-pool
ProtectHome=true

# Environment
Environment=DOTNET_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://127.0.0.1:4000

[Install]
WantedBy=multi-user.target
EOF
    
    # Create log directory
    mkdir -p /var/log/velocity-pool
    chown $POOL_USER:$POOL_USER /var/log/velocity-pool
    
    # Enable service
    systemctl daemon-reload
    systemctl enable velocity-pool
    
    log "systemd service created and enabled"
}

configure_nginx() {
    log "Configuring Nginx reverse proxy..."
    
    cat > /etc/nginx/sites-available/velocity-pool << EOF
server {
    listen 80;
    server_name _;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name _;
    
    # SSL configuration (self-signed for now)
    ssl_certificate /etc/ssl/certs/velocity-pool.crt;
    ssl_certificate_key /etc/ssl/private/velocity-pool.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Pool API proxy
    location /api/ {
        proxy_pass http://127.0.0.1:4000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # WebSocket support for notifications
    location /notifications/ {
        proxy_pass http://127.0.0.1:4000/notifications/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Static content
    location / {
        root /var/www/html;
        index index.html;
        try_files \$uri \$uri/ =404;
    }
}
EOF
    
    # Generate self-signed SSL certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/velocity-pool.key \
        -out /etc/ssl/certs/velocity-pool.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=velocity-pool"
    
    # Enable site
    ln -sf /etc/nginx/sites-available/velocity-pool /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload Nginx
    nginx -t && systemctl reload nginx
    
    log "Nginx configured with SSL support"
}

create_management_script() {
    log "Creating management script..."
    
    cat > /usr/local/bin/velocity-pool << 'EOF'
#!/bin/bash

POOL_SERVICE="velocity-pool"
POOL_HOME="/opt/velocity-pool"
LOG_FILE="/var/log/velocity-pool/velocity-pool.log"

case "$1" in
    start)
        echo "Starting Velocity Pool..."
        systemctl start $POOL_SERVICE
        ;;
    stop)
        echo "Stopping Velocity Pool..."
        systemctl stop $POOL_SERVICE
        ;;
    restart)
        echo "Restarting Velocity Pool..."
        systemctl restart $POOL_SERVICE
        ;;
    status)
        systemctl status $POOL_SERVICE
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            journalctl -u $POOL_SERVICE -f
        fi
        ;;
    config)
        nano $POOL_HOME/config.json
        ;;
    *)
        echo "Usage: velocity-pool {start|stop|restart|status|logs|config}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the pool service"
        echo "  stop    - Stop the pool service"
        echo "  restart - Restart the pool service"
        echo "  status  - Show service status"
        echo "  logs    - Show live logs"
        echo "  config  - Edit configuration"
        exit 1
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/velocity-pool
    log "Management script created at /usr/local/bin/velocity-pool"
}

setup_logrotate() {
    log "Setting up log rotation..."
    
    cat > /etc/logrotate.d/velocity-pool << EOF
/var/log/velocity-pool/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    copytruncate
    notifempty
    create 644 velocity velocity
}
EOF
    
    log "Log rotation configured"
}

display_summary() {
    log "Velocity Pool deployment completed!"
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    DEPLOYMENT SUMMARY                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "🏠 Installation Directory: $POOL_HOME"
    echo "👤 Service User: $POOL_USER"
    echo "🗄️  Database: PostgreSQL"
    echo "🌐 Web Server: Nginx with SSL"
    echo "🔧 Service: systemd (velocity-pool)"
    echo ""
    echo -e "${GREEN}📋 Configuration Files:${NC}"
    echo "   Pool Config: $POOL_HOME/config.json"
    echo "   Database Credentials: /root/db-credentials.txt"
    echo "   Nginx Config: /etc/nginx/sites-available/velocity-pool"
    echo ""
    echo -e "${GREEN}🔧 Management Commands:${NC}"
    echo "   velocity-pool start     # Start the pool"
    echo "   velocity-pool stop      # Stop the pool"
    echo "   velocity-pool status    # Check status"
    echo "   velocity-pool logs      # View logs"
    echo "   velocity-pool config    # Edit configuration"
    echo ""
    echo -e "${GREEN}🌍 Network Ports:${NC}"
    echo "   HTTP:  80  (redirects to HTTPS)"
    echo "   HTTPS: 443 (Web interface & API)"
    echo "   API:   4000 (internal)"
    echo "   Stratum ports: 3333-3337 (mining connections)"
    echo ""
    echo -e "${YELLOW}⚠️  NEXT STEPS:${NC}"
    echo "1. Deploy coin daemons using scripts in $POOL_HOME/deployment/daemons/"
    echo "2. Update pool configuration with daemon RPC credentials"
    echo "3. Add your wallet addresses to pool configurations"
    echo "4. Start the pool service: velocity-pool start"
    echo ""
    echo -e "${GREEN}✅ Ready to deploy coin daemons!${NC}"
}

# Main execution
main() {
    display_banner
    log "Starting Velocity Pool VPS deployment..."
    
    check_prerequisites
    update_system
    install_dependencies
    install_dotnet
    install_postgresql  
    install_nginx
    setup_firewall
    create_pool_user
    setup_database
    clone_and_build
    initialize_database_schema
    create_pool_config
    create_systemd_service
    configure_nginx
    create_management_script
    setup_logrotate
    display_summary
    
    log "Deployment completed successfully!"
}

# Execute main function
main "$@"
