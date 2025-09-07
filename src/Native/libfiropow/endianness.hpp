// Endianness utilities for FiroPow
// Based on ethash implementation
// Copyright 2023-2025 Velocity Pool Contributors

#pragma once

#include <array>
#include <cstdint>

namespace le  // little-endian
{

/// Converts native uint32_t to little-endian bytes.
inline uint32_t uint32(uint32_t x) noexcept
{
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    return x;
#else
    return __builtin_bswap32(x);
#endif
}

/// Converts array of uint32_t values to little-endian.
template <size_t N>
inline std::array<uint32_t, N> uint32s(const std::array<uint32_t, N>& arr) noexcept
{
    std::array<uint32_t, N> result;
    for (size_t i = 0; i < N; ++i)
        result[i] = uint32(arr[i]);
    return result;
}

}  // namespace le

namespace be  // big-endian
{

/// Converts native uint32_t to big-endian bytes.
inline uint32_t uint32(uint32_t x) noexcept
{
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    return x;
#else
    return __builtin_bswap32(x);
#endif
}

/// Converts native uint64_t to big-endian bytes.
inline uint64_t uint64(uint64_t x) noexcept
{
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
    return x;
#else
    return __builtin_bswap64(x);
#endif
}

}  // namespace be
