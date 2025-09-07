# Blake3 Makefile for Miningcore
CC := gcc
AR := ar
TARGET := libblake3.so
STATIC_TARGET := libblake3.a

# Source files
BLAKE3_C_SOURCES := c/blake3.c c/blake3_dispatch.c c/blake3_portable.c
EXPORT_SOURCES := exports.c

# Check for CPU features and set flags accordingly
CPU_FLAGS := -march=native -mtune=native

# Check if AVX2 is available
HAS_AVX2 := $(shell $(CC) -mavx2 -dM -E - < /dev/null 2>/dev/null | grep -q "__AVX2__" && echo "1")
ifeq ($(HAS_AVX2),1)
    BLAKE3_C_SOURCES += c/blake3_avx2.c
    CPU_FLAGS += -mavx2
    $(info Blake3: AVX2 support enabled)
endif

# Check if SSE4.1 is available
HAS_SSE41 := $(shell $(CC) -msse4.1 -dM -E - < /dev/null 2>/dev/null | grep -q "__SSE4_1__" && echo "1")
ifeq ($(HAS_SSE41),1)
    BLAKE3_C_SOURCES += c/blake3_sse41.c
    CPU_FLAGS += -msse4.1
    $(info Blake3: SSE4.1 support enabled)
endif

# Check if SSE2 is available (almost always on x64)
HAS_SSE2 := $(shell $(CC) -msse2 -dM -E - < /dev/null 2>/dev/null | grep -q "__SSE2__" && echo "1")
ifeq ($(HAS_SSE2),1)
    BLAKE3_C_SOURCES += c/blake3_sse2.c
    CPU_FLAGS += -msse2
    $(info Blake3: SSE2 support enabled)
endif

# Compiler flags
CFLAGS := -std=c99 -O3 -fPIC -Wall -Wextra $(CPU_FLAGS)
CFLAGS += -fvisibility=hidden -DBLAKE3_USE_NEON=0

# Debug flags (uncomment for debugging)
# CFLAGS += -g -DDEBUG

# Platform specific flags
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    LDFLAGS := -shared -Wl,-soname,$(TARGET)
endif
ifeq ($(UNAME_S),Darwin)
    TARGET := libblake3.dylib
    LDFLAGS := -dynamiclib -install_name $(TARGET)
endif

# Object files
BLAKE3_OBJECTS := $(BLAKE3_C_SOURCES:.c=.o)
EXPORT_OBJECTS := $(EXPORT_SOURCES:.c=.o)
ALL_OBJECTS := $(BLAKE3_OBJECTS) $(EXPORT_OBJECTS)

.PHONY: all clean install test

all: $(TARGET) $(STATIC_TARGET)

$(TARGET): $(ALL_OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^
	@echo "Blake3: Shared library $(TARGET) built successfully"

$(STATIC_TARGET): $(ALL_OBJECTS)
	$(AR) rcs $@ $^
	@echo "Blake3: Static library $(STATIC_TARGET) built successfully"

# Special compilation rules for SIMD files
c/blake3_avx2.o: c/blake3_avx2.c
	$(CC) $(CFLAGS) -mavx2 -c $< -o $@

c/blake3_sse41.o: c/blake3_sse41.c
	$(CC) $(CFLAGS) -msse4.1 -c $< -o $@

c/blake3_sse2.o: c/blake3_sse2.c
	$(CC) $(CFLAGS) -msse2 -c $< -o $@

# Generic object compilation
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(ALL_OBJECTS) $(TARGET) $(STATIC_TARGET)
	@echo "Blake3: Cleaned build artifacts"

install: $(TARGET)
	@mkdir -p ../../build
	cp $(TARGET) ../../build/
	@echo "Blake3: Installed $(TARGET) to ../../build/"

# Simple test to verify the library works
test: $(TARGET)
	@echo "Blake3: Running basic functionality test..."
	@echo -n "Testing Blake3 hash... "
	@echo "hello world" | ./test_blake3 && echo "PASSED" || echo "FAILED"

# Test program (optional)
test_blake3: test_blake3.c $(STATIC_TARGET)
	$(CC) $(CFLAGS) -o $@ $< -L. -lblake3

# Show CPU capabilities
cpu-info:
	@echo "Blake3: CPU capability detection:"
	@echo "  AVX2: $(HAS_AVX2)"
	@echo "  SSE4.1: $(HAS_SSE41)"
	@echo "  SSE2: $(HAS_SSE2)"
	@echo "  Compiler flags: $(CPU_FLAGS)"

# Benchmark target
benchmark: $(TARGET)
	@echo "Blake3: Performance benchmark (if available):"
	@if [ -f "c/blake3_benchmark" ]; then ./c/blake3_benchmark; fi

