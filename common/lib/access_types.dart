
// the access level of a given file or directory
enum EntityAccessLevel
{
  invisible, // entity invisible to a user in standard access mode
  opaque,    // entity opaque to a user in standard access mode
  readable,  // entity readable to a user in standard access mode
  writable   // entity writable to a user in standard access mode (implies readable)
}

const EntityAccessLevel DEFAULT_ENTITY_ACCESS_LEVEL = EntityAccessLevel.opaque; // default to opaque

// a file created under standard access should be readable & writable by standard access.
const EntityAccessLevel STANDARD_ACCESS_CREATED_FILE_INITIAL_ACCESS_LEVEL = EntityAccessLevel.writable;

typedef EntityAccessLevel AccessLevelRule(EntityAccessLevel fileAccessLevel);

EntityAccessLevel _rootAccessLevelRule(EntityAccessLevel fileAccessLevel)
{
  return EntityAccessLevel.writable; // root always has access mode of writable
}

EntityAccessLevel _standardAccessLevelRule(EntityAccessLevel fileAccessLevel)
{
  return fileAccessLevel; // results in an access mode matching the file's access level
}

// the privilege level of the current user
enum UserAccessPrivilege
{
  bare(accessLevelRule: _rootAccessLevelRule), // bare bypasses chroot in monolith FS, reads from source path directly (used for trusted executables)
  root(accessLevelRule: _rootAccessLevelRule), // access within chroot, but able to see all files
  standard(accessLevelRule: _standardAccessLevelRule); // access within chroot, certain files seen only

  final AccessLevelRule accessLevelRule;

  const UserAccessPrivilege({required AccessLevelRule this.accessLevelRule});
}
