#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include <stdint.h> // For fixed-width integers like uint32_t
#include <unistd.h> // For ssize_t

#include "request.h"

/** The request.c binary protocol

  * Architecture:
  * The child process sends binary-formatted requests to parent process via stdout,
  * the parent process responds via stdin.
  * The protocol is length-prefixed to handle framing.
  *
  * This is the child process side.
  * See request.dart for parent process side.
 */

/**
 * @brief Writes a 32-bit unsigned integer as little-endian.
 */
static void write_u32_le(uint32_t val, FILE* stream)
{
  uint8_t buf[4];
  buf[0] = (uint8_t)(val & 0xFF);
  buf[1] = (uint8_t)((val >> 8) & 0xFF);
  buf[2] = (uint8_t)((val >> 16) & 0xFF);
  buf[3] = (uint8_t)((val >> 24) & 0xFF);
  fwrite(buf, 1, 4, stream);
}

/**
 * @brief Writes a 32-bit signed integer as little-endian.
 */
static void write_i32_le(int32_t val, FILE* stream)
{
  write_u32_le((uint32_t)val, stream);
}

/**
 * @brief Writes a block of bytes.
 */
static void write_bytes(const char* data, uint32_t len, FILE* stream)
{
  if (len > 0) {
    fwrite(data, 1, len, stream);
  }
}

/**
 * @brief Reads a 32-bit unsigned integer from little-endian stream.
 * @return 1 on success, 0 on failure/EOF.
 */
static int read_u32_le(uint32_t* val, FILE* stream)
{
  uint8_t buf[4];
  if (fread(buf, 1, 4, stream) != 4) {
    // Failed to read 4 bytes (EOF or error)
    return 0;
  }
  *val = ((uint32_t)buf[0]) |
         ((uint32_t)buf[1] << 8) |
         ((uint32_t)buf[2] << 16) |
         ((uint32_t)buf[3] << 24);
  return 1;
}

/**
 * @brief Calculate total packet length (sum of all fields *after* this length)
 * @return (len_field + data) * 3 strings + (int32) * 2 params
 */
uint32_t calculate_request_length(uint32_t type_len, uint32_t path_len, uint32_t data_param_len)
{
  return (4 + type_len) +
          (4 + path_len) +
          (4) + // x_param
          (4) + // y_param
          (4 + data_param_len);
}

void write_request_packet(const char* type, const char* path, int x_param, int y_param, const char* data, uint32_t data_len)
{
  uint32_t type_len = (uint32_t)strlen(type);
  uint32_t path_len = (uint32_t)strlen(path);

  uint32_t total_length = calculate_request_length(type_len, path_len, data_len);
  
  write_u32_le(total_length, stdout);     // Frame: Total packet length

  write_u32_le(type_len, stdout);         // Field: type_len
  write_bytes(type, type_len, stdout);    // Field: type_data

  write_u32_le(path_len, stdout);         // Field: path_len
  write_bytes(path, path_len, stdout);    // Field: path_data

  write_i32_le(x_param, stdout);          // Field: x_param
  write_i32_le(y_param, stdout);          // Field: y_param

  write_u32_le(data_len, stdout); // Field: data_len
  write_bytes(data, data_len, stdout); // Field: data

  fflush(stdout); // Ensure packet is sent before blocking
}

/**
 * @brief (Internal) Reads a length-prefixed response and returns it as a
 * new, null-terminated string.
 */
static char* read_string_response()
{
  uint32_t response_len;
  if (!read_u32_le(&response_len, stdin)) {
    return NULL;
  }

  char* response_buf = (char*)malloc(response_len + 1);
  if (response_buf == NULL) {
    return NULL;
  }

  if (response_len > 0) {
    size_t bytes_read = fread(response_buf, 1, response_len, stdin);
    if (bytes_read != response_len) {
      free(response_buf);
      return NULL;
    }
  }

  response_buf[response_len] = '\0'; // Add null terminator
  return response_buf;
}

/**
 * @brief (Internal) Reads a length-prefixed binary response into an existing buffer.
 */
static ssize_t read_binary_response(char* out_buf, size_t out_buf_max_len)
{
  uint32_t response_len;
  if (!read_u32_le(&response_len, stdin)) {
    return -1; // Read error
  }

  if (response_len > out_buf_max_len) {
    // Error: Response is larger than the provided buffer.
    // We must consume the data from stdin to not break the pipe.
    char* temp_buf = (char*)malloc(response_len);
    if (temp_buf) {
      fread(temp_buf, 1, response_len, stdin);
      free(temp_buf);
    }
    return -1; // Buffer too small
  }

  if (response_len == 0) {
    return 0; // No data to read
  }

  size_t bytes_read = fread(out_buf, 1, response_len, stdin);
  if (bytes_read != response_len) {
    return -1; // Read error
  }

  return (ssize_t)bytes_read;
}

char* send_string_request(const char* type, const char* path, int x_param, int y_param, const char* string_param)
{
  write_request_packet(type, path, x_param, y_param, string_param, (uint32_t)strlen(string_param));
  return read_string_response();
}

char* send_binary_request(const char* type, const char* path, int x_param, int y_param, const char* data, uint32_t data_len)
{
  write_request_packet(type, path, x_param, y_param, data, data_len);
  return read_string_response();
}

ssize_t send_request_for_binary(const char* type, const char* path, int x_param, int y_param, const char* string_param, char* out_buf, size_t out_buf_max_len)
{
  write_request_packet(type, path, x_param, y_param, string_param, (uint32_t)strlen(string_param));
  return read_binary_response(out_buf, out_buf_max_len);
}

char* send_request(const char* type, const char* path)
{
  return send_string_request(type, path, 0, 0, "");
}