[![.NET](https://github.com/Lazydayz137/velocity-pool/actions/workflows/dotnet.yml/badge.svg)](https://github.com/Lazydayz137/velocity-pool/actions/workflows/dotnet.yml)
[![license](https://img.shields.io/github/license/mashape/apistatus.svg)]()

<img src="https://github.com/Lazydayz137/velocity-pool/raw/master/logo.png" width="150">

# Velocity Pool

A high-performance, multi-currency mining pool software built on .NET 6.0. Based on Miningcore, Velocity Pool provides ultra-low-latency Stratum protocol implementation supporting both Proof-of-Work (PoW) and Proof-of-Stake (PoS) mining for multiple cryptocurrency families including Bitcoin, Ethereum, Monero (CryptoNote), Equihash-based coins, and Ergo.

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

## Quick Start

### Prerequisites
- .NET 6.0 SDK and runtime
- PostgreSQL 10+ (11+ recommended for partitioning)
- Native dependencies: boost, sodium, OpenSSL development headers

### Building on Linux

```bash
git clone https://github.com/Lazydayz137/velocity-pool
cd velocity-pool

# For Ubuntu/Debian
./build-ubuntu-22.04.sh
# or ./build-debian-11.sh
```

### Building with Docker

```bash
docker build -t velocity-pool:latest .
```

### Database Setup

```bash
sudo -u postgres psql
CREATE ROLE miningcore WITH LOGIN ENCRYPTED PASSWORD 'your-secure-password';
CREATE DATABASE miningcore OWNER miningcore;
\q

sudo -u postgres psql -d miningcore -f src/Miningcore/Persistence/Postgres/Scripts/createdb.sql
```

### Configuration

1. Copy `config.json.example` to `config.json`
2. Configure your pools, database connection, and daemon settings
3. See [Configuration Guide](https://github.com/Lazydayz137/velocity-pool/wiki/Configuration) for details

### Running

```bash
cd build
./Miningcore -c config.json
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
