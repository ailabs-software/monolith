#!/bin/sh

# Function to setup proc filesystem inside a chroot directory  -- needed to execute dart vm for getting memory address space layout
setup_proc_dev_filesystem() {
  local mount_point="$1"

  # Create proc directory inside the mount point
  mkdir -p "$mount_point/proc"

  # Mount proc filesystem
  mount -t proc proc "$mount_point/proc"

  # Mount dev file system TODO check this is secure, not a hole. Use mknod instead with select devices.
  mkdir -p "$mount_point/dev"
  mount --bind /dev "$mount_point/dev"
}

# Function to setup a mount point with the specified access level
setup_mount_point() {
  local access_level="$1"
  local mount_point="/mnt/${access_level}_access"
  
  # Create mount point directory
  mkdir -p "$mount_point"
  
  # Start Dart AOT runtime with monolith file system in background
  $DART_AOT_RUNTIME "$CORE_PATH/bin/monolith_file_system.aot" "$mount_point" "$access_level" &

  # wait for monolith file system to be mounted before mounting proc
  sleep 3

  # Setup proc & dev filesystem inside the mount point
  setup_proc_dev_filesystem "$mount_point"
}

# Setup mount points for each access level
setup_mount_point "root"
setup_mount_point "standard"

# start the core's executor service
$DART_AOT_RUNTIME "$CORE_PATH/bin/user_execution_service.aot" &

