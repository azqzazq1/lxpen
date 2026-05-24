#include "md4.h"
#include <stdio.h>
#include <string.h>

static void print_hex(const uint8_t *data, int len)
{
    for (int i = 0; i < len; i++)
        printf("%02x", data[i]);
}

static int check(const char *label, const uint8_t *got, const uint8_t *expected, int len)
{
    if (memcmp(got, expected, len) == 0) {
        printf("[PASS] %s: ", label);
        print_hex(got, len);
        printf("\n");
        return 0;
    } else {
        printf("[FAIL] %s\n  got:      ", label);
        print_hex(got, len);
        printf("\n  expected: ");
        print_hex(expected, len);
        printf("\n");
        return 1;
    }
}

int main(void)
{
    int fails = 0;
    uint8_t out[32];

    /* ── MD5 test vectors (RFC 1321) ── */

    /* MD5("") = d41d8cd98f00b204e9800998ecf8427e */
    lxpen_md5_hash((const uint8_t *)"", 0, out);
    uint8_t md5_empty[] = {0xd4,0x1d,0x8c,0xd9,0x8f,0x00,0xb2,0x04,
                           0xe9,0x80,0x09,0x98,0xec,0xf8,0x42,0x7e};
    fails += check("MD5('')", out, md5_empty, 16);

    /* MD5("a") = 0cc175b9c0f1b6a831c399e269772661 */
    lxpen_md5_hash((const uint8_t *)"a", 1, out);
    uint8_t md5_a[] = {0x0c,0xc1,0x75,0xb9,0xc0,0xf1,0xb6,0xa8,
                       0x31,0xc3,0x99,0xe2,0x69,0x77,0x26,0x61};
    fails += check("MD5('a')", out, md5_a, 16);

    /* MD5("abc") = 900150983cd24fb0d6963f7d28e17f72 */
    lxpen_md5_hash((const uint8_t *)"abc", 3, out);
    uint8_t md5_abc[] = {0x90,0x01,0x50,0x98,0x3c,0xd2,0x4f,0xb0,
                         0xd6,0x96,0x3f,0x7d,0x28,0xe1,0x7f,0x72};
    fails += check("MD5('abc')", out, md5_abc, 16);

    /* MD5("message digest") = f96b697d7cb7938d525a2f31aaf161d0 */
    lxpen_md5_hash((const uint8_t *)"message digest", 14, out);
    uint8_t md5_msgdig[] = {0xf9,0x6b,0x69,0x7d,0x7c,0xb7,0x93,0x8d,
                            0x52,0x5a,0x2f,0x31,0xaa,0xf1,0x61,0xd0};
    fails += check("MD5('message digest')", out, md5_msgdig, 16);

    /* MD5("abcdefghijklmnopqrstuvwxyz") = c3fcd3d76192e4007dfb496cca67e13b */
    lxpen_md5_hash((const uint8_t *)"abcdefghijklmnopqrstuvwxyz", 26, out);
    uint8_t md5_az[] = {0xc3,0xfc,0xd3,0xd7,0x61,0x92,0xe4,0x00,
                        0x7d,0xfb,0x49,0x6c,0xca,0x67,0xe1,0x3b};
    fails += check("MD5('a..z')", out, md5_az, 16);

    /* ── SHA-256 test vectors (FIPS 180-4) ── */

    /* SHA256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 */
    lxpen_sha256_hash((const uint8_t *)"", 0, out);
    uint8_t sha_empty[] = {0xe3,0xb0,0xc4,0x42,0x98,0xfc,0x1c,0x14,
                           0x9a,0xfb,0xf4,0xc8,0x99,0x6f,0xb9,0x24,
                           0x27,0xae,0x41,0xe4,0x64,0x9b,0x93,0x4c,
                           0xa4,0x95,0x99,0x1b,0x78,0x52,0xb8,0x55};
    fails += check("SHA256('')", out, sha_empty, 32);

    /* SHA256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad */
    lxpen_sha256_hash((const uint8_t *)"abc", 3, out);
    uint8_t sha_abc[] = {0xba,0x78,0x16,0xbf,0x8f,0x01,0xcf,0xea,
                         0x41,0x41,0x40,0xde,0x5d,0xae,0x22,0x23,
                         0xb0,0x03,0x61,0xa3,0x96,0x17,0x7a,0x9c,
                         0xb4,0x10,0xff,0x61,0xf2,0x00,0x15,0xad};
    fails += check("SHA256('abc')", out, sha_abc, 32);

    /* SHA256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
       = 248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1 */
    const char *s448 = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq";
    lxpen_sha256_hash((const uint8_t *)s448, strlen(s448), out);
    uint8_t sha_448[] = {0x24,0x8d,0x6a,0x61,0xd2,0x06,0x38,0xb8,
                         0xe5,0xc0,0x26,0x93,0x0c,0x3e,0x60,0x39,
                         0xa3,0x3c,0xe4,0x59,0x64,0xff,0x21,0x67,
                         0xf6,0xec,0xed,0xd4,0x19,0xdb,0x06,0xc1};
    fails += check("SHA256(448-bit)", out, sha_448, 32);

    /* SHA256("password") = 5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8 */
    lxpen_sha256_hash((const uint8_t *)"password", 8, out);
    uint8_t sha_pw[] = {0x5e,0x88,0x48,0x98,0xda,0x28,0x04,0x71,
                        0x51,0xd0,0xe5,0x6f,0x8d,0xc6,0x29,0x27,
                        0x73,0x60,0x3d,0x0d,0x6a,0xab,0xbd,0xd6,
                        0x2a,0x11,0xef,0x72,0x1d,0x15,0x42,0xd8};
    fails += check("SHA256('password')", out, sha_pw, 32);

    /* ── hash_by_type / hash_size tests ── */
    printf("\nhash_size(NTLM)=%d hash_size(MD5)=%d hash_size(SHA256)=%d\n",
           lxpen_hash_size(LXPEN_HASH_NTLM),
           lxpen_hash_size(LXPEN_HASH_MD5),
           lxpen_hash_size(LXPEN_HASH_SHA256));

    /* hash_by_type MD5 */
    lxpen_hash_by_type(LXPEN_HASH_MD5, "abc", 3, out);
    fails += check("hash_by_type(MD5,'abc')", out, md5_abc, 16);

    /* hash_by_type SHA256 */
    lxpen_hash_by_type(LXPEN_HASH_SHA256, "abc", 3, out);
    fails += check("hash_by_type(SHA256,'abc')", out, sha_abc, 32);

    /* hash_compare_n */
    uint8_t a32[32] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,
                       17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32};
    uint8_t b32[32];
    memcpy(b32, a32, 32);
    if (lxpen_hash_compare_n(a32, b32, 32))
        printf("[PASS] hash_compare_n equal\n");
    else { printf("[FAIL] hash_compare_n equal\n"); fails++; }
    b32[31] ^= 0xff;
    if (!lxpen_hash_compare_n(a32, b32, 32))
        printf("[PASS] hash_compare_n differ\n");
    else { printf("[FAIL] hash_compare_n differ\n"); fails++; }

    printf("\n%s (%d failures)\n", fails == 0 ? "ALL TESTS PASSED" : "SOME TESTS FAILED", fails);
    return fails;
}
