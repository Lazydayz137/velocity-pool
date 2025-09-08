# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Miningcore is a high-performance, multi-currency mining pool software built on .NET 6.0. It provides ultra-low-latency Stratum protocol implementation supporting both Proof-of-Work (PoW) and Proof-of-Stake (PoS) mining for multiple cryptocurrency families including Bitcoin, Ethereum, Monero (CryptoNote), Equihash-based coins, and Ergo.

**Key Features:**
- Multi-threaded Stratum server with adaptive share difficulty (vardiff)
- Native code integration for maximum hashing performance
- PostgreSQL persistence with optimized partitioning for high-throughput environments
- Comprehensive payment processing with multiple payout schemes (PPLNS, PROP, SOLO)
- RESTful API with WebSocket streaming for real-time pool statistics
- Docker containerization support
- Session management with DDoS/flood protection

## Architecture Overview

### Core Components

1. **Blockchain Layer** (`/src/Miningcore/Blockchain/`)
   - Modular blockchain family implementations (Bitcoin, Ethereum, Cryptonote, Equihash, Ergo)
   - Each family provides: job management, share validation, block template processing, payment logic
   - Coin definitions managed via `coins.json` with algorithm-specific hashers

2. **Stratum Server** (`/src/Miningcore/Stratum/`)
   - Asynchronous TCP server handling miner connections
   - JSON-RPC protocol implementation for mining communication
   - Variable difficulty adjustment and share processing

3. **Payment Processing** (`/src/Miningcore/Payments/`)
   - Automated payout calculations with configurable schemes
   - Transaction broadcasting and confirmation tracking
   - Share recovery mechanisms for system reliability

4. **Persistence Layer** (`/src/Miningcore/Persistence/`)
   - PostgreSQL-based data storage with Dapper ORM
   - Optimized schema with table partitioning for shares (PostgreSQL 11+)
   - Repository pattern for data access abstraction

5. **API Layer** (`/src/Miningcore/Api/`)
   - ASP.NET Core REST API with rate limiting
   - WebSocket notifications for real-time events
   - Prometheus metrics integration
   - NSwag OpenAPI documentation (debug builds)

6. **Native Libraries** (`/src/Miningcore/Native/`)
   - High-performance hashing algorithms (libmultihash, libcryptonote, etc.)
   - Platform-specific binary compilation (Linux/Windows)

### Data Flow Architecture

**Miner Connection Lifecycle:**
1. TCP connection established → StratumConnection created
2. `mining.subscribe` → ExtraNonce1 assigned, session initialized
3. `mining.authorize` → Worker authentication, difficulty assignment
4. `mining.notify` → Job template broadcast to miners
5. Share submission → Validation → Database storage
6. Block found → RPC broadcast → Payment queue

**Share Processing Pipeline:**
```
Miner Submit → Stratum Validation → Algorithm Verification → 
Difficulty Check → Duplicate Detection → Database Insert → 
Block Candidate Check → Payment Processing
```

**Payment Processing Workflow:**
```
Share Accumulation → PPLNS/PROP Calculation → Balance Updates → 
Minimum Threshold Check → Transaction Building → RPC Broadcast → 
Confirmation Tracking → Balance Finalization
```

**WebSocket Event Flow:**
- Block notifications: `PoolManager` → `NotificationService` → WebSocket clients
- Payment events: `PaymentProcessor` → Event aggregation → Real-time broadcast
- Statistics updates: Periodic collection → Cache update → WebSocket streaming

**Component Communication:**
- **JobManager** ↔ **Daemon RPC**: Block template retrieval and submission
- **StratumServer** ↔ **ShareProcessor**: Share validation and recording
- **PaymentProcessor** ↔ **Database**: Balance calculations and transaction logs
- **API Controller** ↔ **Statistics Service**: Real-time pool metrics

## Deployment & Troubleshooting Rules

### CRITICAL: Balanced Problem-Solving Approach

**When encountering deployment issues:**

1. **IMMEDIATE FIX**: Provide direct command to fix the current issue
   - Example: `systemctl stop service && sed -i 's/old/new/' /path/to/config && systemctl start service`
   - Don't make user wait while you "research" - give working solution first

2. **ROOT CAUSE FIX**: Update deployment scripts/code to prevent future occurrences
   - Fix the actual source code that caused the problem
   - Commit proper fixes to repository
   - Don't create "band-aid" scripts for one-time issues

