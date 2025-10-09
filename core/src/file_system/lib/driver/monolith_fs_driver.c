/*
  FUSE: Filesystem in Userspace
  Copyright (C) 2001-2007  Miklos Szeredi <miklos@szeredi.hu>

  This program can be distributed under the terms of the GNU GPLv2.
  See the file COPYING.
*/

#define FUSE_USE_VERSION 31

#include <stdlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <stddef.h>
#include <assert.h>
#include <fuse.h>
#include "request.h"
#include "cjson/cJSON.h"
#include "base64.h"

#ifndef RENAME_NOREPLACE
#define RENAME_NOREPLACE (1 << 0)
#endif

#ifndef RENAME_EXCHANGE
#define RENAME_EXCHANGE (1 << 1)
#endif

static void *monolith_fs_init(struct fuse_conn_info *conn, struct fuse_config *cfg)
{
  (void) conn;
  cfg->kernel_cache = 0;  // Disable kernel cache when using direct_io
  cfg->direct_io = 1;     // Enable direct I/O globally
  return NULL;
}

static bool check_exists(const char *path)
{
  char *response = send_request("exists", path);
  bool exists = strcmp(response, "1") == 0;
  free(response);
  return exists;
}

static bool check_file_writable(const char *path)
{
  char *response = send_request("file_writable", path);
  bool writable = strcmp(response, "1") == 0;
  free(response);
  return writable;
}

static int get_entity_type(const char *path)
{
  char *response = send_request("entity_type", path);
  int entity_type = atoi(response);
  free(response);
  return entity_type;
}

static int get_file_size(const char *path)
{
  char *response = send_request("file_size", path);
  int size = atoi(response);
  free(response);
  return size;
}

static int monolith_fs_getattr(const char *path, struct stat *stbuf, struct fuse_file_info *fi)
{
  (void) fi;

  memset(stbuf, 0, sizeof(struct stat));

  int entity_type = get_entity_type(path);

  if (entity_type == 0) {
    // 0 is a not found
    return -ENOENT;
  }
  else if (entity_type == 1) {
    // 1 is a file
    stbuf->st_mode = S_IFREG | ( check_file_writable(path) ? 0755 : 0555 ); // TODO -- makes all files executable (not ideal -- should pass through underlying permission)
    stbuf->st_nlink = 1;
    stbuf->st_size = get_file_size(path);
    return 0;
  }
  else if (entity_type == 2) {
    stbuf->st_mode = S_IFSOCK | 0755;
    stbuf->st_nlink = 1;
    stbuf->st_size = 0; // Unix domain sockets typically have zero size
    return 0;
  }
  else if (entity_type == 3) {
    // 3 is a directory
    stbuf->st_mode = S_IFDIR | 0755;
    stbuf->st_nlink = 2;
    return 0;
  }
  return -1; // fail
}

static int monolith_fs_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
       off_t offset, struct fuse_file_info *fi,
       enum fuse_readdir_flags flags)
{
  (void) offset;
  (void) fi;
  (void) flags;

  if ( !check_exists(path) ) {
    return -ENOENT;
  }

  char *response = send_request("read_dir", path);
  cJSON *array = cJSON_Parse(response);
  free(response);

  int count = cJSON_GetArraySize(array);

  // standard
  filler(buf, ".", NULL, 0, 0);
  filler(buf, "..", NULL, 0, 0);

  // add each filename from response
  for (int i = 0; i < count; i++)
  {
    cJSON *item = cJSON_GetArrayItem(array, i);
    char *filename = strdup(item->valuestring);
    filler(buf, filename, NULL, 0, 0);
    free(filename);
  }

  cJSON_Delete(array);

  return 0;
}

static int monolith_fs_open(const char *path, struct fuse_file_info *fi)
{
  if ( !check_exists(path) ) {
    return -ENOENT;
  }

  if ( !check_file_writable(path) ) {
    // Enforce read only on open
    if ((fi->flags & O_ACCMODE) != O_RDONLY) {
      return -EACCES;
    }
  }

  return 0;
}

