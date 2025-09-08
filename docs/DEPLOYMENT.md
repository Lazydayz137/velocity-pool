# Velocity Pool Deployment Guide

## 🚨 **CRITICAL DEPLOYMENT PRINCIPLE: "MEASURE TWICE, CUT ONCE"**

**NEVER write deployment code without complete research and testing first.**

### Research Checklist (MANDATORY before any deployment script):
1. **Download URLs** - Verify with GitHub API, test actual downloads
2. **Archive Structure** - Download to /tmp, extract, and inspect contents
3. **Directory Layout** - Note exact folder names after extraction
4. **Binary Names** - Verify executable names and locations
5. **Dependencies** - Check system requirements and library dependencies
6. **Configuration** - Understand config file formats and required settings

**DO NOT GUESS. DO NOT ASSUME. VERIFY EVERYTHING.**

This guide covers the complete deployment of Velocity Pool on a VPS, including coin daemon setup, pool configuration, and monitoring.

## Table of Contents

- [Prerequisites](#prerequisites)
- [System Setup](#system-setup)
- [Coin Daemon Deployment](#coin-daemon-deployment)
- [Pool Deployment](#pool-deployment)
- [Security Configuration](#security-configuration)
- [Monitoring & Maintenance](#monitoring--maintenance)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware Requirements

**Minimum VPS Specifications:**
- CPU: 4 cores (8 recommended for multiple coins)
- RAM: 8GB (16GB recommended)
- Storage: 100GB SSD (500GB+ recommended for blockchain sync)
- Network: 100Mbps connection
- OS: Ubuntu 20.04 LTS or later

**Recommended for Production:**
- CPU: 8+ cores with AES-NI support
- RAM: 32GB+
- Storage: 1TB+ NVMe SSD
- Network: 1Gbps connection

### Software Dependencies

- Docker & Docker Compose
- Node.js 18+ (for frontend)
- PostgreSQL 14+
- Nginx (reverse proxy)
- Fail2ban (security)
- UFW (firewall)

## System Setup

### 1. Initial Server Configuration

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git vim htop tmux ufw fail2ban

# Configure timezone
sudo timedatectl set-timezone UTC

# Create deployment user
sudo adduser velocity
sudo usermod -aG sudo velocity
sudo usermod -aG docker velocity
```

### 2. Security Hardening

```bash
# Configure UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Configure SSH security
sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# Configure fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Coin Daemon Deployment

### Strategic Coin Selection

Velocity Pool focuses on coins that offer the best opportunities for new mining operations:

1. **Verus (VRSC)** - VerusHash algorithm (CPU-friendly, ASIC-resistant)
2. **Monero (XMR)** - RandomX algorithm (CPU-only, privacy-focused)
3. **Ergo (ERG)** - Autolykos algorithm (GPU-friendly, small but growing)
4. **Raptoreum (RTM)** - GhostRider algorithm (CPU-only, ASIC-resistant)
5. **Alephium (ALPH)** - BlockFlow algorithm (GPU-friendly, innovative sharding)

### Why These Coins?

- **CPU-focused algorithms** (Verus, Monero, Raptoreum) avoid ASIC dominance
- **Smaller market cap coins** with growth potential
- **ASIC-resistant** algorithms favor decentralized mining
- **Active communities** and ongoing development
- **Avoid oversaturated markets** (Bitcoin, Ethereum Classic)

### Deployment Scripts

Each coin has dedicated deployment scripts in the `deployment/daemons/` directory:

- `deployment/daemons/verus/deploy-verus.sh`
- `deployment/daemons/monero/deploy-monero.sh`
- `deployment/daemons/ergo/deploy-ergo.sh`
- `deployment/daemons/raptoreum/deploy-raptoreum.sh`
- `deployment/daemons/alephium/deploy-alephium.sh`

### General Daemon Setup Process

1. **Download and Verify Binaries**
2. **Configure Daemon Settings**
3. **Create systemd Service**
4. **Setup Log Rotation**
5. **Configure Monitoring**
6. **Start Blockchain Sync**

## Pool Deployment

### 1. Database Setup

```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql << EOF
CREATE ROLE velocity WITH LOGIN ENCRYPTED PASSWORD 'your-secure-password';
CREATE DATABASE velocitypool OWNER velocity;
GRANT ALL PRIVILEGES ON DATABASE velocitypool TO velocity;
EOF

# Initialize schema
psql -h localhost -U velocity -d velocitypool -f src/Miningcore/Persistence/Postgres/Scripts/createdb.sql
```

### 2. Pool Configuration

```bash
# Clone repository
git clone https://github.com/your-org/velocity-pool.git
cd velocity-pool

# Build pool software
./build-ubuntu-22.04.sh build

# Configure pool settings
cp examples/pool-config-template.json pool-config.json
# Edit pool-config.json with your settings
```

### 3. Service Deployment

```bash
# Create systemd service
sudo cp deployment/services/velocity-pool.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable velocity-pool
sudo systemctl start velocity-pool
```

## Security Configuration

### SSL/TLS Setup

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
sudo certbot --nginx -d pool.yourdomian.com

# Auto-renewal
sudo crontab -e
# Add: 0 12 * * * /usr/bin/certbot renew --quiet
```

### Wallet Security

- Use hardware wallets for pool payout addresses
- Implement multi-signature wallets where possible
- Regular security audits and updates
- Monitor wallet balances and transactions

## Monitoring & Maintenance

### 1. System Monitoring

```bash
# Install monitoring tools
sudo apt install -y prometheus node-exporter grafana

# Configure Grafana dashboards
# - Pool statistics
# - System metrics
# - Blockchain sync status
# - Mining performance
```

### 2. Log Management

```bash
# Configure logrotate
sudo vim /etc/logrotate.d/velocity-pool
# Add rotation rules for pool and daemon logs
```

### 3. Backup Strategy

```bash
# Database backups
pg_dump velocitypool > backup-$(date +%Y%m%d).sql

# Configuration backups
tar -czf config-backup-$(date +%Y%m%d).tar.gz pool-config.json deployment/
```

## Troubleshooting

### Common Issues

#### 1. Daemon Sync Problems
- Check network connectivity
- Verify peer connections
- Monitor disk space
- Check daemon logs

#### 2. Pool Connection Issues
- Verify RPC credentials
- Check firewall settings
- Monitor daemon responsiveness
- Validate configuration

#### 3. Mining Performance Issues
- Check algorithm implementations
- Monitor CPU/memory usage
- Verify share validation
- Review difficulty calculations

### Debug Commands

```bash
# Check pool status
sudo systemctl status velocity-pool

# View pool logs
sudo journalctl -u velocity-pool -f

# Check daemon status
sudo systemctl status verus-daemon

# Monitor system resources
htop
iostat -x 1
```

## Performance Optimization

### Database Optimization

```sql
-- Enable table partitioning for high-volume pools
-- See: src/Miningcore/Persistence/Postgres/Scripts/createdb_postgresql_11_appendix.sql
```

### Pool Optimization

- Enable native library optimizations
- Configure appropriate share difficulties
- Implement efficient worker management
- Use connection pooling

### Network Optimization

- Configure nginx for SSL termination
- Enable gzip compression
- Setup CDN for static assets
- Optimize WebSocket connections

## Scaling Considerations

### Horizontal Scaling

- Database read replicas
- Load balancing for web interface
- Separate daemon servers
- Geographic distribution

### Monitoring at Scale

- Centralized logging (ELK stack)
- Distributed monitoring (Prometheus)
- Automated alerting
- Performance analytics

## Support and Maintenance

### Regular Tasks

- **Daily**: Monitor pool operations, check daemon sync
- **Weekly**: Review security logs, update software
- **Monthly**: Security audits, performance reviews
- **Quarterly**: System backups, disaster recovery tests

### Emergency Procedures

- Pool shutdown procedures
- Wallet security protocols
- Incident response plan
- Communication templates

## Additional Resources

- [Miningcore Documentation](https://github.com/oliverw/miningcore)
- [Coin-Specific Setup Guides](deployment/daemons/)
- [Pool Configuration Examples](examples/)
- [Security Best Practices](docs/SECURITY.md)
