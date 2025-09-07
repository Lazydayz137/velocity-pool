#include "verushash.h"
#include <iostream>
#include <iomanip>
#include <chrono>
#include <cstring>
#include <vector>

// Test vectors for VerusHash validation
struct TestVector {
    const char* input;
    const char* expected_hex;
};

// Known test vectors (these would come from reference implementation)
static const TestVector test_vectors[] = {
    // Empty input
    {"", ""},
    // Simple test cases (would be filled with known good values)
    {"test", ""},
    {"VerusCoin", ""},
    {"The quick brown fox jumps over the lazy dog", ""}
};

void print_hex(const uint8_t* data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') 
                  << static_cast<int>(data[i]);
    }
}

bool test_basic_functionality() {
    std::cout << "Testing basic VerusHash functionality...\n";
    
    const char* test_input = "Hello, VerusHash!";
    uint8_t output[32];
    
    verushash_hash(reinterpret_cast<const uint8_t*>(test_input), 
                   output, strlen(test_input));
    
    std::cout << "Input: " << test_input << "\n";
    std::cout << "Output: ";
    print_hex(output, 32);
    std::cout << "\n";
    
    // Check that output is not all zeros (basic sanity check)
    bool non_zero = false;
    for (int i = 0; i < 32; i++) {
        if (output[i] != 0) {
            non_zero = true;
            break;
        }
    }
    
    if (!non_zero) {
        std::cout << "ERROR: Output is all zeros!\n";
        return false;
    }
    
    std::cout << "✓ Basic functionality test passed\n\n";
    return true;
}

bool test_streaming_api() {
    std::cout << "Testing streaming API...\n";
    
    const char* test_input = "This is a longer test message for streaming API";
    size_t input_len = strlen(test_input);
    
    // Test 1: Single call vs streaming should produce same result
    uint8_t single_output[32];
    uint8_t stream_output[32];
    
    // Single call
    verushash_hash(reinterpret_cast<const uint8_t*>(test_input), 
                   single_output, input_len);
    
    // Streaming call
    verushash_ctx* ctx = verushash_create_context();
    if (!ctx) {
        std::cout << "ERROR: Failed to create context\n";
        return false;
    }
    
    verushash_update(ctx, reinterpret_cast<const uint8_t*>(test_input), input_len);
    verushash_finalize(ctx, stream_output);
    verushash_destroy_context(ctx);
    
    // Compare results
    bool match = memcmp(single_output, stream_output, 32) == 0;
    
    std::cout << "Single call output: ";
    print_hex(single_output, 32);
    std::cout << "\n";
    
    std::cout << "Stream call output: ";
    print_hex(stream_output, 32);
    std::cout << "\n";
    
    if (match) {
        std::cout << "✓ Streaming API test passed\n\n";
        return true;
    } else {
        std::cout << "ERROR: Single call and streaming results don't match!\n";
        return false;
    }
}

bool test_chunked_streaming() {
    std::cout << "Testing chunked streaming...\n";
    
    const char* test_input = "This is a test message that will be processed in chunks";
    size_t input_len = strlen(test_input);
    
    // Full input hash
    uint8_t full_output[32];
    verushash_hash(reinterpret_cast<const uint8_t*>(test_input), 
                   full_output, input_len);
    
    // Chunked input hash
    uint8_t chunked_output[32];
    verushash_ctx* ctx = verushash_create_context();
    
    // Process in 7-byte chunks (arbitrary small size)
    const uint8_t* data = reinterpret_cast<const uint8_t*>(test_input);
    size_t remaining = input_len;
    size_t chunk_size = 7;
    
    while (remaining > 0) {
        size_t current_chunk = (remaining < chunk_size) ? remaining : chunk_size;
        verushash_update(ctx, data, current_chunk);
        data += current_chunk;
        remaining -= current_chunk;
    }
    
    verushash_finalize(ctx, chunked_output);
    verushash_destroy_context(ctx);
    
    bool match = memcmp(full_output, chunked_output, 32) == 0;
    
    std::cout << "Full input output: ";
    print_hex(full_output, 32);
    std::cout << "\n";
    
    std::cout << "Chunked output:    ";
    print_hex(chunked_output, 32);
    std::cout << "\n";
    
    if (match) {
        std::cout << "✓ Chunked streaming test passed\n\n";
        return true;
    } else {
        std::cout << "ERROR: Full and chunked results don't match!\n";
        return false;
    }
}

