#!/bin/bash

# Fix Neoxa systemd service with correct port
# Run on VPS as root

echo "Fixing Neoxa service with non-conflicting port..."

# Stop current service
systemctl stop neoxa-daemon

# Update systemd service with correct port
cat > /etc/systemd/system/neoxa-daemon.service << 'EOF'
[Unit]
Description=Neoxa Daemon
Documentation=https://github.com/NeoxaChain/Neoxa
After=network.target

[Service]
Type=forking
User=root
Group=root
WorkingDirectory=/root
ExecStart=/usr/local/bin/neoxad -datadir=/root/.neoxa -daemon -port=8789
ExecStop=/usr/local/bin/neoxa-cli -datadir=/root/.neoxa stop
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

# Reload and start
systemctl daemon-reload
systemctl start neoxa-daemon

echo "Service restarted with port 8789. Checking status..."
sleep 3
systemctl status neoxa-daemon --no-pager
