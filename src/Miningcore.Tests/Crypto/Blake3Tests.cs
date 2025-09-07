using System;
using System.Linq;
using System.Text;
using Miningcore.Crypto.Hashing.Algorithms;
using Miningcore.Extensions;
using Miningcore.Tests.Util;
using Xunit;

namespace Miningcore.Tests.Crypto;

public class Blake3Tests : TestBase
{
    private static readonly byte[] testValue = Enumerable.Repeat((byte) 0x80, 32).ToArray();
    private static readonly byte[] testValue2 = Enumerable.Repeat((byte) 0x80, 80).ToArray();

    [Fact]
    public void Blake3_Hash_Empty_Input()
    {
        var hasher = new Blake3();
        var hash = new byte[32];
        hasher.Digest(Array.Empty<byte>(), hash);
        var result = hash.ToHexString();

        // Blake3 of empty input should match reference implementation
        Assert.Equal("af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262", result);
    }

    [Fact]
    public void Blake3_Hash_Standard_32_Bytes()
    {
        var hasher = new Blake3();
        var hash = new byte[32];
        hasher.Digest(testValue, hash);
        var result = hash.ToHexString();

        // This should produce a consistent hash for 32 bytes of 0x80
        Assert.NotEmpty(result);
        Assert.Equal(64, result.Length); // 32 bytes = 64 hex chars
    }

    [Fact]
    public void Blake3_Hash_Mining_Header_80_Bytes()
    {
        var hasher = new Blake3();
        var hash = new byte[32];
        hasher.Digest(testValue2, hash);
        var result = hash.ToHexString();

        // Mining headers are typically 80 bytes
        Assert.NotEmpty(result);
        Assert.Equal(64, result.Length);
    }

    [Fact]
    public void Blake3_Hash_Custom_Length_64_Bytes()
    {
        var hasher = new Blake3();
        var hash = new byte[64]; // Custom longer output
        hasher.Digest(testValue, hash);
        var result = hash.ToHexString();

        Assert.NotEmpty(result);
        Assert.Equal(128, result.Length); // 64 bytes = 128 hex chars
    }

    [Fact]
    public void Blake3_Hash_Custom_Length_16_Bytes()
    {
        var hasher = new Blake3();
        var hash = new byte[16]; // Custom shorter output
        hasher.Digest(testValue, hash);
        var result = hash.ToHexString();

        Assert.NotEmpty(result);
        Assert.Equal(32, result.Length); // 16 bytes = 32 hex chars
    }

    [Fact]
    public void Blake3_Hash_Known_Test_Vector()
    {
        var hasher = new Blake3();
        var hash = new byte[32];
        var input = Encoding.UTF8.GetBytes("abc");
        hasher.Digest(input, hash);
        var result = hash.ToHexString();

        // Known Blake3 test vector for "abc"
        Assert.Equal("6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85", result);
    }

    [Fact]
    public void Blake3_Hash_Keyed_Variant()
    {
        var hasher = new Blake3();
        var key = new byte[32];
        for(int i = 0; i < 32; i++) key[i] = (byte)i;
        
        var input = Encoding.UTF8.GetBytes("test data");
        var hash = new byte[32];
        
        hasher.DigestKeyed(input, key, hash);
        var result = hash.ToHexString();
        
        Assert.NotEmpty(result);
        Assert.Equal(64, result.Length);
    }

    [Fact]
    public void Blake3_Hash_Should_Throw_On_Invalid_Output_Buffer()
    {
        var hasher = new Blake3();
        var hash = new byte[16]; // Too small for standard Blake3 (32 bytes minimum in our implementation)
        
        Assert.Throws<ArgumentException>(() => hasher.Digest(testValue, hash));
    }

    [Fact]
    public void Blake3_Keyed_Should_Throw_On_Invalid_Key_Size()
    {
        var hasher = new Blake3();
        var key = new byte[16]; // Wrong key size (needs 32 bytes)
        var input = Encoding.UTF8.GetBytes("test");
        var hash = new byte[32];
        
        Assert.Throws<ArgumentException>(() => hasher.DigestKeyed(input, key, hash));
    }

    [Fact]
    public void Blake3_Streaming_Hash()
    {
        var hasher = new Blake3Streaming();
        var hash = new byte[32];
        hasher.Digest(testValue, hash);
        var result = hash.ToHexString();

        Assert.NotEmpty(result);
        Assert.Equal(64, result.Length);
        
        hasher.Dispose();
    }

    [Fact]
    public void Blake3_Streaming_Incremental_Update()
    {
        var hasher = new Blake3Streaming();
        
        // Update in chunks
        hasher.Update(testValue.AsSpan(0, 16));
        hasher.Update(testValue.AsSpan(16, 16));
        
        var result1 = hasher.Finalize();
        
        // Compare with single digest
        var hasher2 = new Blake3();
        var hash2 = new byte[32];
        hasher2.Digest(testValue, hash2);
        
        Assert.Equal(hash2.ToHexString(), result1.ToHexString());
        
        hasher.Dispose();
    }

    [Fact]
    public void Blake3_Streaming_Should_Throw_After_Dispose()
    {
        var hasher = new Blake3Streaming();
        hasher.Dispose();
        
        Assert.Throws<ObjectDisposedException>(() => hasher.Update(testValue));
        Assert.Throws<ObjectDisposedException>(() => hasher.Finalize());
    }

    [Fact]
    public void Blake3_Consistency_Test()
    {
        // Test that multiple calls with same input produce same output
        var hasher = new Blake3();
        var hash1 = new byte[32];
        var hash2 = new byte[32];
        
        hasher.Digest(testValue, hash1);
        hasher.Digest(testValue, hash2);
        
        Assert.Equal(hash1.ToHexString(), hash2.ToHexString());
    }

    [Fact]
    public void Blake3_Different_Inputs_Different_Outputs()
    {
        var hasher = new Blake3();
        var hash1 = new byte[32];
        var hash2 = new byte[32];
        
        var input1 = Enumerable.Repeat((byte)0x00, 32).ToArray();
        var input2 = Enumerable.Repeat((byte)0xFF, 32).ToArray();
        
        hasher.Digest(input1, hash1);
        hasher.Digest(input2, hash2);
        
        Assert.NotEqual(hash1.ToHexString(), hash2.ToHexString());
    }
}
