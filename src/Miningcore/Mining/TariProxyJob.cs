using System.Globalization;
using System.Text;
using Miningcore.Blockchain.Bitcoin;
using Miningcore.Blockchain.Cryptonote;
using Miningcore.Configuration;
using Miningcore.Crypto.Hashing.Algorithms;
using Miningcore.Extensions;
using Miningcore.Native;
using Miningcore.Persistence.Model;
using Miningcore.Stratum;
using NBitcoin;
using Newtonsoft.Json;
using NLog;
using Contract = Miningcore.Contracts.Contract;

namespace Miningcore.Mining;

/// <summary>
/// Tari Proxy Job that supports both SHA3x and RandomX algorithms
/// as specified in RFC-0131
/// </summary>
public class TariProxyJob
{
    public TariProxyJob(string jobId, TariProxyJobParams parameters)
    {
        Id = jobId;
        Parameters = parameters;
    }

    public string Id { get; }
    public TariProxyJobParams Parameters { get; }

    public void Init(PoolConfig poolConfig, ClusterConfig clusterConfig, ILogger logger)
    {
        Contract.RequiresNonNull(poolConfig);
        Contract.RequiresNonNull(clusterConfig);
        Contract.RequiresNonNull(logger);

        this.poolConfig = poolConfig;
        this.clusterConfig = clusterConfig;
        this.logger = logger;
    }

    public (Share Share, string BlockHex) ProcessShare(StratumConnection worker, string extraNonce2, string nTime, string nonce)
    {
        Contract.RequiresNonNull(worker);
        Contract.Requires<ArgumentException>(!string.IsNullOrEmpty(extraNonce2));
        Contract.Requires<ArgumentException>(!string.IsNullOrEmpty(nTime));
        Contract.Requires<ArgumentException>(!string.IsNullOrEmpty(nonce));

        // Process share based on algorithm
        if (Parameters.Algorithm == "sha3x")
            return ProcessSha3Share(worker, extraNonce2, nTime, nonce);
        else if (Parameters.Algorithm == "randomx")
            return ProcessRandomXShare(worker, extraNonce2, nTime, nonce);
        else
            throw new StratumException(StratumError.Other, $"Unsupported algorithm: {Parameters.Algorithm}");
    }

    private (Share Share, string BlockHex) ProcessSha3Share(StratumConnection worker, string extraNonce2, string nTime, string nonce)
    {
        var context = worker.ContextAs<BitcoinWorkerContext>();

        // Validate share
        if (nTime.Length != 8)
            throw new StratumException(StratumError.Other, "incorrect size of ntime");

        if (nonce.Length != 8)
            throw new StratumException(StratumError.Other, "incorrect size of nonce");

        // Validate nonce
        if (!ulong.TryParse(nonce, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var nonceValue))
            throw new StratumException(StratumError.Other, "invalid nonce");

        // Validate time
        if (!uint.TryParse(nTime, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out var nTimeValue))
            throw new StratumException(StratumError.Other, "invalid ntime");

        // Compute share difficulty
        var shareDiff = (double) new BigRational(BitcoinConstants.Diff1, Parameters.Target) * shareMultiplier;

        // Check if the share meets the difficulty requirement
        var stratumDifficulty = context.Difficulty;
        var ratio = shareDiff / stratumDifficulty;

        if (ratio < 0.99)
        {
            // Check if share matched the original difficulty from the miner
            if (context.VarDiff?.LastUpdate != null && context.PreviousDifficulty.HasValue)
            {
                ratio = shareDiff / context.PreviousDifficulty.Value;

                if (ratio < 0.99)
                    throw new StratumException(StratumError.LowDifficultyShare, $"low difficulty share ({shareDiff})");

                // Use previous difficulty
                stratumDifficulty = context.PreviousDifficulty.Value;
            }
            else
                throw new StratumException(StratumError.LowDifficultyShare, $"low difficulty share ({shareDiff})");
        }

        var isBlockCandidate = shareDiff >= (double)Parameters.NetworkDifficulty;

        // Create share
        var share = new Share
        {
            BlockHeight = Parameters.Height,
            NetworkDifficulty = (double)Parameters.NetworkDifficulty,
            Difficulty = stratumDifficulty / shareMultiplier,
            Miner = context.Miner,
            Worker = context.Worker,
            UserAgent = context.UserAgent,
            Algorithm = Parameters.Algorithm,
            PoolId = poolConfig.Id,
            Created = DateTime.UtcNow
        };

        if (isBlockCandidate)
        {
            // Construct block header for SHA3x
            var headerBytes = BuildSha3BlockHeader(nonce, nTimeValue);
            var headerHex = headerBytes.ToHexString();

            // Calculate the hash using SHA3x
            Span<byte> hashBytes = stackalloc byte[32];
            var hasher = new Crypto.Hashing.Algorithms.Sha3x();
            hasher.Digest(headerBytes, hashBytes);
            var hash = hashBytes.ToHexString();

            share.IsBlockCandidate = true;
            share.BlockHash = hash;
            share.TransactionConfirmationData = headerHex;

            return (share, headerHex);
        }

        return (share, null);
    }