3. **AVOID EXTREMES**:
   - ❌ DON'T: Only give manual commands (doesn't fix root cause)
   - ❌ DON'T: Over-engineer with unnecessary "fix" scripts in repo
   - ✅ DO: Balance immediate relief + permanent solution

### Port Conflict Resolution

**Current daemon port assignments:**
- Verus: 27485 (P2P), 27486 (RPC)
- MeowCoin: 8788 (P2P), 8766 (RPC) 
- Raptoreum: 10225 (P2P), 10226 (RPC)
- Dero: 10101 (P2P), 10102 (RPC)
- Neoxa: 8789 (P2P), 8766 (RPC)

**When daemon fails to start:**
1. Check actual port usage: `ss -tuln | grep PORT` and `lsof -i :PORT`
2. Identify conflicting process before assuming multiple instances
3. Update systemd service with `-port=XXXX` parameter if needed

### Configuration Conflicts

**Never use both:**
- `-daemon` command line flag AND `daemon=1` in config file
- Choose one method consistently across all daemons

## Common Development Commands

### Building the Project

**Linux (Debian 11):**
```bash
./build-debian-11.sh [build-directory]
```

**Linux (Ubuntu 20.04/21.04/22.04):**
```bash
./build-ubuntu-20.04.sh [build-directory]
./build-ubuntu-21.04.sh [build-directory]
./build-ubuntu-22.04.sh [build-directory]
```

**Windows:**
```cmd
build-windows.bat
```

**Manual .NET Build:**
```bash
cd src/Miningcore
dotnet publish -c Release --framework net6.0 -o ../../build
```

**Docker Build:**
```bash
docker build -t miningcore:latest .

# With runtime-specific optimization
docker run --rm -v $(pwd):/app -w /app mcr.microsoft.com/dotnet/sdk:6.0 /bin/bash -c \
  'apt update && apt install libssl-dev pkg-config libboost-all-dev libsodium-dev build-essential cmake -y --no-install-recommends && \
   cd src/Miningcore && dotnet publish -c Release --framework net6.0 -o /app/build/'
```

### Testing

**Run All Tests:**
```bash
cd src
dotnet test --logger:"console;verbosity=detailed" --verbosity normal
```

**Run Single Test Project:**
```bash
cd src/Miningcore.Tests
dotnet test --logger:"console;verbosity=detailed"
```

**Run Tests by Category:**
```bash
# Unit tests only
dotnet test --filter "Category=Unit"

# Integration tests (requires database)
dotnet test --filter "Category=Integration"

# Blockchain-specific tests
dotnet test --filter "FullyQualifiedName~Bitcoin"
dotnet test --filter "FullyQualifiedName~Ethereum"
```

**Performance Benchmarks:**
```bash
cd src/Miningcore.Tests
dotnet run -c Release -- --filter "*Benchmark*"

# Specific benchmark categories
dotnet run -c Release -- --job Short --filter "*ShareProcessing*"
dotnet run -c Release -- --job Medium --filter "*StratumConnection*"
```

**Performance Profiling:**
```bash
# Memory profiling
dotnet-trace collect --providers Microsoft-Windows-DotNETRuntime -- dotnet run -c Release

# CPU profiling with detailed traces
dotnet-trace collect --format speedscope --providers Microsoft-DotNETCore-SampleProfiler -- ./Miningcore -c config.json

# .NET diagnostic tools
dotnet-counters monitor --process-id <PID>
dotnet-dump collect --process-id <PID>
```

### Database Operations

**Create Database (PostgreSQL):**
```sql
sudo -u postgres psql
CREATE ROLE miningcore WITH LOGIN ENCRYPTED PASSWORD 'your-secure-password';
CREATE DATABASE miningcore OWNER miningcore;
\q
```

**Initialize Schema:**
```bash
sudo -u postgres psql -d miningcore -f src/Miningcore/Persistence/Postgres/Scripts/createdb.sql
```

**Enable Table Partitioning (PostgreSQL 11+):**
```bash
# WARNING: Deletes existing shares data
sudo -u postgres psql -d miningcore -f src/Miningcore/Persistence/Postgres/Scripts/createdb_postgresql_11_appendix.sql
```

**Create Pool-Specific Partition:**
```sql
CREATE TABLE shares_[pool-id] PARTITION OF shares FOR VALUES IN ('[pool-id]');
```

