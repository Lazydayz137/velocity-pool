# Alephium Mining Pool - Complete Deployment Guide

## 🚀 Quick Start (5 Minutes)

### 1. Setup Alephium Daemon
```bash
# Make scripts executable
chmod +x /home/lazydayz137/alephium-daemon/scripts/*.sh

# Setup and start daemon
/home/lazydayz137/alephium-daemon/scripts/setup-daemon.sh
/home/lazydayz137/alephium-daemon/scripts/start-daemon.sh

# Monitor daemon sync (this may take 2-4 hours)
/home/lazydayz137/alephium-daemon/scripts/monitor.sh
```

### 2. Setup Mining Pool
```bash
# Make pool scripts executable
chmod +x /home/lazydayz137/velocity-pool/pool-configs/alephium/*.sh

# Setup pool configuration
/home/lazydayz137/velocity-pool/pool-configs/alephium/setup-pool.sh
```

### 3. Configure Wallet
```bash
# Read wallet setup instructions
cat /home/lazydayz137/velocity-pool/pool-configs/alephium/WALLET_SETUP.md

# Get your Alephium wallet address, then update configuration:
sed -i 's/YOUR_ALEPHIUM_WALLET_ADDRESS_HERE/your-actual-address-here/g' \
  /home/lazydayz137/velocity-pool/pool-configs/alephium/pool-config.json
```

### 4. Start Pool
```bash
# Wait for daemon to be fully synced, then:
/home/lazydayz137/velocity-pool/pool-configs/alephium/start-pool.sh
```

---

## 📋 Detailed Setup Process

### Prerequisites Installation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y openjdk-11-jdk postgresql postgresql-contrib curl wget jq

# Install .NET 6.0 (if not already installed)
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt update && sudo apt install -y dotnet-sdk-6.0
```

### PostgreSQL Setup

```bash
# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user
sudo -u postgres psql << EOF
CREATE DATABASE miningcore;
CREATE USER miningcore WITH ENCRYPTED PASSWORD 'your-secure-password';
GRANT ALL PRIVILEGES ON DATABASE miningcore TO miningcore;
\q
EOF
```

### Firewall Configuration

```bash
# Allow required ports
sudo ufw allow 9973/tcp   # Alephium P2P
sudo ufw allow 12973/tcp  # Alephium RPC (local only)
sudo ufw allow 4001/tcp   # Pool Stratum port
sudo ufw allow 4002/tcp   # Pool high-end port
sudo ufw allow 4001/tcp   # Pool API/Web interface

# Enable firewall
sudo ufw enable
```

---

## 🔧 Configuration Files

### Alephium Daemon Configuration
Location: `/home/lazydayz137/alephium-daemon/config/user.conf`

Key settings to review:
- `api.api-key`: Secure API key (auto-generated)
- `mining.addresses`: Pool wallet addresses
- `node.data-dir`: Data storage location
- `logging.level`: Log verbosity

### Pool Configuration
Location: `/home/lazydayz137/velocity-pool/pool-configs/alephium/pool-config.json`

**Required Updates:**
1. Replace `YOUR_ALEPHIUM_WALLET_ADDRESS_HERE` with your address
2. Update database password in `persistence.postgres.password`
3. Configure email notifications (optional)
4. Set pool fees if desired

**Port Configuration:**
- Port 4001: Regular miners (1M difficulty)
- Port 4002: High-end miners (10M difficulty)

---

## 📊 Monitoring & Maintenance

### Health Check Scripts

```bash
# Quick status check
/home/lazydayz137/alephium-daemon/scripts/monitor.sh status
/home/lazydayz137/velocity-pool/pool-configs/alephium/monitor-pool.sh

# Continuous monitoring
watch -n 30 '/home/lazydayz137/alephium-daemon/scripts/monitor.sh'
```

### Log Locations

```bash
# Daemon logs
tail -f /home/lazydayz137/alephium-daemon/logs/alephium.log
tail -f /home/lazydayz137/alephium-daemon/logs/daemon.out

# Pool logs
tail -f /home/lazydayz137/velocity-pool/pool-configs/alephium/logs/alephium-pool.log
```

### System Resources

**Minimum Requirements:**
- CPU: 4+ cores
- RAM: 8GB+ (4GB for daemon, 4GB for pool)
- Storage: 50GB+ SSD (blockchain growth)
- Network: 100Mbps+ with low latency

**Recommended for High Traffic:**
- CPU: 8+ cores
- RAM: 16GB+
- Storage: 100GB+ NVMe SSD
- Network: 1Gbps+

---

## 🚨 Troubleshooting

### Common Issues

#### 1. Daemon Won't Start
```bash
# Check Java installation
java -version

# Check logs for errors
tail -f /home/lazydayz137/alephium-daemon/logs/daemon.out

# Common fixes:
sudo apt install openjdk-11-jdk  # If Java missing
killall java                     # If port conflicts
```

#### 2. Daemon Won't Sync
```bash
# Check network connectivity
ping bootstrap0.mainnet.alephium.org

# Check peers
/home/lazydayz137/alephium-daemon/scripts/monitor.sh api

# Restart if stuck
/home/lazydayz137/alephium-daemon/scripts/stop-daemon.sh
/home/lazydayz137/alephium-daemon/scripts/start-daemon.sh
```

#### 3. Pool Can't Connect to Daemon
```bash
# Verify API key
cat /home/lazydayz137/alephium-daemon/config/api-key.txt