bool test_cpu_features() {
    std::cout << "Testing CPU feature detection...\n";
    
    bool has_aes_ni = verushash_has_aes_ni();
    bool has_avx2 = verushash_has_avx2();
    int optimal_threads = verushash_optimal_threads();
    
    std::cout << "AES-NI support: " << (has_aes_ni ? "Yes" : "No") << "\n";
    std::cout << "AVX2 support: " << (has_avx2 ? "Yes" : "No") << "\n";
    std::cout << "Optimal thread count: " << optimal_threads << "\n";
    std::cout << "Library version: " << verushash_get_version() << "\n";
    
    std::cout << "✓ CPU feature detection test passed\n\n";
    return true;
}

void benchmark_performance() {
    std::cout << "Running performance benchmark...\n";
    
    const size_t test_size = 1024; // 1KB (smaller to avoid issues)
    std::vector<uint8_t> test_data(test_size);
    
    // Fill with simple pattern
    for (size_t i = 0; i < test_size; i++) {
        test_data[i] = static_cast<uint8_t>(i & 0xFF);
    }
    
    const int iterations = 1000;
    uint8_t output[32];
    
    auto start = std::chrono::high_resolution_clock::now();
    
    for (int i = 0; i < iterations; i++) {
        verushash_hash(test_data.data(), output, test_size);
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    
    double avg_time_us = static_cast<double>(duration.count()) / iterations;
    double hashes_per_sec = iterations * 1000000.0 / duration.count();
    
    std::cout << "Processed " << iterations << " iterations of " << test_size << " bytes\n";
    std::cout << "Average time per hash: " << std::fixed << std::setprecision(2) 
              << avg_time_us << " microseconds\n";
    std::cout << "Hashes per second: " << std::fixed << std::setprecision(0) 
              << hashes_per_sec << " H/s\n";
    std::cout << "Final hash: ";
    print_hex(output, 32);
    std::cout << "\n\n";
}

bool test_haraka512() {
    std::cout << "Testing Haraka512 function...\n";
    
    // Test with 64-byte input
    uint8_t input[64];
    uint8_t output[32];
    
    // Fill input with test pattern
    for (int i = 0; i < 64; i++) {
        input[i] = static_cast<uint8_t>(i);
    }
    
    haraka512(input, output);
    
    std::cout << "Input (first 32 bytes): ";
    print_hex(input, 32);
    std::cout << "\n";
    
    std::cout << "Output: ";
    print_hex(output, 32);
    std::cout << "\n";
    
    // Basic sanity check - output should not be identical to input
    bool different = memcmp(input, output, 32) != 0;
    
    if (different) {
        std::cout << "✓ Haraka512 test passed\n\n";
        return true;
    } else {
        std::cout << "ERROR: Haraka512 output identical to input!\n";
        return false;
    }
}

int main(int argc, char* argv[]) {
    std::cout << "VerusHash Native Library Test Suite\n";
    std::cout << "=====================================\n\n";
    
    bool benchmark_mode = false;
    if (argc > 1 && strcmp(argv[1], "--benchmark") == 0) {
        benchmark_mode = true;
    }
    
    if (benchmark_mode) {
        benchmark_performance();
        return 0;
    }
    
    bool all_passed = true;
    
    all_passed &= test_cpu_features();
    all_passed &= test_haraka512();
    all_passed &= test_basic_functionality();
    all_passed &= test_streaming_api();
    all_passed &= test_chunked_streaming();
    
    std::cout << "=====================================\n";
    if (all_passed) {
        std::cout << "✅ All tests passed!\n";
        return 0;
    } else {
        std::cout << "❌ Some tests failed!\n";
        return 1;
    }
}
