
/** @fileoverview Any entity path containing one of these segments is considered special
 *                and cannot be used to set an entity attribute.
 *
 *                These directories are hidden from the monolith file system.
 *                This means that git must operate underneath monolith (as a trusted command not chrooted into monolith).
 */

const Set<String> special_entity_path_segments = {".monolith", ".git"};
