CC = gcc
CFLAGS = -O3 -march=native -Wall -Wextra -pthread
CRYSTAL = crystal
CRYSTAL_FLAGS = --release

CORE_SRC = core/md4.c
CORE_OBJ = core/md4.o
CORE_LIB = core/liblxpen_core.a

TARGET = lxpen

.PHONY: all clean rebuild test bench

all: $(TARGET)

$(CORE_OBJ): $(CORE_SRC) core/md4.h
	$(CC) $(CFLAGS) -c $(CORE_SRC) -o $(CORE_OBJ)

$(CORE_LIB): $(CORE_OBJ)
	ar rcs $(CORE_LIB) $(CORE_OBJ)

$(TARGET): $(CORE_LIB) src/main.cr src/cli.cr src/core/ntlm.cr src/patterns/*.cr src/generator/*.cr
	$(CRYSTAL) build $(CRYSTAL_FLAGS) src/main.cr -o $(TARGET)

clean:
	rm -f $(TARGET) $(CORE_OBJ) $(CORE_LIB) core/test_core

rebuild: clean all

test: $(TARGET)
	@echo "=== Hash Tests ==="
	@./$(TARGET) hash "password"
	@./$(TARGET) hash "123456"
	@./$(TARGET) hash ""
	@echo ""
	@echo "=== Crack Tests ==="
	@./$(TARGET) crack $$(./$(TARGET) hash "dragon123" | cut -d'>' -f2 | tr -d ' ')
	@echo ""
	@./$(TARGET) crack $$(./$(TARGET) hash "Mehmet1994" | cut -d'>' -f2 | tr -d ' ')

bench: $(TARGET)
	./$(TARGET) bench
