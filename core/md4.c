#include "md4.h"
#include <string.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

/* ── MD4 core ───────────────────────────────────────────── */

#define F(x,y,z) (((x)&(y)) | ((~(x))&(z)))
#define G(x,y,z) (((x)&(y)) | ((x)&(z)) | ((y)&(z)))
#define H(x,y,z) ((x)^(y)^(z))

#define ROL(x,n) (((x)<<(n)) | ((x)>>(32-(n))))

#define R1(a,b,c,d,x,s) a = ROL((a) + F(b,c,d) + (x), s)
#define R2(a,b,c,d,x,s) a = ROL((a) + G(b,c,d) + (x) + 0x5A827999u, s)
#define R3(a,b,c,d,x,s) a = ROL((a) + H(b,c,d) + (x) + 0x6ED9EBA1u, s)

static inline void md4_transform(const uint8_t block[64], uint32_t state[4])
{
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t x[16];

    for (int i = 0; i < 16; i++)
        x[i] = (uint32_t)block[i*4]
             | ((uint32_t)block[i*4+1] << 8)
             | ((uint32_t)block[i*4+2] << 16)
             | ((uint32_t)block[i*4+3] << 24);

    R1(a,b,c,d,x[ 0], 3); R1(d,a,b,c,x[ 1], 7);
    R1(c,d,a,b,x[ 2],11); R1(b,c,d,a,x[ 3],19);
    R1(a,b,c,d,x[ 4], 3); R1(d,a,b,c,x[ 5], 7);
    R1(c,d,a,b,x[ 6],11); R1(b,c,d,a,x[ 7],19);
    R1(a,b,c,d,x[ 8], 3); R1(d,a,b,c,x[ 9], 7);
    R1(c,d,a,b,x[10],11); R1(b,c,d,a,x[11],19);
    R1(a,b,c,d,x[12], 3); R1(d,a,b,c,x[13], 7);
    R1(c,d,a,b,x[14],11); R1(b,c,d,a,x[15],19);

    R2(a,b,c,d,x[ 0], 3); R2(d,a,b,c,x[ 4], 5);
    R2(c,d,a,b,x[ 8], 9); R2(b,c,d,a,x[12],13);
    R2(a,b,c,d,x[ 1], 3); R2(d,a,b,c,x[ 5], 5);
    R2(c,d,a,b,x[ 9], 9); R2(b,c,d,a,x[13],13);
    R2(a,b,c,d,x[ 2], 3); R2(d,a,b,c,x[ 6], 5);
    R2(c,d,a,b,x[10], 9); R2(b,c,d,a,x[14],13);
    R2(a,b,c,d,x[ 3], 3); R2(d,a,b,c,x[ 7], 5);
    R2(c,d,a,b,x[11], 9); R2(b,c,d,a,x[15],13);

    R3(a,b,c,d,x[ 0], 3); R3(d,a,b,c,x[ 8], 9);
    R3(c,d,a,b,x[ 4],11); R3(b,c,d,a,x[12],15);
    R3(a,b,c,d,x[ 2], 3); R3(d,a,b,c,x[10], 9);
    R3(c,d,a,b,x[ 6],11); R3(b,c,d,a,x[14],15);
    R3(a,b,c,d,x[ 1], 3); R3(d,a,b,c,x[ 9], 9);
    R3(c,d,a,b,x[ 5],11); R3(b,c,d,a,x[13],15);
    R3(a,b,c,d,x[ 3], 3); R3(d,a,b,c,x[11], 9);
    R3(c,d,a,b,x[ 7],11); R3(b,c,d,a,x[15],15);

    state[0] += a; state[1] += b;
    state[2] += c; state[3] += d;
}

