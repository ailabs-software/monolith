#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

/** The request.c protocol

  *  Architecture:
  *  The child process sends requests to parent process via stdout,
  *  the parent process responds via stdin.
  *  The loop is blocking in the child process (request.c), commands/responses stay in order.
  *
  *  This is the child process side.
  *  See request.dart for parent process side.
 */

static void put_string(const char* str)
{
  int i = 0;
  while (str[i] != '\0')
  {
    putchar(str[i]);
    i++;
  }
}

// eliminate any ':' character from path, replacing with ';' as are not allowed.
static char* sanitise_path(const char* path)
{
  char *sanitised_path = strdup(path);  // Create a modifiable copy
  if (sanitised_path != NULL) {
    char *ptr = sanitised_path;
    while (*ptr)
    {
      if (*ptr == ':') { // cannot allow separator char used by request.c protocol in path
        *ptr = ';';
      }
      ptr++;
    }
  }
  return sanitised_path;
}

// start request, sending initial parameters (the header)
static void send_request_start(const char* type, const char* path, int x_param, int y_param)
{
  // eliminate any ':' character from path, replacing with ';' as are not allowed.
  char *sanitised_path = sanitise_path(path);

  fprintf(stdout, "req-%s:%s:%i:%i:", type, sanitised_path, x_param, y_param);
  // note: dangling ':' waiting for string_param payload sent by send_request_complete()
  free(sanitised_path);  // Clean up allocated memory
}

// finish the request, send string_param (body)
static char* send_request_complete(const char* string_param)
{
  put_string(string_param);
  putchar('\n');
  fflush(stdout); // Ensure output appears before waiting
  // getline dynamically allocates enough space for the input, blocking until a newline is
  char *line = NULL;
  size_t len = 0;
  ssize_t nread = getline(&line, &len, stdin);
  if (nread != -1) {
    // remove newline
    line[nread - 1] = '\0';
    return line;
  }
  return 0;
}

char* send_request_with(const char* type, const char* path, int x_param, int y_param, const char* string_param)
{
  send_request_start(type, path, x_param, y_param);
  return send_request_complete(string_param);
}

char* send_request(const char* type, const char* path)
{
  send_request_start(type, path, 0, 0);
  return send_request_complete("");
}