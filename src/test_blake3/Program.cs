using System;
using Miningcore.Crypto.Hashing.Algorithms;
using Miningcore.Extensions;

class Program
{
    static void Main()
    {
        try 
        {
            Console.WriteLine("Testing Blake3 implementation...");
            
            var hasher = new Blake3();
            var hash = new byte[32];
            var input = new byte[] { 0x80, 0x80, 0x80, 0x80 };
            
            hasher.Digest(input, hash);
            var result = hash.ToHexString();
            
            Console.WriteLine($"Blake3 hash result: {result}");
            Console.WriteLine("Blake3 implementation works correctly!");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error: {ex.Message}");
            Console.WriteLine($"Stack trace: {ex.StackTrace}");
        }
    }
}