static void md4_hash(const uint8_t *data, size_t len, uint8_t out[16])
{
    uint32_t state[4] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476};
    uint8_t block[64];
    size_t off = 0;

    while (off + 64 <= len) {
        md4_transform(data + off, state);
        off += 64;
    }

    size_t rem = len - off;
    memcpy(block, data + off, rem);
    block[rem] = 0x80;
    memset(block + rem + 1, 0, 64 - rem - 1);

    if (rem >= 56) {
        md4_transform(block, state);
        memset(block, 0, 64);
    }

    uint64_t bits = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++)
        block[56 + i] = (uint8_t)(bits >> (i * 8));

    md4_transform(block, state);

    for (int i = 0; i < 4; i++) {
        out[i*4  ] = (uint8_t)(state[i]);
        out[i*4+1] = (uint8_t)(state[i] >> 8);
        out[i*4+2] = (uint8_t)(state[i] >> 16);
        out[i*4+3] = (uint8_t)(state[i] >> 24);
    }
}

/* ── Public: single hash ────────────────────────────────── */

void lxpen_ntlm_hash(const char *password, size_t len, uint8_t out[16])
{
    uint8_t utf16[512];
    size_t u16len = 0;
    for (size_t i = 0; i < len && u16len + 1 < sizeof(utf16); i++) {
        utf16[u16len++] = (uint8_t)password[i];
        utf16[u16len++] = 0;
    }
    md4_hash(utf16, u16len, out);
}

void lxpen_ntlm_hash_utf16(const uint8_t *utf16le, size_t byte_len, uint8_t out[16])
{
    md4_hash(utf16le, byte_len, out);
}

void lxpen_ntlm_batch(const char **passwords, const size_t *lengths,
                       size_t count, uint8_t *out)
{
    for (size_t i = 0; i < count; i++)
        lxpen_ntlm_hash(passwords[i], lengths[i], out + i * 16);
}

int lxpen_hash_compare(const uint8_t a[16], const uint8_t b[16])
{
    uint8_t diff = 0;
    for (int i = 0; i < 16; i++)
        diff |= a[i] ^ b[i];
    return diff == 0;
}

/* ── Multi-threaded crack ───────────────────────────────── */

typedef struct {
    const uint8_t *target;
    const char **passwords;
    const size_t *lengths;
    size_t start;
    size_t end;
    volatile int *found_flag;
    int result;
} crack_thread_arg_t;

static void *crack_worker(void *arg)
{
    crack_thread_arg_t *a = (crack_thread_arg_t *)arg;
    uint8_t hash[16];
    a->result = -1;

    for (size_t i = a->start; i < a->end; i++) {
        if (__atomic_load_n(a->found_flag, __ATOMIC_RELAXED))
            return NULL;
        lxpen_ntlm_hash(a->passwords[i], a->lengths[i], hash);
        if (lxpen_hash_compare(a->target, hash)) {
            a->result = (int)i;
            __atomic_store_n(a->found_flag, 1, __ATOMIC_RELAXED);
            return NULL;
        }
    }
    return NULL;
}

int lxpen_crack_batch(const uint8_t target[16],
                      const char **passwords, const size_t *lengths,
                      size_t count, int num_threads)
{
    if (count == 0) return -1;
    if (num_threads < 1) num_threads = 1;
    if ((size_t)num_threads > count) num_threads = (int)count;

    volatile int found_flag = 0;
    pthread_t *threads = (pthread_t *)malloc(sizeof(pthread_t) * num_threads);
    crack_thread_arg_t *args = (crack_thread_arg_t *)malloc(sizeof(crack_thread_arg_t) * num_threads);

    size_t chunk = count / num_threads;
    size_t remainder = count % num_threads;
    size_t offset = 0;

    for (int t = 0; t < num_threads; t++) {
        args[t].target = target;
        args[t].passwords = passwords;
        args[t].lengths = lengths;
        args[t].start = offset;
        args[t].end = offset + chunk + (t < (int)remainder ? 1 : 0);
        args[t].found_flag = &found_flag;
        args[t].result = -1;
        offset = args[t].end;
        pthread_create(&threads[t], NULL, crack_worker, &args[t]);
    }

    int result = -1;
    for (int t = 0; t < num_threads; t++) {
        pthread_join(threads[t], NULL);
        if (args[t].result >= 0)
            result = args[t].result;
    }

    free(threads);
    free(args);
    return result;
}

