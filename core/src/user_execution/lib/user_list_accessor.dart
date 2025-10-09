import "dart:convert";
import "dart:io";
import "package:user_execution/user.dart";
import "package:common/access_types.dart";

class UserListAccessor
{
  /** format:
   *  json map of auth strings to named access levels, e.g.:
   *  {
   *     ** key is a comma-separated user/password combination
   *    "admin:1234": "root",
   *    "ella:i-love-you": "root",
   *    "gavin:man-of-the-year": "standard",
   *    "shey:roadrunner": "standard"
   *  }
   *
   *  location:
   *   /opt/monolith/core/userlist.json
   */
  static final Map<String, User> _map = _loadUserList();

  static Map<String, User> _loadUserList()
  {
    File file = new File("/opt/monolith/core/userlist.json");
    Map<String, String> map = ( json.decode( file.readAsStringSync() ) as Map ).cast<String, String>();
    return {
      for (MapEntry<String, String> entry in map.entries)
        entry.key:
          new User(
            name: entry.key.split(":").first,
            privilege: UserAccessPrivilege.values.byName(entry.value)
          )
    };
  }

  /** @param authString -- in format of "user:password" */
  static bool getHasUserFromAuthString(String authString)
  {
    return _map.containsKey(authString);
  }

  /** @param authString -- in format of "user:password" */
  static User getUserFromAuthString(String authString)
  {
    if ( _map.containsKey(authString) ) {
      return _map[authString]!;
    }
    throw new Exception("No such user by auth string");
  }
}
