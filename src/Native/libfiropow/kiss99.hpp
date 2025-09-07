// KISS99 Random Number Generator for FiroPow
// Based on ethash implementation
// Copyright 2023-2025 Velocity Pool Contributors

#pragma once

#include <cstdint>

/// KISS99 random number generator.
/// Implementation of KISS algorithm by George Marsaglia.
/// https://en.wikipedia.org/wiki/KISS_(algorithm)
struct kiss99
{
    uint32_t z, w, jsr, jcong;

    kiss99() noexcept = default;
    
    kiss99(uint32_t z_seed, uint32_t w_seed, uint32_t jsr_seed, uint32_t jcong_seed) noexcept
      : z{z_seed}, w{w_seed}, jsr{jsr_seed}, jcong{jcong_seed}
    {}

    /// Generates next random number.
    uint32_t operator()() noexcept
    {
        z = 36969 * (z & 65535) + (z >> 16);
        w = 18000 * (w & 65535) + (w >> 16);
        const auto mwc = (z << 16) + w;

        jsr ^= jsr << 17;
        jsr ^= jsr >> 13;
        jsr ^= jsr << 5;

        jcong = 69069 * jcong + 1234567;

        return (mwc ^ jcong) + jsr;
    }
};
