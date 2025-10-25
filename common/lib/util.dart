import "dart:io";
import "package:path/path.dart" as path_util;
import "package:glob/glob.dart";
import "package:glob/list_local_fs.dart";
import "package:common/constants/file_system_source_path.dart";
import "package:common/constants/special_entity_path_segments.dart";

// string helper to limit splitting to first N (count)
List<String> splitN(String string, Pattern pattern, int count)
{
  List<String> result = <String>[];
  if (count == 0) {
    return result;
  }
  int offset = 0;
  Iterable<Match> matches = pattern.allMatches(string);
  for (Match match in matches)
  {
    if (result.length + 1 == count) {
      break;
    }
    result.add(string.substring(offset, match.start));
    offset = match.end;
  }
  result.add( string.substring(offset) );
  return result;
}

// unlike path.join(), forcedPathJoin() avoids an absolute path breaking out
String safeJoinPaths(String base, String path)
{
  if (base == "") {
    return path;
  }
  // Remove any absolute property from dir by making it relative
  String relativeDir = path_util.relative(path, from: path_util.rootPrefix(path) );
  String fullPath = path_util.normalize( path_util.join(base, relativeDir) );
  if ( !( path_util.isWithin(base, fullPath) ||
          path_util.equals(base, fullPath)  ) ) {
    throw new Exception("monolith: Illegal path after join");
  }
  return fullPath;
}

// canonicalise the path
String getCanonicalPath(String path)
{
  // TODO -- test effect of symlinks on security enforcement -- or can user get around EAV
  // Resolve .. and . segments in a platform-consistent way first.
  return Uri.parse(".").resolveUri( new Uri.file(path) ).toFilePath();
}

// the path contains special segment
bool pathContainsSpecialSegment(String path)
{
  return path.split("/").any(special_entity_path_segments.contains);
}

Future< List<String> > getEntityPathsFromExpression(String expression) async
{
  return
    ( new Glob( (file_system_source_path + "/" + expression).replaceAll("//", "/") ).list() )
    .where( (FileSystemEntity e) => e is File )
    .where( (FileSystemEntity e) => !pathContainsSpecialSegment(e.path) ) // no special segment containing matched
    .map( (FileSystemEntity e) => ("/" + e.path.substring(file_system_source_path.length).replaceAll("//", "/") ) )
    .toList();
}
