import 'package:archery/archery/archery.dart';

/// Role model used for authorization and role-based access control.
///
/// A `Role` represents a named permission grouping that can be attached to
/// users through the user/role pivot table.
///
/// Example:
/// ```dart
/// final role = Role(name: 'admin');
/// print(role.name); // admin
/// ```
class Role extends Model with InstanceDatabaseOps<Role> {
  /// Role name.
  ///
  /// This is typically unique and used to resolve framework role checks.
  late String name;

  /// Optional human-readable description of the role.
  String? description;

  /// Creates a new role with the given [name].
  ///
  /// Example:
  /// ```dart
  /// final role = Role(name: 'staff');
  /// ```
  Role({required this.name}) : super.fromJson({});

  /// Creates a role model from a JSON map.
  ///
  /// Expected keys:
  /// - `name`
  /// - `description`
  ///
  /// Example:
  /// ```dart
  /// final role = Role.fromJson({
  ///   'name': 'owner',
  ///   'description': 'Full application access',
  /// });
  /// ```
  Role.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    name = json['name'];
    description = json['description'];
  }

  /// Database column definitions for persisted roles.
  ///
  /// The `name` field is required and unique. The `description` field is
  /// optional.
  ///
  /// Example:
  /// ```dart
  /// print(Role.columnDefinitions['name']); // TEXT NOT NULL UNIQUE
  /// ```
  static Map<String, String> columnDefinitions = {'name': 'TEXT NOT NULL UNIQUE', 'description': 'TEXT'};

  /// Serializes the role into its standard JSON representation.
  ///
  /// Example:
  /// ```dart
  /// final json = role.toJson();
  /// print(json['name']);
  /// ```
  @override
  Map<String, dynamic> toJson() {
    return { 'name': name, 'description': description};
  }

  /// Serializes the role into a metadata-oriented JSON map.
  ///
  /// Includes the database `id` and model `uuid`.
  ///
  /// Example:
  /// ```dart
  /// final meta = role.toMetaJson();
  /// print(meta['id']);
  /// print(meta['uuid']);
  /// ```
  @override
  Map<String, dynamic> toMetaJson() {
    return {'id': id, 'uuid': uuid, 'name': name, 'description': description};
  }

  /// Middleware that restricts access to users with the `admin` role.
  ///
  /// Requests from unauthenticated users or authenticated users without the
  /// admin role receive a forbidden response.
  ///
  /// Example:
  /// ```dart
  /// router.get(
  ///   '/admin',
  ///   handler: (request) async => adminController.index(request),
  ///   middleware: [Role.admin],
  /// );
  /// ```
  static Future<dynamic> admin(HttpRequest request, Future<void> Function() next) async {

    final user = await request.user;

    if (user == null) {
      return request.forbidden();
    }

    if (!await user.hasRole(.admin)) {
      return request.forbidden();
    }

    await next();
  }
}

/// Built-in role names used by the framework.
///
/// Example:
/// ```dart
/// final role = RoleType.admin;
/// print(role.name); // admin
/// ```
enum RoleType {
  /// Administrative role.
  admin,

  /// Owner role.
  owner,

  /// Staff role.
  staff,

  /// Guest role.
  guest;

  /// Returns the lowercase role name.
  ///
  /// Example:
  /// ```dart
  /// print(RoleType.staff.name); // staff
  /// ```
  String get name => toString().split('.').last.toLowerCase();

  /// Returns the default description for the role.
  ///
  /// Example:
  /// ```dart
  /// print(RoleType.owner.description);
  /// ```
  String get description => "This is the default '$name' role";
}


/// Role-assignment helpers attached to [User].
///
/// These helpers manage many-to-many user/role relationships through the
/// `UserRolePivotTable`.
///
/// Example:
/// ```dart
/// final hasAdmin = await user.hasRole(RoleType.admin);
/// ```
extension HasRole on User {

  /// Attaches the given [role] to the user.
  ///
  /// If the role record exists and the user does not already have it, the role
  /// is attached through the user/role pivot table.
  ///
  /// Returns `true` when the role is attached successfully.
  ///
  /// Example:
  /// ```dart
  /// await user.attachRole(RoleType.staff);
  /// ```
  Future<bool> attachRole(RoleType role, {DatabaseDisk disk = Model.defaultDisk}) async {
    final roleRecord = await Model.firstWhere<Role>(field: 'name', value: role.name);
    if (roleRecord != null) {
      if (!await hasRole(role)) {
        return attach(roleRecord, relationship: .belongsToMany, table: UserRolePivotTable(), disk: disk);
      }
      return false;
    }
    return false;
  }

  /// Detaches the given [role] from the user.
  ///
  /// If the role record exists and the user currently has it, the role is
  /// removed through the user/role pivot table.
  ///
  /// Returns `true` when the role is detached successfully.
  ///
  /// Example:
  /// ```dart
  /// await user.detachRole(RoleType.guest);
  /// ```
  Future<bool> detachRole(RoleType role, {DatabaseDisk disk = Model.defaultDisk}) async {
    final roleRecord = await Model.firstWhere<Role>(field: 'name', value: role.name);
    if (roleRecord != null) {
      if (await hasRole(role)) {
        return detach(roleRecord, relationship: .belongsToMany, table: UserRolePivotTable(), disk: disk);
      }
      return false;
    }
    return false;
  }

  /// Returns `true` when the user currently has the given [role].
  ///
  /// Example:
  /// ```dart
  /// if (await user.hasRole(RoleType.admin)) {
  ///   print('User can access admin routes');
  /// }
  /// ```
  Future<bool> hasRole(RoleType role) async {
    return (await roles).any((userRole) => userRole.name == role.name);
  }

  /// Returns this user serialized with resolved role data.
  ///
  /// The returned map contains this user's `toJson()` output plus a `roles`
  /// key.
  ///
  /// Example:
  /// ```dart
  /// final payload = await user.withRoles();
  /// print(payload['roles']);
  /// ```
  Future<Map<String, dynamic>> withRoles() async {
    return {...toJson(), 'roles': await roles};
  }

}