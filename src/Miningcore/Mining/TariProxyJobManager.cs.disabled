using System.Collections.Concurrent;
using System.Globalization;
using System.Reactive.Linq;
using Autofac;
using AutoMapper;
using Microsoft.IO;
using Miningcore.Blockchain;
using Miningcore.Blockchain.Bitcoin;
using Miningcore.Blockchain.Cryptonote;
using Miningcore.Configuration;
using Miningcore.Extensions;
using Miningcore.Messaging;
using Miningcore.Nicehash;
using Miningcore.Notifications.Messages;
using Miningcore.Persistence;
using Miningcore.Persistence.Model;
using Miningcore.Persistence.Repositories;
using Miningcore.Stratum;
using Miningcore.Time;
using NBitcoin;
using Newtonsoft.Json;
using NLog;
using Contract = Miningcore.Contracts.Contract;
using Miningcore.Util;

namespace Miningcore.Mining;

/// <summary>
/// Tari Proxy Job Manager that implements Tari's hybrid mining approach
/// as specified in RFC-0131 and RFC-0132
/// </summary>
[CoinFamily("tari")]
public class TariProxyJobManager : PoolBase
{
    public TariProxyJobManager(
        IComponentContext ctx,
        JsonSerializerSettings serializerSettings,
        IConnectionFactory cf,
        IStatsRepository statsRepo,
        IMapper mapper,
        IMasterClock clock,
        IMessageBus messageBus,
        RecyclableMemoryStreamManager rmsm,
        NicehashService nicehashService) : base(ctx, serializerSettings, cf, statsRepo, mapper, clock, messageBus, rmsm, nicehashService)
    {
        Contract.RequiresNonNull(ctx);
        Contract.RequiresNonNull(messageBus);
        Contract.RequiresNonNull(clock);

        this.ctx = ctx;
        this.messageBus = messageBus;
        this.clock = clock;
    }

    private readonly IComponentContext ctx;
    private readonly IMessageBus messageBus;
    private readonly IMasterClock clock;
    private readonly ConcurrentDictionary<string, TariProxyJob> validJobs = new();
    private readonly ConcurrentDictionary<string, TariProxyJob> validJobsByBlockTemplate = new();
    private BitcoinJobManager sha3JobManager;
    private CryptonoteJobManager randomxJobManager;
    private string poolId;
    private PoolConfig poolConfig;
    private ClusterConfig clusterConfig;
    private ILogger logger;

    public override double ShareMultiplier => 1.0;

    public override string JobManagerName => "Tari Proxy";

    public override PoolStats PoolStats => sha3JobManager?.PoolStats ?? randomxJobManager?.PoolStats ?? new PoolStats();

    public override BlockchainStats NetworkStats => sha3JobManager?.NetworkStats ?? randomxJobManager?.NetworkStats ?? new BlockchainStats();

    public override PoolConfig Config => poolConfig;

    private void SetupJobManagers()
    {
        // Initialize SHA3 job manager
        sha3JobManager = ctx.Resolve<BitcoinJobManager>();

        // Create a modified pool config for SHA3
        var sha3PoolConfig = new PoolConfig
        {
            Id = $"{poolConfig.Id}-sha3",
            Coin = "tari-sha3",
            Address = poolConfig.Address,
            RewardRecipients = poolConfig.RewardRecipients,
            BlockRefreshInterval = poolConfig.BlockRefreshInterval,
            ClientConnectionTimeout = poolConfig.ClientConnectionTimeout,
            Banning = poolConfig.Banning,
            Ports = poolConfig.Ports,
            Daemons = poolConfig.Daemons,
            PaymentProcessing = poolConfig.PaymentProcessing
        };

        sha3JobManager.Configure(sha3PoolConfig, clusterConfig);

        // Initialize RandomX job manager
        randomxJobManager = ctx.Resolve<CryptonoteJobManager>();

        // Create a modified pool config for RandomX
        var randomxPoolConfig = new PoolConfig
        {
            Id = $"{poolConfig.Id}-randomx",
            Coin = "tari-randomx",
            Address = poolConfig.Address,
            RandomXRealm = poolConfig.Id,
            RewardRecipients = poolConfig.RewardRecipients,
            BlockRefreshInterval = poolConfig.BlockRefreshInterval,
            ClientConnectionTimeout = poolConfig.ClientConnectionTimeout,
            Banning = poolConfig.Banning,
            Ports = poolConfig.Ports,
            Daemons = poolConfig.Daemons,
            PaymentProcessing = poolConfig.PaymentProcessing
        };

        randomxJobManager.Configure(randomxPoolConfig, clusterConfig);

        // Subscribe to job updates from both managers
        sha3JobManager.Jobs.Subscribe(OnSha3NewJob);
        randomxJobManager.Jobs.Subscribe(OnRandomXNewJob);

        // Start both job managers
        sha3JobManager.Start();
        randomxJobManager.Start();
    }