int lxpen_cpu_count(void)
{
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (int)n : 1;
}

/* ── RAM table: flat open-addressing ────────────────────── */

#define RAM_EMPTY   0
#define RAM_OCCUPIED 1
#define RAM_MAX_PW  128

typedef struct {
    uint8_t hash[16];
    char password[RAM_MAX_PW];
    uint8_t occupied;
} ram_slot_t;

struct lxpen_ram_table {
    ram_slot_t *slots;
    size_t capacity;
    size_t size;
    pthread_mutex_t lock;
};

static inline size_t ram_hash_idx(const uint8_t hash[16], size_t cap)
{
    uint64_t h = *(const uint64_t *)hash;
    return (size_t)(h % cap);
}

lxpen_ram_table_t *lxpen_ram_create(size_t capacity)
{
    lxpen_ram_table_t *t = (lxpen_ram_table_t *)calloc(1, sizeof(*t));
    t->capacity = capacity * 2;
    t->slots = (ram_slot_t *)calloc(t->capacity, sizeof(ram_slot_t));
    t->size = 0;
    pthread_mutex_init(&t->lock, NULL);
    return t;
}

void lxpen_ram_destroy(lxpen_ram_table_t *t)
{
    if (!t) return;
    free(t->slots);
    pthread_mutex_destroy(&t->lock);
    free(t);
}

void lxpen_ram_insert(lxpen_ram_table_t *t, const char *password, size_t len)
{
    uint8_t hash[16];
    lxpen_ntlm_hash(password, len, hash);

    size_t idx = ram_hash_idx(hash, t->capacity);

    for (size_t probe = 0; probe < t->capacity; probe++) {
        size_t i = (idx + probe) % t->capacity;
        if (t->slots[i].occupied == RAM_EMPTY) {
            memcpy(t->slots[i].hash, hash, 16);
            size_t copy_len = len < RAM_MAX_PW - 1 ? len : RAM_MAX_PW - 1;
            memcpy(t->slots[i].password, password, copy_len);
            t->slots[i].password[copy_len] = 0;
            t->slots[i].occupied = RAM_OCCUPIED;
            t->size++;
            return;
        }
    }
}

const char *lxpen_ram_lookup(lxpen_ram_table_t *t, const uint8_t hash[16])
{
    size_t idx = ram_hash_idx(hash, t->capacity);

    for (size_t probe = 0; probe < t->capacity; probe++) {
        size_t i = (idx + probe) % t->capacity;
        if (t->slots[i].occupied == RAM_EMPTY)
            return NULL;
        if (lxpen_hash_compare(t->slots[i].hash, hash))
            return t->slots[i].password;
    }
    return NULL;
}

size_t lxpen_ram_size(lxpen_ram_table_t *t)
{
    return t->size;
}

void lxpen_ram_insert_batch(lxpen_ram_table_t *t,
                            const char **passwords, const size_t *lengths,
                            size_t count)
{
    for (size_t i = 0; i < count; i++)
        lxpen_ram_insert(t, passwords[i], lengths[i]);
}

/* Multi-threaded RAM build */
typedef struct {
    lxpen_ram_table_t *table;
    const char **passwords;
    const size_t *lengths;
    size_t start;
    size_t end;
} ram_build_arg_t;

