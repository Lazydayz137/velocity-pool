#!/bin/bash

# Fix Neoxa systemd service
# Run on VPS as root

echo "Fixing Neoxa systemd service..."

# Stop current service
systemctl stop neoxa-daemon

# Create new service file
cat > /etc/systemd/system/neoxa-daemon.service << 'EOF'
[Unit]
Description=Neoxa Daemon
Documentation=https://github.com/NeoxaChain/Neoxa
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/neoxad -datadir=/root/.neoxa -printtoconsole
ExecStop=/bin/kill -TERM $MAINPID
Restart=always
RestartSec=10
TimeoutStartSec=60
TimeoutStopSec=60
KillMode=mixed

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

# Reload and restart
systemctl daemon-reload
systemctl enable neoxa-daemon
systemctl start neoxa-daemon

sleep 3

echo "Service status:"
systemctl status neoxa-daemon --no-pager

echo ""
echo "Testing RPC connection:"
sleep 5
/usr/local/bin/neoxa-cli -datadir=/root/.neoxa getinfo || echo "Still starting up..."
