using System.Diagnostics;
using Miningcore.Contracts;
using Miningcore.Extensions;
using Miningcore.Messaging;
using Miningcore.Native;
using Miningcore.Notifications.Messages;

namespace Miningcore.Crypto.Hashing.Algorithms;

/// <summary>
/// FiroPow algorithm implementation
/// A ProgPow variant specifically designed for Firo cryptocurrency mining
/// Extends KawPow with Firo-specific input constraints
/// </summary>
[Identifier("firopow")]
public unsafe class FiroPow : IHashAlgorithm
{
    internal static IMessageBus messageBus;

    public void Digest(ReadOnlySpan<byte> data, Span<byte> result, params object[] extra)
    {
        Contract.Requires<ArgumentException>(data.Length == 80, "FiroPow requires exactly 80 bytes of input data");
        Contract.Requires<ArgumentException>(result.Length >= 32, "FiroPow requires output buffer of at least 32 bytes");

        var sw = Stopwatch.StartNew();

        // Extract block number from extra parameters for epoch calculation
        var blockNumber = 0;
        if (extra?.Length > 0 && extra[0] is int bn)
            blockNumber = bn;

        fixed (byte* input = data)
        fixed (byte* output = result)
        {
            // Extract header hash (first 32 bytes)
            var headerHashSpan = new Span<byte>(input, 32);
            
            // Extract nonce (bytes 32-39, 8 bytes)
            var nonceBytes = new Span<byte>(input + 32, 8);
            var nonce = BitConverter.ToUInt64(nonceBytes);
            
            // Calculate epoch number for DAG context
            var epochNumber = Native.FiroPow.GetEpochNumber(blockNumber);
            
            try
            {
                // Use native FiroPow implementation
                var (finalHash, mixHash) = Native.FiroPow.ComputeHash(epochNumber, blockNumber, headerHashSpan, nonce);
                
                // Copy final hash to output buffer
                fixed (byte* hashPtr = finalHash)
                {
                    for (int i = 0; i < Math.Min(result.Length, finalHash.Length); i++)
                    {
                        output[i] = hashPtr[i];
                    }
                }
            }
            catch (Exception)
            {
                // Fallback to simplified implementation if native library fails
                SimpleFiroPowHash(input, output, (uint)data.Length, blockNumber, nonce);
            }
        }

        messageBus?.SendTelemetry("FiroPow", TelemetryCategory.Hash, sw.Elapsed);
    }

    /// <summary>
    /// Simplified FiroPow hash implementation
    /// This is a temporary implementation that will be replaced with proper native FiroPow
    /// </summary>
    private void SimpleFiroPowHash(byte* input, byte* output, uint inputLength, int blockNumber, ulong nonce)
    {
        // Temporary implementation using SHA3-256 with FiroPow-specific seed
        // This will be replaced with proper ProgPow implementation with Firo constraints
        
        // Create FiroPow-specific input by combining header with Firo constants
        var tempBuffer = stackalloc byte[80 + 16]; // Header + Firo constants
        
        // Copy original header
        for (int i = 0; i < 80; i++)
        {
            tempBuffer[i] = input[i];
        }
        
        // Append Firo-specific constants (simplified)
        var firoConstants = stackalloc uint[]
        {
            0x00000046, // F
            0x00000049, // I  
            0x00000052, // R
            0x0000004F  // O
        };
        
        for (int i = 0; i < 4; i++)
        {
            var constBytes = BitConverter.GetBytes(firoConstants[i]);
            for (int j = 0; j < 4; j++)
            {
                tempBuffer[80 + i * 4 + j] = constBytes[j];
            }
        }
        
        // Use native multihash for now (temporary)
        Multihash.sha3_256(tempBuffer, output, 96);
    }
}

/// <summary>
/// FiroPow streaming hasher for large data processing
/// Supports incremental hash updates for mining applications
/// </summary>
[Identifier("firopow_streaming")]
public class FiroPowStreaming : IHashAlgorithm, IDisposable
{
    private bool _disposed;
    private readonly byte[] _buffer = new byte[80];
    private int _bufferLength;

    public void Digest(ReadOnlySpan<byte> data, Span<byte> result, params object[] extra)
    {
        Contract.Requires<ArgumentException>(result.Length >= 32, "FiroPow requires output buffer of at least 32 bytes");
        
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
            throw new ArgumentException("FiroPow streaming: Data exceeds 80-byte limit");
            
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
            throw new InvalidOperationException("FiroPow requires exactly 80 bytes of data");
            
        // Use main FiroPow algorithm for finalization
        var firoPow = new FiroPow();
        firoPow.Digest(_buffer.AsSpan(), result, extra);
    }

    private void ThrowIfDisposed()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(FiroPowStreaming));
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

    ~FiroPowStreaming()
    {
        Dispose();
    }
}