# Test API manually
curl -H "X-API-KEY: $(cat /home/lazydayz137/alephium-daemon/config/api-key.txt)" \
  http://127.0.0.1:12973/infos/self-clique

# Check if config has correct API key
grep "YOUR_ALEPHIUM_API_KEY_HERE" \
  /home/lazydayz137/velocity-pool/pool-configs/alephium/pool-config.json
```

#### 4. Database Connection Issues
```bash
# Test database connection
psql -h 127.0.0.1 -U miningcore -d miningcore -c "SELECT 1;"

# Reset database password
sudo -u postgres psql -c "ALTER USER miningcore PASSWORD 'new-password';"

# Reinitialize schema
sudo -u postgres psql -d miningcore -f \
  /home/lazydayz137/velocity-pool/src/Miningcore/Persistence/Postgres/Scripts/createdb.sql
```

#### 5. Miners Can't Connect
```bash
# Check if pool is listening
netstat -tuln | grep -E "(4001|4002)"

# Check firewall
sudo ufw status

# Test stratum connection
telnet your-pool-ip 4001
```

### Performance Issues

#### High Memory Usage
```bash
# Check Java heap usage
jstat -gc $(pgrep -f alephium.jar)

# Adjust JVM settings in:
nano /home/lazydayz137/alephium-daemon/config/jvm.opts

# Restart daemon
/home/lazydayz137/alephium-daemon/scripts/stop-daemon.sh
/home/lazydayz137/alephium-daemon/scripts/start-daemon.sh
```

#### Slow Block Updates
```bash
# Check daemon sync status
/home/lazydayz137/alephium-daemon/scripts/monitor.sh

# Verify network latency to peers
ping bootstrap0.mainnet.alephium.org

# Check disk I/O
iostat -x 1 10
```

---

## 🔒 Security Checklist

### Essential Security Measures

- [ ] API key is secure and not exposed
- [ ] Firewall configured (only necessary ports open)
- [ ] Database password is strong and unique
- [ ] Pool wallet backup exists
- [ ] System updates are current
- [ ] SSH key authentication enabled
- [ ] Regular security monitoring in place

### Security Commands

```bash
# Generate new API key if compromised
openssl rand -hex 32

# Check open ports
nmap -p- localhost

# Monitor failed login attempts
sudo tail -f /var/log/auth.log | grep "Failed password"

# Update system regularly
sudo apt update && sudo apt upgrade -y
```

---

## 📈 Scaling & Optimization

### For High Traffic Pools

1. **Database Optimization:**
   ```sql
   -- Enable table partitioning for PostgreSQL 11+
   -- See: /src/Miningcore/Persistence/Postgres/Scripts/createdb_postgresql_11_appendix.sql
   ```

2. **Load Balancing:**
   - Multiple Miningcore instances
   - HAProxy/Nginx for load distribution
   - Separate read replicas for statistics

3. **Monitoring Stack:**
   - Prometheus metrics collection
   - Grafana dashboards
   - Alert manager for notifications

### Performance Tuning

```bash
# Optimize PostgreSQL
sudo nano /etc/postgresql/*/main/postgresql.conf
# Key settings:
# shared_buffers = 25% of RAM
# effective_cache_size = 75% of RAM
# work_mem = RAM / max_connections

# Optimize Linux kernel
echo 'net.core.rmem_default = 262144' | sudo tee -a /etc/sysctl.conf
echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## 🆘 Emergency Procedures

### Pool Down Emergency

1. **Check daemon first:**
   ```bash
   /home/lazydayz137/alephium-daemon/scripts/monitor.sh
   ```

2. **Restart services in order:**
   ```bash
   # Stop pool first
   pkill -f Miningcore.dll
   
   # Restart daemon
   /home/lazydayz137/alephium-daemon/scripts/stop-daemon.sh
   /home/lazydayz137/alephium-daemon/scripts/start-daemon.sh
   
   # Wait for sync, then restart pool
   /home/lazydayz137/velocity-pool/pool-configs/alephium/start-pool.sh
   ```

3. **Notify miners:**
   - Update pool status page
   - Send notifications if configured
   - Communicate via social media/Discord

### Data Recovery

```bash
# Backup critical data
tar -czf pool-backup-$(date +%Y%m%d).tar.gz \
  /home/lazydayz137/alephium-daemon/config/ \
  /home/lazydayz137/velocity-pool/pool-configs/alephium/

# Database backup
sudo -u postgres pg_dump miningcore > miningcore-backup-$(date +%Y%m%d).sql
```

---

## 📞 Support Resources

### Community Support
- **Alephium Discord:** https://discord.gg/JErgRBfRSB
- **Alephium Telegram:** https://t.me/alephiumgroup
- **Miningcore GitHub:** https://github.com/oliverw/miningcore

### Documentation
- **Alephium Docs:** https://docs.alephium.org/
- **Pool Admin Guide:** Your pool's admin documentation
- **Blake3 Specification:** https://github.com/BLAKE3-team/BLAKE3-specs

---

## 📝 Maintenance Schedule

### Daily
- [ ] Check daemon sync status
- [ ] Monitor pool hashrate and miners
- [ ] Review error logs

### Weekly
- [ ] System updates
- [ ] Database maintenance (VACUUM)
- [ ] Backup configuration files

### Monthly
- [ ] Full system backup
- [ ] Security audit
- [ ] Performance review
- [ ] Update documentation
