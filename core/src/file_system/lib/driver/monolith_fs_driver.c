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
    // TODO -- makes all files executable (not ideal -- should pass through underlying permission)
    stbuf->st_mode = S_IFREG | ( check_file_writable(path) ? 0755 : 0555 );
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

  filler(buf, ".", NULL, 0, 0);
  filler(buf, "..", NULL, 0, 0);

  char *token;
  char *rest = response;
  while ((token = strtok_r(rest, "\n", &rest))) {
    filler(buf, token, NULL, 0, 0);
  }

  free(response);
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
  (void) fi;

  if ( !check_exists(path) ) {
    return -ENOENT;
  }

  ssize_t bytes_read = send_request_for_binary("read_file", path, (int)offset, (int)size, "", buf, size);

  if (bytes_read < 0) {
    return -EIO;
  }
  
  // The number of bytes read is returned directly.
  return (int)bytes_read;
}

static int monolith_fs_write(const char *path, const char *buf, size_t size, off_t offset, struct fuse_file_info *fi)
{
  (void) fi;

  // Ensure the file exists
  if ( !check_exists(path) ) {
    return -ENOENT;
  }
  
  // We send the raw FUSE buffer 'buf' directly.
  char *response = send_binary_request("write_file", path, (int)offset, 0, buf, (uint32_t)size);

  bool success = strcmp(response, "1") == 0;
  free(response);

  if (success) {
    return (int)size;
  }
  else {
    return -EIO;
  }
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
    // TODO IMPLEMENT rename_exchange on dart side
    char *response = send_string_request("rename_exchange", from, 0, 0, to);
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
  char *response = send_string_request("rename", from, 0, 0, to);
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
  char *response = send_string_request("truncate", path, (int)size, 0, "");
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