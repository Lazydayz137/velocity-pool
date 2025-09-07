CFLAGS += -g -Wall -c -fPIC -O2 -Wno-pointer-sign -Wno-char-subscripts -Wno-unused-variable -Wno-unused-function -Wno-strict-aliasing -Wno-discarded-qualifiers -Wno-unused-const-variable $(CPU_FLAGS) 
CXXFLAGS += -g -Wall -fPIC -fpermissive -O2 -Wno-char-subscripts -Wno-unused-variable -Wno-unused-function -Wno-strict-aliasing -Wno-sign-compare -std=c++11 $(CPU_FLAGS)
LDFLAGS += -shared
TARGET = libfiropow.so

OBJECTS = ethash/ethash.o keccak/keccak.o keccak/keccakf800.o keccak/keccakf1600.o ethash/managed.o ethash/primes.o firopow/firopow.o firopow_exports.o

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CXX) $(LDFLAGS) -o $@ $^ $(LDLIBS)

# Copy KawPow sources as base and modify for FiroPow
prepare:
	@echo "Preparing FiroPow sources from KawPow base..."
	@mkdir -p firopow
	@mkdir -p ethash
	@mkdir -p keccak
	@mkdir -p support
	@cp ../libkawpow/*.h . 2>/dev/null || true
	@cp ../libkawpow/*.hpp . 2>/dev/null || true
	@cp ../libkawpow/ethash/*.cpp ethash/ 2>/dev/null || true
	@cp ../libkawpow/ethash/*.c ethash/ 2>/dev/null || true
	@cp ../libkawpow/ethash/*.h ethash/ 2>/dev/null || true
	@cp ../libkawpow/ethash/*.hpp ethash/ 2>/dev/null || true
	@cp ../libkawpow/keccak/*.cpp keccak/ 2>/dev/null || true
	@cp ../libkawpow/keccak/*.c keccak/ 2>/dev/null || true
	@cp ../libkawpow/keccak/*.h keccak/ 2>/dev/null || true
	@cp ../libkawpow/support/*.h support/ 2>/dev/null || true
	@cp ../libkawpow/support/*.hpp support/ 2>/dev/null || true
	@cp ../libkawpow/ethash/progpow.cpp firopow/firopow.cpp 2>/dev/null || true
	@echo "Source preparation complete. Ready for FiroPow-specific modifications."

.PHONY: clean prepare

clean:
	$(RM) $(TARGET) $(OBJECTS)