static void *ram_build_worker(void *arg)
{
    ram_build_arg_t *a = (ram_build_arg_t *)arg;
    uint8_t hash[16];

    for (size_t i = a->start; i < a->end; i++) {
        lxpen_ntlm_hash(a->passwords[i], a->lengths[i], hash);
        size_t idx = ram_hash_idx(hash, a->table->capacity);

        pthread_mutex_lock(&a->table->lock);
        for (size_t probe = 0; probe < a->table->capacity; probe++) {
            size_t slot = (idx + probe) % a->table->capacity;
            if (a->table->slots[slot].occupied == RAM_EMPTY) {
                memcpy(a->table->slots[slot].hash, hash, 16);
                size_t len = a->lengths[i];
                size_t copy_len = len < RAM_MAX_PW - 1 ? len : RAM_MAX_PW - 1;
                memcpy(a->table->slots[slot].password, a->passwords[i], copy_len);
                a->table->slots[slot].password[copy_len] = 0;
                a->table->slots[slot].occupied = RAM_OCCUPIED;
                a->table->size++;
                break;
            }
        }
        pthread_mutex_unlock(&a->table->lock);
    }
    return NULL;
}

void lxpen_ram_build_mt(lxpen_ram_table_t *t,
                        const char **passwords, const size_t *lengths,
                        size_t count, int num_threads)
{
    if (num_threads < 1) num_threads = 1;
    if ((size_t)num_threads > count) num_threads = (int)count;

    pthread_t *threads = (pthread_t *)malloc(sizeof(pthread_t) * num_threads);
    ram_build_arg_t *args = (ram_build_arg_t *)malloc(sizeof(ram_build_arg_t) * num_threads);

    size_t chunk = count / num_threads;
    size_t remainder = count % num_threads;
    size_t offset = 0;

    for (int i = 0; i < num_threads; i++) {
        args[i].table = t;
        args[i].passwords = passwords;
        args[i].lengths = lengths;
        args[i].start = offset;
        args[i].end = offset + chunk + (i < (int)remainder ? 1 : 0);
        offset = args[i].end;
        pthread_create(&threads[i], NULL, ram_build_worker, &args[i]);
    }

    for (int i = 0; i < num_threads; i++)
        pthread_join(threads[i], NULL);

    free(threads);
    free(args);
}

/* ── Pattern-based crack: C-native generation + multi-target ── */

typedef struct {
    const uint8_t *targets;
    volatile uint8_t *active;
    int num_targets;
    int num_slots;
    const char **slot_values_flat;
    const size_t *slot_lengths_flat;
    const size_t *slot_counts;
    size_t slot_offsets[LXPEN_MAX_SLOTS];
    size_t divisors[LXPEN_MAX_SLOTS];
    size_t start;
    size_t end;
    volatile int *all_done;
    int *match_pw_idx;
    char *match_passwords;
    int newly_found;
    size_t tried;
} crack_pattern_arg_t;

static void *crack_pattern_worker(void *arg)
{
    crack_pattern_arg_t *a = (crack_pattern_arg_t *)arg;
    a->newly_found = 0;
    a->tried = 0;

    char candidate[512];
    uint8_t utf16[1024];
    uint8_t hash[16];

    for (size_t k = a->start; k < a->end; k++) {
        if (__atomic_load_n(a->all_done, __ATOMIC_RELAXED))
            return NULL;

        size_t cand_len = 0;
        size_t rem = k;
        for (int s = 0; s < a->num_slots; s++) {
            size_t idx = rem / a->divisors[s];
            rem %= a->divisors[s];
            size_t flat_idx = a->slot_offsets[s] + idx;
            size_t slen = a->slot_lengths_flat[flat_idx];
            memcpy(candidate + cand_len, a->slot_values_flat[flat_idx], slen);
            cand_len += slen;
        }

        size_t u16len = 0;
        for (size_t i = 0; i < cand_len; i++) {
            utf16[u16len++] = (uint8_t)candidate[i];
            utf16[u16len++] = 0;
        }

        md4_hash(utf16, u16len, hash);
        a->tried++;

        for (int t = 0; t < a->num_targets; t++) {
            if (!__atomic_load_n(&a->active[t], __ATOMIC_RELAXED))
                continue;
            if (lxpen_hash_compare(hash, a->targets + t * 16)) {
                uint8_t expected = 1;
                if (__atomic_compare_exchange_n(
                        (uint8_t *)&a->active[t], &expected, 0,
                        0, __ATOMIC_ACQ_REL, __ATOMIC_RELAXED)) {
                    a->match_pw_idx[t] = 1;
                    size_t cl = cand_len < 127 ? cand_len : 127;
                    memcpy(a->match_passwords + t * 128, candidate, cl);
                    a->match_passwords[t * 128 + cl] = 0;
                    a->newly_found++;

                    int all = 1;
                    for (int tt = 0; tt < a->num_targets; tt++) {
                        if (__atomic_load_n(&a->active[tt], __ATOMIC_RELAXED)) {
                            all = 0;
                            break;
                        }
                    }
                    if (all)
                        __atomic_store_n(a->all_done, 1, __ATOMIC_RELEASE);
                }
                break;
            }
        }
    }
    return NULL;
}

