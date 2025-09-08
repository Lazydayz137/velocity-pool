using Miningcore.Blockchain.Bitcoin.DaemonResponses;
using Miningcore.Configuration;
using Miningcore.Contracts;
using Miningcore.Crypto;
using Miningcore.Native;
using Miningcore.Stratum;
using Miningcore.Time;
using NBitcoin;

namespace Miningcore.Blockchain.Bitcoin;

public class FiroJob : BitcoinJob
{
    public byte[] SeedHash { get; protected set; }
    private byte[] headerHash;

    public override void Init(BlockTemplate blockTemplate, string jobId,
        PoolConfig poolConfig, BitcoinPoolConfigExtra extraPoolConfig, ClusterConfig clusterConfig, IMasterClock clock,
        IDestination poolAddressDestination, Network network, bool isPoS,
        double shareMultiplier, IHashAlgorithm coinbaseHasher, IHashAlgorithm headerHasher, IHashAlgorithm blockHasher)
    {
        base.Init(blockTemplate, jobId, poolConfig, extraPoolConfig, clusterConfig, clock, poolAddressDestination, network, isPoS, shareMultiplier, coinbaseHasher, headerHasher, blockHasher);

        // FiroPow-specific initialization
        CalculateSeedHash();

        // Pre-calculate header hash
        headerHash = new byte[80];
        // version
        BitConverter.GetBytes(blockTemplate.Version).CopyTo(headerHash, 0);
        // previousblockhash
        blockTemplate.PreviousBlockhash.HexToByteArray().Reverse().ToArray().CopyTo(headerHash, 4);
        // merkleroot - placeholder for now, will be calculated per share
        // time
        BitConverter.GetBytes(blockTemplate.CurTime).CopyTo(headerHash, 68);
        // bits
        blockTemplate.Bits.HexToByteArray().Reverse().ToArray().CopyTo(headerHash, 72);
        // height
        BitConverter.GetBytes(blockTemplate.Height).CopyTo(headerHash, 76);
    }

    private unsafe void CalculateSeedHash()
    {
        // Based on https://github.com/MintPond/ref-stratum-firo/blob/master/libs/class.Job.js#L268
        const int epochLength = 1300; // FiroPow epoch length
        var epoch = BlockTemplate.Height / epochLength;

        var seed = new byte[32]; // Initial seed is all zeros

        for (var i = 0; i < epoch; i++)
        {
            fixed (byte* input = seed)
            {
                fixed (byte* output = seed)
                {
                    Multihash.sha3_256(input, output, 32);
                }
            }
        }

        SeedHash = seed;
    }

    public (Share Share, string BlockHex) ProcessShareFiro(StratumConnection worker, string nonce, string mixHash)
    {
        var context = worker.ContextAs<BitcoinWorkerContext>();
        var nonceLong = ulong.Parse(nonce, System.Globalization.NumberStyles.HexNumber);
        var mixHashBytes = mixHash.HexToByteArray();
        var hashReturn = new byte[32];

        // build coinbase
        var coinbase = SerializeCoinbase(context.ExtraNonce1, "0000000000000000"); // FiroPow doesn't use extranonce2
        var coinbaseHash = coinbaseHasher.Digest(coinbase);

        // build merkle-root
        var merkleRoot = mt.WithFirst(coinbaseHash);
        merkleRoot.CopyTo(headerHash, 36);

        var headerHashForVerify = new byte[32];
        headerHasher.Digest(headerHash, headerHashForVerify);

        if (LibFiroPow.Verify(headerHashForVerify, nonceLong, (uint)BlockTemplate.Height, mixHashBytes, hashReturn))
        {
            var finalHash = new uint256(hashReturn);
            var shareDiff = (double)new BigRational(BitcoinConstants.Diff1, finalHash.ToBigInteger()) * shareMultiplier;
            var stratumDifficulty = context.Difficulty;
            var ratio = shareDiff / stratumDifficulty;
            var isBlockCandidate = finalHash <= blockTargetValue;

            if (!isBlockCandidate && ratio < 0.99)
            {
                if (context.VarDiff?.LastUpdate != null && context.PreviousDifficulty.HasValue)
                {
                    ratio = shareDiff / context.PreviousDifficulty.Value;

                    if (ratio < 0.99)
                        throw new StratumException(StratumError.LowDifficultyShare, $"low difficulty share ({shareDiff})");

                    stratumDifficulty = context.PreviousDifficulty.Value;
                }
                else
                    throw new StratumException(StratumError.LowDifficultyShare, $"low difficulty share ({shareDiff})");
            }

            var result = new Share
            {
                BlockHeight = BlockTemplate.Height,
                NetworkDifficulty = Difficulty,
                Difficulty = stratumDifficulty / shareMultiplier,
            };

            if (isBlockCandidate)
            {
                result.IsBlockCandidate = true;
                result.BlockHash = new uint256(finalHash.ToBytes().Reverse().ToArray()).ToString();

                var blockHex = SerializeBlockFiro(nonceLong, mixHashBytes, coinbase);
                return (result, blockHex);
            }

            return (result, null);
        }

        throw new StratumException(StratumError.Other, "invalid share");
    }

    private string SerializeBlockFiro(ulong nonce, byte[] mixHash, byte[] coinbase)
    {
        var rawTransactionBuffer = BuildRawTransactionBuffer();
        var transactionCount = (uint)BlockTemplate.Transactions.Length + 1; // +1 for prepended coinbase tx

        using (var stream = new MemoryStream())
        {
            var bs = new BitcoinStream(stream, true);

            bs.ReadWrite(headerHash);

            var nonceBytes = BitConverter.GetBytes(nonce);
            if(!BitConverter.IsLittleEndian)
                Array.Reverse(nonceBytes);
            bs.ReadWrite(nonceBytes);

            bs.ReadWrite(mixHash);
            bs.ReadWriteAsVarInt(ref transactionCount);
            bs.ReadWrite(ref coinbase);
            bs.ReadWrite(ref rawTransactionBuffer);

            return stream.ToArray().ToHexString();
        }
    }

    public object[] GetJobParamsFiro(bool isNew)
    {
        return new object[]
        {
            JobId,
            headerHash.ToHexString(),
            SeedHash.ToHexString(),
            BlockTemplate.Target.ToHexString(),
            BlockTemplate.Height,
            isNew
        };
    }
}
