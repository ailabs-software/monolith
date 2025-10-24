#ifndef FUNC_H
#define FUNC_H

/** function prototypes */

/** Sends a request where the body is a C string, and expects a string response. */
char* send_string_request(const char* type, const char* path, int x_param, int y_param, const char* string_param);

/** Sends a request where the body is raw binary data, and expects a string response. */
char* send_binary_request(const char* type, const char* path, int x_param, int y_param, const char* data, uint32_t data_len);

/** Sends a request where the body is a C string, and expects a raw binary response. */
ssize_t send_request_for_binary(const char* type, const char* path, int x_param, int y_param, const char* string_param, char* out_buf, size_t out_buf_max_len);

/** Helper for simple string-in/string-out requests with no params. */
char* send_request(const char* type, const char* path);

#endif