### Running the Pool

**Standard Execution:**
```bash
cd build
./Miningcore -c config.json
```

**Docker Execution:**
```bash
docker run -d \
  -p 4000:4000 \
  -p 4066:4066 \
  -p 4067:4067 \
  --name miningcore \
  -v $(pwd)/config.json:/app/config.json \
  --restart=unless-stopped \
  miningcore:latest
```

**Configuration Validation:**
```bash
./Miningcore -c config.json --dump-config
```

**JSON Schema Generation:**
```bash
./Miningcore --generate-schema > config.schema.json
```

## Configuration Management

### Pool Configuration Structure

Pool configurations follow a hierarchical JSON structure validated against `config.schema.json`:

```bash path=null start=null
{
  "logging": { "level": "info", "enableConsoleLog": true },
  "persistence": {
    "postgres": {
      "host": "127.0.0.1", "port": 5432,
      "user": "miningcore", "password": "password", "database": "miningcore"
    }
  },
  "pools": [{
    "id": "unique-pool-id",
    "coin": "bitcoin", // References coins.json
    "address": "pool-wallet-address",
    "ports": { "3333": { "difficulty": 1024, "varDiff": {...} }},
    "daemons": [{ "host": "127.0.0.1", "port": 8332, "user": "rpc-user", "password": "rpc-password" }]
  }]
}
```

### Coin Definition System

The `coins.json` file defines supported cryptocurrencies with:
- Algorithm-specific hashers (headerHasher, blockHasher, coinbaseHasher)
- Network parameters and explorer links
- Share multipliers and difficulty adjustments
- Family classification (bitcoin, ethereum, cryptonote, equihash, ergo)

### Environment Variables for Security

```bash path=null start=null
# Database credentials
export DB_PASSWORD=$(secret_manager --secret-name=miningcore-db-password)
export RPC_PASSWORD=$(secret_manager --secret-name=bitcoin-rpc-password)

# Use in config.json as: "password": "${DB_PASSWORD}"
```

## Cryptocurrency-Specific Configurations

### Bitcoin/Altcoin Pools
- Use `family: "bitcoin"` in coins.json
- Configure RPC connection to full node daemon
- Set appropriate difficulty and vardiff parameters
- Enable P2PK/P2PKH address validation

### Ethereum Pools  
- Requires go-ethereum (geth) or similar client
- Configure gas price and gas limit parameters
- Set up uncle block handling
- Monitor DAG epoch changes

### Monero/CryptoNote Pools
- Configure RandomX VM count for throughput
- Set `randomXFlagsAdd: "RANDOMX_FLAG_FULL_MEM"` for fast mode (3GB RAM per VM)
- Use light mode (256MB RAM per VM) by default
- Disable wallet RPC authentication: `--disable-rpc-login`

### ZCash/Equihash Pools
- Configure both t-addr and z-addr for pool
- Set `equihashMaxThreads` for solver concurrency
- Ensure daemon controls both address types
- Support both transparent and shielded miner addresses

### Vertcoin Pools
- Copy `verthash.dat` file to server
- Configure `vertHashDataFile` path in pool config
- Ensure sufficient disk space for verthash data

## Testing Patterns

### Unit Testing with xUnit
- Test classes mirror source namespace structure
- Use `NSubstitute` for mocking blockchain interactions
- Integration tests require PostgreSQL test database
- Performance tests use `BenchmarkDotNet` framework

### Mock Strategies
- Blockchain daemons: Mock RPC responses for unit tests
- Database operations: Use in-memory providers or test containers
- Network operations: Mock Stratum protocol messages
- Time-dependent logic: Inject `ITimeProvider` implementations

## API Integration

### REST API Endpoints
- Pool statistics: `GET /api/pools/{poolId}/stats`
- Miner performance: `GET /api/pools/{poolId}/miners/{address}`
- Payment history: `GET /api/pools/{poolId}/payments`
- Admin operations: `POST /api/admin/pools/{poolId}/blocks/{blockHeight}`

### WebSocket Streams
- Block notifications: `/notifications/blocks`
- Payment events: `/notifications/payments` 
- Real-time statistics: `/notifications/stats`

### Rate Limiting
- Configurable via `clusterConfig.Api.RateLimiting`
- Uses `AspNetCoreRateLimit` library
- Memory-cached policy store for performance

