#!/bin/bash

# Velocity Pool VPS Deployment Script
# This script sets up a complete mining pool infrastructure on a VPS

set -e

# Configuration
POOL_USER="velocity"
POOL_HOME="/home/velocity"
POOL_DIR="$POOL_HOME/velocity-pool"
DATABASE_NAME="velocitypool"
DOMAIN_NAME="${1:-pool.example.com}"  # First argument or default

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

banner() {
    echo ""
    echo "================================================"
    echo "           VELOCITY POOL DEPLOYMENT"
    echo "================================================"
    echo ""
}

check_prerequisites() {
    log "Checking system prerequisites..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Run as a sudo-enabled user."
    fi
    
    # Check system requirements
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 8192 ]; then
        warn "System has less than 8GB RAM. Pool may experience performance issues."
    fi
    
    available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 104857600 ]; then  # 100GB in KB
        warn "Less than 100GB free space available. Consider upgrading storage."
    fi
    
    # Check if domain provided
    if [ "$DOMAIN_NAME" = "pool.example.com" ]; then
        warn "Using default domain. Provide your domain as first argument: ./deploy-vps.sh yourdomain.com"
    fi
    
    log "Prerequisites check completed"
}

system_update() {
    log "Updating system packages..."
    
    sudo apt update
    sudo apt upgrade -y
    
    log "System updated successfully"
}

install_base_packages() {
    log "Installing base packages..."
    
    sudo apt install -y \
        curl \
        wget \
        git \
        vim \
        htop \
        tmux \
        ufw \
        fail2ban \
        nginx \
        certbot \
        python3-certbot-nginx \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        pkg-config \
        libssl-dev \
        libevent-dev \
        libboost-all-dev \
        libsodium-dev \
        cmake \
        bc \
        jq
    
    log "Base packages installed successfully"
}

setup_firewall() {
    log "Configuring firewall..."
    
    # Reset UFW to defaults
    sudo ufw --force reset
    
    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    
    # SSH
    sudo ufw allow ssh
    
    # HTTP/HTTPS
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    
    # Pool stratum ports (configurable range)
    sudo ufw allow 3333:3340/tcp
    sudo ufw allow 4000:4010/tcp
    
    # Database (localhost only)
    # PostgreSQL uses local connections only
    
    # Enable firewall
    sudo ufw --force enable
    
    log "Firewall configured successfully"
}

