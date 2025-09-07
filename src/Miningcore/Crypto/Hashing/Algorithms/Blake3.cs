using Miningcore.Contracts;
using Miningcore.Native;

namespace Miningcore.Crypto.Hashing.Algorithms;

/// <summary>
/// Blake3 cryptographic hash function implementation
/// High-performance, secure, and fast hash algorithm suitable for mining
/// </summary>
[Identifier("blake3")]
public unsafe class Blake3 : IHashAlgorithm
{
    public void Digest(ReadOnlySpan<byte> data, Span<byte> result, params object[] extra)
    {
        Contract.Requires<ArgumentException>(result.Length >= Native.Blake3.OutputLength, 
            $"Blake3 requires output buffer of at least {Native.Blake3.OutputLength} bytes");

        fixed (byte* input = data)
        fixed (byte* output = result)
        {
            if (result.Length == Native.Blake3.OutputLength)
            {
                // Standard 32-byte output
                Native.Blake3.Hash(input, (uint)data.Length, output);
            }
            else
            {
                // Custom length output
                Native.Blake3.HashCustomLength(input, (uint)data.Length, output, (uint)result.Length);
            }
        }
    }

    /// <summary>
    /// Blake3 keyed hash variant
    /// </summary>
    /// <param name="data">Input data to hash</param>
    /// <param name="key">32-byte key for keyed hashing</param>
    /// <param name="result">Output buffer (minimum 32 bytes)</param>
    public void DigestKeyed(ReadOnlySpan<byte> data, ReadOnlySpan<byte> key, Span<byte> result)
    {
        Contract.Requires<ArgumentException>(key.Length == 32, "Blake3 keyed hash requires exactly 32-byte key");
        Contract.Requires<ArgumentException>(result.Length >= Native.Blake3.OutputLength, 
            $"Blake3 requires output buffer of at least {Native.Blake3.OutputLength} bytes");

        fixed (byte* keyPtr = key)
        fixed (byte* input = data)
        fixed (byte* output = result)
        {
            Native.Blake3.HashKeyed(keyPtr, input, (uint)data.Length, output);
        }
    }
}

/// <summary>
/// Blake3 streaming hasher for large data processing
/// Ideal for mining applications requiring incremental hash updates
/// </summary>
[Identifier("blake3_streaming")]
public class Blake3Streaming : IHashAlgorithm, IDisposable
{
    private Blake3Hasher _hasher;
    private bool _disposed;

    public Blake3Streaming()
    {
        _hasher = new Blake3Hasher();
    }

    public void Digest(ReadOnlySpan<byte> data, Span<byte> result, params object[] extra)
    {
        Contract.Requires<ArgumentException>(result.Length >= Native.Blake3.OutputLength, 
            $"Blake3 requires output buffer of at least {Native.Blake3.OutputLength} bytes");

        ThrowIfDisposed();

        // Reset hasher for fresh computation
        Dispose();
        _hasher = new Blake3Hasher();
        
        _hasher.Update(data);
        _hasher.Finalize(result);
    }

    /// <summary>
    /// Update the hasher with additional data
    /// </summary>
    public void Update(ReadOnlySpan<byte> data)
    {
        ThrowIfDisposed();
        _hasher.Update(data);
    }

    /// <summary>
    /// Finalize the hash and get the result
    /// </summary>
    public byte[] Finalize(int outputLength = Native.Blake3.OutputLength)
    {
        ThrowIfDisposed();
        return _hasher.Finalize(outputLength);
    }

    /// <summary>
    /// Finalize the hash into the provided buffer
    /// </summary>
    public void Finalize(Span<byte> result)
    {
        ThrowIfDisposed();
        _hasher.Finalize(result);
    }

    private void ThrowIfDisposed()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(Blake3Streaming));
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            _hasher?.Dispose();
            _hasher = null;
            _disposed = true;
        }
        GC.SuppressFinalize(this);
    }

    ~Blake3Streaming()
    {
        Dispose();
    }
}