## Performance Optimization

### Native Library Compilation
Linux builds automatically compile native libraries via `build-libs-linux.sh`:
- libmultihash: Core hashing algorithms
- libcryptonote: CryptoNote-specific functions  
- libRandomX: Monero RandomX implementation
- Ensure development headers installed: `libssl-dev libboost-all-dev libsodium-dev`

### Database Optimization
- Enable table partitioning for high-volume pools
- Use connection pooling with appropriate pool sizes
- Consider read replicas for analytics queries
- Regular VACUUM and ANALYZE operations

### Memory Management
- Server GC enabled via `<ServerGarbageCollection>true</ServerGarbageCollection>`
- RecyclableMemoryStream for reduced allocations
- Unsafe code blocks for performance-critical operations
- CircularBuffer for efficient share processing

## Native Library Development

### CPU Feature Detection
```bash
# Check available CPU features
lscpu | grep -E "(avx|sse|aes)"

# Test specific CPU capabilities
../Native/check_cpu.sh avx2
../Native/check_cpu.sh aes
../Native/check_cpu.sh sse4_1

# View current compiler optimization flags
echo $CPU_FLAGS
echo $HAVE_FEATURE
```

### Manual Native Library Compilation
```bash
# Compile with specific optimizations
export CPU_FLAGS="-mavx2 -maes -msse4.1"
export HAVE_FEATURE="-DHAVE_AVX2 -D__AES__ -DHAVE_SSE4_1"

# Build individual libraries
cd src/Native/libmultihash && make clean && make
cd src/Native/libcryptonote && make clean && make
cd src/Native/libRandomX && make clean && make

# Custom RandomX build with specific flags
(cd /tmp && git clone https://github.com/tevador/RandomX && cd RandomX && \
 git checkout tags/v1.1.10 && mkdir build && cd build && \
 cmake -DARCH=native -DCMAKE_BUILD_TYPE=Release .. && make)
```

### Native Library Debugging
```bash
# Debug with GDB
gdb --args ./Miningcore -c config.json
(gdb) set environment MALLOC_CHECK_=2
(gdb) run

# Memory profiling with Valgrind
valgrind --tool=memcheck --leak-check=full --track-origins=yes ./Miningcore -c config.json

# Profile native library performance
valgrind --tool=callgrind ./Miningcore -c config.json
kcachegrind callgrind.out.*

# Check library dependencies
ldd build/libmultihash.so
ldd build/libcryptonote.so
objdump -p build/libmultihash.so | grep NEEDED
```

### Troubleshooting Native Builds
```bash
# Check for missing development headers
pkg-config --exists openssl && echo "OpenSSL found" || echo "Install libssl-dev"
pkg-config --exists libsodium && echo "Sodium found" || echo "Install libsodium-dev"

# Verify boost installation
find /usr/include -name "boost" 2>/dev/null || echo "Install libboost-all-dev"

# Check CMake and build tools
cmake --version
gcc --version
make --version

# Fix common compilation errors
# Missing symbols: ensure all required -l flags are present
nm -D build/libmultihash.so | grep -E "(GLIBC|GLIBCXX)"

# Architecture mismatch detection
file build/*.so
uname -m
```

## Performance Monitoring & Debugging

### Real-time Pool Monitoring
```bash
# Pool statistics via API
curl -s http://localhost:4000/api/pools | jq '.[] | {id: .config.id, hashrate: .poolStats.poolHashrate, miners: .poolStats.connectedMiners}'

# Individual pool detailed stats
curl -s http://localhost:4000/api/pools/poolid/stats | jq '.stats[] | {created: .created, hashrate: .poolHashrate, shares: .validShares}'

# Miner performance monitoring
curl -s http://localhost:4000/api/pools/poolid/miners/address | jq '.performance | {hashrate: .hashrate, shares: .validShares}'

# Block notifications via WebSocket
websocat ws://localhost:4000/notifications/blocks
```

### Log Analysis
```bash
# Monitor real-time logs
tail -f core.log | grep -E "(WARN|ERROR|Block found)"

# Analyze share submission patterns
grep "Share accepted" core.log | awk '{print $1, $2}' | uniq -c

# Track connection statistics
grep "Stratum" core.log | awk '{print $3}' | sort | uniq -c

# Payment processing analysis
grep "Payment" core.log | tail -20
```

