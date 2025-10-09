#include <stdint.h>
#include <stdlib.h>

#include <stdint.h>
#include <stddef.h>

// Base64 encoding table
static const char base64_table[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

int base64_encode(uint8_t *dst, size_t dlen, size_t *olen, const uint8_t *src, size_t slen)
{
    size_t required_len;
    size_t i, j;
    uint32_t octet_a, octet_b, octet_c, triple;

    // Calculate required output length: (input_len + 2) / 3 * 4
    required_len = ((slen + 2) / 3) * 4;

    // Set output length
    if (olen) {
        *olen = required_len;
    }

    // Check if destination buffer is large enough
    if (dst == NULL || dlen < required_len) {
        return -1;  // Buffer too small or NULL
    }

    // Perform encoding
    for (i = 0, j = 0; i < slen; ) {
        // Get three input bytes (pad with zeros if needed)
        octet_a = i < slen ? src[i++] : 0;
        octet_b = i < slen ? src[i++] : 0;
        octet_c = i < slen ? src[i++] : 0;

        // Combine into 24-bit triple
        triple = (octet_a << 16) + (octet_b << 8) + octet_c;

        // Extract four 6-bit values and encode
        dst[j++] = base64_table[(triple >> 18) & 0x3F];
        dst[j++] = base64_table[(triple >> 12) & 0x3F];
        dst[j++] = base64_table[(triple >> 6) & 0x3F];
        dst[j++] = base64_table[triple & 0x3F];
    }

    // Add padding characters if necessary
    size_t padding = slen % 3;
    if (padding == 1) {
        dst[j - 1] = '=';
        dst[j - 2] = '=';
    } else if (padding == 2) {
        dst[j - 1] = '=';
    }

    return 0;  // Success
}


static const int T[128] = {
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,-1,
    -1,-1,-1,-1, -1,-1,-1,-1, -1,-1,-1,62, -1,-1,-1,63,
    52,53,54,55, 56,57,58,59, 60,61,-1,-1, -1,-2,-1,-1,
    -1, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,
    15,16,17,18, 19,20,21,22, 23,24,25,-1, -1,-1,-1,-1,
    -1,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,
    41,42,43,44, 45,46,47,48, 49,50,51,-1, -1,-1,-1,-1
};

unsigned char *base64_decode(const char *data, size_t input_length, size_t *output_length) {
    if (input_length % 4 != 0) return NULL;

    *output_length = input_length / 4 * 3;
    if (data[input_length - 1] == '=') (*output_length)--;
    if (data[input_length - 2] == '=') (*output_length)--;

    unsigned char *decoded_data = malloc(*output_length);
    if (decoded_data == NULL) return NULL;

    for (int i = 0, j = 0; i < input_length;) {
        uint32_t a = data[i] == '=' ? 0 & i++ : T[data[i++]];
        uint32_t b = data[i] == '=' ? 0 & i++ : T[data[i++]];
        uint32_t c = data[i] == '=' ? 0 & i++ : T[data[i++]];
        uint32_t d = data[i] == '=' ? 0 & i++ : T[data[i++]];

        uint32_t triple = (a << 3 * 6) + (b << 2 * 6) + (c << 1 * 6) + (d << 0 * 6);

        if (j < *output_length) decoded_data[j++] = (triple >> 2 * 8) & 0xFF;
        if (j < *output_length) decoded_data[j++] = (triple >> 1 * 8) & 0xFF;
        if (j < *output_length) decoded_data[j++] = (triple >> 0 * 8) & 0xFF;
    }

    return decoded_data;
}