    private (Share Share, string BlockHex) ProcessRandomXShare(StratumConnection worker, string extraNonce2, string nTime, string nonce)
    {
        var context = worker.ContextAs<CryptonoteWorkerContext>();

        // Validate nonce
        if (!CryptonoteConstants.RegexValidNonce.IsMatch(nonce))
            throw new StratumException(StratumError.Other, "invalid nonce");

        // Compute share difficulty
        var difficulty = context.Difficulty;
        var stratumDifficulty = difficulty;

        // Check if the share meets the difficulty requirement
        var isBlockCandidate = false;

        // Create share
        var share = new Share
        {
            BlockHeight = Parameters.Height,
            NetworkDifficulty = (double)Parameters.NetworkDifficulty,
            Difficulty = stratumDifficulty,
            Miner = context.Miner,
            Worker = context.Worker,
            UserAgent = context.UserAgent,
            Algorithm = Parameters.Algorithm,
            PoolId = poolConfig.Id,
            Created = DateTime.UtcNow
        };

        // For RandomX, we need to construct a Monero-compatible block
        var blob = Parameters.Blob;
        var blobTemplate = blob.HexToByteArray();
        var nonceBytes = nonce.HexToByteArray();

        // Insert nonce into blob
        Buffer.BlockCopy(nonceBytes, 0, blobTemplate, CryptonoteConstants.BlobNonceOffset, CryptonoteConstants.BlobNonceSize);

        // Calculate the hash using RandomX
        Span<byte> hashBytes = stackalloc byte[32];
        RandomX.CalculateHash(poolConfig.Id, Parameters.Seed, blobTemplate, hashBytes);

        // Check if it's a block candidate
        var hash = hashBytes.ToHexString();
        isBlockCandidate = CryptonoteConstants.CompareHash(hash, Parameters.Target.ToHexString());

        if (isBlockCandidate)
        {
            share.IsBlockCandidate = true;
            share.BlockHash = hash;

            // For RandomX, we submit the blob with the nonce
            var blockHex = blobTemplate.ToHexString();
            share.TransactionConfirmationData = blockHex;

            return (share, blockHex);
        }

        return (share, null);
    }

    private byte[] BuildSha3BlockHeader(string nonce, uint nTimeValue)
    {
        // Construct block header for SHA3x according to Tari RFC-0131
        var headerBytes = new byte[80];
        var version = BitConverter.GetBytes(Parameters.Version);
        var prevHash = Parameters.PrevHash.HexToByteArray().ReverseArray();
        var merkleRoot = Parameters.MerkleRoot.HexToByteArray().ReverseArray();
        var time = BitConverter.GetBytes(nTimeValue);
        var bits = BitConverter.GetBytes(Parameters.Bits);
        var nonceBytes = nonce.HexToByteArray().ReverseArray();

        Buffer.BlockCopy(version, 0, headerBytes, 0, 4);
        Buffer.BlockCopy(prevHash, 0, headerBytes, 4, 32);
        Buffer.BlockCopy(merkleRoot, 0, headerBytes, 36, 32);
        Buffer.BlockCopy(time, 0, headerBytes, 68, 4);
        Buffer.BlockCopy(bits, 0, headerBytes, 72, 4);
        Buffer.BlockCopy(nonceBytes, 0, headerBytes, 76, 4);

        return headerBytes;
    }

    private PoolConfig poolConfig;
    private ClusterConfig clusterConfig;
    private ILogger logger;
    private const double shareMultiplier = 1;
}

/// <summary>
/// Parameters for Tari Proxy Job
/// </summary>
public class TariProxyJobParams
{
    public uint Version { get; set; }
    public string PrevHash { get; set; }
    public string MerkleRoot { get; set; }
    public uint Height { get; set; }
    public uint Bits { get; set; }
    public uint Time { get; set; }
    public System.Numerics.BigInteger NetworkDifficulty { get; set; }
    public byte[] Target { get; set; }

    // Algorithm-specific parameters
    public string Algorithm { get; set; }

    // RandomX specific parameters
    public string Seed { get; set; }
    public string Blob { get; set; }
}
