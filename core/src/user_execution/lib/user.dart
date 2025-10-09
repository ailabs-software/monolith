import "package:common/access_types.dart";

class User
{
  final String name;

  final UserAccessPrivilege privilege;

  User({
    required String this.name,
    required UserAccessPrivilege this.privilege
  });
}
