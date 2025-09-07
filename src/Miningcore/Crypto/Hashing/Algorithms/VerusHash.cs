using System.Diagnostics;
using Miningcore.Contracts;
using Miningcore.Extensions;
using Miningcore.Messaging;
using Miningcore.Native;
using Miningcore.Notifications.Messages;

namespace Miningcore.Crypto.Hashing.Algorithms;

/// <summary>
/// VerusHash algorithm implementation
/// A CPU-optimized PoW algorithm used by Verus coin
/// Combines multiple hash functions with CPU-friendly operations
/// </summary>
[Identifier("verushash")]
public unsafe class VerusHash : IHashAlgorithm
{
    internal static IMessageBus messageBus;

    public void Digest(ReadOnlySpan<byte> data, Span<byte> result, params object[] extra)
    {
        Contract.Requires<ArgumentException>(data.Length == 80, "VerusHash requires exactly 80 bytes of input data");
        Contract.Requires<ArgumentException>(result.Length >= 32, "VerusHash requires output buffer of at least 32 bytes");

        var sw = Stopwatch.StartNew();

        fixed (byte* input = data)
        fixed (byte* output = result)
        {
            // Use our optimized native VerusHash implementation
            Native.VerusHash.Hash(input, output, (uint)data.Length);
        }

        messageBus?.SendTelemetry("VerusHash", TelemetryCategory.Hash, sw.Elapsed);
    }

}

/// <summary>
/// VerusHash streaming hasher for large data processing
/// </summary>
[Identifier("verushash_streaming")]
public class VerusHashStreaming : IHashAlgorithm, IDisposable
{
    private bool _disposed;
    private readonly byte[] _buffer = new byte[80];
    private int _bufferLength;

    public void Digest(ReadOnlySpan<byte> data, Span<byte> result, params object[] extra)
    {
        Contract.Requires<ArgumentException>(result.Length >= 32, "VerusHash requires output buffer of at least 32 bytes");
        
        ThrowIfDisposed();

        // Reset for fresh computation
        _bufferLength = 0;
        
        // Process data through streaming interface
        Update(data);
        Finalize(result, extra);
    }

    /// <summary>
    /// Update the hasher with additional data
    /// </summary>
    public void Update(ReadOnlySpan<byte> data)
    {
        ThrowIfDisposed();
        
        if (_bufferLength + data.Length > _buffer.Length)
            throw new ArgumentException("VerusHash streaming: Data exceeds 80-byte limit");
            
        data.CopyTo(new Span<byte>(_buffer, _bufferLength, data.Length));
        _bufferLength += data.Length;
    }

    /// <summary>
    /// Finalize the hash and write result to output buffer
    /// </summary>
    public void Finalize(Span<byte> result, params object[] extra)
    {
        ThrowIfDisposed();
        
        if (_bufferLength != 80)
            throw new InvalidOperationException("VerusHash requires exactly 80 bytes of data");
            
        // Use main VerusHash algorithm for finalization
        var verusHash = new VerusHash();
        verusHash.Digest(_buffer.AsSpan(), result, extra);
    }

    private void ThrowIfDisposed()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(VerusHashStreaming));
    }

    public void Dispose()
    {
        if (!_disposed)
        {
            // Clear sensitive data
            Array.Clear(_buffer, 0, _buffer.Length);
            _disposed = true;
        }
        GC.SuppressFinalize(this);
    }

    ~VerusHashStreaming()
    {
        Dispose();
    }
}
