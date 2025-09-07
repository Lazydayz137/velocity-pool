// FiroPow C API exports for C# P/Invoke integration
// Copyright 2023-2025 Velocity Pool Contributors  
// Licensed under the MIT License

#include "firopow.hpp"
#include "ethash/ethash.hpp"
#include <cstring>

extern "C"
{

// Minimal C API exports for the basic functionality we've implemented

/// Create FiroPow epoch context (uses ethash context for now)
EXPORT firopow::epoch_context* firopow_create_epoch_context(int epoch_number) noexcept
{
    return ethash_create_epoch_context(epoch_number);
}

/// Destroy FiroPow epoch context
EXPORT void firopow_destroy_epoch_context(firopow::epoch_context* context) noexcept
{
    ethash_destroy_epoch_context(context);
}

/// FiroPow hash calculation - using our implemented hash function
EXPORT void firopow_hash(const firopow::epoch_context* context, int block_number,
    const firopow::hash256* header_hash, uint64_t nonce, firopow::hash256* final_hash, firopow::hash256* mix_hash) noexcept
{
    if (!context || !header_hash || !final_hash || !mix_hash)
        return;

    auto result = firopow::hash(*context, block_number, *header_hash, nonce);
    *final_hash = result.final_hash;
    *mix_hash = result.mix_hash;
}

/// Get epoch number from block number - using our implemented function
EXPORT int firopow_get_epoch_number(int block_number) noexcept
{
    return firopow::get_epoch_number(block_number);
}

/// Copy hash256 from byte array
EXPORT void firopow_hash256_from_bytes(const uint8_t* bytes, firopow::hash256* hash) noexcept
{
    if (bytes && hash)
        std::memcpy(hash->bytes, bytes, 32);
}

/// Copy hash256 to byte array
EXPORT void firopow_hash256_to_bytes(const firopow::hash256* hash, uint8_t* bytes) noexcept
{
    if (hash && bytes)
        std::memcpy(bytes, hash->bytes, 32);
}

/// Get library version string
EXPORT const char* firopow_get_version() noexcept
{
    return firopow::revision;
}

}  // extern "C"
