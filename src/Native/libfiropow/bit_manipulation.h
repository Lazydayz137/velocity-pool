// Bit manipulation utilities for FiroPow
// Based on ethash implementation
// Copyright 2023-2025 Velocity Pool Contributors

#pragma once

#include <cstdint>

#if defined(_MSC_VER)
#include <intrin.h>
#define NO_SANITIZE(x)
#elif defined(__GNUC__)
#define NO_SANITIZE(x) __attribute__((no_sanitize(x)))
#include <x86intrin.h>
#else
#define NO_SANITIZE(x)
#endif

// FNV hash constants
constexpr uint32_t fnv_offset_basis = 0x811c9dc5;
constexpr uint32_t fnv_prime = 0x01000193;

/// FNV1a hash function
inline uint32_t fnv1a(uint32_t u, uint32_t v) noexcept
{
    return (u ^ v) * fnv_prime;
}

/// 32-bit rotate left
inline uint32_t rotl32(uint32_t x, uint32_t n) noexcept
{
    return (x << (n & 31)) | (x >> (32 - (n & 31)));
}

/// 32-bit rotate right  
inline uint32_t rotr32(uint32_t x, uint32_t n) noexcept
{
    return (x >> (n & 31)) | (x << (32 - (n & 31)));
}

/// Get high 32 bits of multiplication
inline uint32_t mul_hi32(uint32_t x, uint32_t y) noexcept
{
    return static_cast<uint32_t>((static_cast<uint64_t>(x) * y) >> 32);
}

/// Count leading zeros
inline uint32_t clz32(uint32_t x) noexcept
{
    if (x == 0)
        return 32;
        
#if defined(_MSC_VER)
    unsigned long index;
    _BitScanReverse(&index, x);
    return 31 - index;
#elif defined(__GNUC__)
    return __builtin_clz(x);
#else
    // Fallback implementation
    uint32_t count = 0;
    if (x == 0) return 32;
    while ((x & 0x80000000) == 0) {
        count++;
        x <<= 1;
    }
    return count;
#endif
}

/// Count population (number of 1 bits)
inline uint32_t popcount32(uint32_t x) noexcept
{
#if defined(_MSC_VER)
    return __popcnt(x);
#elif defined(__GNUC__)
    return __builtin_popcount(x);
#else
    // Fallback implementation
    x = x - ((x >> 1) & 0x55555555);
    x = (x & 0x33333333) + ((x >> 2) & 0x33333333);
    return (((x + (x >> 4)) & 0x0F0F0F0F) * 0x01010101) >> 24;
#endif
}