configure_fail2ban() {
    log "Configuring fail2ban..."
    
    # Copy jail configuration
    sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    
    # Create custom jail for pool
    sudo cat > /etc/fail2ban/jail.d/velocity-pool.conf << EOF
[velocity-pool]
enabled = true
filter = velocity-pool
logpath = $POOL_DIR/logs/*.log
maxretry = 5
bantime = 3600
findtime = 600

[nginx-custom]
enabled = true
port = http,https
logpath = %(nginx_error_log)s
maxretry = 3
bantime = 3600
findtime = 600
EOF

    # Create filter for pool
    sudo cat > /etc/fail2ban/filter.d/velocity-pool.conf << EOF
[Definition]
failregex = ^.*\[.*\] .*WARN.*Invalid.*from.*<HOST>.*$
            ^.*\[.*\] .*ERROR.*Connection.*from.*<HOST>.*$
ignoreregex =
EOF

    sudo systemctl enable fail2ban
    sudo systemctl restart fail2ban
    
    log "Fail2ban configured successfully"
}

install_docker() {
    log "Installing Docker..."
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    sudo usermod -aG docker $POOL_USER
    
    # Start and enable Docker
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log "Docker installed successfully"
}

install_nodejs() {
    log "Installing Node.js..."
    
    # Add NodeSource repository for Node.js 18.x
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Verify installation
    node --version
    npm --version
    
    log "Node.js installed successfully"
}

install_dotnet() {
    log "Installing .NET 6.0..."
    
    # Add Microsoft package repository
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    sudo dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    
    # Install .NET 6.0
    sudo apt update
    sudo apt install -y dotnet-sdk-6.0
    
    log ".NET 6.0 installed successfully"
}

install_postgresql() {
    log "Installing PostgreSQL..."
    
    sudo apt install -y postgresql postgresql-contrib
    
    # Start and enable PostgreSQL
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    
    log "PostgreSQL installed successfully"
}

create_pool_user() {
    log "Creating pool user..."
    
    if ! id "$POOL_USER" &>/dev/null; then
        sudo adduser --disabled-password --gecos "" $POOL_USER
        sudo usermod -aG sudo $POOL_USER
        sudo usermod -aG docker $POOL_USER
        log "Created user: $POOL_USER"
    else
        log "User $POOL_USER already exists"
    fi
}

setup_database() {
    log "Setting up database..."
    
    # Generate database password
    DB_PASSWORD=$(openssl rand -base64 32)
    
    # Create database and user
    sudo -u postgres psql << EOF
CREATE ROLE velocity WITH LOGIN ENCRYPTED PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DATABASE_NAME OWNER velocity;
GRANT ALL PRIVILEGES ON DATABASE $DATABASE_NAME TO velocity;
EOF

    # Save database credentials
    cat > /tmp/database-credentials.txt << EOF
Database Configuration:
Host: localhost
Port: 5432
Database: $DATABASE_NAME
Username: velocity
Password: $DB_PASSWORD
EOF

    log "Database configured. Credentials saved to /tmp/database-credentials.txt"
}

clone_repository() {
    log "Cloning Velocity Pool repository..."
    
    # Switch to pool user context
    sudo -u $POOL_USER bash << EOF
cd $POOL_HOME
if [ ! -d "velocity-pool" ]; then
    git clone https://github.com/your-org/velocity-pool.git
    cd velocity-pool
    git checkout main
else
    cd velocity-pool
    git pull origin main
fi
EOF

    log "Repository cloned successfully"
}

build_pool() {
    log "Building pool software..."
    
    sudo -u $POOL_USER bash << EOF
cd $POOL_DIR
chmod +x build-ubuntu-22.04.sh
./build-ubuntu-22.04.sh build
EOF

    log "Pool software built successfully"
}

setup_database_schema() {
    log "Setting up database schema..."
    
    sudo -u $POOL_USER bash << EOF
cd $POOL_DIR
export PGPASSWORD='$DB_PASSWORD'
psql -h localhost -U velocity -d $DATABASE_NAME -f src/Miningcore/Persistence/Postgres/Scripts/createdb.sql
EOF

    log "Database schema initialized"
}

configure_nginx() {
    log "Configuring Nginx..."
    
    # Remove default site
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Create pool site configuration
    sudo cat > /etc/nginx/sites-available/velocity-pool << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN_NAME;
    
    # SSL configuration (certificates will be added by certbot)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Pool API
    location /api/ {
        proxy_pass http://127.0.0.1:4000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # WebSocket for real-time updates
    location /notifications/ {
        proxy_pass http://127.0.0.1:4000/notifications/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Frontend (will be added later)
    location / {
        root $POOL_DIR/frontend/dist;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }
    
    # Static assets
    location /assets/ {
        root $POOL_DIR/frontend/dist;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    # Enable site
    sudo ln -sf /etc/nginx/sites-available/velocity-pool /etc/nginx/sites-enabled/
    
    # Test configuration
    sudo nginx -t
    
    # Start and enable Nginx
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    
    log "Nginx configured successfully"
}

setup_ssl() {
    log "Setting up SSL certificate..."
    
    if [ "$DOMAIN_NAME" != "pool.example.com" ]; then
        # Obtain SSL certificate
        sudo certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME
        
        # Setup auto-renewal
        sudo crontab -l | grep -q certbot || (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | sudo crontab -
        
        log "SSL certificate configured successfully"
    else
        warn "Skipping SSL setup - please configure with your actual domain"
    fi
}

create_pool_service() {
    log "Creating pool systemd service..."
    
    sudo cat > /etc/systemd/system/velocity-pool.service << EOF
[Unit]
Description=Velocity Mining Pool
Documentation=https://github.com/your-org/velocity-pool
After=network.target postgresql.service

[Service]
Type=simple
User=$POOL_USER
Group=$POOL_USER
WorkingDirectory=$POOL_DIR/build
ExecStart=$POOL_DIR/build/Miningcore -c $POOL_DIR/pool-config.json
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=30

# Environment variables
Environment=DOTNET_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://127.0.0.1:4000

# Resource limits
LimitNOFILE=65536
LimitMEMLOCK=infinity

# Security settings
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable velocity-pool
    
    log "Pool service created successfully"
}

create_sample_config() {
    log "Creating sample pool configuration..."
    
    sudo -u $POOL_USER cat > $POOL_DIR/pool-config.json << EOF
{
    "logging": {
        "level": "info",
        "enableConsoleLog": true,
        "enableConsoleColors": true,
        "logFile": "$POOL_DIR/logs/pool.log",
        "logBaseDirectory": "$POOL_DIR/logs",
        "perPoolLogFile": true
    },
    "banning": {
        "manager": "integrated",
        "banOnJunkReceive": true,
        "banOnInvalidShares": false
    },
    "notifications": {
        "enabled": true,
        "email": {
            "host": "smtp.gmail.com",
            "port": 587,
            "user": "your-email@gmail.com",
            "password": "your-app-password",
            "fromAddress": "noreply@$DOMAIN_NAME",
            "fromName": "Velocity Pool"
        }
    },
    "persistence": {
        "postgres": {
            "host": "127.0.0.1",
            "port": 5432,
            "user": "velocity",
            "password": "UPDATE_WITH_DATABASE_PASSWORD",
            "database": "$DATABASE_NAME"
        }
    },
    "paymentProcessing": {
        "enabled": true,
        "interval": 600,
        "shareRecoveryFile": "$POOL_DIR/data/shares.json"
    },
    "api": {
        "enabled": true,
        "listenAddress": "127.0.0.1",
        "port": 4000,
        "metricsPassword": "$(openssl rand -base64 16)"
    },
    "pools": [
        {
            "id": "verus-pool",
            "enabled": false,
            "coin": "verus",
            "address": "YOUR_POOL_WALLET_ADDRESS",
            "rewardRecipients": [
                {
                    "address": "YOUR_POOL_WALLET_ADDRESS",
                    "percentage": 1.5,
                    "type": "dev"
                }
            ],
            "blockRefreshInterval": 1000,
            "jobRebroadcastTimeout": 10,
            "clientConnectionTimeout": 600,
            "banning": {
                "enabled": true,
                "time": 600,
                "invalidPercent": 50,
                "checkThreshold": 50,
                "purgeInterval": 300
            },
            "ports": {
                "3333": {
                    "difficulty": 0.1,
                    "varDiff": {
                        "minDiff": 0.01,
                        "maxDiff": 1000,
                        "targetTime": 30,
                        "retargetTime": 90,
                        "variancePercent": 30
                    }
                }
            },
            "daemons": [
                {
                    "host": "127.0.0.1",
                    "port": 27486,
                    "user": "UPDATE_WITH_RPC_USER",
                    "password": "UPDATE_WITH_RPC_PASSWORD"
                }
            ],
            "paymentProcessing": {
                "enabled": true,
                "minimumPayment": 0.1,
                "payoutScheme": "PPLNS",
                "payoutSchemeConfig": {
                    "factor": 2.0
                }
            }
        }
    ]
}
EOF

    # Create logs directory
    sudo -u $POOL_USER mkdir -p $POOL_DIR/logs
    sudo -u $POOL_USER mkdir -p $POOL_DIR/data
    
    log "Sample configuration created"
}

create_management_scripts() {
    log "Creating management scripts..."
    
    # Create pool management script
    sudo cat > /usr/local/bin/velocity-pool << 'EOF'
#!/bin/bash

case "$1" in
    start)
        sudo systemctl start velocity-pool
        ;;
    stop)
        sudo systemctl stop velocity-pool
        ;;
    restart)
        sudo systemctl restart velocity-pool
        ;;
    status)
        sudo systemctl status velocity-pool
        ;;
    logs)
        sudo journalctl -u velocity-pool -f
        ;;
    config)
        nano /home/velocity/velocity-pool/pool-config.json
        ;;
    *)
        echo "Usage: velocity-pool {start|stop|restart|status|logs|config}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the pool service"
        echo "  stop    - Stop the pool service"
        echo "  restart - Restart the pool service"
        echo "  status  - Show pool service status"
        echo "  logs    - Show real-time pool logs"
        echo "  config  - Edit pool configuration"
        ;;
esac
EOF

    sudo chmod +x /usr/local/bin/velocity-pool
    
    log "Management scripts created"
}

display_summary() {
    banner
    log "Velocity Pool VPS deployment completed!"
    echo ""
    echo "🚀 DEPLOYMENT SUMMARY"
    echo "====================="
    echo ""
    echo "📋 System Information:"
    echo "  • Domain: $DOMAIN_NAME"
    echo "  • Pool User: $POOL_USER"
    echo "  • Pool Directory: $POOL_DIR"
    echo "  • Database: $DATABASE_NAME"
    echo ""
    echo "🔧 Services Installed:"
    echo "  • Nginx (reverse proxy)"
    echo "  • PostgreSQL (database)"
    echo "  • Docker (containerization)"
    echo "  • .NET 6.0 (pool runtime)"
    echo "  • Node.js 18 (frontend)"
    echo "  • Fail2ban (security)"
    echo "  • UFW firewall"
    echo ""
    echo "🔑 Important Files:"
    echo "  • Database credentials: /tmp/database-credentials.txt"
    echo "  • Pool config: $POOL_DIR/pool-config.json"
    echo "  • Nginx config: /etc/nginx/sites-available/velocity-pool"
    echo ""
    echo "🎮 Management Commands:"
    echo "  • velocity-pool start     # Start pool service"
    echo "  • velocity-pool status    # Check pool status"
    echo "  • velocity-pool logs      # View real-time logs"
    echo "  • velocity-pool config    # Edit configuration"
    echo ""
    echo "📱 Deployment Scripts Available:"
    echo "  • Verus: $POOL_DIR/deployment/daemons/verus/deploy-verus.sh"
    echo "  • Monero: $POOL_DIR/deployment/daemons/monero/deploy-monero.sh"
    echo ""
    echo "⚡ Next Steps:"
    echo "  1. Update database password in pool config"
    echo "  2. Deploy coin daemons using provided scripts"
    echo "  3. Update pool configuration with daemon credentials"
    echo "  4. Configure pool wallet addresses"
    echo "  5. Start the pool: velocity-pool start"
    echo ""
    if [ "$DOMAIN_NAME" != "pool.example.com" ]; then
        echo "🌐 Pool will be available at: https://$DOMAIN_NAME"
    else
        echo "🌐 Configure your domain and SSL certificate"
    fi
    echo ""
    echo "📖 Documentation: $POOL_DIR/docs/DEPLOYMENT.md"
    echo ""
    echo "✅ Deployment completed successfully!"
}

# Main execution
main() {
    banner
    info "Starting Velocity Pool VPS deployment..."
    
    check_prerequisites
    system_update
    install_base_packages
    setup_firewall
    configure_fail2ban
    install_docker
    install_nodejs
    install_dotnet
    install_postgresql
    create_pool_user
    setup_database
    clone_repository
    build_pool
    setup_database_schema
    configure_nginx
    setup_ssl
    create_pool_service
    create_sample_config
    create_management_scripts
    display_summary
    
    log "🎉 Velocity Pool VPS deployment completed successfully!"
}

# Execute main function
main "$@"
