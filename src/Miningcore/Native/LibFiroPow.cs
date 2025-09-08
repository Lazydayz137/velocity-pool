using System;
using System.Runtime.InteropServices;

namespace Miningcore.Native
{
    public static class LibFiroPow
    {
        [DllImport("libfiropow", EntryPoint = "firopow_verify", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool Verify(
            [In] byte[] header_hash,
            ulong nonce,
            uint height,
            [In] byte[] mix_hash,
            [Out] byte[] hash_return);
    }
}
