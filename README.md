# LXPEN

**Layered Exploration Password Engine** — NTLM hash cracker using **Hierarchical Probabilistic Decomposition (HPD)**.

> *"Don't crack the password. Crack the idea."*

LXPEN cracks NTLM hashes without wordlists. Instead of brute force or dictionary attacks, it decomposes the password space into **human behavioral patterns** — how people actually construct passwords — and generates candidates in probability order.

## HPD Algorithm

**Hierarchical Probabilistic Decomposition** works in three layers:

```
Structure    →  [CapName] + [Year] + [Symbol]
Components   →  "Michael"   "1994"    "!"
Variations   →  frequency-weighted slot entries
```

1. **Pattern Layer**: 45 password structure templates ranked by real-world frequency (e.g., `word+digits`, `name+year+symbol`, `l33t+digits`)
2. **Slot Layer**: Each pattern slot maps to a frequency-weighted dictionary — common words, names (EN+TR), years, digit sequences, symbols, l33t transforms, keyboard walks
3. **Generation Layer**: C-native engine generates candidates directly in the hot loop — no string allocation, no interpreter overhead. Multi-threaded with atomic early exit.

The key insight: most human-chosen passwords follow a small number of structural patterns. By modeling *how people think* rather than *what they type*, HPD covers a massive password space with a compact model.

## Benchmark: LXPEN vs Hashcat

CPU-only, same machine (6 cores), same 20 NTLM hashes across 5 difficulty tiers:

### Crack Rate

| Tier | LXPEN | Hashcat (3.5K+best64) | Hashcat (100K+best64) |
|---|---|---|---|
| Trivial | 4/4 (100%) | 4/4 (100%) | 4/4 (100%) |
| Word+Digits | 4/4 (100%) | 4/4 (100%) | 4/4 (100%) |
| Name+Year | **4/4 (100%)** | 1/4 (25%) | 1/4 (25%) |
| L33t/Symbol | **4/4 (100%)** | 0/4 (0%) | 2/4 (50%) |
| Hard | 2/4 (50%) | 2/4 (50%) | 2/4 (50%) |
| **Total** | **18/20 (90%)** | 11/20 (55%) | 13/20 (65%) |

### Speed & Resources

| Metric | LXPEN | Hashcat (100K+best64) |
|---|---|---|
| **Wall-clock time** | **0.56s** | 3.95s |
| **RAM usage** | **4.4 MB** | 475 MB |
| **Wordlist required** | No | Yes (100K file) |
| **Candidate space** | 4.3M | ~6.4M |
| **Disk I/O** | 0 | Wordlist read |

**LXPEN is 7x faster, uses 108x less RAM, and cracks 38% more passwords — with zero external files.**

## Architecture

```
Crystal (orchestrator)          C core (-O3 -march=native -pthread)
┌──────────────────┐           ┌─────────────────────────┐
│  CLI / IO        │           │  MD4 transform          │
│  Pattern schema  │  ──FFI──▶ │  NTLM hash (UTF-16LE)   │
│  Frequency data  │           │  Multi-target crack      │
│  Candidate engine│           │  Pattern worker threads  │
└──────────────────┘           │  RAM table (O(1) lookup) │
                               └─────────────────────────┘
```

- **Hot path in C**: MD4 hashing, UTF-16LE conversion, multi-threaded candidate generation, and multi-target comparison all run in C with `-O3 -march=native`
- **Pattern engine in Crystal**: Slot data and pattern definitions are managed in Crystal, then passed to C for bulk processing
- **Zero-copy FFI**: Crystal passes raw pointers to slot value arrays; C iterates the cartesian product internally

## Usage

```bash
# Crack a single NTLM hash
lxpen crack 8846f7eaee8fb117ad06bdd830b7586c

# Crack multiple hashes from file (multi-target, fastest)
lxpen crack -f hashes.txt

# Generate NTLM hash
lxpen hash "password"

# Performance benchmark
lxpen bench

# Pattern statistics
lxpen stats
```

## Build

Requirements: GCC, Crystal >= 1.19.1, pthreads

```bash
make          # Build release
make clean    # Clean artifacts
make rebuild  # Clean + build
make test     # Run basic tests
make bench    # Run performance benchmark
```

## How It Works

Traditional crackers try passwords from a list. LXPEN generates them from a model:

1. **No wordlist**: The ~4.3M candidate space is generated algorithmically from 45 patterns and frequency-weighted slot tables
2. **Probability ordering**: High-frequency patterns and slot entries are tried first — `password123` is tried before `xylophone789`
3. **Multi-target**: When cracking N hashes, all candidates are checked against all targets simultaneously. Finding one hash costs the same as finding twenty.
4. **C-native generation**: Candidates are generated and hashed entirely in C threads. Crystal only passes the slot tables once.
5. **Atomic early exit**: When all targets are found, worker threads stop immediately via atomic flags

## Project Structure

```
lxpen/
  core/
    md4.c              # C core: MD4, NTLM, multi-thread crack, RAM table, pattern engine
    md4.h              # C API header
  src/
    main.cr            # Entry point
    cli.cr             # CLI commands
    core/ntlm.cr       # Crystal FFI bindings to C core
    patterns/
      schema.cr        # SlotType, Pattern, Slot definitions
      frequency_data.cr # 45 patterns, 900+ slot entries (EN+TR)
    generator/
      candidate_engine.cr # Pattern iteration + slot data provider
  benchmark/
    benchmark_v4.sh    # Full comparison benchmark vs Hashcat
  Makefile
```

## License

MIT License - Azizcan Dastan, 2026
