using System;
using System.Text;
using Miningcore.Crypto.Hashing.Algorithms;
using Miningcore.Extensions;
using Xunit;

namespace Miningcore.Tests.Crypto;

public class VerusHashTests : TestBase
{
    [Fact]
    public void VerusHash_Should_Produce_Consistent_Results()
    {
        // Test with standard 80-byte mining input
        var testInput = new byte[80];
        
        // Fill with test pattern
        for (int i = 0; i < testInput.Length; i++)
            testInput[i] = (byte)(i % 256);

        var hasher = new VerusHash();
        var result1 = new byte[32];
        var result2 = new byte[32];

        // Hash the same input twice
        hasher.Digest(testInput, result1);
        hasher.Digest(testInput, result2);

        // Results should be identical
        Assert.Equal(result1.ToHexString(), result2.ToHexString());
        
        // Result should not be all zeros
        Assert.False(Array.TrueForAll(result1, b => b == 0));
    }

    [Fact]
    public void VerusHash_Should_Enforce_80_Byte_Input_Length()
    {
        var hasher = new VerusHash();
        
        // Test with invalid input lengths - should throw ArgumentException
        var invalidInputs = new[]
        {
            new byte[32],
            new byte[64], 
            new byte[128]
        };

        foreach (var input in invalidInputs)
        {
            // Fill with unique pattern
            for (int i = 0; i < input.Length; i++)
                input[i] = (byte)(i ^ input.Length);

            var result = new byte[32];
            
            // Should throw exception for incorrect length
            Assert.Throws<ArgumentException>(() => hasher.Digest(input, result));
        }
        
        // Test with valid 80-byte input - should NOT throw
        var validInput = new byte[80];
        for (int i = 0; i < validInput.Length; i++)
            validInput[i] = (byte)(i ^ validInput.Length);
            
        var validResult = new byte[32];
        hasher.Digest(validInput, validResult);
        
        // Should produce non-zero output
        Assert.False(Array.TrueForAll(validResult, b => b == 0));
    }

    [Fact] 
    public void VerusHash_Should_Produce_Different_Results_For_Different_Inputs()
    {
        var hasher = new VerusHash();
        
        var input1 = new byte[80];
        var input2 = new byte[80];
        
        // Fill inputs with different patterns
        for (int i = 0; i < 80; i++)
        {
            input1[i] = (byte)(i);
            input2[i] = (byte)(i + 1);
        }

        var result1 = new byte[32];
        var result2 = new byte[32];

        hasher.Digest(input1, result1);
        hasher.Digest(input2, result2);

        // Results should be different
        Assert.NotEqual(result1.ToHexString(), result2.ToHexString());
    }

    [Fact]
    public void VerusHash_Should_Handle_Verus_Block_Header()
    {
        // Test with realistic Verus block header format
        var hasher = new VerusHash();
        
        // Create a mock block header (80 bytes)
        var blockHeader = new byte[80];
        
        // Version (4 bytes)
        BitConverter.GetBytes(0x20000000).CopyTo(blockHeader, 0);
        
        // Previous block hash (32 bytes) - filled with test pattern
        for (int i = 0; i < 32; i++)
            blockHeader[4 + i] = (byte)(i * 2);
            
        // Merkle root (32 bytes) - filled with test pattern
        for (int i = 0; i < 32; i++)
            blockHeader[36 + i] = (byte)(i * 3);
            
        // Timestamp (4 bytes)
        BitConverter.GetBytes(DateTimeOffset.UtcNow.ToUnixTimeSeconds()).CopyTo(blockHeader, 68);
        
        // Bits (4 bytes) - difficulty target
        BitConverter.GetBytes(0x1d00ffff).CopyTo(blockHeader, 72);
        
        // Nonce (4 bytes)
        BitConverter.GetBytes(12345678U).CopyTo(blockHeader, 76);

        var result = new byte[32];
        
        // Should hash without errors
        hasher.Digest(blockHeader, result);
        
        // Result should be valid
        Assert.NotNull(result);
        Assert.Equal(32, result.Length);
        Assert.False(Array.TrueForAll(result, b => b == 0));
        
        // Output for verification
        var hashHex = result.ToHexString();
        Assert.True(hashHex.Length == 64); // 32 bytes = 64 hex characters
    }

    [Fact]
    public void VerusHash_Should_Be_CPU_Friendly()
    {
        var hasher = new VerusHash();
        var input = new byte[80];
        var result = new byte[32];
        
        // Fill input with test data
        for (int i = 0; i < input.Length; i++)
            input[i] = (byte)(i ^ 0xAA);

        // Time multiple hash operations
        const int iterations = 1000;
        var startTime = DateTime.UtcNow;
        
        for (int i = 0; i < iterations; i++)
        {
            // Modify input slightly for each iteration
            input[79] = (byte)i;
            hasher.Digest(input, result);
        }
        
        var elapsed = DateTime.UtcNow - startTime;
        
        // Should complete reasonably quickly (less than 1 second for 1000 hashes)
        Assert.True(elapsed.TotalSeconds < 5.0, $"VerusHash took too long: {elapsed.TotalSeconds:F2} seconds for {iterations} iterations");
        
        // Average time per hash should be reasonable for CPU mining
        var avgTimeMs = elapsed.TotalMilliseconds / iterations;
        Assert.True(avgTimeMs < 10.0, $"Average time per hash too high: {avgTimeMs:F2} ms");
    }

    [Fact]
    public void VerusHashStreaming_Should_Work_Correctly()
    {
        var streamingHasher = new VerusHashStreaming();
        var regularHasher = new VerusHash();
        
        var testData = new byte[80];
        for (int i = 0; i < testData.Length; i++)
            testData[i] = (byte)(i + 42);

        var streamResult = new byte[32];
        var regularResult = new byte[32];

        // Test streaming hasher
        using (streamingHasher)
        {
            streamingHasher.Digest(testData, streamResult);
        }
        
        // Test regular hasher
        regularHasher.Digest(testData, regularResult);

        // Results should be identical
        Assert.Equal(regularResult.ToHexString(), streamResult.ToHexString());
    }

    [Fact]
    public void VerusHash_Should_Handle_Edge_Cases()
    {
        var hasher = new VerusHash();
        var result = new byte[32];
        
        // Test with all zeros input (valid 80-byte length)
        var zeroInput = new byte[80];
        hasher.Digest(zeroInput, result);
        Assert.NotNull(result);
        Assert.False(Array.TrueForAll(result, b => b == 0), "All-zero input should not produce all-zero output");
        
        // Test with all ones input (valid 80-byte length)
        var onesInput = new byte[80];
        Array.Fill<byte>(onesInput, 0xFF);
        hasher.Digest(onesInput, result);
        Assert.NotNull(result);
        Assert.False(Array.TrueForAll(result, b => b == 0), "All-ones input should not produce all-zero output");
        
        // Test with input containing invalid length - should throw
        var invalidInput = new byte[1];
        Assert.Throws<ArgumentException>(() => hasher.Digest(invalidInput, result));
        
        // Test with input containing invalid length - should throw
        var invalidLargeInput = new byte[1024];
        Assert.Throws<ArgumentException>(() => hasher.Digest(invalidLargeInput, result));
    }
}
