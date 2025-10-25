
/** @fileoverview Any entity path containing one of these segments is considered special
 *                and cannot be used to set an entity attribute.
 */

const Set<String> special_entity_path_segments = {".monolith", ".git"};
