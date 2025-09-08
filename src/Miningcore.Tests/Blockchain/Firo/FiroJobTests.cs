using Autofac;
using Microsoft.IO;
using Miningcore.Blockchain.Bitcoin;
using Miningcore.Configuration;
using Miningcore.Stratum;
using Miningcore.Tests.Util;
using NBitcoin;
using NBitcoin.DataEncoders;
using Newtonsoft.Json;
using NLog;
using Xunit;

namespace Miningcore.Tests.Blockchain.Firo;

public class FiroJobTests : TestBase
{
    static FiroJobTests()
    {
        // Register Firo network
        var firoConsensus = new Consensus
        {
            SubsidyHalvingInterval = 210000,
            MajorityEnforceBlockUpgrade = 750,
            MajorityRejectBlockOutdated = 950,
            MajorityWindow = 1000,
            BIP34Hash = new uint256("0x000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8"),
            PowLimit = new Target(new uint256("00000fffffffffffffffffffffffffffffffffffffffffffffffffffffff")),
            PowTargetTimespan = System.TimeSpan.FromSeconds(14 * 24 * 60 * 60), // two weeks
            PowTargetSpacing = System.TimeSpan.FromSeconds(10 * 60),
            PowAllowMinDifficultyBlocks = false,
            PowNoRetargeting = false,
            RuleChangeActivationThreshold = 1916, // 95% of 2016
            MinerConfirmationWindow = 2016, // nPowTargetTimespan / nPowTargetSpacing
            CoinbaseMaturity = 100,
            SupportSegwit = true
        };

        var firoNetwork = new NetworkBuilder()
            .SetName("firo-main")
            .SetConsensus(firoConsensus)
            .SetMagic(0xf1fed9e3)
            .SetPort(8168)
            .SetRPCPort(9998)
            .SetBase58Bytes(Base58Type.PUBKEY_ADDRESS, new byte[] { 82 })
            .SetBase58Bytes(Base58Type.SCRIPT_ADDRESS, new byte[] { 7 })
            .SetBase58Bytes(Base58Type.SECRET_KEY, new byte[] { 210 })
            .BuildAndRegister();
    }

    [Fact]
    public void Should_Verify_Valid_Share()
    {
        var (job, worker) = CreateJob();

        // Test vectors from https://github.com/MintPond/hasher-firopow/blob/master/test.js
        var nonce = "9b95eb33003ba288"; // this is the little-endian nonce
        var mixHash = "3414b7c3105a45426e56e6f4c800f4358334cc7df74d98141bb887185166436d";
        var headerHash = "63543d3913fe56e6720c5e61e8d208d05582875822628f483279a3e8d9c9a8b3";

        // The ProcessShareFiro method expects the raw header hash, not the one that's been through the header hasher
        // So we need to set the internal headerHash field of the job to the correct value
        var headerHashBytes = headerHash.HexToByteArray();
        var jobHeaderField = typeof(FiroJob).GetField("headerHash", System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
        jobHeaderField.SetValue(job, headerHashBytes);

        var (share, blockHex) = job.ProcessShareFiro(worker, nonce, mixHash);

        Assert.NotNull(share);
        Assert.True(share.IsBlockCandidate);
        Assert.Equal("717e7b6181ac3feb159059eca5080039df5676190a5f80a44d40e7c37d364126", share.BlockHash);
    }

    private (FiroJob, StratumConnection) CreateJob()
    {
        var job = new FiroJob();
        var coin = (BitcoinTemplate) ModuleInitializer.CoinTemplates["firo"];
        var pc = new PoolConfig { Template = coin };

        var blockTemplate = new Miningcore.Blockchain.Bitcoin.DaemonResponses.BlockTemplate
        {
            Height = 262523,
            Bits = "1e0ffff0", // A reasonably low difficulty
            Target = "00000ffff0000000000000000000000000000000000000000000000000000000"
        };

        var clock = MockMasterClock.FromTicks(638010200200475015);
        var poolAddressDestination = BitcoinUtils.AddressToDestination("a8A4Q2X22n33t1v4s4x6XyY7Z3q5D6E7F8", Network.GetNetwork("firo-main"));
        var network = Network.GetNetwork("firo-main");

        var context = new BitcoinWorkerContext
        {
            Miner = "test",
            ExtraNonce1 = "00000001",
            Difficulty = 1,
            UserAgent = "test"
        };

        var worker = new StratumConnection(new NullLogger(LogManager.LogFactory), container.Resolve<RecyclableMemoryStreamManager>(), clock, "1", false);
        worker.SetContext(context);

        job.Init(blockTemplate, "1", pc, null, new ClusterConfig(), clock, poolAddressDestination, network, false,
            coin.ShareMultiplier, coin.CoinbaseHasherValue, coin.HeaderHasherValue, coin.BlockHasherValue);

        return (job, worker);
    }
}
