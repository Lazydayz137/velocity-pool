// FiroPow: Firo-specific extension of ProgPoW algorithm
// Based on ethash and KawPoW implementations
// Copyright 2023-2025 Velocity Pool Contributors
// Licensed under the MIT License

#pragma once

#include "ethash/hash_types.h"
#include "ethash/ethash.h"
#include <cstdint>
#include <cstddef>

#if defined(_MSC_VER)
//  Microsoft
#define EXPORT __declspec(dllexport)
#define IMPORT __declspec(dllimport)
#elif defined(__GNUC__)
//  GCC
#define EXPORT __attribute__((visibility("default")))
#define IMPORT
#else
//  Do nothing and hope for the best?
#define EXPORT
#define IMPORT
#pragma warning Unknown dynamic link import/export semantics.
#endif

namespace firopow
{
    // Use ethash types
    using hash256 = ethash_hash256;
    using hash512 = ethash_hash512;
    using hash1024 = ethash_hash1024;
    using hash2048 = ethash_hash2048;
    using epoch_context = ethash_epoch_context;
    using epoch_context_full = ethash_epoch_context_full;

    // Result structure for FiroPow hash operations
    struct result
    {
        hash256 final_hash;
        hash256 mix_hash;
    };

    // Search result structure for mining operations
    struct search_result
    {
        result value;
        uint64_t nonce;
        bool success;
    };

    // FiroPow-specific ProgPoW parameters
    constexpr auto revision = "1.0.0";
    constexpr int period_length = 10;
    constexpr uint32_t num_regs = 32;
    constexpr size_t num_lanes = 16;
    constexpr int num_cache_accesses = 11;
    constexpr int num_math_operations = 18;
    constexpr size_t l1_cache_size = 16 * 1024;
    constexpr size_t l1_cache_num_items = l1_cache_size / sizeof(uint32_t);

    // FiroPow specific constants for Keccak padding
    constexpr uint32_t firo_constants[9] = {
        0x00000046, // F
        0x00000049, // I  
        0x00000052, // R
        0x0000004F, // O
        0x00000046, // F (repeated)
        0x00000049, // I
        0x00000052, // R
        0x0000004F, // O
        0x00000046  // F
    };

    // Core FiroPow functions
    result hash(const epoch_context& context, int block_number, const hash256& header_hash, uint64_t nonce) noexcept;
    int get_epoch_number(int block_number) noexcept;
}
