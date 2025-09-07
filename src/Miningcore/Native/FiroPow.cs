using System.Runtime.InteropServices;

// ReSharper disable FieldCanBeMadeReadOnly.Local
// ReSharper disable MemberCanBePrivate.Local
// ReSharper disable InconsistentNaming

namespace Miningcore.Native;

/// <summary>
/// FiroPow native library P/Invoke wrapper
/// Provides access to FiroPow ProgPow implementation with Firo-specific parameters
/// </summary>
public static unsafe class FiroPow
{
    #region Constants
    
    /// <summary>
    /// FiroPow-specific input constraints for Keccak state padding
    /// Represents "FIRO" repeated to fill the required state positions
    /// </summary>
    public static readonly uint[] FiroConstants = 
    {
        0x00000046, // F
        0x00000049, // I  
        0x00000052, // R
        0x0000004F, // O
        0x00000046, // F (repeated)
        0x00000049, // I
        0x00000052, // R
        0x0000004F, // O
        0x00000046  // F
    };

    /// <summary>
    /// FiroPow ProgPow period length (blocks)
    /// Different from KawPow to provide distinct mining characteristics
    /// </summary>
    public const int PeriodLength = 10;

    /// <summary>
    /// FiroPow cache size multiplier
    /// Adjusted for optimal ASIC resistance while maintaining GPU efficiency
    /// </summary>
    public const int CacheSizeMultiplier = 1024;

    /// <summary>
    /// Number of ProgPow mix rounds for FiroPow
    /// Balances security and performance requirements
    /// </summary>
    public const int NumRounds = 64;

    #endregion

    #region P/Invoke Declarations

