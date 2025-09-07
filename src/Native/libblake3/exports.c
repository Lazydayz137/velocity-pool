// Blake3 C wrapper for Miningcore .NET interop
#include "c/blake3.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

// Single-shot hashing function for simple cases
EXPORT void blake3_hash_simple(const uint8_t* input, size_t input_len, uint8_t* output) {
    blake3_hasher hasher;
    blake3_hasher_init(&hasher);
    blake3_hasher_update(&hasher, input, input_len);
    blake3_hasher_finalize(&hasher, output, BLAKE3_OUT_LEN);
}

// Initialize a Blake3 hasher
EXPORT blake3_hasher* blake3_create_hasher(void) {
    blake3_hasher* hasher = malloc(sizeof(blake3_hasher));
    if (hasher != NULL) {
        blake3_hasher_init(hasher);
    }
    return hasher;
}

// Update hasher with data
EXPORT void blake3_update_hasher(blake3_hasher* hasher, const uint8_t* input, size_t input_len) {
    if (hasher != NULL) {
        blake3_hasher_update(hasher, input, input_len);
    }
}

// Finalize and get the hash
EXPORT void blake3_finalize_hasher(blake3_hasher* hasher, uint8_t* output, size_t output_len) {
    if (hasher != NULL) {
        blake3_hasher_finalize(hasher, output, output_len);
    }
}

// Clean up hasher
EXPORT void blake3_destroy_hasher(blake3_hasher* hasher) {
    if (hasher != NULL) {
        // Clear sensitive data
        memset(hasher, 0, sizeof(blake3_hasher));
        free(hasher);
    }
}

// Get Blake3 output length constant
EXPORT int blake3_get_output_length(void) {
    return BLAKE3_OUT_LEN;
}

// Hash with custom output length (Blake3 supports variable output length)
EXPORT void blake3_hash_custom_length(const uint8_t* input, size_t input_len, 
                                     uint8_t* output, size_t output_len) {
    blake3_hasher hasher;
    blake3_hasher_init(&hasher);
    blake3_hasher_update(&hasher, input, input_len);
    blake3_hasher_finalize(&hasher, output, output_len);
}

// Hash with key (Blake3 supports keyed hashing)
EXPORT void blake3_hash_keyed(const uint8_t* key, const uint8_t* input, 
                             size_t input_len, uint8_t* output) {
    blake3_hasher hasher;
    blake3_hasher_init_keyed(&hasher, key);
    blake3_hasher_update(&hasher, input, input_len);
    blake3_hasher_finalize(&hasher, output, BLAKE3_OUT_LEN);
}
