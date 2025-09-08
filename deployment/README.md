# Velocity Pool Deployment

This directory contains deployment scripts and configurations for setting up Velocity Pool mining infrastructure.

## Quick Start

To deploy a complete mining pool on a VPS:

```bash
curl -sL https://raw.githubusercontent.com/Lazydayz137/velocity-pool/main/deployment/deploy-vps.sh | bash
```

## Available Coin Deployments

### CPU Mining Coins
- **Verus (VRSC)** - VerusHash algorithm, established network
- **Raptoreum (RTM)** - GhostRider algorithm, CPU optimized
- **Dero (DERO)** - AstroBWT algorithm, privacy-focused

### GPU Mining Coins  
- **MeowCoin (MEWC)** - KawPoW algorithm, small network
- **Neoxa (NEOX)** - KawPoW algorithm, gaming-focused

## Deployment Scripts

### Main Pool Deployment
- `deploy-vps.sh` - Complete VPS setup with pool software

### Individual Coin Daemons
- `daemons/verus/deploy-verus.sh` - Verus daemon setup
- `daemons/raptoreum/deploy-raptoreum.sh` - Raptoreum daemon setup  
- `daemons/dero/deploy-dero.sh` - Dero daemon setup
- `daemons/meowcoin/deploy-meowcoin.sh` - MeowCoin daemon setup
- `daemons/neoxa/deploy-neoxa.sh` - Neoxa daemon setup

## Manual Deployment Process

### 1. Server Preparation

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install basic dependencies
sudo apt install -y curl wget git build-essential
```

### 2. Pool Deployment

```bash
# Clone repository
git clone https://github.com/Lazydayz137/velocity-pool.git
cd velocity-pool/deployment

# Run main deployment
./deploy-vps.sh
```

### 3. Daemon Deployment

Choose which coins to support and deploy their daemons:

```bash
# Deploy CPU mining coins
./daemons/verus/deploy-verus.sh
./daemons/raptoreum/deploy-raptoreum.sh
./daemons/dero/deploy-dero.sh

# Deploy GPU mining coins
./daemons/meowcoin/deploy-meowcoin.sh
./daemons/neoxa/deploy-neoxa.sh
```

### 4. Configuration

After deployment, configure each pool in the main config file:

```bash
nano /opt/velocity-pool/config.json
```

Add daemon RPC credentials from `/tmp/*-rpc-credentials.txt` files.

## Algorithm Support

The pool supports these mining algorithms:

| Algorithm | Coins | Hardware | Performance |
|-----------|-------|----------|-------------|
| VerusHash | Verus | CPU | High |
| GhostRider | Raptoreum | CPU | Medium |
| AstroBWT | Dero | CPU | Medium |
| KawPoW | MeowCoin, Neoxa | GPU | High |

## Network Strategy

Our coin selection targets smaller, profitable networks where a new pool can realistically find blocks:

- **Small Network Hash**: Lower competition for block discovery
- **Active Development**: Coins with ongoing development and community
- **Diverse Algorithms**: Both CPU and GPU mining opportunities
- **Profitability Focus**: Higher potential rewards due to lower competition

## Monitoring

Each daemon includes monitoring scripts:

```bash
# Check daemon status
/usr/local/bin/verus-monitor.sh
/usr/local/bin/raptoreum-monitor.sh
/usr/local/bin/dero-monitor.sh
/usr/local/bin/meowcoin-monitor.sh
/usr/local/bin/neoxa-monitor.sh

# Check pool status
velocity-pool status

# View logs
sudo journalctl -u velocity-pool -f
sudo journalctl -u verus-daemon -f
```

## Troubleshooting

### Common Issues

1. **Daemon sync issues**: Allow time for blockchain synchronization
2. **RPC connection errors**: Verify daemon is running and RPC settings
3. **Share validation errors**: Check algorithm implementation and coin definitions

### Log Locations

- Pool logs: `/var/log/velocity-pool/`
- Daemon logs: Check systemd journals or data directories
- Nginx logs: `/var/log/nginx/`

### Support Commands

```bash
# Restart all services
sudo systemctl restart velocity-pool
sudo systemctl restart verus-daemon
sudo systemctl restart raptoreum-daemon

# Check service status
sudo systemctl status velocity-pool
sudo systemctl status *-daemon

# Monitor resource usage
htop
df -h
```

## Security Notes

- All daemon RPC interfaces are bound to localhost only
- Firewall rules restrict access to essential ports
- Regular security updates are recommended
- Monitor for unusual mining activity or attacks

## Performance Optimization

### System Requirements

**Minimum per daemon:**
- CPU: 2 cores
- RAM: 2-4GB 
- Storage: 20GB SSD
- Network: 100Mbps

**Recommended for full deployment:**
- CPU: 8+ cores
- RAM: 16GB+
- Storage: 200GB NVMe SSD
- Network: 1Gbps

### Optimization Tips

1. Use NVMe SSDs for blockchain data
2. Allocate sufficient RAM for daemon caching
3. Monitor network bandwidth usage
4. Regular database maintenance
5. Load balance across multiple servers if needed

## Contributing

To add support for additional coins:

1. Create daemon deployment script in `daemons/[coin]/`
2. Add coin definition to main pool configuration
3. Test deployment process
4. Update documentation

## Support

For issues or questions:

- Check the main repository documentation
- Review daemon logs for error messages
- Ensure all prerequisites are met
- Verify network connectivity to coin networks
