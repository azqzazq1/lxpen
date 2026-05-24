#ifndef LXPEN_MD4_H
#define LXPEN_MD4_H

#include <stdint.h>
#include <stddef.h>

/* Single hash */
void lxpen_ntlm_hash(const char *password, size_t len, uint8_t out[16]);
void lxpen_ntlm_hash_utf16(const uint8_t *utf16le, size_t byte_len, uint8_t out[16]);

/* Batch hash */
void lxpen_ntlm_batch(const char **passwords, const size_t *lengths,
                       size_t count, uint8_t *out);

/* Compare */
int lxpen_hash_compare(const uint8_t a[16], const uint8_t b[16]);

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

#endif
