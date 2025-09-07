using System.Runtime.InteropServices;

namespace Miningcore.Native;

public static unsafe class VerusHash
{
    /// <summary>
    /// VerusHash 2.2 native hashing function
    /// </summary>
    /// <param name="input">Input data pointer</param>
    /// <param name="output">Output hash buffer pointer</param>
    /// <param name="inputLength">Length of input data</param>
    [DllImport("libverushash", EntryPoint = "verushash_hash", CallingConvention = CallingConvention.Cdecl)]
    public static extern void Hash(byte* input, byte* output, uint inputLength);

    /// <summary>
    /// Get VerusHash library version
    /// </summary>
    /// <returns>Version string</returns>
    [DllImport("libverushash", EntryPoint = "verushash_get_version", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr GetVersion();

    /// <summary>
    /// Initialize VerusHash context for streaming operations
    /// </summary>
    /// <returns>Context pointer</returns>
    [DllImport("libverushash", EntryPoint = "verushash_create_context", CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr CreateContext();

    /// <summary>
    /// Destroy VerusHash context
    /// </summary>
    /// <param name="context">Context pointer to destroy</param>
    [DllImport("libverushash", EntryPoint = "verushash_destroy_context", CallingConvention = CallingConvention.Cdecl)]
    public static extern void DestroyContext(IntPtr context);

    /// <summary>
    /// Update VerusHash context with data
    /// </summary>
    /// <param name="context">Context pointer</param>
    /// <param name="data">Data to hash</param>
    /// <param name="length">Data length</param>
    [DllImport("libverushash", EntryPoint = "verushash_update", CallingConvention = CallingConvention.Cdecl)]
    public static extern void Update(IntPtr context, byte* data, uint length);

    /// <summary>
    /// Finalize VerusHash context and get result
    /// </summary>
    /// <param name="context">Context pointer</param>
    /// <param name="output">Output buffer</param>
    [DllImport("libverushash", EntryPoint = "verushash_finalize", CallingConvention = CallingConvention.Cdecl)]
    public static extern void Finalize(IntPtr context, byte* output);

    /// <summary>
    /// Haraka512 function used in VerusHash
    /// </summary>
    /// <param name="input">Input data (64 bytes)</param>
    /// <param name="output">Output hash (32 bytes)</param>
    [DllImport("libverushash", EntryPoint = "haraka512", CallingConvention = CallingConvention.Cdecl)]
    public static extern void Haraka512(byte* input, byte* output);

    /// <summary>
    /// Test if CPU supports AES-NI (required for optimal VerusHash performance)
    /// </summary>
    /// <returns>True if AES-NI is supported</returns>
    [DllImport("libverushash", EntryPoint = "verushash_has_aes_ni", CallingConvention = CallingConvention.Cdecl)]
    public static extern bool HasAesNi();

    /// <summary>
    /// Test if CPU supports AVX2 (improves VerusHash performance)
    /// </summary>
    /// <returns>True if AVX2 is supported</returns>
    [DllImport("libverushash", EntryPoint = "verushash_has_avx2", CallingConvention = CallingConvention.Cdecl)]
    public static extern bool HasAvx2();

    /// <summary>
    /// Get optimal thread count for VerusHash mining on current system
    /// </summary>
    /// <returns>Recommended thread count</returns>
    [DllImport("libverushash", EntryPoint = "verushash_optimal_threads", CallingConvention = CallingConvention.Cdecl)]
    public static extern int GetOptimalThreads();
}

/// <summary>
/// Managed wrapper for VerusHash operations with proper resource management
/// </summary>
public sealed class VerusHashContext : IDisposable
{
    private IntPtr _context;
    private bool _disposed;

    public VerusHashContext()
    {
        _context = VerusHash.CreateContext();
        if (_context == IntPtr.Zero)
            throw new OutOfMemoryException("Failed to create VerusHash context");
    }

    public unsafe void Update(ReadOnlySpan<byte> data)
    {
        ThrowIfDisposed();
        
        fixed (byte* dataPtr = data)
        {
            VerusHash.Update(_context, dataPtr, (uint)data.Length);
        }
    }

    public unsafe void Finalize(Span<byte> output)
    {
        ThrowIfDisposed();
        
        if (output.Length < 32)
            throw new ArgumentException("Output buffer must be at least 32 bytes");

        fixed (byte* outputPtr = output)
        {
            VerusHash.Finalize(_context, outputPtr);
        }
    }

    public unsafe byte[] ComputeHash(ReadOnlySpan<byte> data)
    {
        var result = new byte[32];
        
        fixed (byte* input = data)
        fixed (byte* output = result)
        {
            VerusHash.Hash(input, output, (uint)data.Length);
        }
        
        return result;
    }

    private void ThrowIfDisposed()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(VerusHashContext));
    }

    public void Dispose()
    {
        if (!_disposed && _context != IntPtr.Zero)
        {
            VerusHash.DestroyContext(_context);
            _context = IntPtr.Zero;
            _disposed = true;
        }
        GC.SuppressFinalize(this);
    }

    ~VerusHashContext()
    {
        Dispose();
    }
}
