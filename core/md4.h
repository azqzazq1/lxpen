#ifndef LXPEN_MD4_H
#define LXPEN_MD4_H

#include <stdint.h>
#include <stddef.h>

/* ── Hash type enum ───────────────────────────────────────── */
typedef enum {
    LXPEN_HASH_NTLM = 0,
    LXPEN_HASH_MD5 = 1,
    LXPEN_HASH_SHA256 = 2
} lxpen_hash_type_t;

/* Hash size helper */
#define LXPEN_MAX_HASH_SIZE 32

/* ── Single hash: NTLM (MD4 of UTF-16LE) ─────────────────── */
void lxpen_ntlm_hash(const char *password, size_t len, uint8_t out[16]);
void lxpen_ntlm_hash_utf16(const uint8_t *utf16le, size_t byte_len, uint8_t out[16]);

/* ── MD5 hash ─────────────────────────────────────────────── */
void lxpen_md5_hash(const uint8_t *data, size_t len, uint8_t out[16]);

/* ── SHA-256 hash ─────────────────────────────────────────── */
void lxpen_sha256_hash(const uint8_t *data, size_t len, uint8_t out[32]);

/* ── Generic hash by type ─────────────────────────────────── */
void lxpen_hash_by_type(lxpen_hash_type_t type, const char *password, size_t len, uint8_t *out);
int lxpen_hash_size(lxpen_hash_type_t type);

/* Batch hash */
void lxpen_ntlm_batch(const char **passwords, const size_t *lengths,
                       size_t count, uint8_t *out);

/* Compare */
int lxpen_hash_compare(const uint8_t a[16], const uint8_t b[16]);
int lxpen_hash_compare_n(const uint8_t *a, const uint8_t *b, int n);

/* Multi-thread crack: returns index or -1 */
int lxpen_crack_batch(const uint8_t target[16],
                      const char **passwords, const size_t *lengths,
                      size_t count, int num_threads);

int lxpen_cpu_count(void);

/* RAM table (flat open-addressing) */
typedef struct lxpen_ram_table lxpen_ram_table_t;

lxpen_ram_table_t *lxpen_ram_create(size_t capacity);
void lxpen_ram_destroy(lxpen_ram_table_t *t);
void lxpen_ram_insert(lxpen_ram_table_t *t, const char *password, size_t len);
const char *lxpen_ram_lookup(lxpen_ram_table_t *t, const uint8_t hash[16]);
size_t lxpen_ram_size(lxpen_ram_table_t *t);

/* Batch insert: insert many passwords at once, avoids per-call overhead */
void lxpen_ram_insert_batch(lxpen_ram_table_t *t,
                            const char **passwords, const size_t *lengths,
                            size_t count);

/* Multi-thread RAM build: insert passwords using N threads */
void lxpen_ram_build_mt(lxpen_ram_table_t *t,
                        const char **passwords, const size_t *lengths,
                        size_t count, int num_threads);

/* Pattern-based crack: C-native candidate generation + multi-target compare.
   slot_values_flat / slot_lengths_flat are concatenated per-slot entries.
   slot_counts[s] = number of entries for slot s.
   match_pw_idx[t] set to 1 when target t is found.
   match_passwords + t*128 receives the cracked password string.
   Returns number of newly cracked targets. */
#define LXPEN_MAX_SLOTS 8
int lxpen_crack_pattern(
    const uint8_t *targets, uint8_t *active, int num_targets,
    int num_slots,
    const char **slot_values_flat,
    const size_t *slot_lengths_flat,
    const size_t *slot_counts,
    int num_threads,
    int *match_pw_idx,
    char *match_passwords,
    size_t *total_tried);

/* Pattern-based crack with hash type support */
int lxpen_crack_pattern_typed(
    const uint8_t *targets, uint8_t *active, int num_targets,
    int hash_size,
    int num_slots,
    const char **slot_values_flat,
    const size_t *slot_lengths_flat,
    const size_t *slot_counts,
    int num_threads,
    int *match_pw_idx,
    char *match_passwords,
    size_t *total_tried,
    lxpen_hash_type_t hash_type);

#endif