    private void OnSha3NewJob(object job)
    {
        // Process new job from SHA3 manager
        if (job is BitcoinJob bitcoinJob)
        {
            // Create a proxy job that wraps the SHA3 job
            var proxyJob = CreateProxyJobFromBitcoinJob(bitcoinJob, "sha3");

            // Store the job
            validJobs[proxyJob.Id] = proxyJob;
            validJobsByBlockTemplate[bitcoinJob.BlockTemplate.JobId] = proxyJob;

            // Notify clients
            messageBus.NotifyChainHeight(poolId, bitcoinJob.BlockTemplate.Height, poolConfig.Id);
        }
    }

    private void OnRandomXNewJob(object job)
    {
        // Process new job from RandomX manager
        if (job is CryptonoteJob cryptonoteJob)
        {
            // Create a proxy job that wraps the RandomX job
            var proxyJob = CreateProxyJobFromCryptonoteJob(cryptonoteJob);

            // Store the job
            validJobs[proxyJob.Id] = proxyJob;

            // Notify clients
            messageBus.NotifyChainHeight(poolId, cryptonoteJob.BlockTemplate.Height, poolConfig.Id);
        }
    }

    private TariProxyJob CreateProxyJobFromBitcoinJob(BitcoinJob bitcoinJob, string algo)
    {
        // Extract necessary parameters from the Bitcoin job
        var jobParams = new TariProxyJobParams
        {
            Version = (uint)bitcoinJob.BlockTemplate.Version,
            PrevHash = bitcoinJob.BlockTemplate.PreviousBlockhash,
            MerkleRoot = bitcoinJob.BlockTemplate.CoinbaseHash,
            Height = bitcoinJob.BlockTemplate.Height,
            Bits = bitcoinJob.BlockTemplate.Bits.HexToByteArray().ToUInt32(),
            Time = bitcoinJob.BlockTemplate.CurTime,
            NetworkDifficulty = bitcoinJob.BlockTemplate.Target.HexToByteArray().ToBigInteger().GetDifficulty(),
            Target = bitcoinJob.BlockTemplate.Target.HexToByteArray(),
            Algorithm = "sha3x"
        };

        // Create a new proxy job with a unique ID
        var jobId = $"sha3-{bitcoinJob.BlockTemplate.JobId}";
        var proxyJob = new TariProxyJob(jobId, jobParams);
        proxyJob.Init(poolConfig, clusterConfig, logger);

        return proxyJob;
    }

    private TariProxyJob CreateProxyJobFromCryptonoteJob(CryptonoteJob cryptonoteJob)
    {
        // Extract necessary parameters from the Cryptonote job
        var jobParams = new TariProxyJobParams
        {
            Version = cryptonoteJob.BlockTemplate.Version,
            PrevHash = cryptonoteJob.BlockTemplate.PreviousBlockhash,
            Height = cryptonoteJob.BlockTemplate.Height,
            NetworkDifficulty = cryptonoteJob.BlockTemplate.Difficulty,
            Bits = 0, // Not used for RandomX
            Time = (uint)DateTimeOffset.UtcNow.ToUnixTimeSeconds(),
            Target = cryptonoteJob.BlockTemplate.Target.HexToByteArray(),
            Algorithm = "randomx",
            Seed = cryptonoteJob.BlockTemplate.Seed,
            Blob = cryptonoteJob.BlockTemplate.Blob
        };

        // Create a new proxy job with a unique ID
        var jobId = $"randomx-{cryptonoteJob.Id}";
        var proxyJob = new TariProxyJob(jobId, jobParams);
        proxyJob.Init(poolConfig, clusterConfig, logger);

        return proxyJob;
    }

    public override void Configure(PoolConfig poolConfig, ClusterConfig clusterConfig)
    {
        this.poolConfig = poolConfig;
        this.clusterConfig = clusterConfig;
        this.poolId = poolConfig.Id;

        logger = LogUtil.GetPoolScopedLogger(typeof(TariProxyJobManager), poolConfig);

        SetupJobManagers();
    }

