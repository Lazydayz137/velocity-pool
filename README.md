[![.NET](https://github.com/Lazydayz137/velocity-pool/actions/workflows/dotnet.yml/badge.svg)](https://github.com/Lazydayz137/velocity-pool/actions/workflows/dotnet.yml)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)]()

<img src="https://github.com/Lazydayz137/velocity-pool/raw/master/logo.png" width="150">

# Velocity Pool 🚀

A high-performance, multi-currency mining pool with **one-click VPS deployment** and focus on CPU-friendly, ASIC-resistant coins. Built on .NET 6.0 with optimized native libraries for maximum performance.

## ⚡ Quick Deploy

Deploy your entire mining pool infrastructure in under 30 minutes:

```bash
# On your Ubuntu VPS
wget -O deploy-vps.sh https://raw.githubusercontent.com/Lazydayz137/velocity-pool/master/deployment/deploy-vps.sh
chmod +x deploy-vps.sh
./deploy-vps.sh your-domain.com
```

## 🎯 Strategic Coin Focus

Velocity Pool targets profitable opportunities for new mining operations:

- **Verus (VRSC)** - VerusHash algorithm (CPU-friendly, ASIC-resistant) ✅
- **Monero (XMR)** - RandomX algorithm (CPU-only, privacy-focused)
- **Ergo (ERG)** - Autolykos algorithm (GPU-friendly, emerging)
- **Raptoreum (RTM)** - GhostRider algorithm (CPU-only, ASIC-resistant)

*Why these coins? They avoid ASIC dominance, have active communities, and offer growth potential for new pool operators.*

### Features

- Supports clusters of pools each running individual currencies
- Ultra-low-latency, multi-threaded Stratum implementation using asynchronous I/O
- Adaptive share difficulty ("vardiff")
- PoW validation (hashing) using native code for maximum performance
- Session management for purging DDoS/flood initiated zombie workers
- Payment processing with multiple schemes (PPLNS, PROP, SOLO)
- Banning System with DDoS/flood protection
- Live Stats API on Port 4000
- WebSocket streaming of notable events like Blocks found, Blocks unlocked, Payments and more
- POW (proof-of-work) & POS (proof-of-stake) support
- Detailed per-pool logging to console & filesystem
- Docker containerization support
- Runs on Linux and Windows

## 📋 Documentation

- **[Quick Start Guide](docs/QUICK_START.md)** - Get running in 30 minutes
- **[Deployment Guide](docs/DEPLOYMENT.md)** - Complete VPS deployment
- **[Architecture Overview](WARP.md)** - Technical details and development

## 🖥️ VPS Requirements

- **OS**: Ubuntu 20.04/22.04 LTS
- **CPU**: 4+ cores (8+ recommended)
- **RAM**: 8GB minimum (16GB+ recommended) 
- **Storage**: 200GB SSD (500GB+ recommended)
- **Network**: 100Mbps (1Gbps recommended)

## 🚀 Key Features

✅ **One-Click Deployment** - Complete VPS setup with single script  
✅ **VerusHash Support** - Native optimized implementation with AES-NI  
✅ **CPU-Focused Mining** - ASIC-resistant algorithms  
✅ **Enterprise Security** - UFW firewall, fail2ban, SSL certificates  
✅ **Auto-Monitoring** - Built-in daemon and pool monitoring  
✅ **Scalable Architecture** - PostgreSQL, Nginx, systemd services

## 🔧 Management Commands

After deployment, manage your pool with simple commands:

```bash
velocity-pool start      # Start pool service
velocity-pool status     # Check service status
velocity-pool logs       # View real-time logs
velocity-pool config     # Edit configuration
```

## Documentation

- **[WARP.md](WARP.md)** - Comprehensive development guide and architecture overview
- **[AGENTS.md](AGENTS.md)** - Task Master AI integration guide for development workflows
- **[Configuration Wiki](https://github.com/Lazydayz137/velocity-pool/wiki/Configuration)** - Detailed configuration documentation

## Supported Cryptocurrencies

Refer to [coins.json](src/Miningcore/coins.json) for the complete list of supported currencies including:
- Bitcoin and Bitcoin-based altcoins
- Ethereum and EVM-compatible chains
- Monero and CryptoNote currencies
- Equihash-based coins (ZCash, etc.)
- Ergo
- And many more...

## Architecture

Velocity Pool follows a modular architecture with these core components:

- **Stratum Server** - Asynchronous TCP server for miner connections
- **Blockchain Layer** - Modular implementations for different cryptocurrency families
- **Payment Processing** - Automated payouts with configurable schemes
- **Persistence Layer** - PostgreSQL with optimized partitioning
- **API Layer** - REST API with WebSocket streaming
- **Native Libraries** - High-performance hashing algorithms

## Performance Features

- Server GC enabled for high-throughput environments
- Native library compilation for optimal CPU feature utilization
- Table partitioning for high-volume share processing
- Configurable RandomX VM count for Monero mining
- Adaptive difficulty adjustment (vardiff)

## Support

For questions and discussions, please use the [GitHub Discussions](https://github.com/Lazydayz137/velocity-pool/discussions) area.

## Contributions

Code contributions are welcome and should be submitted as standard [pull requests](https://docs.github.com/en/pull-requests) based on the `master` branch.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Based on the excellent [Miningcore](https://github.com/oliverw/miningcore) project by Oliver Weichhold.
