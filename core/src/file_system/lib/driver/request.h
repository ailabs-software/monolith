#ifndef FUNC_H
#define FUNC_H

/** function prototypes */

/** send request for path with no parameters */
char* send_request(const char* type, const char* path);

/** send request for path with two parameters (int) */
char* send_request_with(const char* type, const char* path, int x_param, int y_param, const char* string_param);

#endif
