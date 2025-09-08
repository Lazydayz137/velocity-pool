using Miningcore.Contracts;
using System;

namespace Miningcore.Crypto.Hashing.Algorithms
{
    [Identifier("firopow")]
    public class FiroPow : IHashAlgorithm
    {
        public void Digest(ReadOnlySpan<byte> data, Span<byte> result, params object[] extra)
        {
            // The actual hashing is done in the native library, this is just a placeholder
            // for the dependency injection container.
            // The real logic is in FiroJob.cs, which calls the native libfiropow.
            throw new NotImplementedException();
        }
    }
}