### Database Performance Analysis
```bash
# Connection to database for analysis
psql -h localhost -U miningcore -d miningcore

# Analyze slow queries
SET log_min_duration_statement = 1000;

# Share table performance
EXPLAIN ANALYZE SELECT * FROM shares WHERE poolid = 'poolname' AND created > NOW() - INTERVAL '1 hour';

# Payment processing performance
EXPLAIN ANALYZE SELECT * FROM payments WHERE poolid = 'poolname' ORDER BY created DESC LIMIT 100;

# Database maintenance
VACUUM ANALYZE shares;
VACUUM ANALYZE payments;
```

### Memory and Performance Profiling
```bash
# Monitor memory usage
watch -n 5 'ps aux | grep Miningcore | grep -v grep'

# Network connection monitoring
ss -tuln | grep -E "(4000|3333|8332)"
netstat -an | grep -E "(LISTEN|ESTABLISHED)" | grep -E "(4000|3333|8332)"

# RandomX memory optimization
echo 3 > /proc/sys/vm/drop_caches  # Clear page cache before profiling
top -p $(pgrep Miningcore)

# Monitor Stratum connection latency
tcpdump -i any -c 100 port 3333
```

### Prometheus Metrics Queries
```bash
# Pool hashrate trending
curl -s "http://localhost:4000/metrics" | grep pool_hashrate

# Share validation metrics
curl -s "http://localhost:4000/metrics" | grep shares_

# Connection metrics
curl -s "http://localhost:4000/metrics" | grep stratum_connections
```

## Development Environment

### Visual Studio Code Configuration

**`.vscode/settings.json`:**
```json
{
    "dotnet.defaultSolution": "src/Miningcore.sln",
    "omnisharp.enableRoslynAnalyzers": true,
    "omnisharp.enableEditorConfigSupport": true,
    "files.exclude": {
        "**/bin": true,
        "**/obj": true,
        "**/.vs": true
    }
}
```

**`.vscode/launch.json`:**
```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Launch Miningcore",
            "type": "coreclr",
            "request": "launch",
            "program": "${workspaceFolder}/build/Miningcore.dll",
            "args": ["-c", "config.json"],
            "cwd": "${workspaceFolder}/build",
            "console": "internalConsole",
            "stopAtEntry": false
        },
        {
            "name": "Debug Tests",
            "type": "coreclr",
            "request": "launch",
            "program": "dotnet",
            "args": ["test", "--logger:console;verbosity=detailed"],
            "cwd": "${workspaceFolder}/src",
            "console": "internalConsole"
        }
    ]
}
```

**`.vscode/tasks.json`:**
```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build",
            "command": "dotnet",
            "type": "process",
            "args": ["build", "src/Miningcore.sln"],
            "problemMatcher": "$msCompile"
        },
        {
            "label": "build-native",
            "command": "./src/Miningcore/build-libs-linux.sh",
            "type": "shell",
            "args": ["build"],
            "group": "build"
        }
    ]
}
```

### Recommended VS Code Extensions
- **C# Dev Kit**: Advanced C# and .NET support
- **C/C++**: Native library development and debugging
- **Docker**: Container development and debugging
- **REST Client**: API endpoint testing
- **PostgreSQL**: Database query and management
- **GitLens**: Enhanced Git integration
- **Error Lens**: Inline error display

### Development Container Setup

**`.devcontainer/devcontainer.json`:**
```json
{
    "name": "Miningcore Development",
    "image": "mcr.microsoft.com/dotnet/sdk:6.0",
    "features": {
        "ghcr.io/devcontainers/features/docker-in-docker:2": {},
        "ghcr.io/devcontainers/features/github-cli:1": {}
    },
    "postCreateCommand": "apt update && apt install -y libssl-dev pkg-config libboost-all-dev libsodium-dev build-essential cmake postgresql-client",
    "forwardPorts": [4000, 3333, 5432],
    "extensions": [
        "ms-dotnettools.csharp",
        "ms-vscode.cpptools",
        "ms-azuretools.vscode-docker"
    ]
}
```

## Troubleshooting

### Common Build Issues
- Missing native dependencies: Install boost, sodium, SSL development headers
- Native library compilation failures: Check CMake and build tools installation
- Docker permission issues: Use `--privileged` flag for container builds

