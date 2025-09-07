CC = gcc
CXX = g++
TARGET_SO = libverushash.so
OBJECTS = verushash.o

# CPU feature flags for optimization (conservative for broader compatibility)
CPU_FLAGS = -msse4.1 -msse4.2
HAVE_AES_NI = 
HAVE_AVX = 
HAVE_SSE = -msse4.1 -DHAVE_SSE4_1

# Compiler flags
CXXFLAGS = -std=c++17 -fPIC -O3 -g -Wall -Wextra
CXXFLAGS += $(CPU_FLAGS) $(HAVE_AES_NI) $(HAVE_AVX) $(HAVE_SSE)
CXXFLAGS += -ffast-math -funroll-loops -fomit-frame-pointer
CXXFLAGS += -falign-functions=16 -falign-loops=16

# Include directories
INCLUDES = -I.

# Linker flags
LDFLAGS = -shared -Wl,-soname,$(TARGET_SO)
LIBS = -lpthread

# Source files
SOURCES = verushash.cpp
HEADERS = verushash.h

.PHONY: all clean install test

all: $(TARGET_SO)

$(TARGET_SO): $(OBJECTS)
	$(CXX) $(LDFLAGS) -o $@ $^ $(LIBS)

%.o: %.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

clean:
	rm -f $(OBJECTS) $(TARGET_SO) test_verushash

install: $(TARGET_SO)
	cp $(TARGET_SO) ../../../build/

# Test program for verification
test_verushash: test_verushash.o $(OBJECTS)
	$(CXX) -O3 -g -o $@ $^ $(LIBS)

test_verushash.o: test_verushash.cpp $(HEADERS)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $< -o $@

test: test_verushash
	./test_verushash

# Debug build
debug: CXXFLAGS += -DDEBUG -O0 -ggdb3
debug: clean $(TARGET_SO)

# Check CPU features
check_cpu:
	@echo "Checking CPU features:"
	@grep -E "(aes|avx2|sse4)" /proc/cpuinfo | head -5 || echo "CPU feature detection not available"
	@echo "Compiler support:"
	@echo "int main(){}" | $(CXX) -march=native -dM -E - | grep -E "(AES|AVX|SSE)" || echo "No CPU features detected"

# Performance benchmark
benchmark: test_verushash
	@echo "Running VerusHash performance benchmark..."
	@time ./test_verushash --benchmark

# Profile with perf (Linux only)
profile: test_verushash
	perf record -g ./test_verushash --benchmark
	perf report

# Memory check with valgrind
memcheck: test_verushash
	valgrind --tool=memcheck --leak-check=full --track-origins=yes ./test_verushash

# Static analysis
analyze:
	cppcheck --enable=all --std=c++17 $(SOURCES)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -Wall -Wextra -Wpedantic -fsyntax-only $(SOURCES)

help:
	@echo "Available targets:"
	@echo "  all        - Build the shared library (default)"
	@echo "  clean      - Remove build artifacts"
	@echo "  install    - Copy library to build directory"
	@echo "  test       - Build and run test program"
	@echo "  debug      - Build debug version"
	@echo "  check_cpu  - Check CPU features and compiler support"
	@echo "  benchmark  - Run performance benchmark"
	@echo "  profile    - Profile with perf"
	@echo "  memcheck   - Memory check with valgrind"
	@echo "  analyze    - Static code analysis"
	@echo "  help       - Show this help message"
