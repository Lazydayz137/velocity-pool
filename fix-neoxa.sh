#!/bin/bash

# Fix Neoxa Daemon Issues
# Run this on your VPS as root

set -e

echo "=== NEOXA DAEMON TROUBLESHOOTING ==="

# Stop the failing service
echo "Stopping neoxa-daemon..."
systemctl stop neoxa-daemon

# Check binary
echo "Checking binary..."
ls -la /usr/local/bin/neoxa*
echo "Testing binary version..."
/usr/local/bin/neoxad --version

# Check data directory
echo "Checking data directory..."
ls -la /root/.neoxa/
echo "Config file contents:"
cat /root/.neoxa/neoxa.conf

# Check for missing dependencies
echo "Checking dependencies..."
ldd /usr/local/bin/neoxad | grep "not found" || echo "All dependencies satisfied"

# Try running manually to see error
echo "=== MANUAL TEST (will show actual error) ==="
echo "Running neoxad manually..."
cd /root
/usr/local/bin/neoxad -datadir=/root/.neoxa -printtoconsole &
MANUAL_PID=$!
sleep 5
kill $MANUAL_PID 2>/dev/null || true

echo "=== TRYING WITH DIFFERENT CONFIG ==="
# Create minimal config
cat > /root/.neoxa/neoxa.conf << 'EOF'
# Minimal Neoxa configuration
daemon=1
server=1
rpcuser=neoxarpc12345
rpcpassword=testpassword123
rpcbind=127.0.0.1
rpcport=8766
rpcallowip=127.0.0.1
datadir=/root/.neoxa
EOF

chmod 600 /root/.neoxa/neoxa.conf
echo "Created minimal config, restarting service..."
systemctl start neoxa-daemon
sleep 3
systemctl status neoxa-daemon --no-pager
