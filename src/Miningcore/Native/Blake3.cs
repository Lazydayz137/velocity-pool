using System.Runtime.InteropServices;

namespace Miningcore.Native;

public static unsafe class Blake3
{
    // Blake3 standard output length (32 bytes)
    public const int OutputLength = 32;

    [DllImport("libblake3", EntryPoint = "blake3_hash_simple", CallingConvention = CallingConvention.Cdecl)]
    public static extern void Hash(byte* input, uint inputLength, byte* output);

    [DllImport("libblake3", EntryPoint = "blake3_hash_custom_length", CallingConvention = CallingConvention.Cdecl)]
    public static extern void HashCustomLength(byte* input, uint inputLength, byte* output, uint outputLength);

    [DllImport("libblake3", EntryPoint = "blake3_hash_keyed", CallingConvention = CallingConvention.Cdecl)]
    public static extern void HashKeyed(byte* key, byte* input, uint inputLength, byte* output);

    [DllImport("libblake3", EntryPoint = "blake3_get_output_length", CallingConvention = CallingConvention.Cdecl)]
    public static extern int GetOutputLength();

    // Streaming interface for large data
    [DllImport("libblake3", EntryPoint = "blake3_create_hasher", CallingConvention = CallingConvention.Cdecl)]
    public static extern void* CreateHasher();

    [DllImport("libblake3", EntryPoint = "blake3_update_hasher", CallingConvention = CallingConvention.Cdecl)]
    public static extern void UpdateHasher(void* hasher, byte* input, uint inputLength);

    [DllImport("libblake3", EntryPoint = "blake3_finalize_hasher", CallingConvention = CallingConvention.Cdecl)]
    public static extern void FinalizeHasher(void* hasher, byte* output, uint outputLength);

    [DllImport("libblake3", EntryPoint = "blake3_destroy_hasher", CallingConvention = CallingConvention.Cdecl)]
    public static extern void DestroyHasher(void* hasher);
}

/// <summary>
/// Safe managed wrapper for Blake3 streaming hasher
/// </summary>
public class Blake3Hasher : IDisposable
{
    private unsafe void* _hasher;
    private bool _disposed;

    public unsafe Blake3Hasher()
    {
        _hasher = Blake3.CreateHasher();
        if (_hasher == null)
            throw new OutOfMemoryException("Failed to create Blake3 hasher");
    }

    public unsafe void Update(ReadOnlySpan<byte> data)
    {
        ThrowIfDisposed();
        if (data.IsEmpty) return;

        fixed (byte* dataPtr = data)
        {
            Blake3.UpdateHasher(_hasher, dataPtr, (uint)data.Length);
        }
    }

    public unsafe void Update(byte[] data, int offset = 0, int count = -1)
    {
        if (count == -1) count = data.Length - offset;
        Update(new ReadOnlySpan<byte>(data, offset, count));
    }

    public unsafe void Finalize(Span<byte> output)
    {
        ThrowIfDisposed();
        if (output.Length < Blake3.OutputLength)
            throw new ArgumentException($"Output buffer must be at least {Blake3.OutputLength} bytes");

        fixed (byte* outputPtr = output)
        {
            Blake3.FinalizeHasher(_hasher, outputPtr, (uint)output.Length);
        }
    }

    public unsafe byte[] Finalize(int outputLength = Blake3.OutputLength)
    {
        var result = new byte[outputLength];
        Finalize(result);
        return result;
    }

    private void ThrowIfDisposed()
    {
        if (_disposed)
            throw new ObjectDisposedException(nameof(Blake3Hasher));
    }

    public unsafe void Dispose()
    {
        if (!_disposed && _hasher != null)
        {
            Blake3.DestroyHasher(_hasher);
            _hasher = null;
            _disposed = true;
        }
        GC.SuppressFinalize(this);
    }

    ~Blake3Hasher()
    {
        Dispose();
    }
}