    public override Task StartAsync(CancellationToken ct)
    {
        // Already started in SetupJobManagers
        return Task.CompletedTask;
    }

    public override Task RunAsync(CancellationToken ct)
    {
        logger.Info(() => $"Starting Tari Proxy Job Manager for pool {poolConfig.Id}");

        // Both job managers are already running
        return Task.CompletedTask;
    }

    public override Task StopAsync(CancellationToken ct)
    {
        sha3JobManager?.StopAsync(ct);
        randomxJobManager?.StopAsync(ct);
        return Task.CompletedTask;
    }

    public override bool ValidateAddress(string address)
    {
        // Try both validation methods
        return sha3JobManager.ValidateAddress(address) || randomxJobManager.ValidateAddress(address);
    }

    public override void PrepareWorker(StratumConnection connection)
    {
        // Determine which job manager to use based on the port
        var port = connection.LocalEndpoint.Port;

        // Check if this is a SHA3 port (even port numbers) or RandomX port (odd port numbers)
        if (port % 2 == 0)
            sha3JobManager.PrepareWorker(connection);
        else
            randomxJobManager.PrepareWorker(connection);
    }

    public override async Task<Share> SubmitShareAsync(StratumConnection worker, string[] request, CancellationToken ct)
    {
        Contract.RequiresNonNull(worker);
        Contract.RequiresNonNull(request);

        if (request.Length < 5)
            throw new StratumException(StratumError.Other, "invalid params");

        var workerId = request[0];
        var jobId = request[1];
        var extraNonce2 = request[2];
        var nTime = request[3];
        var nonce = request[4];

        // Lookup job by id
        if (!validJobs.TryGetValue(jobId, out var job))
            throw new StratumException(StratumError.JobNotFound, "job not found");

        // Process the share
        var (share, blockHex) = job.ProcessShare(worker, extraNonce2, nTime, nonce);

        // Is it a block candidate?
        if (share.IsBlockCandidate)
        {
            logger.Info(() => $"Submitting block {share.BlockHeight} [{share.BlockHash}]");

            // Determine which job manager to use based on the job ID
            bool accepted;
            if (jobId.StartsWith("randomx"))
            {
                var acceptResponse = await randomxJobManager.SubmitBlockAsync(blockHex, ct);
                accepted = acceptResponse.Accepted;
            }
            else
            {
                var acceptResponse = await sha3JobManager.SubmitBlockAsync(blockHex, ct);
                accepted = acceptResponse.Accepted;
            }

            // Was it accepted?
            share.IsBlockCandidate = accepted;

            if (share.IsBlockCandidate)
            {
                logger.Info(() => $"Block {share.BlockHeight} [{share.BlockHash}] accepted by network");

                // Publish block found notification
                messageBus.SendMessage(new BlockFoundNotification(poolId, share.BlockHeight, share.BlockHash, share.Reward));
            }
            else
            {
                logger.Warn(() => $"Block {share.BlockHeight} [{share.BlockHash}] rejected by network");
            }
        }

        return share;
    }

    public override double HashrateFromShares(double shares, double interval)
    {
        // Use the SHA3 job manager for hashrate calculation
        return sha3JobManager.HashrateFromShares(shares, interval);
    }

    protected override void UpdateJob(bool forceUpdate)
    {
        // Jobs are updated through the subscription to the SHA3 and RandomX job managers
    }

    protected override string FormatAmount(decimal amount)
    {
        return sha3JobManager?.FormatAmount(amount) ?? amount.ToString(CultureInfo.InvariantCulture);
    }

    protected override async Task<bool> AreDaemonsHealthyAsync(CancellationToken ct)
    {
        var sha3Healthy = await sha3JobManager.AreDaemonsHealthyAsync(ct);
        var randomxHealthy = await randomxJobManager.AreDaemonsHealthyAsync(ct);

        return sha3Healthy && randomxHealthy;
    }

    protected override async Task<bool> AreDaemonsConnectedAsync(CancellationToken ct)
    {
        var sha3Connected = await sha3JobManager.AreDaemonsConnectedAsync(ct);
        var randomxConnected = await randomxJobManager.AreDaemonsConnectedAsync(ct);

        return sha3Connected && randomxConnected;
    }
}