    /// <summary>
    /// Create FiroPow epoch context for DAG generation
    /// </summary>
    [DllImport("libfiropow", EntryPoint = "firopow_create_epoch_context", CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr CreateEpochContext(int epoch_number);

    /// <summary>
    /// Destroy FiroPow epoch context and free memory
    /// </summary>
    [DllImport("libfiropow", EntryPoint = "firopow_destroy_epoch_context", CallingConvention = CallingConvention.Cdecl)]
    private static extern void DestroyEpochContext(IntPtr context);

    /// <summary>
    /// FiroPow hash function with extended parameters for mining verification
    /// </summary>
    [DllImport("libfiropow", EntryPoint = "firopow_hash_ext", CallingConvention = CallingConvention.Cdecl)]
    private static extern FiroPow_result HashExt(IntPtr context, int block_number, ref FiroPow_hash256 header_hash, 
        ulong nonce, ref FiroPow_hash256 mix_hash, ref FiroPow_hash256 boundary1, ref FiroPow_hash256 boundary2, out int retcode);

    /// <summary>
    /// Standard FiroPow hash function
    /// </summary>
    [DllImport("libfiropow", EntryPoint = "firopow_hash", CallingConvention = CallingConvention.Cdecl)]
    private static extern FiroPow_result Hash(IntPtr context, int block_number, ref FiroPow_hash256 header_hash, ulong nonce);

    /// <summary>
    /// FiroPow verification function
    /// </summary>
    [DllImport("libfiropow", EntryPoint = "firopow_verify", CallingConvention = CallingConvention.Cdecl)]
    private static extern bool Verify(IntPtr context, int block_number, ref FiroPow_hash256 header_hash,
        ref FiroPow_hash256 mix_hash, ulong nonce, ref FiroPow_hash256 boundary);

    /// <summary>
    /// FiroPow light verification for pool mining
    /// </summary>
    [DllImport("libfiropow", EntryPoint = "firopow_light_verify", CallingConvention = CallingConvention.Cdecl)]
    private static extern bool LightVerify(IntPtr light_context, int block_number, ref FiroPow_hash256 header_hash,
        ref FiroPow_hash256 mix_hash, ulong nonce, ref FiroPow_hash256 boundary);

    #endregion

    #region Data Structures

    /// <summary>
    /// FiroPow 256-bit hash structure
    /// </summary>
    [StructLayout(LayoutKind.Explicit)]
    private struct FiroPow_hash256
    {
        [FieldOffset(0)]
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 32)]
        public byte[] bytes;

        [FieldOffset(0)]
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = 8)]
        public uint[] word32s;
    }

    /// <summary>
    /// FiroPow hash result structure
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    private struct FiroPow_result
    {
        public FiroPow_hash256 final_hash;
        public FiroPow_hash256 mix_hash;
    }

    /// <summary>
    /// FiroPow epoch context handle
    /// </summary>
    public struct EpochContext : IDisposable
    {
        private IntPtr _handle;
        private bool _disposed;

        public EpochContext(int epochNumber)
        {
            _handle = CreateEpochContext(epochNumber);
            _disposed = false;
        }

        public IntPtr Handle => _handle;
        public bool IsValid => _handle != IntPtr.Zero && !_disposed;

        public void Dispose()
        {
            if (!_disposed && _handle != IntPtr.Zero)
            {
                DestroyEpochContext(_handle);
                _handle = IntPtr.Zero;
                _disposed = true;
            }
        }
    }

    #endregion

    #region Public API

    /// <summary>
    /// Calculate FiroPow hash for mining
    /// </summary>
    /// <param name="epochNumber">Current epoch number for DAG selection</param>
    /// <param name="blockNumber">Block number for ProgPow period calculation</param>
    /// <param name="headerHash">80-byte block header hash</param>
    /// <param name="nonce">Mining nonce value</param>
    /// <returns>Tuple of (final_hash, mix_hash)</returns>
    public static (byte[] finalHash, byte[] mixHash) ComputeHash(int epochNumber, int blockNumber, 
        ReadOnlySpan<byte> headerHash, ulong nonce)
    {
        if (headerHash.Length != 32)
            throw new ArgumentException("Header hash must be exactly 32 bytes", nameof(headerHash));

        using var context = new EpochContext(epochNumber);
        if (!context.IsValid)
            throw new InvalidOperationException("Failed to create FiroPow epoch context");

        var headerStruct = new FiroPow_hash256 { bytes = headerHash.ToArray() };
        var result = Hash(context.Handle, blockNumber, ref headerStruct, nonce);

        return (result.final_hash.bytes, result.mix_hash.bytes);
    }

    /// <summary>
    /// Verify FiroPow hash against difficulty target
    /// </summary>
    /// <param name="epochNumber">Current epoch number</param>
    /// <param name="blockNumber">Block number</param>
    /// <param name="headerHash">Block header hash</param>
    /// <param name="mixHash">ProgPow mix hash</param>
    /// <param name="nonce">Mining nonce</param>
    /// <param name="boundary">Difficulty boundary (target)</param>
    /// <returns>True if hash meets difficulty requirement</returns>
    public static bool VerifyHash(int epochNumber, int blockNumber, ReadOnlySpan<byte> headerHash,
        ReadOnlySpan<byte> mixHash, ulong nonce, ReadOnlySpan<byte> boundary)
    {
        if (headerHash.Length != 32 || mixHash.Length != 32 || boundary.Length != 32)
            throw new ArgumentException("All hash parameters must be exactly 32 bytes");

        using var context = new EpochContext(epochNumber);
        if (!context.IsValid)
            return false;

        var headerStruct = new FiroPow_hash256 { bytes = headerHash.ToArray() };
        var mixStruct = new FiroPow_hash256 { bytes = mixHash.ToArray() };
        var boundaryStruct = new FiroPow_hash256 { bytes = boundary.ToArray() };

        return Verify(context.Handle, blockNumber, ref headerStruct, ref mixStruct, nonce, ref boundaryStruct);
    }

    /// <summary>
    /// Get epoch number from block number
    /// FiroPow uses different epoch calculation than Ethereum
    /// </summary>
    /// <param name="blockNumber">Block number</param>
    /// <returns>Epoch number</returns>
    public static int GetEpochNumber(int blockNumber)
    {
        // FiroPow epoch length - may differ from Ethereum's 30000 blocks
        const int epochLength = 7500; // Adjusted for faster epoch transitions
        return blockNumber / epochLength;
    }

    /// <summary>
    /// Get ProgPow period from block number
    /// </summary>
    /// <param name="blockNumber">Block number</param>
    /// <returns>ProgPow period for algorithm variation</returns>
    public static int GetProgPowPeriod(int blockNumber)
    {
        return blockNumber / PeriodLength;
    }

    #endregion
}