### Runtime Issues
- Database connection failures: Verify PostgreSQL service and credentials
- RPC daemon connectivity: Check daemon status and authentication
- Share validation errors: Verify coin definition hashers match blockchain
- Memory issues with RandomX: Adjust VM count or use light mode

### Troubleshooting Command Reference

**Database Connection Testing:**
```bash
# Test basic connectivity
psql -h localhost -U miningcore -c "SELECT 1"

# Check database schema
psql -h localhost -U miningcore -d miningcore -c "\dt"

# Verify shares table structure
psql -h localhost -U miningcore -d miningcore -c "\d shares"

# Check table partitioning (PostgreSQL 11+)
psql -h localhost -U miningcore -d miningcore -c "SELECT schemaname, tablename FROM pg_tables WHERE tablename LIKE 'shares_%';"
```

**RPC Daemon Health Checks:**
```bash
# Bitcoin/Altcoin daemon check
curl --data-binary '{"jsonrpc":"1.0","method":"getblockcount","params":[]}' \
  http://user:password@localhost:8332

# Ethereum daemon check
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  http://localhost:8545

# Monero daemon check
curl -X POST http://localhost:18081/json_rpc \
  -d '{"jsonrpc":"2.0","id":"0","method":"get_height"}' \
  -H 'Content-Type: application/json'

# Check daemon synchronization
curl --data-binary '{"jsonrpc":"1.0","method":"getblockchaininfo","params":[]}' \
  http://user:password@localhost:8332 | jq '.result.verificationprogress'
```

**Share Validation Debugging:**
```bash
# Enable verbose share logging
grep -A5 -B5 "Share.*rejected" core.log

# Monitor difficulty adjustments
grep "difficulty" core.log | tail -20

# Check for duplicate shares
grep "duplicate" core.log | wc -l

# Validate algorithm-specific errors
grep -E "(hash|algorithm|nonce)" core.log | grep -i error
```

**Memory Leak Detection:**
```bash
# Monitor memory growth over time
while true; do echo "$(date): $(ps -o pid,vsz,rss,comm -p $(pgrep Miningcore))"; sleep 300; done

# Detailed memory analysis
valgrind --tool=massif --time-unit=B ./Miningcore -c config.json
ms_print massif.out.*

# Check for memory fragmentation
cat /proc/$(pgrep Miningcore)/status | grep -E "(VmPeak|VmSize|VmRSS)"
```

**Network Analysis:**
```bash
# Monitor Stratum connections
ss -tuln | grep 3333
ss -tu | grep 3333 | wc -l  # Count active connections

# Capture Stratum protocol traffic
tcpdump -i any -A -s 0 port 3333 and host miner.ip.address

# Check for connection flooding
netstat -an | grep :3333 | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | sort -nr

# Monitor API endpoint performance
time curl -s http://localhost:4000/api/pools

# WebSocket connection testing
websocat ws://localhost:4000/notifications/stats
```

**Log Analysis and Monitoring:**
```bash
# Real-time error monitoring
tail -f core.log | grep -E "(ERROR|FATAL|Exception)"

# Performance bottleneck identification
grep "slow" core.log | awk '{print $1, $2, $NF}' | sort

# Share processing rate analysis
grep "Share accepted" core.log | awk '{print substr($1" "$2, 1, 16)}' | uniq -c

# Payment processing status
grep -E "(Payment.*sent|Balance.*updated)" core.log | tail -10

# Block discovery tracking
grep "Block found" core.log | awk '{print $1, $2, $NF}'
```

### Development Environment
- **Supported OS**: Linux (production), Windows (development only)
- **Database**: PostgreSQL 10+ (11+ recommended for partitioning)
- **Runtime**: .NET 6.0 SDK and runtime
- **Dependencies**: Native mining libraries, boost, sodium, OpenSSL

## Quick Reference

**Solution Structure:**
- `src/Miningcore/` - Main application
- `src/Miningcore.Tests/` - Test suite
- `examples/` - Sample pool configurations
- `Dockerfile` - Container build definition

**Key Files:**
- `coins.json` - Supported cryptocurrency definitions
- `config.schema.json` - Configuration validation schema
- `build-*.sh` - Platform-specific build scripts
- `createdb.sql` - Database schema initialization

**Testing:** xUnit framework with BenchmarkDotNet for performance
**Logging:** NLog with configurable targets and levels
**Dependencies:** Autofac DI container, Dapper ORM, ASP.NET Core API
