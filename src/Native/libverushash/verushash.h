#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdbool.h>

// VerusHash 2.2 constants
#define VERUS_KEY_SIZE 32
#define VERUS_BLOCKSIZE 64
#define VERUS_ROUNDS 8

// Main hashing function
void verushash_hash(const uint8_t* input, uint8_t* output, uint32_t input_len);

// Context-based streaming API
typedef struct verushash_ctx verushash_ctx;

verushash_ctx* verushash_create_context();
void verushash_destroy_context(verushash_ctx* ctx);
void verushash_update(verushash_ctx* ctx, const uint8_t* data, uint32_t len);
void verushash_finalize(verushash_ctx* ctx, uint8_t* output);

// Haraka512 hash function (core of VerusHash)
void haraka512(const uint8_t* input, uint8_t* output);

// CPU feature detection
bool verushash_has_aes_ni();
bool verushash_has_avx2();
int verushash_optimal_threads();

// Library information
const char* verushash_get_version();

#ifdef __cplusplus
}
#endif
