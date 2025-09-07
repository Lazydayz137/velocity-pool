#!/bin/bash
set -e

# Alephium Pool Setup Script
# This script configures and starts the Alephium mining pool

POOL_DIR="/home/lazydayz137/velocity-pool"
CONFIG_DIR="$POOL_DIR/pool-configs/alephium"
DAEMON_DIR="/home/lazydayz137/alephium-daemon"
MININGCORE_DIR="$POOL_DIR/src/build"

echo "🏊 Setting up Alephium Mining Pool..."

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check if Alephium daemon is set up
    if [ ! -f "$DAEMON_DIR/config/api-key.txt" ]; then
        echo "❌ Alephium daemon not configured. Run:"
        echo "   $DAEMON_DIR/scripts/setup-daemon.sh"
        exit 1
    fi
    
    # Check if Miningcore is built
    if [ ! -f "$MININGCORE_DIR/Miningcore.dll" ]; then
        echo "❌ Miningcore not built. Run:"
        echo "   cd $POOL_DIR/src && dotnet build -c Release"
        exit 1
    fi
    
    # Check PostgreSQL
    if ! command -v psql &> /dev/null; then
        echo "❌ PostgreSQL not found. Install with:"
        echo "   sudo apt update && sudo apt install postgresql postgresql-contrib"
        exit 1
    fi
    
    echo "✅ Prerequisites check passed"
}

# Configure pool with API key
configure_pool() {
    echo "⚙️  Configuring pool..."
    
    # Get API key from daemon
    API_KEY=$(cat "$DAEMON_DIR/config/api-key.txt")
    
    if [ -z "$API_KEY" ]; then
        echo "❌ Could not read API key from daemon configuration"
        exit 1
    fi
    
    # Update pool configuration
    sed -i "s/YOUR_ALEPHIUM_API_KEY_HERE/$API_KEY/g" "$CONFIG_DIR/pool-config.json"
    
    echo "✅ Pool configured with API key"
    echo "🔑 API Key: ${API_KEY:0:8}..."
}

# Setup database
setup_database() {
    echo "🗄️  Setting up database..."
    
    # Check if database exists
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw miningcore; then
        echo "⚡ Database 'miningcore' already exists"
    else
        echo "📊 Creating database..."
        sudo -u postgres createdb miningcore
        sudo -u postgres psql -c "CREATE USER miningcore WITH ENCRYPTED PASSWORD 'your-secure-password';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE miningcore TO miningcore;"
    fi
    
    # Initialize schema if needed
    if [ -f "$POOL_DIR/src/Miningcore/Persistence/Postgres/Scripts/createdb.sql" ]; then
        echo "📝 Initializing database schema..."
        sudo -u postgres psql -d miningcore -f "$POOL_DIR/src/Miningcore/Persistence/Postgres/Scripts/createdb.sql" || true
    fi
    
    echo "✅ Database setup complete"
}

# Create start script
create_start_script() {
    cat > "$CONFIG_DIR/start-pool.sh" << 'EOF'
#!/bin/bash
set -e

POOL_DIR="/home/lazydayz137/velocity-pool"
CONFIG_DIR="$POOL_DIR/pool-configs/alephium"
MININGCORE_DIR="$POOL_DIR/src/build"
DAEMON_DIR="/home/lazydayz137/alephium-daemon"

echo "🏊 Starting Alephium Mining Pool..."

# Check if daemon is running
if ! $DAEMON_DIR/scripts/monitor.sh status | grep -q "RUNNING"; then
    echo "⚠️  Alephium daemon is not running. Starting it first..."
    $DAEMON_DIR/scripts/start-daemon.sh
    
    # Wait for daemon to be ready
    echo "⏳ Waiting for daemon to be ready..."
    for i in {1..60}; do
        if $DAEMON_DIR/scripts/monitor.sh api | grep -q "ACCESSIBLE"; then
            echo "✅ Daemon is ready"
            break
        fi
        echo "   Waiting... ($i/60)"
        sleep 5
    done
    
    if [ $i -eq 60 ]; then
        echo "❌ Daemon failed to become ready"
        exit 1
    fi
fi

# Create logs directory
mkdir -p "$CONFIG_DIR/logs"

# Start Miningcore
cd "$MININGCORE_DIR"

echo "🚀 Starting Miningcore with Alephium pool..."
dotnet Miningcore.dll -c "$CONFIG_DIR/pool-config.json"
EOF

    chmod +x "$CONFIG_DIR/start-pool.sh"
    echo "✅ Start script created at $CONFIG_DIR/start-pool.sh"
}

