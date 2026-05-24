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

/* ── MD5 core (RFC 1321) ───────────────────────────────── */

#undef F
#undef G
#undef H

#define MD5_F(x,y,z) (((x)&(y)) | ((~(x))&(z)))
#define MD5_G(x,y,z) (((x)&(z)) | ((y)&(~(z))))
#define MD5_H(x,y,z) ((x)^(y)^(z))
#define MD5_I(x,y,z) ((y) ^ ((x) | (~(z))))

static const uint32_t md5_T[64] = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391
};

static const int md5_s[64] = {
    7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
    5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
    4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
    6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21
};

static inline void md5_transform(const uint8_t block[64], uint32_t state[4])
{
    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t M[16];

    for (int i = 0; i < 16; i++)
        M[i] = (uint32_t)block[i*4]
             | ((uint32_t)block[i*4+1] << 8)
             | ((uint32_t)block[i*4+2] << 16)
             | ((uint32_t)block[i*4+3] << 24);

    for (int i = 0; i < 64; i++) {
        uint32_t f, g;
        if (i < 16) {
            f = MD5_F(b, c, d);
            g = (uint32_t)i;
        } else if (i < 32) {
            f = MD5_G(b, c, d);
            g = (5 * (uint32_t)i + 1) % 16;
        } else if (i < 48) {
            f = MD5_H(b, c, d);
            g = (3 * (uint32_t)i + 5) % 16;
        } else {
            f = MD5_I(b, c, d);
            g = (7 * (uint32_t)i) % 16;
        }
        uint32_t temp = d;
        d = c;
        c = b;
        b = b + ROL(a + f + md5_T[i] + M[g], md5_s[i]);
        a = temp;
    }

    state[0] += a; state[1] += b;
    state[2] += c; state[3] += d;
}

void lxpen_md5_hash(const uint8_t *data, size_t len, uint8_t out[16])
{
    uint32_t state[4] = {0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476};
    uint8_t block[64];
    size_t off = 0;

    while (off + 64 <= len) {
        md5_transform(data + off, state);
        off += 64;
    }

    size_t rem = len - off;
    memcpy(block, data + off, rem);
    block[rem] = 0x80;
    memset(block + rem + 1, 0, 64 - rem - 1);

    if (rem >= 56) {
        md5_transform(block, state);
        memset(block, 0, 64);
    }

    uint64_t bits = (uint64_t)len * 8;
    for (int i = 0; i < 8; i++)
        block[56 + i] = (uint8_t)(bits >> (i * 8));

    md5_transform(block, state);

    for (int i = 0; i < 4; i++) {
        out[i*4  ] = (uint8_t)(state[i]);
        out[i*4+1] = (uint8_t)(state[i] >> 8);
        out[i*4+2] = (uint8_t)(state[i] >> 16);
        out[i*4+3] = (uint8_t)(state[i] >> 24);
    }
}

/* ── SHA-256 core (FIPS 180-4) ─────────────────────────── */

#define SHA256_ROR(x,n) (((x)>>(n)) | ((x)<<(32-(n))))
#define SHA256_CH(x,y,z)  (((x)&(y)) ^ ((~(x))&(z)))
#define SHA256_MAJ(x,y,z) (((x)&(y)) ^ ((x)&(z)) ^ ((y)&(z)))
#define SHA256_SIGMA0(x) (SHA256_ROR(x,2)  ^ SHA256_ROR(x,13) ^ SHA256_ROR(x,22))
#define SHA256_SIGMA1(x) (SHA256_ROR(x,6)  ^ SHA256_ROR(x,11) ^ SHA256_ROR(x,25))
#define SHA256_sigma0(x) (SHA256_ROR(x,7)  ^ SHA256_ROR(x,18) ^ ((x)>>3))
#define SHA256_sigma1(x) (SHA256_ROR(x,17) ^ SHA256_ROR(x,19) ^ ((x)>>10))

static const uint32_t sha256_K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

