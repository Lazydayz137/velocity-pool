# Velocity Pool Quick Start Guide

This guide will get your mining pool up and running on a VPS in under 30 minutes.

## 🚀 One-Command Deployment

Deploy the entire pool infrastructure with a single command:

```bash
# On your VPS (Ubuntu 20.04/22.04)
wget -O deploy-vps.sh https://raw.githubusercontent.com/your-org/velocity-pool/main/deployment/deploy-vps.sh
chmod +x deploy-vps.sh
./deploy-vps.sh your-domain.com
```

## 📋 Prerequisites

### VPS Requirements
- **OS**: Ubuntu 20.04 LTS or 22.04 LTS
- **CPU**: 4+ cores (8+ recommended)
- **RAM**: 8GB minimum (16GB+ recommended)
- **Storage**: 200GB SSD (500GB+ recommended)
- **Network**: 100Mbps (1Gbps recommended)

### Domain Setup
- Point your domain A record to your VPS IP
- Ensure DNS propagation is complete before deployment

## ⚡ Quick Start Steps

### 1. Deploy Infrastructure
```bash
# Run the master deployment script
./deploy-vps.sh your-domain.com
```

This installs and configures:
- ✅ System security (UFW, fail2ban)
- ✅ Web server (Nginx with SSL)
- ✅ Database (PostgreSQL)
- ✅ Pool software (.NET, native libraries)
- ✅ Management tools

### 2. Deploy Coin Daemons

Choose your coin(s) and run the deployment scripts:

```bash
# Deploy Verus (VerusHash - CPU mining)
/home/velocity/velocity-pool/deployment/daemons/verus/deploy-verus.sh

# Deploy Monero (RandomX - CPU mining)
/home/velocity/velocity-pool/deployment/daemons/monero/deploy-monero.sh
```

### 3. Configure Pool

Update the pool configuration:
```bash
velocity-pool config
```

**Required Updates:**
1. Database password (from `/tmp/database-credentials.txt`)
2. RPC credentials (from coin daemon deployment)
3. Pool wallet addresses
4. Email settings (optional)

### 4. Start Mining Pool

```bash
velocity-pool start
velocity-pool status
```

## 🎯 Strategic Coin Selection

Velocity Pool focuses on profitable opportunities for new operations:

| Coin | Algorithm | Type | Market | Benefits |
|------|-----------|------|---------|----------|
| **Verus (VRSC)** | VerusHash | CPU | Growing | ASIC-resistant, innovative tech |
| **Monero (XMR)** | RandomX | CPU | Established | Privacy focus, ASIC-proof |
| **Ergo (ERG)** | Autolykos | GPU | Emerging | Small but active community |
| **Raptoreum (RTM)** | GhostRider | CPU | New | CPU-only, ASIC-resistant |

## 🔧 Management Commands

```bash
# Pool management
velocity-pool start      # Start pool service
velocity-pool stop       # Stop pool service
velocity-pool restart    # Restart pool service
velocity-pool status     # Check service status
velocity-pool logs       # View real-time logs
velocity-pool config     # Edit configuration

# Daemon management
sudo systemctl status verus-daemon    # Check Verus daemon
sudo systemctl status monero-daemon   # Check Monero daemon
```

## 📊 Monitoring & Maintenance

### System Monitoring
```bash
htop                    # System resources
df -h                   # Disk usage
systemctl status nginx # Web server status
```

### Pool Monitoring
```bash
# Check pool API
curl -s http://localhost:4000/api/pools | jq

# Monitor daemon sync
/usr/local/bin/verus-monitor.sh
/usr/local/bin/monero-monitor.sh
```

### Log Analysis
```bash
# Pool logs
tail -f /home/velocity/velocity-pool/logs/pool.log

# System logs
sudo journalctl -f

# Daemon logs
sudo journalctl -u verus-daemon -f
sudo journalctl -u monero-daemon -f
```

## 🛡️ Security Best Practices

### Firewall Status
```bash
sudo ufw status verbose
```

### Active Protections
- ✅ UFW firewall (minimal ports exposed)
- ✅ Fail2ban (automated IP blocking)
- ✅ SSL/TLS encryption (Let's Encrypt)
- ✅ Regular security updates
- ✅ Service isolation

### Wallet Security
- Use hardware wallets for pool addresses
- Enable 2FA where possible
- Regular backup of configurations
- Monitor wallet balances

## 📈 Scaling & Optimization

### Performance Tuning
```bash
# Database optimization
sudo -u postgres psql velocitypool -c "VACUUM ANALYZE;"

# System optimization
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

### Adding More Coins
1. Deploy additional daemon: `./deployment/daemons/[coin]/deploy-[coin].sh`
2. Add pool configuration block
3. Restart pool service

### Scaling Resources
- Upgrade VPS specifications as needed
- Add SSD storage for blockchain data
- Consider separate daemon servers for multiple coins

## 🚨 Troubleshooting

### Common Issues

#### Pool Won't Start
```bash
# Check configuration
velocity-pool config
# Check database connection
psql -h localhost -U velocity -d velocitypool -c "SELECT 1;"
# Check logs
velocity-pool logs
```

#### Daemon Sync Issues
```bash
# Check daemon status
sudo systemctl status [coin]-daemon
# Check connections
[coin]-monitor.sh
# Check disk space
df -h
```

#### SSL Certificate Issues
```bash
# Renew certificate
sudo certbot renew
# Check certificate status
sudo certbot certificates
```

### Getting Help

- **Documentation**: `/home/velocity/velocity-pool/docs/`
- **Logs**: `/home/velocity/velocity-pool/logs/`
- **Configuration**: `/home/velocity/velocity-pool/pool-config.json`

## 🎉 Success Checklist

✅ VPS deployed and secured  
✅ Domain pointing to VPS  
✅ SSL certificate installed  
✅ Coin daemon(s) deployed and syncing  
✅ Pool configuration updated  
✅ Pool service started  
✅ Web interface accessible  
✅ First miner connected successfully  

**Your mining pool is ready for business! 🚀**

## ⚡ Next Steps

1. **Marketing**: Create social media presence
2. **Community**: Join coin-specific Discord/Telegram
3. **Monitoring**: Set up alerting for critical issues
4. **Optimization**: Fine-tune difficulty and payout settings
5. **Growth**: Add more coins based on demand

---

**Need help?** Check the full documentation in `docs/DEPLOYMENT.md` for detailed configuration options and advanced setups.
