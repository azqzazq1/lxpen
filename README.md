# LXPEN

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20366383.svg)](https://doi.org/10.5281/zenodo.20366383)

**Layered Exploration Password Engine** — Hash cracker (NTLM / MD5 / SHA-256) powered by **Hierarchical Probabilistic Decomposition (HPD)**.

> *"Don't crack the password. Crack the idea."*  
> *Inspired by Arsene Lupin — the gentleman who cracks the mind, not the lock.*

LXPEN cracks hashes **without wordlists, without OSINT, without GPU**. Instead of brute force or dictionary attacks, it decomposes the password space into **human behavioral patterns** — how people actually construct passwords — and generates candidates in probability order.

## Results at a Glance

```
                    LXPEN v0.5       Hashcat (100K+best64)
  Cracked:          18/20 (90%)      13/20 (65%)
  Time:             0.56s            3.95s
  RAM:              4.4 MB           475 MB
  Wordlist:         NONE             100K file required
  Speedup:          7x faster        baseline
  RAM efficiency:   108x less        baseline
  Hash types:       NTLM/MD5/SHA256  --
  Patterns:         48               --
  Candidate space:  26.6M            6.4M
```

---

## Table of Contents

- [What's New in v0.5.0](#whats-new-in-v050)
- [HPD Algorithm](#hpd-algorithm)
- [Why It Works](#why-it-works)
- [Benchmark](#benchmark-lxpen-vs-hashcat)
- [Usage](#usage)
- [Usage Scenarios](#usage-scenarios)
- [Architecture](#architecture)
- [Extending LXPEN](#extending-lxpen)
- [Build](#build)
- [Project Structure](#project-structure)
- [Benchmark Methodology](#benchmark-methodology)
- [Roadmap](#roadmap)
- [License](#license)

---

## What's New in v0.5.0

### v0.4.0 → v0.5.0 Comparison

| | v0.4.0 | v0.5.0 |
|---|---|---|
| **Hash types** | NTLM only | NTLM + MD5 + SHA-256 |
| **Patterns** | 45 | 48 (+3 passphrase) |
| **Candidate space** | 4.3M | 26.6M (+6x) |
| **Slot entries** | ~530 (EN+TR) | ~900+ (EN+TR+DE+RU+AR) |
| **Languages** | English, Turkish | + German, Russian, Arabic |
| **Commands** | crack, hash, bench, stats | + analyze, coverage |
| **Output** | Terminal only | + JSON (`--json`) |
| **Post-pattern fallback** | None | Hybrid brute-force (a-z0-9, 1-4 char) |
| **Test suite** | Placeholder | 26 Crystal specs + 13 C tests |

### New Features

**Multi-Hash Support** — Full MD5 (RFC 1321) and SHA-256 (FIPS 180-4) implementations in C, with the same multi-threaded pattern cracking engine:

```bash
lxpen crack <MD5_HASH> --type md5
lxpen crack <SHA256_HASH> --type sha256
lxpen hash "password" --type sha256
```

**`lxpen analyze`** — Reverse-match any password to HPD patterns. Shows which patterns would catch it, plus all three hash types:

```bash
$ lxpen analyze "Michael1994!"
  ✓ 2 pattern matches found:
    1. cap_year_sym (4.7%)  — [CapWord:Michael] + [Year:1994] + [SymbolSuffix:!]
    2. cap_name_year_sym (2.5%) — [CapName:Michael] + [Year:1994] + [SymbolSuffix:!]
  NTLM: 3d87e4a5ed025f248af37286dcea4639
  MD5:  a7284ec3b35502a7f75bbc9e9f702d17
  SHA256: 59c30f8424405cf88cc66e0d0c0698e02e2b99b79ab40ed27de16995e496ad57

$ lxpen analyze "xK9mZ2pLq"
  ✗ No HPD pattern matches this password.
  This password is outside the current pattern space.
```

**`lxpen coverage`** — Full pattern space report with candidate counts per pattern and slot statistics:

```bash
$ lxpen coverage
  Total candidate space: 26,638,972
  Total patterns:        48

  #   Pattern                   Freq%   Candidates  Slots
  ─────────────────────────────────────────────────────────
  1   lower_digits              22.4%       12,896  LowerWord(208) × SeqDigits(62)
  2   cap_digits                14.1%       12,896  CapWord(208) × SeqDigits(62)
  3   lower_only                11.8%          208  LowerWord(208)
  ...
```

**JSON Output** — Machine-readable output for all commands with `--json`:

```bash
$ lxpen crack 8846f7eaee8fb117ad06bdd830b7586c --json
{"status":"cracked","password":"password","hash":"8846f7ea...","type":"ntlm","tried":25827,"time_s":0.0068}
```

**Language Packs** — German, Russian, and Arabic names + cultural words added to slot data:

| Language | Names | Words | Examples |
|---|---|---|---|
| German | hans, klaus, petra, stefan... | passwort, geheim, bayern, berlin... | `Stefan2024!`, `passwort123` |
| Russian | ivan, dmitri, natasha, vladimir... | parol, spartak, moskva, zenit... | `Vladimir1994`, `spartak123` |
| Arabic | mohammed, ahmed, fatima, omar... | salam, habibi, allah, yalla... | `Mohammed2024`, `habibi123` |

**Passphrase Patterns** — Three new multi-word patterns:

```
lower_lower_lower    passworddragonmaster
cap_cap_cap          PasswordDragonMaster
name_name_name       MichaelJessicaOmar
```

**Hybrid Brute-Force** — After HPD patterns, automatically tries `[a-z0-9]` combinations up to 4 characters. Catches short passwords that don't match any pattern.

**Test Suite** — 26 Crystal specs (hash correctness, pattern loading, engine validation) + 13 C-level hash verification tests against RFC/FIPS reference vectors.

---

## HPD Algorithm

**Hierarchical Probabilistic Decomposition** models password creation as a three-layer generative process:

### Layer 1: Structure Templates

Human passwords follow structural patterns. HPD defines 48 templates ranked by real-world frequency:

```
Pattern                  Frequency   Example
[LowerWord+SeqDigits]    22.4%      shadow99, dragon69
[CapWord+SeqDigits]      14.1%      Master123, Admin007
[LowerWord]              11.8%      password, butterfly
[LowerWord+Year]          8.9%      summer2024, love1994
[Name+Year]               7.2%      michael1994, jessica2024
[CapName+Year+Symbol]     2.5%      Michael1994!, Mehmet2024.
[L33t+SeqDigits]          2.4%      h4ck3r666, p@ss123
...48 patterns total
```

### Layer 2: Slot Filling

Each template slot maps to a **frequency-weighted dictionary**:

| Slot Type | Entries | Examples |
|---|---|---|
| LowerWord | 208 | password, dragon, shadow, butterfly, galatasaray, passwort, habibi |
| Name | 151 | michael, jessica, mehmet, ayse, hans, ivan, mohammed (EN+TR+DE+RU+AR) |
| Year | 61 | 2024, 1994, 1907, 1453 |
| SeqDigits | 62 | 123, 69, 007, 12345678 |
| Symbol | 25 | !, @, #, !@#$, . |
| L33t | 28 | p@ssw0rd, h4ck3r, @dmin, r00t |
| Keyboard | 24 | qwerty, asdf, zxcv, qazwsx |

### Layer 3: Candidate Generation

The cartesian product of all slot values within each pattern generates the candidate space:

```
Pattern [LowerWord + SeqDigits]:  208 words x 62 digits = 12,896 candidates
Pattern [Name + Year + Symbol]:   151 names x 61 years x 25 symbols = 230,275 candidates
...
Total across 48 patterns:         26,638,972 candidates
```

Candidates are generated **in probability order** — high-frequency patterns first, high-frequency slot entries first within each pattern.

### Mathematical Foundation

The probability of a candidate `c` generated from pattern `P` with slot values `s1, s2, ..., sk`:

```
P(c) = P(pattern) * P(s1|slot1) * P(s2|slot2) * ... * P(sk|slotk)
```

The total coverage probability:

```
Coverage = SUM over all patterns P:
           P(P) * PRODUCT over slots in P:
           SUM over entries in slot
```

With 48 patterns and ~26.6M candidates, HPD covers an estimated **85-95% of human-chosen passwords** that follow recognizable structural patterns.

---

## Why It Works

### The Human Password Problem

People don't generate random passwords. They follow mental templates:

- **"My name + birth year"** → `Michael1994`, `Jessica2024`
- **"A word I know + some numbers"** → `password123`, `shadow99`  
- **"L33t speak makes it secure"** → `P@ssw0rd123`, `h4ck3r666`
- **"My team + founding year + !"** → `Galatasaray1905!`

### Why Wordlists Fail

| Scenario | Wordlist Approach | HPD Approach |
|---|---|---|
| `Michael1994` | Need "Michael1994" literally in wordlist or complex rule chain | Pattern [CapName+Year] generates it directly |
| `Galatasaray1905!` | Need Turkish football wordlist + year rules + symbol rules | Pattern [CapWord+Year+Symbol] with TR slot data |
| `h4ck3r666` | Need l33t transformation rules applied to "hacker" | Pattern [L33t+SeqDigits] has `h4ck3r` as native entry |
| `Mehmet1994` | Extremely unlikely in any English wordlist | Turkish names in Name slot, generated naturally |

### The Efficiency Argument

Hashcat with a 100K wordlist + best64 rules generates ~6.4M candidates but only cracks 65% of the test set. LXPEN generates 26.6M candidates (including hybrid brute-force) and cracks 90%. The difference:

- **Hashcat**: Uniform exploration of word variations. Most candidates are irrelevant (e.g., `zygote123`, `xylophone!`)
- **LXPEN**: Every candidate follows a pattern humans actually use. Hybrid fallback catches edge cases.

```
Effective coverage:
  LXPEN:   18/20 found in 4.3M pattern candidates = 1 hit per 238K candidates
  Hashcat: 13/20 found in 6.4M candidates          = 1 hit per 492K candidates
  
LXPEN is 2x more efficient per candidate generated.
Pattern-based candidates find 90% of targets before hybrid even starts.
```

---

## Benchmark: LXPEN vs Hashcat

CPU-only, same machine (6 cores, 12GB RAM), same 20 NTLM hashes across 5 difficulty tiers.

### Crack Rate by Tier

| Tier | Passwords | LXPEN | HC (3.5K) | HC (100K) |
|---|---|---|---|---|
| Trivial | password, 123456, admin, qwerty | **4/4** | 4/4 | 4/4 |
| Word+Digits | password123, admin123, shadow99, dragon69 | **4/4** | 4/4 | 4/4 |
| Name+Year | Michael1994, Jessica2024, Mehmet1994, Shadow99 | **4/4** | 1/4 | 1/4 |
| L33t/Symbol | P@ssw0rd123, h4ck3r666, Galatasaray1905!, fenerbahce1907 | **4/4** | 0/4 | 2/4 |
| Hard | Tr0ub4dor&3, xK9#mZ2pLq, butterfly, superman1 | 2/4 | 2/4 | 2/4 |
| **Total** | | **18/20 (90%)** | **11/20 (55%)** | **13/20 (65%)** |

### Speed & Resource Comparison

| Metric | LXPEN | HC (3.5K+best64) | HC (100K+best64) |
|---|---|---|---|
| Wall-clock time | **0.56s** | 2.53s | 3.95s |
| User CPU time | 1.20s | 1.56s | 5.58s |
| System CPU time | 0.28s | 0.44s | 1.02s |
| CPU utilization | 266% (6 cores) | 79% (1 core) | 166% (~2 cores) |
| Peak RAM (RSS) | **4.4 MB** | 470 MB | 475 MB |
| Disk I/O | **Zero** | Wordlist read | Wordlist read |
| Context switches | 283 | 619 | 1,715 |
| External files | **None** | 3.5K wordlist + rules | 100K wordlist + rules |

### Per-Hash Timing (LXPEN)

| Password | Time | Candidates tried |
|---|---|---|
| superman1 | 4ms | ~300 |
| password123 | 4ms | ~1 |
| dragon69 | 4ms | ~69 |
| Shadow99 | 8ms | ~10K |
| password | 13ms | ~23K |
| butterfly | 13ms | ~23K |
| fenerbahce1907 | 16ms | ~23K |
| Michael1994 | 38ms | ~236K |
| Galatasaray1905! | 67ms | ~294K |
| 123456 | 79ms | ~518K |
| h4ck3r666 | 211ms | ~1.6M |
| qwerty | 240ms | ~1.9M |
| P@ssw0rd123 | 255ms | ~1.9M |

Most passwords crack in under 100ms. The full 4.3M space exhausts in ~500ms.

---

## Usage

```bash
# Crack a single NTLM hash
lxpen crack 8846f7eaee8fb117ad06bdd830b7586c

# Crack MD5 / SHA-256 hashes
lxpen crack 5f4dcc3b5aa765d61d8327deb882cf99 --type md5
lxpen crack 5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8 --type sha256

# Crack multiple hashes from file (multi-target — fastest mode)
lxpen crack -f hashes.txt
lxpen crack -f md5_hashes.txt --type md5

# Generate hash for a password
lxpen hash "P@ssw0rd123"
lxpen hash "P@ssw0rd123" --type md5
lxpen hash "P@ssw0rd123" --type sha256

# Analyze a password — reverse-match to HPD patterns
lxpen analyze "Michael1994!"
lxpen analyze "xK9mZ2pLq"

# Full coverage report — all patterns, slots, candidate counts
lxpen coverage

# JSON output for scripting/automation
lxpen crack <hash> --json
lxpen analyze "password" --json
lxpen coverage --json

# Performance benchmark (hash rate, thread scaling)
lxpen bench

# Quick stats overview
lxpen stats
```

### Input Format

Hash file: one hash per line (32 hex chars for NTLM/MD5, 64 for SHA-256):
```
8846f7eaee8fb117ad06bdd830b7586c
32ed87bdb5fdc5e9cba88547376818d4
a9fdfa038c4b75ebc76dc855dd74f0da
```

---

## Usage Scenarios

### 1. Active Directory Password Audit

Extract NTLM hashes from AD using `secretsdump.py` or `mimikatz`, then audit password strength:

```bash
# Extract hashes (example with impacket)
secretsdump.py -just-dc-ntlm domain/admin@dc01.corp.local -outputfile ad_hashes

# Audit with LXPEN (no wordlist needed on the audit machine)
cat ad_hashes.ntds | cut -d: -f4 > ntlm_only.txt
lxpen crack -f ntlm_only.txt

# Result: instantly see which users have pattern-based passwords
```

**Advantage over Hashcat**: No need to download or maintain wordlists on the audit machine. LXPEN is a single 2MB binary with zero dependencies.

### 2. Penetration Testing (Internal Network)

During an internal pentest, after obtaining NTLM hashes via LLMNR/NBT-NS poisoning or relay attacks:

```bash
# Quick triage — which hashes are low-hanging fruit?
lxpen crack -f captured_hashes.txt

# Under 1 second for up to 100 hashes
# Immediately shows which accounts have weak passwords
```

**Use case**: Rapid triage before investing time in full Hashcat runs with massive wordlists.

### 3. CTF Competitions

In time-limited CTF environments where you can't download 10GB wordlists:

```bash
# LXPEN requires ZERO external files
# Copy the binary, crack immediately
lxpen crack <hash_from_challenge>
```

### 4. Red Team Operations

Minimal footprint on target systems:

- **4.4 MB RAM** — runs on resource-constrained boxes
- **Single binary** — no wordlists, no rules, no config files
- **Zero disk I/O** — no wordlist reads that could trigger alerts
- **Sub-second execution** — crack and move on

### 5. Password Policy Validation

Test whether your organization's password policy actually prevents weak passwords:

```bash
# Generate test passwords that comply with your policy
# (8+ chars, uppercase, lowercase, digit, symbol)
# Then check if LXPEN can crack them

lxpen hash "Company2024!" | cut -d'>' -f2 | tr -d ' ' | xargs lxpen crack
# → Cracked in 67ms. Policy is insufficient.
```

### 6. Security Research & Education

Study human password patterns:

```bash
# See the full pattern space
lxpen stats

# Understand which patterns are most common
# Patterns: 48
# Total candidate space: 26,638,972
# Top patterns by frequency:
#   1. lower_digits          (22.4%) — LowerWord + SeqDigits
#   2. cap_digits            (14.1%) — CapWord + SeqDigits
#   3. lower_only            (11.8%) — LowerWord
```

---

## Architecture

```
                    Crystal (orchestrator)
                    ┌──────────────────────────────┐
                    │  CLI          (cli.cr)        │
                    │  Patterns     (schema.cr)     │
                    │  Freq. Data   (frequency_data)│
                    │  Engine       (candidate_eng) │
                    │  HashType     (ntlm.cr)       │
                    └──────────┬───────────────────┘
                               │ FFI (slot pointers + hash type)
                               ▼
                    C Core (-O3 -march=native -pthread)
                    ┌──────────────────────────────┐
                    │  lxpen_crack_pattern()        │  ← NTLM fast path
                    │  lxpen_crack_pattern_typed()  │  ← MD5/SHA-256
                    │  ├─ Thread pool (N cores)     │
                    │  ├─ Cartesian product gen     │
                    │  ├─ Hash dispatch (NTLM/MD5/  │
                    │  │   SHA-256)                  │
                    │  └─ Multi-target compare      │
                    │     (atomic CAS early exit)    │
                    │                                │
                    │  lxpen_md5_hash()    (RFC 1321)│
                    │  lxpen_sha256_hash() (FIPS 180)│
                    │  lxpen_ntlm_hash()   (MD4)     │
                    └──────────────────────────────┘
```

### Data Flow (Multi-Target Mode)

```
1. Crystal reads hash file → parses N target hashes
2. For each of 48 patterns (sorted by frequency):
   a. Crystal builds flat slot arrays (pointers + lengths + counts)
   b. Crystal calls lxpen_crack_pattern[_typed]() via FFI
   c. C spawns thread pool, divides cartesian product space
   d. Each thread:
      - Decodes combination index → slot indices
      - Concatenates slot values into candidate buffer
      - Hashes via selected algorithm (NTLM/MD5/SHA-256)
      - Compares against all N active targets (atomic flags)
      - On match: CAS to claim target, store password
   e. Threads join, C returns found count
   f. Crystal reports newly found passwords
   g. If all targets found → early exit (skip remaining patterns)
3. If targets remain → hybrid brute-force [a-z0-9] 1-4 chars
4. Crystal prints summary (text or JSON)
```

### Why C + Crystal?

| Component | Language | Why |
|---|---|---|
| MD4 hashing | C | Inline assembly-level optimization with `-O3 -march=native` |
| Candidate generation | C | No GC pauses, no string allocation overhead, loop-level parallelism |
| Multi-threading | C (pthreads) | Direct control over thread pool, atomic operations, zero-overhead |
| UTF-16LE conversion | C | Inline byte manipulation, no encoding library needed |
| CLI / Pattern schema | Crystal | Clean type system, easy to extend patterns and slot data |
| Frequency tables | Crystal | Human-readable data definitions, compile-time validation |

---

## Extending LXPEN

### Adding Words to Existing Slots

Edit `src/patterns/frequency_data.cr`:

```crystal
LOWER_WORDS = [
  # Add your words with estimated frequency weight
  SlotEntry.new("mycompany", 0.003),
  SlotEntry.new("targetword", 0.002),
  ...
]
```

Higher frequency = tried earlier. Rebuild with `make rebuild`.

### Adding a New Language

Add name entries for your target language:

```crystal
NAMES = [
  # Existing EN+TR names...
  
  # German names
  SlotEntry.new("hans", 0.004), SlotEntry.new("klaus", 0.003),
  SlotEntry.new("petra", 0.003), SlotEntry.new("heidi", 0.002),
  
  # Arabic names
  SlotEntry.new("mohammed", 0.008), SlotEntry.new("ahmed", 0.006),
  SlotEntry.new("fatima", 0.005), SlotEntry.new("omar", 0.004),
]
```

Also add culturally significant words to `LOWER_WORDS` (team names, cities, etc.) and relevant years to `YEARS`.

### Adding a New Pattern

Define a new structural template:

```crystal
PATTERNS = [
  # Existing patterns...
  
  # New: Year + Name + Digits (e.g., "1994Michael23")
  Pattern.new("year_name_digits",
    [Slot.new(SlotType::Year), Slot.new(SlotType::CapName), Slot.new(SlotType::SeqDigits)],
    0.008  # estimated frequency
  ),
]
```

The candidate engine automatically generates all combinations for the new pattern.

### Adding a New Slot Type

1. Add to `SlotType` enum in `schema.cr`:
```crystal
enum SlotType
  # Existing types...
  CityName    # NEW
end
```

2. Add slot data in `frequency_data.cr`:
```crystal
CITIES = [
  SlotEntry.new("newyork", 0.005), SlotEntry.new("london", 0.004),
  SlotEntry.new("istanbul", 0.004), SlotEntry.new("paris", 0.003),
]
```

3. Map it in `get_slot_data`:
```crystal
when .city_name? then CITIES
```

4. Use it in patterns:
```crystal
Pattern.new("city_year", [Slot.new(SlotType::CityName), Slot.new(SlotType::Year)], 0.005),
```

### Adding a New Hash Type

The C core implements NTLM (MD4), MD5, and SHA-256. To add another (e.g., SHA-512):

1. Implement the hash function in `core/md4.c`
2. Add to `lxpen_hash_type_t` enum in `core/md4.h`
3. Wire it into `lxpen_hash_by_type()` and `lxpen_hash_size()`
4. Add FFI binding in `src/core/ntlm.cr`
5. Add to `HashType` enum in Crystal

The multi-threading and pattern engine remain identical — only the hash function changes.

---

## Build

### Requirements

- GCC (with `-O3 -march=native` support)
- Crystal >= 1.19.1
- pthreads (standard on Linux/macOS)
- Make

### Commands

```bash
make              # Build release (C core + Crystal, optimized)
make clean        # Remove build artifacts
make rebuild      # Clean + build
make spec         # Run Crystal test suite (26 tests)
make test_hashes  # Run C hash verification tests (13 vectors)
make test         # Run basic hash/crack smoke tests
make bench        # Run performance benchmark
```

### Build Output

```
gcc -O3 -march=native -Wall -Wextra -pthread -c core/md4.c -o core/md4.o
ar rcs core/liblxpen_core.a core/md4.o
crystal build --release src/main.cr -o lxpen
```

The final binary is `./lxpen` (~2MB, statically linked C core).

---

## Project Structure

```
lxpen/
  core/
    md4.c                  # C core: MD4/MD5/SHA-256, pattern crack engine, RAM table
    md4.h                  # C API header (hash type enum, all function declarations)
    test_hashes.c          # C-level hash verification tests (13 RFC/FIPS vectors)
  src/
    main.cr                # Entry point
    cli.cr                 # CLI: crack, hash, analyze, coverage, bench, stats
    lxpen.cr               # Module + version
    core/
      ntlm.cr              # Crystal FFI bindings + HashType enum + Hasher module
    patterns/
      schema.cr            # SlotType enum, Pattern/Slot/SlotEntry records
      frequency_data.cr    # 48 patterns, 900+ freq-weighted entries (EN+TR+DE+RU+AR)
    generator/
      candidate_engine.cr  # Pattern iteration, slot data provider
    precompute/
      ram_table.cr         # Legacy Crystal RAM table (superseded by C core)
  spec/
    spec_helper.cr         # Test helper
    lxpen_spec.cr          # 26 specs: hashing, patterns, engine, types
  benchmark/
    benchmark_v4.sh        # Full benchmark vs Hashcat
  docs/
    HPD-ALGORITHM.md       # Formal algorithm description (DOI: 10.5281/zenodo.20366383)
  Makefile                 # Build system
  shard.yml                # Crystal project config
```

---

## Benchmark Methodology

### Test Environment

- **CPU**: 6 cores (Contabo VPS)
- **RAM**: 12 GB
- **OS**: Linux 6.8.0
- **Crystal**: 1.19.1
- **GCC**: with `-O3 -march=native -pthread`
- **Hashcat**: v6.2.6, CPU-only (`-D 1 --force`)
- **No GPU** — pure CPU comparison

### Test Set Design

20 passwords across 5 difficulty tiers, chosen to represent real-world password patterns:

| Tier | Count | Selection Criteria |
|---|---|---|
| Trivial | 4 | Top-10 most common passwords globally |
| Word+Digits | 4 | Common word + 2-3 digit suffix |
| Name+Year | 4 | First name + 4-digit year (EN+TR mix) |
| L33t/Symbol | 4 | L33t substitutions, cultural words, symbol suffixes |
| Hard | 4 | Random strings, uncommon patterns |

### Hashcat Configurations

Two Hashcat configs tested to bracket typical usage:

1. **HC 3.5K**: John the Ripper's `password.lst` (3,546 words) + `best64.rule` (~228K candidates)
2. **HC 100K**: `100k-most-common.txt` + `best64.rule` (~6.4M candidates)

Both run with `--potfile-path` isolated per run to prevent caching effects.

### Measurement

- Wall-clock time: `date +%s%N` before/after (nanosecond precision)
- Resource usage: `/usr/bin/time -v` (RSS, CPU time, context switches)
- Each benchmark run is fresh (potfiles deleted, no caching)

### Fairness Notes

- LXPEN processes all 20 hashes simultaneously (multi-target). Hashcat does the same.
- Hashcat's exit code 1 (exhausted) is expected and handled.
- The 2 passwords neither tool cracks (`Tr0ub4dor&3`, `xK9#mZ2pLq`) are genuinely random — no pattern-based or small-wordlist approach can find them.

---

## Roadmap

- [x] **Hash type expansion**: MD5 + SHA-256 support *(v0.5.0)*
- [x] **Language packs**: German, Russian, Arabic names + cultural words *(v0.5.0)*
- [x] **Hybrid mode**: Post-pattern brute-force fallback *(v0.5.0)*
- [x] **Password analyzer**: Reverse-match passwords to HPD patterns *(v0.5.0)*
- [x] **JSON output**: Machine-readable output for automation *(v0.5.0)*
- [x] **Test suite**: Crystal specs + C hash verification tests *(v0.5.0)*
- [ ] **GPU acceleration**: Port hash hot loop to OpenCL/CUDA for 100x+ throughput
- [ ] **Adaptive patterns**: Learn pattern distributions from cracked hashes during a session
- [ ] **Markov chain slot ordering**: Order slot entries by character-level Markov probability instead of flat frequency
- [ ] **REST API**: Serve as a microservice for automated password auditing pipelines
- [ ] **More languages**: FR, JP, KR, ES, PT slot data
- [ ] **PCFG integration**: Merge Probabilistic Context-Free Grammar research into the pattern layer
- [ ] **Distributed cracking**: Split pattern space across multiple machines
- [ ] **Salted hash support**: bcrypt, scrypt, Argon2 (per-salt candidate generation)

---

## License

MIT License — Azizcan Dastan, 2026

---

## Acknowledgments

- Algorithm: **HPD (Hierarchical Probabilistic Decomposition)** — original research
- Inspiration: Arsene Lupin — *"Don't crack the password. Crack the idea."*
- Core engine: C with `-O3 -march=native`, Crystal orchestrator
- Built with assistance from Claude (Anthropic)