# Create monitoring script for the pool
create_pool_monitor() {
    cat > "$CONFIG_DIR/monitor-pool.sh" << 'EOF'
#!/bin/bash

CONFIG_DIR="/home/lazydayz137/velocity-pool/pool-configs/alephium"
DAEMON_DIR="/home/lazydayz137/alephium-daemon"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏊 Alephium Pool Monitor${NC}"
echo "=================================="

# Check daemon status
echo -e "${BLUE}📡 Alephium Daemon:${NC}"
$DAEMON_DIR/scripts/monitor.sh status

echo ""

# Check pool API
echo -e "${BLUE}🔌 Pool API:${NC}"
if curl -s http://127.0.0.1:4001/api/pools > /dev/null; then
    echo -e "${GREEN}✅ Pool API: ACCESSIBLE${NC}"
    
    # Get pool stats
    POOL_STATS=$(curl -s http://127.0.0.1:4001/api/pools/alephium)
    if [ -n "$POOL_STATS" ]; then
        HASHRATE=$(echo "$POOL_STATS" | jq -r '.poolStats.poolHashrate // 0' 2>/dev/null || echo "0")
        MINERS=$(echo "$POOL_STATS" | jq -r '.poolStats.connectedMiners // 0' 2>/dev/null || echo "0")
        
        echo -e "${GREEN}⚡ Pool Hashrate: $HASHRATE H/s${NC}"
        echo -e "${GREEN}👥 Connected Miners: $MINERS${NC}"
    fi
else
    echo -e "${RED}❌ Pool API: NOT ACCESSIBLE${NC}"
fi

echo ""

# Check recent pool logs
echo -e "${BLUE}📋 Recent Pool Logs:${NC}"
if [ -f "$CONFIG_DIR/logs/alephium-pool.log" ]; then
    tail -5 "$CONFIG_DIR/logs/alephium-pool.log"
else
    echo -e "${YELLOW}⚠️  Pool log file not found${NC}"
fi

echo ""
echo "=================================="
echo -e "${BLUE}🔄 Continuous monitoring: watch -n 30 '$0'${NC}"
echo -e "${BLUE}🌐 Pool web interface: http://your-domain:4001${NC}"
EOF

    chmod +x "$CONFIG_DIR/monitor-pool.sh"
    echo "✅ Pool monitor created at $CONFIG_DIR/monitor-pool.sh"
}

# Create wallet setup guide
create_wallet_guide() {
    cat > "$CONFIG_DIR/WALLET_SETUP.md" << 'EOF'
# Alephium Wallet Setup

## 1. Download Alephium Wallet

Download the official Alephium wallet from:
- Desktop: https://github.com/alephium/desktop-wallet/releases
- Mobile: Available on App Store and Google Play

## 2. Create Wallet

1. Open the wallet application
2. Click "Create Wallet"
3. **IMPORTANT**: Save your seed phrase securely
4. Set a strong password
5. Complete wallet creation

## 3. Get Your Address

1. In the wallet, go to "Receive"
2. Copy your wallet address (starts with "1...")
3. This is your pool payout address

## 4. Update Pool Configuration

Replace "YOUR_ALEPHIUM_WALLET_ADDRESS_HERE" in pool-config.json with your address:

```bash
sed -i 's/YOUR_ALEPHIUM_WALLET_ADDRESS_HERE/your-actual-address-here/g' pool-config.json
```

## 5. Verify Configuration

After updating, verify the configuration:
```bash
grep "address" pool-config.json
```

You should see your wallet address in multiple places.

## Security Notes

- ⚠️  **Never share your seed phrase or private keys**
- 🔐 Use a strong password for your wallet
- 💾 Backup your wallet file regularly
- 🏦 Consider using a hardware wallet for large amounts

## Pool Configuration Fields

- `address`: Your payout address
- `rewardRecipients.address`: Same as above for pool fees
- Both should be the same Alephium address you control
EOF

    echo "✅ Wallet setup guide created at $CONFIG_DIR/WALLET_SETUP.md"
}

# Main setup function
main() {
    echo "🏗️  Alephium Pool Setup Starting..."
    
    check_prerequisites
    configure_pool
    setup_database
    create_start_script
    create_pool_monitor
    create_wallet_guide
    
    echo ""
    echo "🎉 Alephium pool setup complete!"
    echo ""
    echo "📁 Configuration directory: $CONFIG_DIR"
    echo "⚙️  Pool configuration: $CONFIG_DIR/pool-config.json"
    echo "📝 Wallet setup guide: $CONFIG_DIR/WALLET_SETUP.md"
    echo ""
    echo "Next steps:"
    echo "1. 📖 Read the wallet setup guide: cat $CONFIG_DIR/WALLET_SETUP.md"
    echo "2. 💰 Set up your Alephium wallet and get your address"
    echo "3. ⚙️  Update wallet address in pool-config.json"
    echo "4. 🚀 Start the pool: $CONFIG_DIR/start-pool.sh"
    echo "5. 📊 Monitor the pool: $CONFIG_DIR/monitor-pool.sh"
    echo ""
    echo "⚠️  IMPORTANT: Update your wallet address before starting the pool!"
}

main "$@"