static inline void sha256_transform(const uint8_t block[64], uint32_t state[8])
{
    uint32_t W[64];

    /* Big-endian load for first 16 words */
    for (int i = 0; i < 16; i++)
        W[i] = ((uint32_t)block[i*4] << 24)
             | ((uint32_t)block[i*4+1] << 16)
             | ((uint32_t)block[i*4+2] << 8)
             | ((uint32_t)block[i*4+3]);

    /* Message schedule expansion */
    for (int i = 16; i < 64; i++)
        W[i] = SHA256_sigma1(W[i-2]) + W[i-7] + SHA256_sigma0(W[i-15]) + W[i-16];

    uint32_t a = state[0], b = state[1], c = state[2], d = state[3];
    uint32_t e = state[4], f = state[5], g = state[6], h = state[7];

    for (int i = 0; i < 64; i++) {
        uint32_t T1 = h + SHA256_SIGMA1(e) + SHA256_CH(e, f, g) + sha256_K[i] + W[i];
        uint32_t T2 = SHA256_SIGMA0(a) + SHA256_MAJ(a, b, c);
        h = g;
        g = f;
        f = e;
        e = d + T1;
        d = c;
        c = b;
        b = a;
        a = T1 + T2;
    }

    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

void lxpen_sha256_hash(const uint8_t *data, size_t len, uint8_t out[32])
{
    uint32_t state[8] = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    };
    uint8_t block[64];
    size_t off = 0;

    while (off + 64 <= len) {
        sha256_transform(data + off, state);
        off += 64;
    }

    size_t rem = len - off;
    memcpy(block, data + off, rem);
    block[rem] = 0x80;
    memset(block + rem + 1, 0, 64 - rem - 1);

    if (rem >= 56) {
        sha256_transform(block, state);
        memset(block, 0, 64);
    }

    /* Big-endian length in bits */
    uint64_t bits = (uint64_t)len * 8;
    block[56] = (uint8_t)(bits >> 56);
    block[57] = (uint8_t)(bits >> 48);
    block[58] = (uint8_t)(bits >> 40);
    block[59] = (uint8_t)(bits >> 32);
    block[60] = (uint8_t)(bits >> 24);
    block[61] = (uint8_t)(bits >> 16);
    block[62] = (uint8_t)(bits >> 8);
    block[63] = (uint8_t)(bits);

    sha256_transform(block, state);

    /* Big-endian output */
    for (int i = 0; i < 8; i++) {
        out[i*4  ] = (uint8_t)(state[i] >> 24);
        out[i*4+1] = (uint8_t)(state[i] >> 16);
        out[i*4+2] = (uint8_t)(state[i] >> 8);
        out[i*4+3] = (uint8_t)(state[i]);
    }
}

/* ── Generic hash dispatch ─────────────────────────────── */

void lxpen_hash_by_type(lxpen_hash_type_t type, const char *password, size_t len, uint8_t *out)
{
    switch (type) {
        case LXPEN_HASH_NTLM:
            lxpen_ntlm_hash(password, len, out);
            break;
        case LXPEN_HASH_MD5:
            lxpen_md5_hash((const uint8_t *)password, len, out);
            break;
        case LXPEN_HASH_SHA256:
            lxpen_sha256_hash((const uint8_t *)password, len, out);
            break;
    }
}

int lxpen_hash_size(lxpen_hash_type_t type)
{
    switch (type) {
        case LXPEN_HASH_NTLM:  return 16;
        case LXPEN_HASH_MD5:   return 16;
        case LXPEN_HASH_SHA256: return 32;
        default: return 16;
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

int lxpen_hash_compare_n(const uint8_t *a, const uint8_t *b, int n)
{
    uint8_t diff = 0;
    for (int i = 0; i < n; i++)
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

/* ── Pattern-based crack: typed (multi-hash-algo) ────────── */

typedef struct {
    const uint8_t *targets;
    volatile uint8_t *active;
    int num_targets;
    int hash_size;
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
    lxpen_hash_type_t hash_type;
} crack_pattern_typed_arg_t;

static void *crack_pattern_typed_worker(void *arg)
{
    crack_pattern_typed_arg_t *a = (crack_pattern_typed_arg_t *)arg;
    a->newly_found = 0;
    a->tried = 0;

    char candidate[512];
    uint8_t hash[LXPEN_MAX_HASH_SIZE];
    int hs = a->hash_size;

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

        lxpen_hash_by_type(a->hash_type, candidate, cand_len, hash);
        a->tried++;

        for (int t = 0; t < a->num_targets; t++) {
            if (!__atomic_load_n(&a->active[t], __ATOMIC_RELAXED))
                continue;
            if (lxpen_hash_compare_n(hash, a->targets + t * hs, hs)) {
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
    lxpen_hash_type_t hash_type)
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
    crack_pattern_typed_arg_t *args = (crack_pattern_typed_arg_t *)malloc(sizeof(crack_pattern_typed_arg_t) * num_threads);

    size_t chunk = total_combos / num_threads;
    size_t remainder = total_combos % num_threads;
    size_t offset = 0;

    for (int i = 0; i < num_threads; i++) {
        args[i].targets = targets;
        args[i].active = (volatile uint8_t *)active;
        args[i].num_targets = num_targets;
        args[i].hash_size = hash_size;
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
        args[i].hash_type = hash_type;
        offset = args[i].end;
        pthread_create(&threads[i], NULL, crack_pattern_typed_worker, &args[i]);
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
