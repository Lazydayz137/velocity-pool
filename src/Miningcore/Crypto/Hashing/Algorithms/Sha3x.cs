using Miningcore.Contracts;
using Miningcore.Native;

namespace Miningcore.Crypto.Hashing.Algorithms;

[Identifier("sha3x")]
public unsafe class Sha3x : IHashAlgorithm
{
    public void Digest(ReadOnlySpan<byte> data, Span<byte> result, params object[] extra)
    {
        Contract.Requires<ArgumentException>(result.Length >= 32);

        // Tari's SHA3x algorithm is a triple hash of SHA3-256
        // First hash
        Span<byte> hash1 = stackalloc byte[32];
        fixed (byte* input = data)
        {
            fixed (byte* output = hash1)
            {
                Multihash.sha3_256(input, output, (uint)data.Length);
            }
        }

        // Second hash
        Span<byte> hash2 = stackalloc byte[32];
        fixed (byte* input = hash1)
        {
            fixed (byte* output = hash2)
            {
                Multihash.sha3_256(input, output, 32);
            }
        }

        // Third hash (final result)
        fixed (byte* input = hash2)
        {
            fixed (byte* output = result)
            {
                Multihash.sha3_256(input, output, 32);
            }
        }
    }
}