int lxpen_crack_pattern(
    const uint8_t *targets, uint8_t *active, int num_targets,
    int num_slots,
    const char **slot_values_flat,
    const size_t *slot_lengths_flat,
    const size_t *slot_counts,
    int num_threads,
    int *match_pw_idx,
    char *match_passwords,
    size_t *total_tried)
{
    if (num_slots <= 0 || num_targets <= 0) return 0;

    size_t total_combos = 1;
    for (int s = 0; s < num_slots; s++)
        total_combos *= slot_counts[s];

    if (total_combos == 0) return 0;
    if (num_threads < 1) num_threads = 1;
    if ((size_t)num_threads > total_combos) num_threads = (int)total_combos;

    size_t slot_offsets[LXPEN_MAX_SLOTS];
    size_t divisors[LXPEN_MAX_SLOTS];

    slot_offsets[0] = 0;
    for (int s = 1; s < num_slots; s++)
        slot_offsets[s] = slot_offsets[s - 1] + slot_counts[s - 1];

    divisors[num_slots - 1] = 1;
    for (int s = num_slots - 2; s >= 0; s--)
        divisors[s] = divisors[s + 1] * slot_counts[s + 1];

    volatile int all_done = 0;
    pthread_t *threads = (pthread_t *)malloc(sizeof(pthread_t) * num_threads);
    crack_pattern_arg_t *args = (crack_pattern_arg_t *)malloc(sizeof(crack_pattern_arg_t) * num_threads);

    size_t chunk = total_combos / num_threads;
    size_t remainder = total_combos % num_threads;
    size_t offset = 0;

    for (int i = 0; i < num_threads; i++) {
        args[i].targets = targets;
        args[i].active = (volatile uint8_t *)active;
        args[i].num_targets = num_targets;
        args[i].num_slots = num_slots;
        args[i].slot_values_flat = slot_values_flat;
        args[i].slot_lengths_flat = slot_lengths_flat;
        args[i].slot_counts = slot_counts;
        memcpy(args[i].slot_offsets, slot_offsets, sizeof(size_t) * num_slots);
        memcpy(args[i].divisors, divisors, sizeof(size_t) * num_slots);
        args[i].start = offset;
        args[i].end = offset + chunk + (i < (int)remainder ? 1 : 0);
        args[i].all_done = &all_done;
        args[i].match_pw_idx = match_pw_idx;
        args[i].match_passwords = match_passwords;
        args[i].newly_found = 0;
        args[i].tried = 0;
        offset = args[i].end;
        pthread_create(&threads[i], NULL, crack_pattern_worker, &args[i]);
    }

    int total_found = 0;
    size_t total_t = 0;
    for (int i = 0; i < num_threads; i++) {
        pthread_join(threads[i], NULL);
        total_found += args[i].newly_found;
        total_t += args[i].tried;
    }
    *total_tried += total_t;

    free(threads);
    free(args);
    return total_found;
}