static int monolith_fs_read(const char *path, char *buf, size_t size, off_t offset, struct fuse_file_info *fi)
{
  size_t len;
  (void) fi;

  if ( !check_exists(path) ) {
    return -ENOENT;
  }

  len = (size_t)get_file_size(path);

  if (offset < len) {
    if (offset + size > len) {
      size = len - offset;
    }

    // Get the base64-encoded response from the backend
    char* response = send_request_with("read_file", path, offset, size, "");

    // Parse the JSON response to get the base64-encoded data
    cJSON *json_data = cJSON_Parse(response);
    if (!json_data) {
      free(response);
      return -EIO;
    }

    // Extract the base64-encoded string
    const char* base64_data = cJSON_GetStringValue(json_data);
    if (!base64_data) {
      cJSON_Delete(json_data);
      free(response);
      return -EIO;
    }

    // Decode the base64 data
    size_t decoded_length;
    unsigned char* decoded_data = base64_decode(base64_data, strlen(base64_data), &decoded_length);

    if (!decoded_data || decoded_length < size) {
      free(decoded_data);
      cJSON_Delete(json_data);
      free(response);
      return -EIO;
    }

    // Copy the decoded binary data to the buffer
    memcpy(buf, decoded_data, size);

    // Clean up
    free(decoded_data);
    cJSON_Delete(json_data);
    free(response);
  }
  else {
    size = 0;
  }

  return size;
}

static int monolith_fs_write(const char *path, const char *buf, size_t size, off_t offset, struct fuse_file_info *fi)
{
  (void) fi;

  // Ensure the file exists
  if ( !check_exists(path) ) {
    return -ENOENT;
  }

  // Calculate base64 encoded length and allocate buffer
  size_t encoded_len = ((size + 2) / 3) * 4;
  uint8_t *encoded_buf = malloc(encoded_len + 1); // +1 for null terminator
  if (!encoded_buf) {
    return -ENOMEM;
  }

  // Encode binary data to base64
  size_t actual_len;
  int encode_result = base64_encode(encoded_buf, encoded_len, &actual_len,
                                   (const uint8_t*)buf, size);
  if (encode_result != 0) {
    free(encoded_buf);
    return -EIO;
  }

  // Null-terminate the encoded string
  encoded_buf[actual_len] = '\0';

  // Prepare buffer as a JSON string for transmission
  // Using cJSON to encode the base64 string safely
  cJSON *data = cJSON_CreateString((const char*)encoded_buf);
  char *payload = cJSON_PrintUnformatted(data);

  // Send the write request
  char *response = send_request_with("write_file", path, offset, 0, payload);

  // Clean up
  free(encoded_buf);
  cJSON_Delete(data);
  free(payload);

  // Interpret response: if success, response should be the number of bytes actually written
  bool success = strcmp(response, "1") == 0;
  free(response);

  int written = 0;
  if (success) {
    written = (int)size;
  }
  else {
    return -EIO;
  }

  return written;
}


static int monolith_fs_create(const char *path, mode_t mode, struct fuse_file_info *fi)
{
  (void) mode; // You might want to pass this to your backend

  // Send request to create file
  char *response = send_request("create_file", path);
  bool success = strcmp(response, "1") == 0;
  free(response);

  if (success) {
    // File created successfully, now we can "open" it
    fi->fh = 0; // You might want to set a file handle here
    return 0;
  }
  else {
    return -EIO;
  }
}

static int monolith_fs_mkdir(const char *path, mode_t mode)
{
  (void) mode; // You might want to pass this to your backend if needed

  // Check if parent directory exists (optional, depending on your backend)
  // You might want to validate the parent path exists first

  // Send request to create directory
  char *response = send_request("mkdir", path);
  bool success = strcmp(response, "1") == 0;
  free(response);

  if (success) {
    return 0; // Success
  }
  else {
    return -EIO; // I/O error, or you might want to return a more specific error
  }
}

static int monolith_fs_unlink(const char *path)
{
  // Check if the file exists before attempting to unlink
  if (!check_exists(path)) {
    return -ENOENT;
  }

  // Send request to delete the file
  char *response = send_request("unlink", path);
  bool success = strcmp(response, "1") == 0;
  free(response);

  if (success) {
    return 0; // Success
  }
  else {
    return -EIO; // I/O error or operation failed
  }
}

static int monolith_fs_rmdir(const char *path)
{
  // Check if the directory exists before attempting to remove
  if (!check_exists(path)) {
    return -ENOENT;
  }

  // Send request to remove the directory
  char *response = send_request("rmdir", path);
  bool success = strcmp(response, "1") == 0;
  free(response);

  if (success) {
    return 0; // Success
  }
  else {
    return -EIO; // I/O error or operation failed
  }
}

static int monolith_fs_rename(const char *from, const char *to, unsigned int flags)
{
  // Check if the source file/directory exists
  if (!check_exists(from)) {
    return -ENOENT;
  }

  // Handle RENAME_NOREPLACE flag
  if (flags & RENAME_NOREPLACE) {
    // Don't overwrite if target exists
    if (check_exists(to)) {
      return -EEXIST;
    }
  }

  // Handle RENAME_EXCHANGE flag
  if (flags & RENAME_EXCHANGE) {
    // Both files must exist for exchange
    if (!check_exists(to)) {
      return -ENOENT;
    }
    // Send exchange request to backend
    char *response = send_request_with("rename_exchange", from, 0, 0, to); // TODO IMPLEMENT rename_exchange on dart side
    bool success = strcmp(response, "1") == 0;
    free(response);

    if (success) {
      return 0;
    }
    else {
      return -EIO;
    }
  }

  // Standard rename operation
  char *response = send_request_with("rename", from, 0, 0, to);
  bool success = strcmp(response, "1") == 0;
  free(response);

  if (success) {
    return 0; // Success
  }
  else {
    return -EIO; // I/O error or operation failed
  }
}

static int monolith_fs_chmod(const char *path, mode_t mode, struct fuse_file_info *fi)
{
  (void) fi; // May be NULL for path-based chmod operations

  // Check if the file exists
  if (!check_exists(path)) {
    return -ENOENT;
  }

  // Send request to change permissions
  return 0; // Success TODO properly implement chmod
  /*char *response = send_request_with("chmod", path, 0, mode, "");
  bool success = strcmp(response, "1") == 0;
  free(response);

  if (success) {
    return 0; // Success
  }
  else {
    return -EIO; // I/O error
  }*/
}

static int monolith_fs_truncate(const char *path, off_t size, struct fuse_file_info *fi)
{
  (void) fi; // May be NULL for path-based truncate operations

  // Check if the file exists
  if (!check_exists(path)) {
    return -ENOENT;
  }

  // Check if the file is writable
  if (!check_file_writable(path)) {
    return -EACCES;
  }

  // Send request to truncate the file
  char *response = send_request_with("truncate", path, size, 0, "");
  bool success = strcmp(response, "1") == 0;
  free(response);

  if (success) {
    return 0; // Success
  }
  else {
    return -EIO; // I/O error
  }
}

static const struct fuse_operations monolith_fs_oper = {
  .init = monolith_fs_init,
  .getattr = monolith_fs_getattr,
  .readdir = monolith_fs_readdir,
  .open = monolith_fs_open,
  .read = monolith_fs_read,
  .write = monolith_fs_write,
  .create = monolith_fs_create,
  .mkdir = monolith_fs_mkdir,
  .unlink = monolith_fs_unlink,
  .rmdir = monolith_fs_rmdir,
  .rename = monolith_fs_rename,
  .chmod = monolith_fs_chmod,
  .truncate = monolith_fs_truncate
};

int main(int argc, char *argv[])
{
  char *mountpoint = argv[1];
  int ret;
  /* set -s to keep single threaded, -f to run in foreground */
  char *fuse_args_list[4] = {"self", "-s", "-f", mountpoint};
  struct fuse_args args = FUSE_ARGS_INIT(4, fuse_args_list);

  ret = fuse_main(args.argc, args.argv, &monolith_fs_oper, NULL);
  fuse_opt_free_args(&args);
  return ret;
}